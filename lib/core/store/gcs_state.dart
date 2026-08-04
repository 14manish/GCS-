import '../models/models.dart';

// ─────────────────────────────────────────────
// GCS STATE (immutable snapshot)
// ─────────────────────────────────────────────
class GcsState {
  const GcsState({
    // Connection
    this.connectionStatus = 'Disconnected',
    this.connectionType = 'UDP',
    this.serialPort = 'COM3',
    this.baudRate = 57600,
    this.flowControl = 'None',
    this.hostIp = '127.0.0.1',
    this.port = 14550,
    this.encryption = true,
    this.sessionExpiry = 3480,
    this.signalStrength = 87,
    this.lastHeartbeat = 0,
    this.autoScanList = const [],
    this.isScanning = false,

    // MAVLink identity (populated once real HEARTBEAT is received)
    this.remoteSystemId,
    this.remoteComponentId,
    this.autopilotType,
    this.vehicleType,
    this.lastError,

    // MAVLink message log (live inspector)
    this.mavlinkLog = const [],

    // Fleet
    this.drones = const [],
    this.selectedDroneId = 'D1',

    // Mission
    this.missionName = '',
    this.missionType = 'Waypoint',
    this.altitudeFrame = 'Relative',
    this.defaultAltitude = 50.0,
    this.waypoints = const [],
    this.geofence = const [],
    this.validationSteps = const [],
    this.uploadProgress = 0,
    this.isValidating = false,

    // Simulation
    this.simStatus = 'idle',
    this.simFirmware = 'ArduPlane',
    this.simSpeed = 1.0,
    this.simHome = const {'lat': 28.6139, 'lng': 77.2090},
    this.simConsoleLogs = const [],
    this.simHeading = 90,
    this.simWipe = false,

    // Alerts
    this.alerts = const [],

    // UI
    this.utcTime = '00:00:00',
    this.themeMode = 'dark',
    this.mapProvider = 'google_hybrid',
  });

  // Connection
  final String connectionStatus;
  final String connectionType;
  final String serialPort;
  final int baudRate;
  final String flowControl;
  final String hostIp;
  final int port;
  final bool encryption;
  final int sessionExpiry;
  final int signalStrength;
  final int lastHeartbeat;
  final List<Map<String, dynamic>> autoScanList;
  final bool isScanning;

  // MAVLink identity — null until first real HEARTBEAT received
  final int? remoteSystemId;
  final int? remoteComponentId;
  final int? autopilotType; // MAV_AUTOPILOT enum value
  final int? vehicleType; // MAV_TYPE enum value
  final String? lastError;

  // Fleet
  final List<DroneModel> drones;
  final String selectedDroneId;

  // Mission
  final String missionName;
  final String missionType;
  final String altitudeFrame;
  final double defaultAltitude;
  final List<WaypointModel> waypoints;
  final List<Map<String, double>> geofence;
  final List<ValidationStepModel> validationSteps;
  final int uploadProgress;
  final bool isValidating;

  // Simulation
  final String simStatus;
  final String simFirmware;
  final double simSpeed;
  final Map<String, double> simHome;
  final List<String> simConsoleLogs;
  final int simHeading;
  final bool simWipe;

  // Alerts
  final List<AlertModel> alerts;

  // MAVLink live message log (capped at 200 entries)
  final List<String> mavlinkLog;

  // UI
  final String utcTime;
  final String themeMode;
  final String mapProvider;

  GcsState copyWith({
    String? connectionStatus,
    String? connectionType,
    String? serialPort,
    int? baudRate,
    String? flowControl,
    String? hostIp,
    int? port,
    bool? encryption,
    int? sessionExpiry,
    int? signalStrength,
    int? lastHeartbeat,
    List<Map<String, dynamic>>? autoScanList,
    bool? isScanning,
    int? remoteSystemId,
    int? remoteComponentId,
    int? autopilotType,
    int? vehicleType,
    String? lastError,
    List<DroneModel>? drones,
    String? selectedDroneId,
    String? missionName,
    String? missionType,
    String? altitudeFrame,
    double? defaultAltitude,
    List<WaypointModel>? waypoints,
    List<Map<String, double>>? geofence,
    List<ValidationStepModel>? validationSteps,
    int? uploadProgress,
    bool? isValidating,
    String? simStatus,
    String? simFirmware,
    double? simSpeed,
    Map<String, double>? simHome,
    List<String>? simConsoleLogs,
    int? simHeading,
    bool? simWipe,
    List<AlertModel>? alerts,
    List<String>? mavlinkLog,
    String? utcTime,
    String? themeMode,
    String? mapProvider,
  }) {
    return GcsState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionType: connectionType ?? this.connectionType,
      serialPort: serialPort ?? this.serialPort,
      baudRate: baudRate ?? this.baudRate,
      flowControl: flowControl ?? this.flowControl,
      hostIp: hostIp ?? this.hostIp,
      port: port ?? this.port,
      encryption: encryption ?? this.encryption,
      sessionExpiry: sessionExpiry ?? this.sessionExpiry,
      signalStrength: signalStrength ?? this.signalStrength,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      autoScanList: autoScanList ?? this.autoScanList,
      isScanning: isScanning ?? this.isScanning,
      remoteSystemId: remoteSystemId ?? this.remoteSystemId,
      remoteComponentId: remoteComponentId ?? this.remoteComponentId,
      autopilotType: autopilotType ?? this.autopilotType,
      vehicleType: vehicleType ?? this.vehicleType,
      lastError: lastError ?? this.lastError,
      drones: drones ?? this.drones,
      selectedDroneId: selectedDroneId ?? this.selectedDroneId,
      missionName: missionName ?? this.missionName,
      missionType: missionType ?? this.missionType,
      altitudeFrame: altitudeFrame ?? this.altitudeFrame,
      defaultAltitude: defaultAltitude ?? this.defaultAltitude,
      waypoints: waypoints ?? this.waypoints,
      geofence: geofence ?? this.geofence,
      validationSteps: validationSteps ?? this.validationSteps,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isValidating: isValidating ?? this.isValidating,
      simStatus: simStatus ?? this.simStatus,
      simFirmware: simFirmware ?? this.simFirmware,
      simSpeed: simSpeed ?? this.simSpeed,
      simHome: simHome ?? this.simHome,
      simConsoleLogs: simConsoleLogs ?? this.simConsoleLogs,
      simHeading: simHeading ?? this.simHeading,
      simWipe: simWipe ?? this.simWipe,
      alerts: alerts ?? this.alerts,
      mavlinkLog: mavlinkLog ?? this.mavlinkLog,
      utcTime: utcTime ?? this.utcTime,
      themeMode: themeMode ?? this.themeMode,
      mapProvider: mapProvider ?? this.mapProvider,
    );
  }
}
