/// Data models translated from useGcsStore.ts interfaces
library;

class DroneModel {
  const DroneModel({
    required this.id,
    required this.name,
    required this.battery,
    required this.signal,
    required this.flightMode,
    required this.missionStatus,
    required this.gpsQuality,
    required this.encrypted,
    required this.health,
    required this.lat,
    required this.lng,
    required this.altitude,
    required this.speed,
    required this.heading,
    this.pitch = 0.0,
    this.roll = 0.0,
    this.climbRate = 0.0,
    this.satellites = 12,
    this.hdop = 0.8,
    this.voltage = 22.2,
    this.current = 18.5,
    this.latency = 42,
    this.packetLoss = 0.3,
    this.history = const [],
    this.targetWpIdx = 0,
    this.motor1Rpm = 0,
    this.motor2Rpm = 0,
    this.motor3Rpm = 0,
    this.motor4Rpm = 0,
  });

  final String id;
  final String name;
  final double battery;
  final double signal; // dBm
  final String flightMode;
  final String missionStatus;
  final String gpsQuality;
  final bool encrypted;
  final String health; // 'Healthy' | 'Warning' | 'Critical'
  final double lat;
  final double lng;
  final double altitude;
  final double speed;
  final double heading;
  final double pitch;
  final double roll;
  final double climbRate;
  final int satellites;
  final double hdop;
  final double voltage;
  final double current;
  final int latency;
  final double packetLoss;
  final List<Map<String, double>> history;
  final int targetWpIdx;
  final int motor1Rpm;
  final int motor2Rpm;
  final int motor3Rpm;
  final int motor4Rpm;

  DroneModel copyWith({
    String? id,
    String? name,
    double? battery,
    double? signal,
    String? flightMode,
    String? missionStatus,
    String? gpsQuality,
    bool? encrypted,
    String? health,
    double? lat,
    double? lng,
    double? altitude,
    double? speed,
    double? heading,
    double? pitch,
    double? roll,
    double? climbRate,
    int? satellites,
    double? hdop,
    double? voltage,
    double? current,
    int? latency,
    double? packetLoss,
    List<Map<String, double>>? history,
    int? targetWpIdx,
    int? motor1Rpm,
    int? motor2Rpm,
    int? motor3Rpm,
    int? motor4Rpm,
  }) {
    return DroneModel(
      id: id ?? this.id,
      name: name ?? this.name,
      battery: battery ?? this.battery,
      signal: signal ?? this.signal,
      flightMode: flightMode ?? this.flightMode,
      missionStatus: missionStatus ?? this.missionStatus,
      gpsQuality: gpsQuality ?? this.gpsQuality,
      encrypted: encrypted ?? this.encrypted,
      health: health ?? this.health,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
      climbRate: climbRate ?? this.climbRate,
      satellites: satellites ?? this.satellites,
      hdop: hdop ?? this.hdop,
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      latency: latency ?? this.latency,
      packetLoss: packetLoss ?? this.packetLoss,
      history: history ?? this.history,
      targetWpIdx: targetWpIdx ?? this.targetWpIdx,
      motor1Rpm: motor1Rpm ?? this.motor1Rpm,
      motor2Rpm: motor2Rpm ?? this.motor2Rpm,
      motor3Rpm: motor3Rpm ?? this.motor3Rpm,
      motor4Rpm: motor4Rpm ?? this.motor4Rpm,
    );
  }
}

class WaypointModel {
  const WaypointModel({
    required this.id,
    required this.lat,
    required this.lng,
    required this.alt,
    required this.action,
  });

  final String id;
  final double lat;
  final double lng;
  final double alt;
  final String action;

  WaypointModel copyWith({
    String? id,
    double? lat,
    double? lng,
    double? alt,
    String? action,
  }) {
    return WaypointModel(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      alt: alt ?? this.alt,
      action: action ?? this.action,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        'alt': alt,
        'action': action,
      };
}

class AlertModel {
  const AlertModel({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.message,
    required this.droneId,
    required this.severity,
    this.read = false,
  });

  final String id;
  final String timestamp;
  final String title;
  final String message;
  final String droneId;
  final String severity; // 'critical' | 'high' | 'medium' | 'low'
  final bool read;

  AlertModel copyWith({
    String? id,
    String? timestamp,
    String? title,
    String? message,
    String? droneId,
    String? severity,
    bool? read,
  }) {
    return AlertModel(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      message: message ?? this.message,
      droneId: droneId ?? this.droneId,
      severity: severity ?? this.severity,
      read: read ?? this.read,
    );
  }
}

class ValidationStepModel {
  const ValidationStepModel({
    required this.name,
    required this.status,
    required this.result,
  });

  final String name;
  final String status; // 'pending' | 'loading' | 'pass' | 'fail'
  final String result;

  ValidationStepModel copyWith({String? name, String? status, String? result}) {
    return ValidationStepModel(
      name: name ?? this.name,
      status: status ?? this.status,
      result: result ?? this.result,
    );
  }
}
