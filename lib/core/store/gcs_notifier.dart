import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gcs_state.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────
// GCS NOTIFIER (all business logic — translated from useGcsStore.ts)
// ─────────────────────────────────────────────
class GcsNotifier extends StateNotifier<GcsState> {
  GcsNotifier() : super(GcsState(drones: _initialDrones())) {
    _startTicker();
    _startAlertGenerator();
  }

  final _rng = Random();
  Timer? _ticker;
  Timer? _alertTimer;
  Timer? _connectTimer;
  Timer? _scanTimer;
  Timer? _validationTimer;
  Timer? _uploadTimer;

  // ─── Initial simulated drone fleet ───
  static List<DroneModel> _initialDrones() {
    return [
      const DroneModel(
        id: 'D1',
        name: 'Alpha-1',
        battery: 87,
        signal: -62,
        flightMode: 'Loiter',
        missionStatus: 'Awaiting Upload',
        gpsQuality: '3D RTK',
        encrypted: true,
        health: 'Healthy',
        lat: 28.6139,
        lng: 77.2090,
        altitude: 120.4,
        speed: 14.2,
        heading: 045,
        pitch: 2.1,
        roll: -1.3,
        climbRate: 0.4,
        satellites: 18,
        hdop: 0.7,
        voltage: 22.1,
        current: 18.5,
        latency: 38,
        packetLoss: 0.2,
        motor1Rpm: 5200,
        motor2Rpm: 5150,
        motor3Rpm: 5250,
        motor4Rpm: 5180,
      ),
      const DroneModel(
        id: 'D2',
        name: 'Beta-2',
        battery: 62,
        signal: -71,
        flightMode: 'Mission Active',
        missionStatus: 'WP 4 of 12',
        gpsQuality: '3D FIX',
        encrypted: true,
        health: 'Warning',
        lat: 28.6200,
        lng: 77.2150,
        altitude: 85.0,
        speed: 22.6,
        heading: 180,
        pitch: -0.8,
        roll: 0.5,
        climbRate: -0.2,
        satellites: 14,
        hdop: 1.1,
        voltage: 21.3,
        current: 21.2,
        latency: 55,
        packetLoss: 0.8,
        motor1Rpm: 5800,
        motor2Rpm: 5750,
        motor3Rpm: 5820,
        motor4Rpm: 5770,
      ),
      const DroneModel(
        id: 'D3',
        name: 'Gamma-3',
        battery: 34,
        signal: -88,
        flightMode: 'RTL',
        missionStatus: 'Returning Home',
        gpsQuality: '2D FIX',
        encrypted: false,
        health: 'Critical',
        lat: 28.6080,
        lng: 77.2010,
        altitude: 55.0,
        speed: 8.1,
        heading: 270,
        pitch: 0.0,
        roll: 0.0,
        climbRate: -1.5,
        satellites: 9,
        hdop: 1.8,
        voltage: 20.1,
        current: 14.3,
        latency: 112,
        packetLoss: 2.1,
        motor1Rpm: 4200,
        motor2Rpm: 4100,
        motor3Rpm: 4180,
        motor4Rpm: 4220,
      ),
    ];
  }

  // ─── 1Hz ticker (UTC clock + telemetry drift + session countdown) ───
  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now().toUtc();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final utc = '$h:$m:$s UTC';

    // Drift telemetry for all drones
    final updated = state.drones.map((d) {
      if (d.flightMode == 'Standby') return d;
      final newHistory = [
        ...d.history,
        {'lat': d.lat, 'lng': d.lng}
      ];
      if (newHistory.length > 100) newHistory.removeAt(0);

      return d.copyWith(
        altitude:
            (d.altitude + (_rng.nextDouble() - 0.5) * 0.8).clamp(10.0, 400.0),
        speed: (d.speed + (_rng.nextDouble() - 0.5) * 0.6).clamp(0.0, 30.0),
        heading: (d.heading + (_rng.nextDouble() - 0.5) * 1.5) % 360,
        pitch: (d.pitch + (_rng.nextDouble() - 0.5) * 0.3).clamp(-30.0, 30.0),
        roll: (d.roll + (_rng.nextDouble() - 0.5) * 0.4).clamp(-45.0, 45.0),
        climbRate:
            (d.climbRate + (_rng.nextDouble() - 0.5) * 0.2).clamp(-5.0, 5.0),
        battery: (d.battery - 0.005).clamp(0.0, 100.0),
        lat: d.lat + (_rng.nextDouble() - 0.5) * 0.0002,
        lng: d.lng + (_rng.nextDouble() - 0.5) * 0.0002,
        latency: (d.latency + (_rng.nextInt(11) - 5)).clamp(20, 300),
        motor1Rpm: (d.motor1Rpm + _rng.nextInt(201) - 100).clamp(0, 8000),
        motor2Rpm: (d.motor2Rpm + _rng.nextInt(201) - 100).clamp(0, 8000),
        motor3Rpm: (d.motor3Rpm + _rng.nextInt(201) - 100).clamp(0, 8000),
        motor4Rpm: (d.motor4Rpm + _rng.nextInt(201) - 100).clamp(0, 8000),
        history: newHistory,
      );
    }).toList();

    // Session countdown
    final newExpiry = state.connectionStatus == 'Connected'
        ? (state.sessionExpiry - 1).clamp(0, 9999)
        : state.sessionExpiry;

    state = state.copyWith(
      utcTime: utc,
      drones: updated,
      sessionExpiry: newExpiry,
    );
  }

  // ─── Random alert generator (every 20s) ───
  void _startAlertGenerator() {
    _alertTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (state.drones.isEmpty) return;
      final alertsPool = [
        {
          'title': 'Airspace Boundary Warning',
          'message': 'Vehicle approaching restricted corridor limits.',
          'severity': 'medium'
        },
        {
          'title': 'Motor Heat Warning',
          'message': 'ESC 3 temperature climbing, current draw stable.',
          'severity': 'medium'
        },
        {
          'title': 'Satellite Count Degradation',
          'message': 'GNSS lock count dropped below optimal threshold.',
          'severity': 'high'
        },
        {
          'title': 'Wind Speed Limit Warning',
          'message': 'Local gusts approaching structural limit thresholds.',
          'severity': 'medium'
        },
        {
          'title': 'Geofence Breach',
          'message': 'Clearance perimeter crossed. System vector hold active.',
          'severity': 'critical'
        },
        {
          'title': 'Low Power RTL Failsafe',
          'message': 'Voltage threshold reached. Initiate return sequence.',
          'severity': 'critical'
        },
        {
          'title': 'Telemetry Latency Spike',
          'message': 'Link latency exceeded 220ms on physical interface.',
          'severity': 'high'
        },
        {
          'title': 'Camera Snapshot Done',
          'message': 'Grid survey footprint captured and logged.',
          'severity': 'low'
        },
        {
          'title': 'Payload Target Locked',
          'message': 'Object tracking box registered lock state.',
          'severity': 'low'
        },
      ];
      final drone = state.drones[_rng.nextInt(state.drones.length)];
      final alert = alertsPool[_rng.nextInt(alertsPool.length)];
      addAlert(
        title: alert['title']!,
        message: '[${drone.name}] ${alert['message']}',
        droneId: drone.id,
        severity: alert['severity']!,
      );
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _alertTimer?.cancel();
    _connectTimer?.cancel();
    _scanTimer?.cancel();
    _validationTimer?.cancel();
    _uploadTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // CONNECTION ACTIONS
  // ─────────────────────────────────────────────
  void connect({
    String? connectionType,
    String? serialPort,
    int? baudRate,
    String? hostIp,
    int? port,
    bool? encryption,
  }) {
    state = state.copyWith(
      connectionStatus: 'Connecting',
      connectionType: connectionType ?? state.connectionType,
      serialPort: serialPort ?? state.serialPort,
      baudRate: baudRate ?? state.baudRate,
      hostIp: hostIp ?? state.hostIp,
      port: port ?? state.port,
      encryption: encryption ?? state.encryption,
    );
    _connectTimer?.cancel();
    _connectTimer = Timer(const Duration(seconds: 2), () {
      state = state.copyWith(
        connectionStatus: 'Connected',
        sessionExpiry: 3480,
      );
    });
  }

  void disconnect() {
    state = state.copyWith(connectionStatus: 'Disconnected');
  }

  void setScanning(bool scanning) {
    state = state.copyWith(isScanning: scanning);
    if (scanning) {
      _scanTimer = Timer(const Duration(seconds: 3), () {
        state = state.copyWith(
          isScanning: false,
          autoScanList: [
            {'name': 'Pixhawk 6C', 'port': 'COM5', 'model': 'ArduPlane 4.5'},
            {'name': 'Cube Orange', 'port': 'COM8', 'model': 'ArduCopter 4.4'},
            {'name': 'Holybro X500', 'port': 'COM12', 'model': 'PX4 v1.14'},
          ],
        );
      });
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
}

// ─────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────
final gcsProvider = StateNotifierProvider<GcsNotifier, GcsState>(
  (ref) => GcsNotifier(),
);

// Convenience selectors
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
