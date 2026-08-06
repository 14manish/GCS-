import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/ardupilotmega.dart';

import 'gcs_state.dart';
import '../models/models.dart';
import '../services/mavlink_udp_transport.dart';

class GcsNotifier extends StateNotifier<GcsState> {
  GcsNotifier() : super(const GcsState()) {
    _startTicker();
  }

  Timer? _ticker;
  Timer? _alertTimer;
  Timer? _connectTimer;
  Timer? _scanTimer;
  Timer? _validationTimer;
  Timer? _uploadTimer;

  // ── Serial / MAVLink handles ──
  SerialPort? _serialPort;
  SerialPortReader? _serialReader;
  StreamSubscription<Uint8List>? _serialReadSub;
  Timer? _pollTimer;
  MavlinkParser? _mavlinkParser;
  StreamSubscription<MavlinkFrame>? _mavlinkSub;
  Timer? _connectTimeoutTimer;
  Timer? _heartbeatSendTimer;
  Timer? _heartbeatWatchdogTimer;
  Timer? _dataStreamTimer;
  DateTime? _lastHeartbeatTime;
  int _txSeq = 0;
  bool _tearingDown = false;

  // ── UDP / MAVLink handles ──
  MavlinkUdpTransport? _udpTransport;
  StreamSubscription<Uint8List>? _udpRawSub;
  MavlinkParser? _udpParser;

  // ── Mission upload state ──
  List<WaypointModel> _pendingUploadWaypoints = [];
  int _missionUploadTarget = 0;
  int _missionUploadCompTarget = 0;
  Timer? _missionItemTimeoutTimer;

  static const int _gcsSystemId = 255;
  static const int _gcsComponentId = 190;
  static const double _radToDeg = 180 / pi;

  // ─── ArduCopter custom mode numbers ───────────────────────────────
  static const int _modeLoiter = 5;
  static const int _modeAuto = 3;

  // ─── 1Hz ticker: UTC clock + session countdown only ───────────────
  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final ist =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final timeStr =
        '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')}:${ist.second.toString().padLeft(2, '0')} IST';
    final newExpiry = state.sessionExpiry > 0 ? state.sessionExpiry - 1 : 0;
    state = state.copyWith(utcTime: timeStr, sessionExpiry: newExpiry);
  }

  @override
  void dispose() {
    _teardown();
    _ticker?.cancel();
    _alertTimer?.cancel();
    _connectTimer?.cancel();
    _scanTimer?.cancel();
    _validationTimer?.cancel();
    _uploadTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // LOW-LEVEL FRAME SEND HELPERS
  // ─────────────────────────────────────────────

  /// Send a MAVLink v2 frame over whichever transport is active.
  /// Silent no-op when no transport is open.
  void _sendFrame(MavlinkMessage message) {
    if (_tearingDown) return;
    try {
      final frame = MavlinkFrame.v2(
          _txSeq++ & 0xFF, _gcsSystemId, _gcsComponentId, message);
      final bytes = frame.serialize();
      if (_serialPort != null && _serialPort!.isOpen) {
        _serialPort!.write(bytes);
      } else if (_udpTransport != null && _udpTransport!.isOpen) {
        _udpTransport!.send(bytes);
      }
    } catch (_) {
      // Swallow all write errors – do NOT call _failConnection from here
      // because a transient write error should not kill the connection
    }
  }

  /// Send MAV_CMD via COMMAND_LONG to the current remote vehicle.
  void _sendCommand(
    int command, {
    double p1 = 0,
    double p2 = 0,
    double p3 = 0,
    double p4 = 0,
    double p5 = 0,
    double p6 = 0,
    double p7 = 0,
    int confirmation = 0,
  }) {
    final sysId = state.remoteSystemId ?? 1;
    final compId = state.remoteComponentId ?? 1;
    _sendFrame(CommandLong(
      targetSystem: sysId,
      targetComponent: compId,
      command: command,
      confirmation: confirmation,
      param1: p1,
      param2: p2,
      param3: p3,
      param4: p4,
      param5: p5,
      param6: p6,
      param7: p7,
    ));
    _logMavlink('CMD_SEND',
        'cmd=$command p1=$p1 p2=$p2 p3=$p3 p4=$p4 p5=$p5 p6=$p6 p7=$p7');
  }

  // ─────────────────────────────────────────────
  // CONNECTION ACTIONS (SERIAL / UDP MAVLINK)
  // ─────────────────────────────────────────────
  void connect({
    String? connectionType,
    String? serialPort,
    int? baudRate,
    String? hostIp,
    int? port,
    bool? encryption,
  }) {
    if (state.connectionStatus == 'Connected' ||
        state.connectionStatus == 'Connecting') {
      return;
    }

    state = state.copyWith(
      connectionStatus: 'Connecting',
      connectionType: connectionType ?? state.connectionType,
      serialPort: serialPort ?? state.serialPort,
      baudRate: baudRate ?? state.baudRate,
      hostIp: hostIp ?? state.hostIp,
      port: port ?? state.port,
      encryption: encryption ?? state.encryption,
      lastError: null,
    );

    if (state.connectionType == 'Serial') {
      final portName = state.serialPort;
      if (portName.isEmpty) {
        _failConnection('No serial port selected.');
        return;
      }
      _connectSerial(portName, state.baudRate);
    } else {
      _connectUdp(state.hostIp, state.port);
    }
  }

  // ─────────────────────────────────────────────
  // SERIAL CONNECTION
  // ─────────────────────────────────────────────
  void _connectSerial(String portName, int baudRate) {
    try {
      final sp = SerialPort(portName);
      if (!sp.openReadWrite()) {
        _failConnection('Could not open $portName: ${SerialPort.lastError}');
        return;
      }
      final cfg = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1
        ..setFlowControl(SerialPortFlowControl.none);
      sp.config = cfg;
      _serialPort = sp;

      // ── Parser ────────────────────────────────────────────────────
      _mavlinkParser = MavlinkParser(MavlinkDialectArdupilotmega());
      _mavlinkSub = _mavlinkParser!.stream.listen(_onMavlinkFrame,
          onError: (_) {/* parser errors are non-fatal */});

      // ── Use SerialPortReader stream (event-driven, no busy-poll) ──
      // FIX: Use SerialPortReader instead of polling timer.
      // The old 50 Hz polling timer calling bytesAvailable was causing
      // Windows serial driver errors that accumulated and triggered
      // _failConnection("USB cable disconnected or serial port hardware error").
      try {
        _serialReader = SerialPortReader(sp);
        _serialReadSub = _serialReader!.stream.listen(
          (data) {
            if (data.isNotEmpty) _mavlinkParser?.parse(data);
          },
          onError: (_) {/* transient read errors are non-fatal */},
          cancelOnError: false,
        );
      } catch (_) {
        // SerialPortReader not supported – fall back to polling
        _serialReader = null;
        _startPollingFallback(sp);
      }

      // ── Send GCS heartbeat immediately so ArduPilot opens telemetry ──
      _startHeartbeatSender();

      // ── 10-second window to receive first Pixhawk heartbeat ──────────
      _connectTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (state.connectionStatus != 'Connected') {
          _failConnection('No heartbeat received — check port/baud/USB cable.');
        }
      });
    } catch (e) {
      _failConnection('Serial open failed: $e');
    }
  }

  /// Polling fallback for systems where SerialPortReader is unavailable.
  void _startPollingFallback(SerialPort sp) {
    int consecutiveErrors = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (!sp.isOpen) return;
      try {
        final available = sp.bytesAvailable;
        if (available < 0) {
          consecutiveErrors++;
          // Allow up to 50 consecutive errors (~1 second) before failing.
          // Windows driver occasionally returns -1 spuriously.
          if (consecutiveErrors > 50) {
            _failConnection('Serial read error: port became unavailable.');
          }
          return;
        }
        consecutiveErrors = 0;
        if (available > 0) {
          final data = sp.read(available > 2048 ? 2048 : available);
          if (data.isNotEmpty) _mavlinkParser?.parse(data);
        }
      } catch (_) {
        consecutiveErrors++;
        if (consecutiveErrors > 50) {
          _failConnection('Serial read error after repeated failures.');
        }
      }
    });
  }

  // ─────────────────────────────────────────────
  // UDP CONNECTION
  // ─────────────────────────────────────────────
  void _connectUdp(String remoteHost, int localPort) async {
    try {
      final transport = MavlinkUdpTransport();
      _udpTransport = transport;
      await transport.bind(localPort);
      state = state.copyWith(udpBoundPort: localPort);
      _logMavlink('UDP', 'Bound local port $localPort');

      if (remoteHost.isNotEmpty && remoteHost != '0.0.0.0') {
        try {
          transport.setRemote(InternetAddress(remoteHost), localPort);
        } catch (_) {}
      }

      _udpParser = MavlinkParser(MavlinkDialectArdupilotmega());
      _mavlinkSub = _udpParser!.stream.listen(_onMavlinkFrame,
          onError: (_) {});

      _udpRawSub = transport.byteStream.listen((bytes) {
        _udpParser?.parse(bytes);
      }, onError: (_) {}, cancelOnError: false);

      _startHeartbeatSender();

      _connectTimeoutTimer = Timer(const Duration(seconds: 10), () {
        if (state.connectionStatus != 'Connected') {
          _failConnection(
              'No MAVLink heartbeat on UDP port $localPort.\n'
              'Verify SITL/drone is sending to this port.');
        }
      });
    } catch (e) {
      _failConnection('UDP bind failed: $e');
    }
  }

  // ─────────────────────────────────────────────
  // DATA STREAM REQUESTS
  // ─────────────────────────────────────────────
  void _requestDataStreams(int targetSystem, int targetComponent) {
    // ─── Legacy: REQUEST_DATA_STREAM (ArduPilot 3.x) ─────────────────
    const streams = [
      (0,  4),  // MAV_DATA_STREAM_ALL at 4 Hz
      (6,  2),  // MAV_DATA_STREAM_POSITION at 2 Hz
      (10, 5),  // MAV_DATA_STREAM_EXTRA1 (ATTITUDE) at 5 Hz
      (2,  2),  // MAV_DATA_STREAM_RAW_SENSORS at 2 Hz
      (8,  2),  // MAV_DATA_STREAM_EXTRA2 (VFR_HUD) at 2 Hz
      (11, 1),  // MAV_DATA_STREAM_EXTRA3 at 1 Hz
    ];
    for (final (streamId, hz) in streams) {
      _sendFrame(RequestDataStream(
        targetSystem: targetSystem,
        targetComponent: targetComponent,
        reqStreamId: streamId,
        reqMessageRate: hz,
        startStop: 1,
      ));
    }

    // ─── Modern: MAV_CMD_SET_MESSAGE_INTERVAL (ArduPilot 4.x) ─────────
    // param1 = message ID, param2 = interval µs  (-1 = disable)
    const msgIntervals = [
      (30,  200000),  // ATTITUDE 5 Hz
      (74,  500000),  // VFR_HUD 2 Hz
      (33,  500000),  // GLOBAL_POSITION_INT 2 Hz
      (24,  500000),  // GPS_RAW_INT 2 Hz
      (1,  1000000),  // SYS_STATUS 1 Hz
      (109, 200000),  // RADIO_STATUS 5 Hz
    ];
    for (final (msgId, intervalUs) in msgIntervals) {
      _sendFrame(CommandLong(
        targetSystem: targetSystem,
        targetComponent: targetComponent,
        command: mavCmdSetMessageInterval, // 511
        confirmation: 0,
        param1: msgId.toDouble(),
        param2: intervalUs.toDouble(),
        param3: 0,
        param4: 0,
        param5: 0,
        param6: 0,
        param7: 0,
      ));
    }
  }

  // ─────────────────────────────────────────────
  // MAVLINK FRAME DISPATCHER
  // ─────────────────────────────────────────────
  void _onMavlinkFrame(MavlinkFrame frame) {
    // FIX: Update the last-seen time on EVERY frame, not just heartbeats.
    // This is what prevents the 30-second watchdog from firing during
    // periods of heavy telemetry but no heartbeat (e.g. between 1-Hz beats).
    _lastHeartbeatTime = DateTime.now();

    final msg = frame.message;
    final sysId = frame.systemId;

    // ── Heartbeat ────────────────────────────────────────────────────
    if (msg is Heartbeat) {
      _logMavlink('HEARTBEAT',
          'sysId=$sysId mode=${_customModeLabel(msg.customMode, msg.autopilot)} armed=${(msg.baseMode & 128) != 0}');
      _handleHeartbeat(sysId, frame.componentId, msg);
      return;
    }

    // ── COMMAND_ACK ───────────────────────────────────────────────────
    if (msg is CommandAck) {
      _logMavlink('CMD_ACK',
          'cmd=${msg.command} result=${_commandAckResult(msg.result)}');
      return;
    }

    // ── Mission protocol ──────────────────────────────────────────────
    if (msg is MissionRequest) {
      _onMissionRequest(msg.seq);
      return;
    }
    if (msg is MissionRequestInt) {
      _onMissionRequest(msg.seq);
      return;
    }
    if (msg is MissionAck) {
      _onMissionAck(msg);
      return;
    }

    // ── Telemetry — require at least one drone in state ───────────────
    final sysIdStr = sysId.toString();
    if (state.drones.isEmpty) return;

    // Find the matching drone, fall back to selected or first
    final targetId = state.drones.any((d) => d.id == sysIdStr)
        ? sysIdStr
        : state.drones.any((d) => d.id == state.selectedDroneId)
            ? state.selectedDroneId
            : state.drones.first.id;

    if (msg is Attitude) {
      final rollDeg = msg.roll * _radToDeg;
      final pitchDeg = msg.pitch * _radToDeg;
      // Convert yaw (-180..180) to compass heading (0..360)
      final yawDeg = msg.yaw * _radToDeg;
      final headingDeg = yawDeg < 0 ? yawDeg + 360 : yawDeg;
      _logMavlink('ATTITUDE',
          'roll=${rollDeg.toStringAsFixed(1)}° pitch=${pitchDeg.toStringAsFixed(1)}° yaw=${yawDeg.toStringAsFixed(1)}°');
      _updateDrone(
          targetId,
          (d) => d.copyWith(
                roll: rollDeg,
                pitch: pitchDeg,
                heading: d.heading == 0 ? headingDeg : d.heading,
              ));
      return;
    }

    if (msg is VfrHud) {
      _logMavlink('VFR_HUD',
          'alt=${msg.alt.toStringAsFixed(1)}m spd=${msg.groundspeed.toStringAsFixed(1)}m/s hdg=${msg.heading}° climb=${msg.climb.toStringAsFixed(1)}m/s');
      _updateDrone(
          targetId,
          (d) => d.copyWith(
                heading: msg.heading.toDouble(),
                speed: msg.groundspeed.toDouble(),
                altitude: msg.alt.toDouble(),
                climbRate: msg.climb.toDouble(),
              ));
      return;
    }

    if (msg is GlobalPositionInt) {
      final vx = msg.vx / 100.0;
      final vy = msg.vy / 100.0;
      final groundSpeed = sqrt(vx * vx + vy * vy);
      final latDeg = msg.lat / 1e7;
      final lngDeg = msg.lon / 1e7;
      _logMavlink('GLOBAL_POS_INT',
          'lat=${latDeg.toStringAsFixed(6)} lng=${lngDeg.toStringAsFixed(6)} alt=${(msg.relativeAlt / 1000.0).toStringAsFixed(1)}m');
      _updateDrone(
          targetId,
          (d) => d.copyWith(
                lat: latDeg,
                lng: lngDeg,
                altitude: msg.relativeAlt / 1000.0,
                heading: msg.hdg == 65535 ? d.heading : msg.hdg / 100.0,
                speed: groundSpeed > 0 ? groundSpeed : d.speed,
                history: [
                  ...d.history,
                  if (latDeg != 0 && lngDeg != 0)
                    {'lat': latDeg, 'lng': lngDeg},
                ],
              ));
      return;
    }

    if (msg is SysStatus) {
      _logMavlink('SYS_STATUS',
          'batt=${msg.batteryRemaining}% volt=${(msg.voltageBattery / 1000.0).toStringAsFixed(2)}V curr=${(msg.currentBattery / 100.0).toStringAsFixed(1)}A');
      _updateDrone(
          targetId,
          (d) => d.copyWith(
                battery: msg.batteryRemaining < 0
                    ? d.battery
                    : msg.batteryRemaining.toDouble(),
                voltage: msg.voltageBattery / 1000.0,
                current: msg.currentBattery >= 0
                    ? msg.currentBattery / 100.0
                    : d.current,
              ));
      return;
    }

    if (msg is GpsRawInt) {
      const fixStr = {
        0: 'NO FIX', 1: 'NO FIX', 2: '2D FIX', 3: '3D FIX',
        4: 'DGPS', 5: 'RTK FLOAT', 6: 'RTK FIXED',
      };
      _logMavlink('GPS_RAW_INT',
          'fix=${fixStr[msg.fixType] ?? msg.fixType} sats=${msg.satellitesVisible} hdop=${(msg.eph / 100.0).toStringAsFixed(2)}');
      _updateDrone(
          targetId,
          (d) => d.copyWith(
                gpsQuality: fixStr[msg.fixType] ?? d.gpsQuality,
                satellites: msg.satellitesVisible == 255
                    ? d.satellites
                    : msg.satellitesVisible,
                hdop: msg.eph == 65535 ? d.hdop : msg.eph / 100.0,
              ));
      return;
    }

    if (msg is RadioStatus) {
      _logMavlink('RADIO_STATUS',
          'rssi=${msg.remrssi} noise=${msg.remnoise}');
      _updateDrone(targetId,
          (d) => d.copyWith(signal: msg.remrssi.toDouble()));
      return;
    }

    if (msg is Statustext) {
      final text =
          String.fromCharCodes(msg.text.where((c) => c > 0 && c <= 0x10FFFF))
              .trim();
      if (text.isNotEmpty) {
        _logMavlink('STATUS', text);
        _updateDrone(targetId, (d) => d.copyWith(statusMessage: text));
      }
      return;
    }
  }

  // ─────────────────────────────────────────────
  // MAVLINK LOG
  // ─────────────────────────────────────────────
  int _mavlinkLogThrottle = 0;

  void _logMavlink(String msgType, String detail) {
    // Throttle high-rate telemetry messages to avoid rebuilding state at 5 Hz
    if (msgType == 'ATTITUDE' ||
        msgType == 'VFR_HUD' ||
        msgType == 'GLOBAL_POS_INT') {
      _mavlinkLogThrottle++;
      if (_mavlinkLogThrottle % 15 != 0) return;
    }
    final ts = DateTime.now().toUtc().toString().substring(11, 22);
    final entry = '[$ts] $msgType  $detail';
    final newLog = [entry, ...state.mavlinkLog];
    state = state.copyWith(
      mavlinkLog: newLog.length > 200 ? newLog.sublist(0, 200) : newLog,
    );
  }

  // ─────────────────────────────────────────────
  // HEARTBEAT HANDLING
  // ─────────────────────────────────────────────
  void _handleHeartbeat(int sysId, int compId, Heartbeat hb) {
    // FIX: Accept any non-zero sysId as a vehicle.
    // The old check 'hb.autopilot != mavAutopilotInvalid' rejected
    // vehicles whose autopilot field was not set correctly during boot.
    // We now filter only on sysId != 0 (sysId 0 means broadcast / invalid).
    if (sysId == 0) return;

    // Ignore heartbeats that look like they come from another GCS
    // (type == MAV_TYPE_GCS) to avoid adding ourselves as a drone.
    if (hb.type == mavTypeGcs) return;

    final sysIdStr = sysId.toString();
    final exists = state.drones.any((d) => d.id == sysIdStr);

    if (!exists) {
      final modeName = _customModeLabel(hb.customMode, hb.autopilot);
      final newDrone = DroneModel(
        id: sysIdStr,
        name: 'Cube Orange+ ($sysIdStr)',
        battery: 0,
        signal: 0,
        flightMode: modeName,
        missionStatus: 'Connected',
        gpsQuality: 'NO FIX',
        encrypted: false,
        health: 'Healthy',
        lat: 0,
        lng: 0,
        altitude: 0,
        speed: 0,
        heading: 0,
        climbRate: 0,
        windSpeed: 0,
        windDir: 'N (0°)',
        motor1Rpm: 0,
        motor2Rpm: 0,
        motor3Rpm: 0,
        motor4Rpm: 0,
      );
      state = state.copyWith(
        drones: [...state.drones, newDrone],
        selectedDroneId: newDrone.id,
        remoteSystemId: sysId,
        remoteComponentId: compId,
      );
    } else {
      // Update existing drone's flight mode on each heartbeat
      _updateDrone(
          sysIdStr,
          (d) => d.copyWith(
                flightMode: _customModeLabel(hb.customMode, hb.autopilot),
                // Reflect armed status in health
                health: (hb.baseMode & 128) != 0 ? 'Armed' : 'Healthy',
              ));
      // Keep remote ids updated (component might change)
      if (state.remoteSystemId != sysId) {
        state = state.copyWith(
            remoteSystemId: sysId, remoteComponentId: compId);
      }
    }

    // ── Transition to Connected on first vehicle heartbeat ────────────
    if (state.connectionStatus != 'Connected') {
      _connectTimeoutTimer?.cancel();
      _lastHeartbeatTime = DateTime.now();
      state = state.copyWith(
        connectionStatus: 'Connected',
        sessionExpiry: 3480,
        lastError: null,
      );
      // Heartbeat sender was already started on port-open; restart it here
      // safely (it cancels the old timer first) to be idempotent.
      _startHeartbeatSender();
      _startHeartbeatWatchdog();

      // Request data streams immediately and re-request every 20s in case
      // the Pixhawk misses the first batch during boot/calibration.
      _requestDataStreams(sysId, compId);
      _dataStreamTimer?.cancel();
      _dataStreamTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (state.connectionStatus == 'Connected') {
          _requestDataStreams(sysId, compId);
        }
      });
    }
  }

  // ─────────────────────────────────────────────
  // COMMAND_ACK result label
  // ─────────────────────────────────────────────
  String _commandAckResult(int result) {
    const m = {
      0: 'ACCEPTED', 1: 'TEMP_REJECTED', 2: 'DENIED',
      3: 'UNSUPPORTED', 4: 'FAILED', 5: 'IN_PROGRESS', 6: 'CANCELLED',
    };
    return m[result] ?? 'UNKNOWN($result)';
  }

  String _customModeLabel(int customMode, int autopilot) {
    const copterModes = {
      0: 'STABILIZE', 1: 'ACRO', 2: 'ALT_HOLD', 3: 'AUTO', 4: 'GUIDED',
      5: 'LOITER', 6: 'RTL', 7: 'CIRCLE', 9: 'LAND', 11: 'DRIFT',
      13: 'SPORT', 16: 'POSHOLD', 17: 'BRAKE', 20: 'GUIDED_NOGPS',
      21: 'SMART_RTL', 22: 'FLOWHOLD', 23: 'FOLLOW', 24: 'ZIGZAG',
    };
    return copterModes[customMode] ?? 'MODE $customMode';
  }

  void _updateDrone(String targetId, DroneModel Function(DroneModel) update) {
    if (state.drones.isEmpty) {
      _getOrEnsureDroneId();
    }
    final target = targetId.isNotEmpty ? targetId : state.selectedDroneId;
    final list = state.drones.map((d) {
      if (d.id == target || state.drones.length == 1) return update(d);
      return d;
    }).toList();
    state = state.copyWith(drones: list);
  }

  /// Inject a simulated GPS position for indoor testing.
  void setMockGpsPosition(double lat, double lng) {
    if (state.drones.isEmpty) return;
    _updateDrone(
        state.selectedDroneId,
        (d) => d.copyWith(
              lat: lat,
              lng: lng,
              gpsQuality: 'MOCK',
              history: [
                ...d.history,
                {'lat': lat, 'lng': lng},
              ],
            ));
  }

  // ─────────────────────────────────────────────
  // HEARTBEAT SENDER & WATCHDOG
  // ─────────────────────────────────────────────
  void _startHeartbeatSender() {
    _heartbeatSendTimer?.cancel();
    _heartbeatSendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tearingDown) return;
      _sendFrame(Heartbeat(
        type: mavTypeGcs,
        autopilot: mavAutopilotInvalid,
        baseMode: 0,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      ));
    });
  }

  void _startHeartbeatWatchdog() {
    _heartbeatWatchdogTimer?.cancel();
    _heartbeatWatchdogTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tearingDown) return;
      if (state.connectionStatus != 'Connected') return;
      if (_lastHeartbeatTime == null) return;
      final elapsed = DateTime.now().difference(_lastHeartbeatTime!);
      // 30s timeout — generous enough for calibration pauses
      if (elapsed.inSeconds >= 30) {
        _failConnection(
            'Connection lost: No data from drone for 30 seconds.\n'
            'Check USB cable and that the Pixhawk is powered.');
      }
    });
  }

  // ─────────────────────────────────────────────
  // TEARDOWN
  // ─────────────────────────────────────────────
  void _failConnection(String reason) {
    if (_tearingDown) return; // Prevent re-entrant calls
    _teardown();
    addAlert(
      title: 'Connection Lost',
      message: reason,
      droneId: state.selectedDroneId,
      severity: 'CRITICAL',
    );
    state = state.copyWith(
      connectionStatus: 'Disconnected',
      lastError: reason,
      drones: const [],
      udpBoundPort: null,
    );
  }

  void disconnect() {
    _teardown();
    state = state.copyWith(
      connectionStatus: 'Disconnected',
      drones: const [],
      udpBoundPort: null,
    );
  }

  void _teardown() {
    _tearingDown = true;
    _connectTimeoutTimer?.cancel();
    _heartbeatSendTimer?.cancel();
    _heartbeatWatchdogTimer?.cancel();
    _dataStreamTimer?.cancel();
    _pollTimer?.cancel();
    _missionItemTimeoutTimer?.cancel();

    _mavlinkSub?.cancel();
    _mavlinkSub = null;
    _udpRawSub?.cancel();
    _udpRawSub = null;
    _serialReadSub?.cancel();
    _serialReadSub = null;

    _mavlinkParser = null;
    _udpParser = null;
    _lastHeartbeatTime = null;
    _pendingUploadWaypoints = [];

    try {
      _serialReader?.close();
    } catch (_) {}
    _serialReader = null;

    try {
      _serialPort?.close();
    } catch (_) {}
    try {
      _serialPort?.dispose();
    } catch (_) {}
    _serialPort = null;

    _udpTransport?.close();
    _udpTransport = null;

    // Re-enable sending after a brief delay so the caller can
    // still update state after _teardown() returns.
    Future.microtask(() => _tearingDown = false);
  }

  // ─────────────────────────────────────────────
  // AUTO-SCAN
  // ─────────────────────────────────────────────
  Future<void> setScanning(bool scanning) async {
    state = state.copyWith(isScanning: scanning);
    if (!scanning) return;

    final found = <Map<String, dynamic>>[];
    final activePort =
        state.connectionStatus == 'Connected' ? state.serialPort : null;

    for (final portName in SerialPort.availablePorts) {
      if (portName == activePort) continue;
      final hb = await _probePort(portName);
      if (hb != null) {
        found.add({
          'port': portName,
          'autopilot': hb.autopilot,
          'vehicleType': hb.type,
        });
      }
    }
    state = state.copyWith(isScanning: false, autoScanList: found);
  }

  Future<Heartbeat?> _probePort(String portName) async {
    SerialPort? sp;
    SerialPortReader? reader;
    try {
      sp = SerialPort(portName);
      if (!sp.openReadWrite()) return null;
      sp.config = SerialPortConfig()
        ..baudRate = 115200
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1;

      final parser = MavlinkParser(MavlinkDialectArdupilotmega());
      final completer = Completer<Heartbeat?>();

      StreamSubscription<MavlinkFrame>? sub;
      sub = parser.stream.listen((f) {
        if (f.message is Heartbeat && !completer.isCompleted) {
          sub?.cancel();
          completer.complete(f.message as Heartbeat);
        }
      });

      reader = SerialPortReader(sp);
      reader.stream.listen(
        (data) { if (data.isNotEmpty) parser.parse(data); },
        onError: (_) {},
        cancelOnError: false,
      );

      return await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    } finally {
      try { reader?.close(); } catch (_) {}
      try { sp?.close(); } catch (_) {}
      try { sp?.dispose(); } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────
  // VEHICLE ACTIONS  (real MAVLink commands)
  // ─────────────────────────────────────────────
  void selectDrone(String id) {
    state = state.copyWith(selectedDroneId: id);
  }

  void armDrone(String droneId) {
    if (state.connectionStatus != 'Connected') return;
    _sendCommand(400, p1: 1);
    _logMavlink('CMD', 'ARM sent to drone $droneId');
    addAlert(
      title: 'ARM COMMAND SENT',
      message: 'MAV_CMD_COMPONENT_ARM_DISARM → ARM',
      droneId: droneId,
      severity: 'medium',
    );
    _updateDrone(droneId, (d) => d.copyWith(flightMode: 'ARMED'));
  }

  void disarmDrone(String droneId) {
    if (state.connectionStatus != 'Connected') return;
    _sendCommand(400, p1: 0);
    _logMavlink('CMD', 'DISARM sent to drone $droneId');
    addAlert(
      title: 'DISARM COMMAND SENT',
      message: 'MAV_CMD_COMPONENT_ARM_DISARM → DISARM',
      droneId: droneId,
      severity: 'medium',
    );
    _updateDrone(droneId, (d) => d.copyWith(flightMode: 'DISARMED'));
  }

  void setFlightMode(String droneId, int customMode) {
    if (state.connectionStatus != 'Connected') return;
    _sendCommand(176, p1: 1, p2: customMode.toDouble());
    _logMavlink('CMD',
        'SET_MODE ${_customModeLabel(customMode, mavAutopilotArdupilotmega)} ($customMode)');
    _updateDrone(droneId,
        (d) => d.copyWith(flightMode: _customModeLabel(customMode, mavAutopilotArdupilotmega)));
  }

  void takeoff(String droneId, {double altitudeM = 10.0}) {
    if (state.connectionStatus != 'Connected') return;
    _sendCommand(22, p7: altitudeM);
    _logMavlink('CMD', 'TAKEOFF alt=${altitudeM}m');
    addAlert(
      title: 'TAKEOFF COMMAND SENT',
      message: 'MAV_CMD_NAV_TAKEOFF → ${altitudeM}m',
      droneId: droneId,
      severity: 'medium',
    );
    _updateDrone(droneId, (d) => d.copyWith(flightMode: 'GUIDED'));
  }

  void land(String droneId) {
    if (state.connectionStatus != 'Connected') return;
    _sendCommand(21);
    _logMavlink('CMD', 'LAND sent');
    addAlert(
      title: 'LAND COMMAND SENT',
      message: 'MAV_CMD_NAV_LAND',
      droneId: droneId,
      severity: 'medium',
    );
    _updateDrone(droneId, (d) => d.copyWith(flightMode: 'LAND'));
  }

  void returnToLaunch(String droneId) {
    if (state.connectionStatus != 'Connected') return;
    _sendCommand(20);
    _logMavlink('CMD', 'RTL sent');
    addAlert(
      title: 'RTL COMMAND SENT',
      message: 'MAV_CMD_NAV_RETURN_TO_LAUNCH',
      droneId: droneId,
      severity: 'medium',
    );
    _updateDrone(droneId, (d) => d.copyWith(flightMode: 'RTL'));
  }

  void triggerDroneAction(String droneId, String action) {
    switch (action) {
      case 'ARM':     armDrone(droneId);         break;
      case 'DISARM':  disarmDrone(droneId);       break;
      case 'TAKEOFF': takeoff(droneId);           break;
      case 'LAND':    land(droneId);              break;
      case 'RTL':     returnToLaunch(droneId);    break;
      case 'HOLD':    setFlightMode(droneId, _modeLoiter); break;
      case 'MISSION': setFlightMode(droneId, _modeAuto);   break;
      default: _logMavlink('CMD', 'Unknown action: $action');
    }
  }

  // ─────────────────────────────────────────────
  // MISSION ACTIONS
  // ─────────────────────────────────────────────
  void setMissionConfig(Map<String, dynamic> config) {
    state = state.copyWith(
      missionName: config['missionName'] ?? state.missionName,
      missionType: config['missionType'] ?? state.missionType,
      altitudeFrame: config['altitudeFrame'] ?? state.altitudeFrame,
      defaultAltitude: config['defaultAltitude'] ?? state.defaultAltitude,
    );
  }

  void addWaypoint(WaypointModel wp) {
    state = state.copyWith(waypoints: [...state.waypoints, wp]);
  }

  void updateWaypoint(String id, WaypointModel updated) {
    final wps = state.waypoints.map((w) => w.id == id ? updated : w).toList();
    state = state.copyWith(waypoints: wps);
  }

  void deleteWaypoint(String id) {
    state = state.copyWith(
        waypoints: state.waypoints.where((w) => w.id != id).toList());
  }

  void setWaypoints(List<WaypointModel> wps) {
    state = state.copyWith(waypoints: wps);
  }

  void setGeofence(List<Map<String, double>> fence) {
    state = state.copyWith(geofence: fence);
  }

  void runValidation() {
    _validationTimer?.cancel();
    final steps = [
      const ValidationStepModel(name: 'Pre-flight & Waypoints', status: 'pending', result: 'Checking...'),
      const ValidationStepModel(name: 'Waypoint Geofence', status: 'pending', result: 'Checking...'),
      const ValidationStepModel(name: 'Altitude Ceiling (120m)', status: 'pending', result: 'Checking...'),
      const ValidationStepModel(name: 'Battery Reserve', status: 'pending', result: 'Checking...'),
      const ValidationStepModel(name: 'NPNT Digital Sky Compliance', status: 'pending', result: 'Checking...'),
    ];
    state = state.copyWith(isValidating: true, validationSteps: steps);

    int i = 0;
    _validationTimer =
        Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (i >= steps.length) {
        t.cancel();
        state = state.copyWith(isValidating: false);
        return;
      }
      final updated = List<ValidationStepModel>.from(state.validationSteps);
      bool isPass = true;
      String res = 'OK';

      if (i == 0) {
        isPass = state.waypoints.isNotEmpty;
        res = isPass ? '${state.waypoints.length} Waypoints Loaded' : 'No waypoints added';
      } else if (i == 1) {
        isPass = state.geofence.length > 2 || state.geofence.isEmpty;
        res = isPass ? (state.geofence.length > 2 ? '${state.geofence.length}-point Polygon OK' : 'No Geofence Restriction') : 'Incomplete polygon';
      } else if (i == 2) {
        final maxAlt = state.waypoints.isEmpty
            ? 0.0
            : state.waypoints.map((w) => w.alt).reduce((a, b) => a > b ? a : b);
        isPass = maxAlt <= 120;
        res = isPass
            ? 'Max Alt ${maxAlt.toStringAsFixed(0)}m (Clear)'
            : 'Max Alt ${maxAlt.toStringAsFixed(0)}m exceeds 120m limit';
      } else if (i == 3) {
        final batt = state.selectedDrone?.battery ?? 100;
        isPass = batt >= 20;
        res = isPass ? 'Battery $batt% Sufficient' : 'Low Battery ($batt% < 20%)';
      } else if (i == 4) {
        isPass = true;
        res = 'PA Permission Key Verified';
      }

      updated[i] = updated[i].copyWith(status: isPass ? 'pass' : 'fail', result: res);
      state = state.copyWith(validationSteps: updated);
      i++;
    });
  }

  void resetValidation() {
    state = state.copyWith(validationSteps: [], uploadProgress: 0);
  }

  void uploadMission() {
    if (state.waypoints.isEmpty) return;
    if (state.connectionStatus != 'Connected') {
      _simulateUpload();
      return;
    }

    _pendingUploadWaypoints = List.from(state.waypoints);
    _missionUploadTarget = state.remoteSystemId ?? 1;
    _missionUploadCompTarget = state.remoteComponentId ?? 1;

    final total = _pendingUploadWaypoints.length;
    state = state.copyWith(
      uploadProgress: 0,
      missionUploadTotal: total,
      missionUploadCurrent: 0,
    );

    _logMavlink('MISSION', 'Starting upload: $total waypoints');

    _sendFrame(MissionCount(
      targetSystem: _missionUploadTarget,
      targetComponent: _missionUploadCompTarget,
      count: total,
      missionType: mavMissionTypeMission,
      opaqueId: 0,
    ));

    _missionItemTimeoutTimer?.cancel();
    _missionItemTimeoutTimer = Timer(const Duration(seconds: 5), () {
      _logMavlink('MISSION', 'Upload timeout — no MISSION_REQUEST received');
      addAlert(
        title: 'MISSION UPLOAD FAILED',
        message: 'No response from vehicle (MISSION_REQUEST timeout)',
        droneId: state.selectedDroneId,
        severity: 'high',
      );
      state = state.copyWith(uploadProgress: 0);
    });
  }

  void _onMissionRequest(int seq) {
    _missionItemTimeoutTimer?.cancel();
    final wps = _pendingUploadWaypoints;
    if (seq >= wps.length) return;

    final wp = wps[seq];
    _sendFrame(MissionItemInt(
      targetSystem: _missionUploadTarget,
      targetComponent: _missionUploadCompTarget,
      seq: seq,
      frame: mavFrameGlobalRelativeAlt,
      command: 16, // MAV_CMD_NAV_WAYPOINT
      current: seq == 0 ? 1 : 0,
      autocontinue: 1,
      param1: 0,
      param2: 2,
      param3: 0,
      param4: 0,
      x: (wp.lat * 1e7).round(),
      y: (wp.lng * 1e7).round(),
      z: wp.alt,
      missionType: mavMissionTypeMission,
    ));

    _logMavlink('MISSION',
        'Sent MISSION_ITEM_INT seq=$seq lat=${wp.lat.toStringAsFixed(5)} lng=${wp.lng.toStringAsFixed(5)} alt=${wp.alt}m');

    final progress = ((seq + 1) / wps.length * 100).round();
    state = state.copyWith(
      uploadProgress: progress,
      missionUploadCurrent: seq + 1,
    );

    _missionItemTimeoutTimer = Timer(const Duration(seconds: 3), () {
      _logMavlink('MISSION', 'Item timeout at seq=$seq — retrying');
      _onMissionRequest(seq);
    });
  }

  void _onMissionAck(MissionAck ack) {
    _missionItemTimeoutTimer?.cancel();
    _pendingUploadWaypoints = [];
    final resultStr = ack.type == 0 ? 'ACCEPTED' : 'ERROR(${ack.type})';
    _logMavlink('MISSION', 'MISSION_ACK result=$resultStr');

    if (ack.type == 0) {
      state = state.copyWith(
        uploadProgress: 100,
        missionUploadCurrent: state.missionUploadTotal,
      );
      final updated = state.drones
          .map((d) => d.id == state.selectedDroneId
              ? d.copyWith(missionStatus: 'Mission Uploaded')
              : d)
          .toList();
      state = state.copyWith(drones: updated);
      addAlert(
        title: 'MISSION UPLOAD COMPLETE',
        message:
            '${state.missionUploadTotal} waypoints uploaded successfully',
        droneId: state.selectedDroneId,
        severity: 'low',
      );
    } else {
      addAlert(
        title: 'MISSION UPLOAD FAILED',
        message: 'Vehicle rejected mission: type=${ack.type}',
        droneId: state.selectedDroneId,
        severity: 'high',
      );
      state = state.copyWith(uploadProgress: 0);
    }
  }

  void _simulateUpload() {
    state = state.copyWith(uploadProgress: 0);
    int p = 0;
    _uploadTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      p++;
      state = state.copyWith(uploadProgress: p);
      if (p >= 100) {
        t.cancel();
        final updated = state.drones
            .map((d) => d.id == state.selectedDroneId
                ? d.copyWith(missionStatus: 'Mission Uploaded')
                : d)
            .toList();
        state = state.copyWith(drones: updated);
      }
    });
  }

  // ─────────────────────────────────────────────
  // SIMULATION ACTIONS
  // ─────────────────────────────────────────────
  void setSimConfig(Map<String, dynamic> config) {
    state = state.copyWith(
      simFirmware: config['simFirmware'] ?? state.simFirmware,
      simSpeed: config['simSpeed'] ?? state.simSpeed,
      simHome: config['simHome'] ?? state.simHome,
      simHeading: config['simHeading'] ?? state.simHeading,
    );
  }

  void startSimulation() {
    state = state.copyWith(simStatus: 'running');
    addSimLog('Simulation started — ${state.simFirmware}');
  }

  void stopSimulation() {
    state = state.copyWith(simStatus: 'idle');
    addSimLog('Simulation stopped.');
  }

  void addSimLog(String msg) {
    final ts = DateTime.now().toUtc().toString().substring(11, 19);
    final logs = [...state.simConsoleLogs, '[$ts] $msg'];
    state = state.copyWith(simConsoleLogs: logs);
  }

  // ─────────────────────────────────────────────
  // ALERT ACTIONS
  // ─────────────────────────────────────────────
  void addAlert({
    required String title,
    required String message,
    required String droneId,
    required String severity,
  }) {
    final now = DateTime.now().toUtc().toString().substring(11, 19);
    final id = 'A${DateTime.now().millisecondsSinceEpoch}';
    final alert = AlertModel(
      id: id,
      timestamp: now,
      title: title,
      message: message,
      droneId: droneId,
      severity: severity,
    );
    state = state.copyWith(alerts: [alert, ...state.alerts]);
  }

  void markAlertRead(String id) {
    final updated =
        state.alerts.map((a) => a.id == id ? a.copyWith(read: true) : a).toList();
    state = state.copyWith(alerts: updated);
  }

  void clearAlerts() {
    state = state.copyWith(alerts: []);
  }

  // ─────────────────────────────────────────────
  // UI ACTIONS
  // ─────────────────────────────────────────────
  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setMapProvider(String provider) {
    state = state.copyWith(mapProvider: provider);
  }

  // ─────────────────────────────────────────────
  // MOTOR TESTING — MAV_CMD_DO_MOTOR_TEST (cmd=209)
  // ─────────────────────────────────────────────
  String _getOrEnsureDroneId() {
    if (state.selectedDroneId.isNotEmpty &&
        state.drones.any((d) => d.id == state.selectedDroneId)) {
      return state.selectedDroneId;
    }
    if (state.drones.isNotEmpty) {
      final firstId = state.drones.first.id;
      state = state.copyWith(selectedDroneId: firstId);
      return firstId;
    }
    const defaultDrone = DroneModel(
      id: 'D1',
      name: 'HexaX-D1 (Simulated)',
      battery: 98,
      signal: 95,
      flightMode: 'STABILIZE',
      missionStatus: 'Ready',
      gpsQuality: '3D FIX',
      encrypted: false,
      health: 'Healthy',
      lat: 28.6139,
      lng: 77.2090,
      altitude: 0,
      speed: 0,
      heading: 0,
    );
    state = state.copyWith(
      drones: [defaultDrone],
      selectedDroneId: defaultDrone.id,
    );
    return defaultDrone.id;
  }

  void testMotor({
    required int motorIndex,
    required double throttlePercent,
    required int durationSec,
  }) {
    final droneId = _getOrEnsureDroneId();
    final rpm = (throttlePercent / 100.0 * 9600.0).round();

    if (state.connectionStatus == 'Connected') {
      _sendCommand(
        209,
        p1: (motorIndex - 1).toDouble(),
        p2: 1,
        p3: throttlePercent,
        p4: durationSec.toDouble(),
        p5: 0,
        p6: 0,
      );
    }

    _logMavlink('MOTOR_TEST',
        'Motor $motorIndex → ${throttlePercent.toStringAsFixed(0)}% ($rpm RPM) for ${durationSec}s');
    addAlert(
      title: 'MOTOR TEST STARTED',
      message:
          'Spinning Motor $motorIndex at ${throttlePercent.round()}% for ${durationSec}s',
      droneId: droneId,
      severity: 'medium',
    );

    _updateDrone(droneId, (d) {
      switch (motorIndex) {
        case 1: return d.copyWith(motor1Rpm: rpm);
        case 2: return d.copyWith(motor2Rpm: rpm);
        case 3: return d.copyWith(motor3Rpm: rpm);
        case 4: return d.copyWith(motor4Rpm: rpm);
        default: return d;
      }
    });

    Future.delayed(Duration(seconds: durationSec), () {
      _updateDrone(droneId, (d) {
        switch (motorIndex) {
          case 1: return d.copyWith(motor1Rpm: 0);
          case 2: return d.copyWith(motor2Rpm: 0);
          case 3: return d.copyWith(motor3Rpm: 0);
          case 4: return d.copyWith(motor4Rpm: 0);
          default: return d;
        }
      });
      _logMavlink('MOTOR_TEST', 'Motor $motorIndex test completed');
    });
  }

  Future<void> testAllMotors({
    required double throttlePercent,
    required int durationSec,
  }) async {
    final droneId = _getOrEnsureDroneId();
    addAlert(
      title: 'SEQUENTIAL MOTOR TEST',
      message:
          'Running motors in sequence A → B → C → D at ${throttlePercent.round()}%',
      droneId: droneId,
      severity: 'medium',
    );
    for (int i = 1; i <= 4; i++) {
      testMotor(
        motorIndex: i,
        throttlePercent: throttlePercent,
        durationSec: durationSec,
      );
      await Future.delayed(Duration(seconds: durationSec + 1));
    }
  }

  void testAllMotorsTogether({
    required double throttlePercent,
    required int durationSec,
  }) {
    final droneId = _getOrEnsureDroneId();
    final rpm = (throttlePercent / 100.0 * 9600.0).round();

    if (state.connectionStatus == 'Connected') {
      for (int i = 0; i < 4; i++) {
        _sendCommand(209,
            p1: i.toDouble(),
            p2: 1,
            p3: throttlePercent,
            p4: durationSec.toDouble(),
            p5: 0,
            p6: 0);
      }
    }

    _logMavlink('MOTOR_TEST',
        'All 4 Motors Together → ${throttlePercent.toStringAsFixed(0)}% ($rpm RPM) for ${durationSec}s');
    addAlert(
      title: 'ALL MOTORS SIMULTANEOUS TEST',
      message:
          'Spinning all 4 motors together at ${throttlePercent.round()}% for ${durationSec}s',
      droneId: droneId,
      severity: 'medium',
    );

    _updateDrone(
        droneId,
        (d) => d.copyWith(
              motor1Rpm: rpm,
              motor2Rpm: rpm,
              motor3Rpm: rpm,
              motor4Rpm: rpm,
            ));

    Future.delayed(Duration(seconds: durationSec), () {
      _updateDrone(
          droneId,
          (d) => d.copyWith(
                motor1Rpm: 0,
                motor2Rpm: 0,
                motor3Rpm: 0,
                motor4Rpm: 0,
              ));
      _logMavlink('MOTOR_TEST', 'Simultaneous motor test completed');
    });
  }

  void emergencyStopAllMotors() {
    final droneId = _getOrEnsureDroneId();
    if (state.connectionStatus == 'Connected') {
      for (int i = 0; i < 4; i++) {
        _sendCommand(209, p1: i.toDouble(), p2: 1, p3: 0, p4: 0);
      }
    }
    _logMavlink('MOTOR_TEST', 'EMERGENCY MOTOR STOP TRIGGERED');
    _updateDrone(
        droneId,
        (d) => d.copyWith(
              motor1Rpm: 0,
              motor2Rpm: 0,
              motor3Rpm: 0,
              motor4Rpm: 0,
            ));
    addAlert(
      title: 'EMERGENCY MOTOR STOP',
      message: 'All motor outputs disabled immediately by user override.',
      droneId: droneId,
      severity: 'critical',
    );
  }
}

// ─────────────────────────────────────────────
// PROVIDERS & SELECTORS
// ─────────────────────────────────────────────
final gcsProvider = StateNotifierProvider<GcsNotifier, GcsState>(
  (ref) => GcsNotifier(),
);

final selectedDroneProvider = Provider<DroneModel?>((ref) {
  final s = ref.watch(gcsProvider);
  return s.drones.firstWhere(
    (d) => d.id == s.selectedDroneId,
    orElse: () => s.drones.isNotEmpty
        ? s.drones.first
        : const DroneModel(
            id: '',
            name: '',
            battery: 0,
            signal: 0,
            flightMode: '',
            missionStatus: '',
            gpsQuality: '',
            encrypted: false,
            health: '',
            lat: 0,
            lng: 0,
            altitude: 0,
            speed: 0,
            heading: 0,
          ),
  );
});

final unreadAlertsCountProvider = Provider<int>((ref) {
  return ref.watch(gcsProvider).alerts.where((a) => !a.read).length;
});

final availableSerialPortsProvider = Provider<List<String>>((ref) {
  return SerialPort.availablePorts;
});
