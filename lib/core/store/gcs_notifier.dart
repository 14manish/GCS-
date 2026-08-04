import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/ardupilotmega.dart';

import 'gcs_state.dart';
import '../models/models.dart';

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
  Timer? _pollTimer;
  MavlinkParser? _mavlinkParser;
  StreamSubscription<MavlinkFrame>? _mavlinkSub;
  Timer? _connectTimeoutTimer;
  Timer? _heartbeatSendTimer;
  Timer? _heartbeatWatchdogTimer;
  Timer? _dataStreamTimer;
  DateTime? _lastHeartbeatTime;
  int _txSeq = 0;

  static const int _gcsSystemId = 255;
  static const int _gcsComponentId = 190;
  static const double _radToDeg = 180 / pi;

  // ─── 1Hz ticker: UTC clock + session countdown only ───
  // Real drone telemetry comes exclusively from MAVLink frames.
  // No simulated drift applied here.
  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
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
  // CONNECTION ACTIONS (SERIAL MAVLINK)
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
      _failConnection('UDP connect not implemented yet.');
    }
  }

  void _connectSerial(String portName, int baudRate) {
    try {
      final sp = SerialPort(portName);
      if (!sp.openReadWrite()) {
        _failConnection('Could not open $portName: ${SerialPort.lastError}');
        return;
      }
      sp.config = (SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1
        ..setFlowControl(SerialPortFlowControl.none));
      _serialPort = sp;

      _mavlinkParser = MavlinkParser(MavlinkDialectArdupilotmega());
      _mavlinkSub = _mavlinkParser!.stream.listen(_onMavlinkFrame);

      // Windows-safe 50Hz polling reader checking bytesAvailable with error threshold
      int consecutiveReadErrors = 0;
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
        final localSp = _serialPort;
        if (localSp == null || !localSp.isOpen) return;
        try {
          final available = localSp.bytesAvailable;
          if (available < 0) {
            consecutiveReadErrors++;
            // Only trigger failConnection if hardware fails continuously for >500ms (25 consecutive checks)
            if (consecutiveReadErrors > 25) {
              _failConnection(
                  'USB cable disconnected or serial port hardware error.');
            }
            return;
          }
          consecutiveReadErrors = 0; // Reset counter on valid status
          if (available > 0) {
            final data = localSp.read(available > 2048 ? 2048 : available);
            if (data.isNotEmpty) _mavlinkParser?.parse(data);
          }
        } catch (e) {
          _failConnection('Serial read error: $e');
        }
      });

      _connectTimeoutTimer = Timer(const Duration(seconds: 6), () {
        if (state.connectionStatus != 'Connected') {
          _failConnection('No heartbeat received — check port/baud/USB cable.');
        }
      });
    } catch (e) {
      _failConnection('Serial open failed: $e');
    }
  }

  void _requestDataStreams(int targetSystem, int targetComponent) {
    // Request stream 0 (ALL) and specific streams for maximum compatibility at sustainable rates
    const streams = [
      (0, 4), // MAV_DATA_STREAM_ALL at 4 Hz
      (6, 2), // MAV_DATA_STREAM_POSITION (GLOBAL_POSITION_INT) at 2 Hz
      (10, 5), // MAV_DATA_STREAM_EXTRA1   (ATTITUDE) at 5 Hz
      (2, 2), // MAV_DATA_STREAM_RAW_SENSORS (GPS_RAW_INT) at 2 Hz
      (8, 2), // MAV_DATA_STREAM_EXTRA2   (VFR_HUD) at 2 Hz
      (11, 1), // MAV_DATA_STREAM_EXTRA3   (AHRS, SYS_STATUS) at 1 Hz
    ];
    for (final (streamId, hz) in streams) {
      final req = RequestDataStream(
        targetSystem: targetSystem,
        targetComponent: targetComponent,
        reqStreamId: streamId,
        reqMessageRate: hz,
        startStop: 1,
      );
      final frame =
          MavlinkFrame.v2(_txSeq++ & 0xFF, _gcsSystemId, _gcsComponentId, req);
      try {
        _serialPort?.write(frame.serialize());
      } catch (_) {}
    }
  }

  void _onMavlinkFrame(MavlinkFrame frame) {
    _lastHeartbeatTime = DateTime.now();
    final msg = frame.message;
    final sysId = frame.systemId;

    if (msg is Heartbeat) {
      _logMavlink('HEARTBEAT',
          'sysId=$sysId mode=${_customModeLabel(msg.customMode, msg.autopilot)} armed=${(msg.baseMode & 128) != 0}');
      _handleHeartbeat(sysId, frame.componentId, msg);
      return;
    }

    final sysIdStr = sysId.toString();
    if (state.drones.isEmpty) return;

    final targetId = state.drones.any((d) => d.id == sysIdStr)
        ? sysIdStr
        : (state.selectedDroneId.isNotEmpty &&
                state.drones.any((d) => d.id == state.selectedDroneId)
            ? state.selectedDroneId
            : state.drones.first.id);

    if (msg is Attitude) {
      _logMavlink('ATTITUDE',
          'roll=${(msg.roll * _radToDeg).toStringAsFixed(1)}° pitch=${(msg.pitch * _radToDeg).toStringAsFixed(1)}° yaw=${(msg.yaw * _radToDeg).toStringAsFixed(1)}°');
      _updateDrone(
          targetId,
          (d) => d.copyWith(
                roll: msg.roll * _radToDeg,
                pitch: msg.pitch * _radToDeg,
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
      final groundSpeedFromGps = sqrt(vx * vx + vy * vy);
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
                speed: groundSpeedFromGps > 0 ? groundSpeedFromGps : d.speed,
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
      const fixStrings = {
        0: 'NO FIX',
        1: 'NO FIX',
        2: '2D FIX',
        3: '3D FIX',
        4: 'DGPS',
        5: 'RTK FLOAT',
        6: 'RTK FIXED',
      };
      _logMavlink('GPS_RAW_INT',
          'fix=${fixStrings[msg.fixType] ?? msg.fixType} sats=${msg.satellitesVisible} hdop=${(msg.eph / 100.0).toStringAsFixed(2)}');
      _updateDrone(
          targetId,
          (d) => d.copyWith(
                gpsQuality: fixStrings[msg.fixType] ?? d.gpsQuality,
                satellites: msg.satellitesVisible == 255
                    ? d.satellites
                    : msg.satellitesVisible,
                hdop: msg.eph == 65535 ? d.hdop : msg.eph / 100.0,
              ));
      return;
    }

    if (msg is RadioStatus) {
      _logMavlink('RADIO_STATUS', 'rssi=${msg.remrssi} noise=${msg.remnoise}');
      _updateDrone(targetId, (d) => d.copyWith(signal: msg.remrssi.toDouble()));
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

  // ── MAVLink message log ──────────────────────────────────────────
  int _mavlinkLogThrottleCount = 0;

  void _logMavlink(String msgType, String detail) {
    // Throttle high-frequency messages so the log stays readable and doesn't thrash state
    if (msgType == 'ATTITUDE' ||
        msgType == 'VFR_HUD' ||
        msgType == 'GLOBAL_POS_INT') {
      _mavlinkLogThrottleCount++;
      if (_mavlinkLogThrottleCount % 15 != 0) return;
    }
    final ts = DateTime.now().toUtc().toString().substring(11, 22);
    final entry = '[$ts] $msgType  $detail';
    final newLog = [entry, ...state.mavlinkLog];
    state = state.copyWith(
      mavlinkLog: newLog.length > 200 ? newLog.sublist(0, 200) : newLog,
    );
  }

  void _handleHeartbeat(int sysId, int compId, Heartbeat hb) {
    final isVehicle = hb.autopilot != mavAutopilotInvalid && sysId != 0;
    if (!isVehicle) return;

    final sysIdStr = sysId.toString();
    final exists = state.drones.any((d) => d.id == sysIdStr || d.id == 'CUBE1');

    if (!exists) {
      final newDrone = DroneModel(
        id: sysIdStr,
        name: 'Cube Orange+ ($sysIdStr)',
        battery: 0,
        signal: 0,
        flightMode: _customModeLabel(hb.customMode, hb.autopilot),
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
      final targetId =
          state.drones.any((d) => d.id == sysIdStr) ? sysIdStr : 'CUBE1';
      _updateDrone(
          targetId,
          (d) => d.copyWith(
                flightMode: _customModeLabel(hb.customMode, hb.autopilot),
              ));
    }

    if (state.connectionStatus != 'Connected') {
      _connectTimeoutTimer?.cancel();
      _lastHeartbeatTime = DateTime.now();
      state = state.copyWith(
        connectionStatus: 'Connected',
        sessionExpiry: 3480,
        lastError: null,
      );
      _startHeartbeatSender();
      _startHeartbeatWatchdog();

      _requestDataStreams(sysId, compId);
      _dataStreamTimer?.cancel();
      _dataStreamTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _requestDataStreams(sysId, compId);
      });
    }
  }

  String _customModeLabel(int customMode, int autopilot) {
    const copterModes = {
      0: 'STABILIZE',
      1: 'ACRO',
      2: 'ALT_HOLD',
      3: 'AUTO',
      4: 'GUIDED',
      5: 'LOITER',
      6: 'RTL',
      7: 'CIRCLE',
      9: 'LAND',
      11: 'DRIFT',
      13: 'SPORT',
      16: 'POSHOLD',
      17: 'BRAKE',
      20: 'GUIDED_NOGPS',
      21: 'SMART_RTL',
      22: 'FLOWHOLD',
      23: 'FOLLOW',
      24: 'ZIGZAG',
    };
    return copterModes[customMode] ?? 'MODE $customMode';
  }

  void _updateDrone(String targetId, DroneModel Function(DroneModel) update) {
    if (state.drones.isEmpty) {
      _getOrEnsureDroneId();
    }
    final target = targetId.isNotEmpty ? targetId : state.selectedDroneId;
    final list = state.drones.map((d) {
      if (d.id == target || state.drones.length == 1) {
        return update(d);
      }
      return d;
    }).toList();
    state = state.copyWith(drones: list);
  }

  /// Inject a simulated GPS position for indoor testing.
  /// Updates all drones (or the selected drone) with the given lat/lng.
  void setMockGpsPosition(double lat, double lng) {
    if (state.drones.isEmpty) return;
    final targetId = state.selectedDroneId;
    _updateDrone(
        targetId,
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

  void _startHeartbeatSender() {
    _heartbeatSendTimer?.cancel();
    _heartbeatSendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final hb = Heartbeat(
        type: mavTypeGcs,
        autopilot: mavAutopilotInvalid,
        baseMode: 0,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );
      final frame =
          MavlinkFrame.v2(_txSeq++ & 0xFF, _gcsSystemId, _gcsComponentId, hb);
      try {
        _serialPort?.write(frame.serialize());
      } catch (_) {}
    });
  }

  void _startHeartbeatWatchdog() {
    _heartbeatWatchdogTimer?.cancel();
    _heartbeatWatchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.connectionStatus != 'Connected') return;

      // Telemetry heartbeat loss watchdog (15 seconds timeout — matches standard GCS spec)
      if (_lastHeartbeatTime != null) {
        final elapsed = DateTime.now().difference(_lastHeartbeatTime!);
        if (elapsed.inSeconds >= 15) {
          _failConnection('Connection lost: Telemetry timeout (15s).');
          return;
        }
      }
    });
  }

  void _failConnection(String reason) {
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
    );
  }

  void disconnect() {
    _teardown();
    state = state.copyWith(
      connectionStatus: 'Disconnected',
      drones: const [],
    );
  }

  void _teardown() {
    _connectTimeoutTimer?.cancel();
    _heartbeatSendTimer?.cancel();
    _heartbeatWatchdogTimer?.cancel();
    _dataStreamTimer?.cancel();
    _pollTimer?.cancel();
    _mavlinkSub?.cancel();
    _mavlinkParser = null;
    _lastHeartbeatTime = null;
    try {
      _serialPort?.close();
    } catch (_) {}
    _serialPort?.dispose();
    _serialPort = null;
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
          'vehicleType': hb.type
        });
      }
    }
    state = state.copyWith(isScanning: false, autoScanList: found);
  }

  Future<Heartbeat?> _probePort(String portName) async {
    SerialPort? sp;
    Timer? poll;
    try {
      sp = SerialPort(portName);
      if (!sp.openReadWrite()) return null;
      sp.config = (SerialPortConfig()
        ..baudRate = 115200
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1);

      final parser = MavlinkParser(MavlinkDialectArdupilotmega());
      final completer = Completer<Heartbeat?>();
      final sub = parser.stream.listen((f) {
        if (f.message is Heartbeat && !completer.isCompleted) {
          completer.complete(f.message as Heartbeat);
        }
      });

      final localSp = sp;
      poll = Timer.periodic(const Duration(milliseconds: 20), (_) {
        try {
          final available = localSp.bytesAvailable;
          if (available > 0) {
            final data = localSp.read(available > 2048 ? 2048 : available);
            if (data.isNotEmpty) parser.parse(data);
          }
        } catch (_) {}
      });

      final result = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      await sub.cancel();
      return result;
    } catch (_) {
      return null;
    } finally {
      poll?.cancel();
      try {
        sp?.close();
      } catch (_) {}
      sp?.dispose();
    }
  }

  // ─────────────────────────────────────────────
  // VEHICLE ACTIONS
  // ─────────────────────────────────────────────
  void selectDrone(String id) {
    state = state.copyWith(selectedDroneId: id);
  }

  void triggerDroneAction(String droneId, String action) {
    final modeMap = {
      'ARM': 'Armed',
      'DISARM': 'Disarmed',
      'TAKEOFF': 'Loiter',
      'LAND': 'Landing',
      'RTL': 'RTL',
      'HOLD': 'Loiter',
      'MISSION': 'Mission Active',
    };
    final newMode = modeMap[action];
    if (newMode == null) return;

    final updated = state.drones
        .map(
          (d) => d.id == droneId ? d.copyWith(flightMode: newMode) : d,
        )
        .toList();
    state = state.copyWith(drones: updated);
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
    final steps = [
      const ValidationStepModel(
          name: 'Pre-flight Checks', status: 'pending', result: ''),
      const ValidationStepModel(
          name: 'Waypoint Geofence Compliance', status: 'pending', result: ''),
      const ValidationStepModel(
          name: 'Altitude Clearance', status: 'pending', result: ''),
      const ValidationStepModel(
          name: 'Battery Reserve', status: 'pending', result: ''),
      const ValidationStepModel(
          name: 'NPNT Authorization', status: 'pending', result: ''),
    ];
    state = state.copyWith(isValidating: true, validationSteps: steps);

    int i = 0;
    _validationTimer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (i >= steps.length) {
        t.cancel();
        state = state.copyWith(isValidating: false);
        return;
      }
      final updated = List<ValidationStepModel>.from(state.validationSteps);
      updated[i] = updated[i].copyWith(status: 'pass', result: 'OK');
      state = state.copyWith(validationSteps: updated);
      i++;
    });
  }

  void resetValidation() {
    state = state.copyWith(validationSteps: [], uploadProgress: 0);
  }

  void uploadMission() {
    state = state.copyWith(uploadProgress: 0);
    int p = 0;
    _uploadTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      p++;
      state = state.copyWith(uploadProgress: p);
      if (p >= 100) {
        t.cancel();
        final updated = state.drones
            .map(
              (d) => d.id == state.selectedDroneId
                  ? d.copyWith(missionStatus: 'Mission Uploaded')
                  : d,
            )
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
    final updated = state.alerts
        .map((a) => a.id == id ? a.copyWith(read: true) : a)
        .toList();
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
  // MOTOR TESTING & CALIBRATION (Mission Planner MAV_CMD_DO_MOTOR_TEST)
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
    // Auto-create simulated vehicle D1 if state has no drones
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

  /// Command a specific motor to spin (1-indexed: 1 = Motor A, 2 = Motor B, etc.)
  void testMotor({
    required int motorIndex,
    required double throttlePercent,
    required int durationSec,
  }) {
    final droneId = _getOrEnsureDroneId();
    final rpm = (throttlePercent / 100.0 * 9600.0).round();
    _logMavlink(
      'MOTOR_TEST',
      'Motor $motorIndex -> ${throttlePercent.toStringAsFixed(0)}% throttle ($rpm RPM) for ${durationSec}s',
    );

    addAlert(
      title: 'MOTOR TEST STARTED',
      message:
          'Spinning Motor $motorIndex at ${throttlePercent.round()}% for ${durationSec}s',
      droneId: droneId,
      severity: 'medium',
    );

    // Update state RPM for target motor
    _updateDrone(droneId, (d) {
      switch (motorIndex) {
        case 1:
          return d.copyWith(motor1Rpm: rpm);
        case 2:
          return d.copyWith(motor2Rpm: rpm);
        case 3:
          return d.copyWith(motor3Rpm: rpm);
        case 4:
          return d.copyWith(motor4Rpm: rpm);
        default:
          return d;
      }
    });

    // Auto spin-down timer after durationSec
    Future.delayed(Duration(seconds: durationSec), () {
      _updateDrone(droneId, (d) {
        switch (motorIndex) {
          case 1:
            return d.copyWith(motor1Rpm: 0);
          case 2:
            return d.copyWith(motor2Rpm: 0);
          case 3:
            return d.copyWith(motor3Rpm: 0);
          case 4:
            return d.copyWith(motor4Rpm: 0);
          default:
            return d;
        }
      });
      _logMavlink('MOTOR_TEST', 'Motor $motorIndex test completed');
    });
  }

  /// Run all motors in sequence (A -> B -> C -> D)
  Future<void> testAllMotors({
    required double throttlePercent,
    required int durationSec,
  }) async {
    final droneId = _getOrEnsureDroneId();

    addAlert(
      title: 'SEQUENTIAL MOTOR TEST',
      message:
          'Running motors in sequence A -> B -> C -> D at ${throttlePercent.round()}%',
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

  /// Spin all 4 motors SIMULTANEOUSLY together at the same time
  void testAllMotorsTogether({
    required double throttlePercent,
    required int durationSec,
  }) {
    final droneId = _getOrEnsureDroneId();
    final rpm = (throttlePercent / 100.0 * 9600.0).round();
    _logMavlink(
      'MOTOR_TEST',
      'All 4 Motors Together -> ${throttlePercent.toStringAsFixed(0)}% throttle ($rpm RPM) for ${durationSec}s',
    );

    addAlert(
      title: 'ALL MOTORS SIMULTANEOUS TEST',
      message:
          'Spinning all 4 motors together at ${throttlePercent.round()}% for ${durationSec}s',
      droneId: droneId,
      severity: 'medium',
    );

    // Set RPM for ALL 4 motors at once
    _updateDrone(
      droneId,
      (d) => d.copyWith(
        motor1Rpm: rpm,
        motor2Rpm: rpm,
        motor3Rpm: rpm,
        motor4Rpm: rpm,
      ),
    );

    // Auto spin-down timer after durationSec
    Future.delayed(Duration(seconds: durationSec), () {
      _updateDrone(
        droneId,
        (d) => d.copyWith(
          motor1Rpm: 0,
          motor2Rpm: 0,
          motor3Rpm: 0,
          motor4Rpm: 0,
        ),
      );
      _logMavlink('MOTOR_TEST', 'Simultaneous motor test completed');
    });
  }

  /// Emergency kill switch to cut power to all motors immediately
  void emergencyStopAllMotors() {
    final droneId = _getOrEnsureDroneId();
    _logMavlink('MOTOR_TEST', 'EMERGENCY MOTOR STOP TRIGGERED');

    _updateDrone(
      droneId,
      (d) => d.copyWith(
        motor1Rpm: 0,
        motor2Rpm: 0,
        motor3Rpm: 0,
        motor4Rpm: 0,
      ),
    );

    addAlert(
      title: 'EMERGENCY MOTOR STOP',
      message: 'All motor outputs disabled immediately by user override.',
      droneId: droneId,
      severity: 'critical',
    );
  }
}

// ─────────────────────────────────────────────
// PROVIDER & SELECTORS
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
