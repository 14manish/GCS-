import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/store/gcs_notifier.dart';
import '../../core/models/models.dart';
import '../../core/models/map_providers.dart';
import '../../core/widgets/map_provider_selector.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/analog_gauges.dart';
import '../../core/widgets/hud/hud_glass_card.dart';
import '../../core/widgets/hud/attitude_horizon_widget.dart';
import '../../core/widgets/hud/compass_heading_widget.dart';
import '../../core/widgets/hud/speedometer_gauge_widget.dart';
import '../../core/widgets/hud/agl_elevation_profile_widget.dart';
import '../../core/widgets/hud/gauge_3d_frame.dart';

class FlyView extends ConsumerStatefulWidget {
  const FlyView({super.key});

  @override
  ConsumerState<FlyView> createState() => _FlyViewState();
}

class _FlyViewState extends ConsumerState<FlyView>
    with TickerProviderStateMixin {
  late AnimationController _hudCtrl;
  late AnimationController _cameraCtrl;
  final _mapController = MapController();
  String _drawMode = 'none';
  bool _mockGpsMode = false; // tap map to simulate GPS position indoors
  bool _showSidePanel =
      false; // collapsible left telemetry drawer (defaults to full-bleed HUD map)

  // Smooth interpolated HUD values
  double _roll = 0, _pitch = 0, _heading = 0, _altitude = 0, _speed = 0;
  // Whether the map has been auto-centered on the drone's real GPS position
  bool _mapCentered = false;
  // Track last known position to avoid redundant map moves
  double _lastCenteredLat = 0;
  double _lastCenteredLng = 0;
  // Track connection status to detect disconnect events
  String _lastConnectionStatus = 'Disconnected';
  // 3D Map perspective mode toggle
  bool _is3DMode = false;

  @override
  void initState() {
    super.initState();
    _hudCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    _cameraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _hudCtrl.addListener(_updateHud);
  }

  void _updateHud() {
    final s = ref.read(gcsProvider);

    // Detect disconnect → reset map centering flag so next connect re-centers
    if (s.connectionStatus != _lastConnectionStatus) {
      _lastConnectionStatus = s.connectionStatus;
      if (s.connectionStatus == 'Disconnected') {
        _mapCentered = false;
        _lastCenteredLat = 0;
        _lastCenteredLng = 0;
      }
    }

    final drone = s.drones.isNotEmpty
        ? s.drones.firstWhere((d) => d.id == s.selectedDroneId,
            orElse: () => s.drones.first)
        : null;
    if (drone == null) return;

    // Auto-center map on first real GPS fix after connection
    if (!_mapCentered && drone.lat != 0 && drone.lng != 0) {
      _mapCentered = true;
      _lastCenteredLat = drone.lat;
      _lastCenteredLng = drone.lng;
      _mapController.move(LatLng(drone.lat, drone.lng), 18);
    } else if (_mapCentered && drone.lat != 0 && drone.lng != 0) {
      // Continuously re-center if drone moved > ~5m (0.00005 deg)
      final latDiff = (drone.lat - _lastCenteredLat).abs();
      final lngDiff = (drone.lng - _lastCenteredLng).abs();
      if (latDiff > 0.00005 || lngDiff > 0.00005) {
        _lastCenteredLat = drone.lat;
        _lastCenteredLng = drone.lng;
        _mapController.move(
            LatLng(drone.lat, drone.lng), _mapController.camera.zoom);
      }
    }

    const lerpSpeed = 0.08;
    setState(() {
      _roll += (drone.roll - _roll) * lerpSpeed;
      _pitch += (drone.pitch - _pitch) * lerpSpeed;
      _heading += (drone.heading - _heading) * lerpSpeed;
      _altitude += (drone.altitude - _altitude) * lerpSpeed;
      _speed += (drone.speed - _speed) * lerpSpeed;
    });
  }

  @override
  void dispose() {
    _hudCtrl.removeListener(_updateHud);
    _hudCtrl.dispose();
    _cameraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final drone = s.drones.isNotEmpty
        ? s.drones.firstWhere((d) => d.id == s.selectedDroneId,
            orElse: () => s.drones.first)
        : null;

    final mode = drone?.flightMode.toUpperCase() ?? '';
    final isArmed = drone?.health == 'Armed' || mode == 'ARMED';
    final isFlying = s.simStatus == 'running' ||
        mode == 'AUTO' ||
        mode == 'GUIDED' ||
        mode == 'TAKEOFF' ||
        mode == 'RTL' ||
        mode == 'LAND' ||
        isArmed ||
        (drone != null && drone.altitude > 0.5) ||
        (drone != null && drone.speed > 0.3) ||
        (drone != null && drone.missionStatus == 'In Progress') ||
        (drone != null && drone.missionStatus == 'Mission Uploaded');

    return Container(
      color: gcs.bg,
      child: Stack(
        children: [
          // ─── 1. FULL-BLEED BASE MAP (WITH 3D PERSPECTIVE TILT) ───
          Positioned.fill(
            child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    transform: _is3DMode
                        ? (Matrix4.identity()
                          ..setEntry(3, 2, 0.0006)
                          ..rotateX(-0.35)
                          ..scale(1.22, 1.22, 1.0))
                        : Matrix4.identity(),
                    transformAlignment: Alignment.topCenter,
                    child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(28.6139, 77.2090),
                initialZoom: 16,
                onTap: (_, latlng) {
                  // Mock GPS: tap the map to set simulated position
                  if (_mockGpsMode && s.connectionStatus == 'Connected') {
                    ref
                        .read(gcsProvider.notifier)
                        .setMockGpsPosition(latlng.latitude, latlng.longitude);
                    setState(() => _mockGpsMode = false);
                    return;
                  }
                  if (_drawMode == 'waypoint') {
                    final idx = s.waypoints.length + 1;
                    final wp = WaypointModel(
                      id: 'W${idx.toString().padLeft(2, '0')}',
                      lat: latlng.latitude,
                      lng: latlng.longitude,
                      alt: s.defaultAltitude,
                      action: 'Waypoint',
                    );
                    ref.read(gcsProvider.notifier).addWaypoint(wp);
                    setState(() => _drawMode = 'none');
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: MapProviders.get(s.mapProvider).urlTemplate,
                  subdomains: MapProviders.get(s.mapProvider).subdomains,
                  userAgentPackageName: 'com.example.gcs_flutter',
                  maxZoom: 20,
                  maxNativeZoom: 19,
                ),

                // Flight trails
                PolylineLayer(
                  polylines: s.drones
                      .map(
                        (d) => Polyline(
                          points: d.history
                              .map((h) => LatLng(h['lat']!, h['lng']!))
                              .toList(),
                          color: AppColors.tacticalCyan.withValues(alpha: 0.6),
                          strokeWidth: 2.0,
                        ),
                      )
                      .toList(),
                ),

                // Mission Waypoints Polyline
                if (s.waypoints.length > 1)
                  PolylineLayer<Object>(polylines: [
                    Polyline(
                      points: s.waypoints
                          .map((wp) => LatLng(wp.lat, wp.lng))
                          .toList(),
                      color: AppColors.warning.withValues(alpha: 0.8),
                      strokeWidth: 2.5,
                    ),
                  ]),

                // Waypoint Markers
                MarkerLayer(
                  markers: s.waypoints
                      .map(
                        (wp) => Marker(
                          point: LatLng(wp.lat, wp.lng),
                          width: 26,
                          height: 26,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.glassBg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.warning, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                wp.id.replaceFirst('W', ''),
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),

                // Geofence
                if (s.geofence.length > 2)
                  PolygonLayer(polygons: [
                    Polygon(
                      points: s.geofence
                          .map((g) => LatLng(g['lat']!, g['lng']!))
                          .toList(),
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderColor: AppColors.warning.withValues(alpha: 0.5),
                      borderStrokeWidth: 1.5,
                    ),
                  ]),

                // Drone markers
                MarkerLayer(
                  markers: s.drones.map((d) {
                    final isSelected = d.id == s.selectedDroneId;
                    final healthColor = d.health == 'Healthy'
                        ? AppColors.tacticalGreen
                        : d.health == 'Warning'
                            ? AppColors.warning
                            : AppColors.danger;
                    return Marker(
                      point: LatLng(d.lat, d.lng),
                      width: isSelected ? 44 : 32,
                      height: isSelected ? 44 : 32,
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(gcsProvider.notifier).selectDrone(d.id),
                        child: Transform.rotate(
                          angle: d.heading * pi / 180,
                          child: Container(
                            decoration: BoxDecoration(
                              color: healthColor.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.tacticalCyan
                                    : healthColor,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.tacticalCyan
                                            .withValues(alpha: 0.6),
                                        blurRadius: 10,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              LucideIcons.navigation,
                              size: isSelected ? 22 : 16,
                              color: isSelected
                                  ? AppColors.tacticalCyan
                                  : healthColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // ─── 2. TOP CENTER FLOATING MODE BAR ───
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: HudGlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Flight Mode',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        color: AppColors.textSecond,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.tacticalCyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      drone?.flightMode.toUpperCase() ?? 'AUTO',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.glassPanel,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Auto (type)',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: AppColors.textSecond,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(LucideIcons.chevronDown,
                              size: 12, color: AppColors.textSecond),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── 3b. TOP RIGHT MAP CONTROLS ───
          Positioned(
            top: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Select Map & Location/Waypoint Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OverlayBtn(
                      LucideIcons.layers,
                      () => showMapProviderSelector(context, ref),
                    ),
                    const SizedBox(width: 8),
                    _OverlayBtn(
                      LucideIcons.mapPin,
                      () => setState(() => _drawMode =
                          _drawMode == 'none' ? 'waypoint' : 'none'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Quick Map Controls (2D/3D toggle, reset location, +, -)
                HudGlassCard(
                  padding: const EdgeInsets.all(6),
                  backgroundColor: _is3DMode
                      ? AppColors.tacticalCyan.withValues(alpha: 0.9)
                      : null,
                  child: GestureDetector(
                    onTap: () => setState(() => _is3DMode = !_is3DMode),
                    child: Text(
                      _is3DMode ? '3D' : '2D',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _is3DMode ? Colors.black : AppColors.tacticalCyan,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                HudGlassCard(
                  padding: const EdgeInsets.all(6),
                  child: GestureDetector(
                    onTap: () {
                      if (drone != null && drone.lat != 0 && drone.lng != 0) {
                        _mapController.move(LatLng(drone.lat, drone.lng), 18);
                      }
                    },
                    child: const Icon(LucideIcons.rotateCcw,
                        size: 12, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                HudGlassCard(
                  padding: const EdgeInsets.all(6),
                  child: GestureDetector(
                    onTap: () => _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1),
                    child: const Icon(LucideIcons.plus,
                        size: 12, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                HudGlassCard(
                  padding: const EdgeInsets.all(6),
                  child: GestureDetector(
                    onTap: () => _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1),
                    child: const Icon(LucideIcons.minus,
                        size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // ─── 3c. RIGHT SIDE TELEMETRY RECTANGULAR STRIP ───
          Positioned(
            bottom: 148,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _TelemetryBox(
                  value: '${_altitude.toStringAsFixed(1)} m',
                  color: const Color(0xFF9B51E0),
                  icon: Icons.height,
                ),
                const SizedBox(height: 4),
                _TelemetryBox(
                  value: '${_speed.toStringAsFixed(1)} m/s',
                  color: const Color(0xFFF2994A),
                  icon: Icons.speed,
                ),
                const SizedBox(height: 4),
                _TelemetryBox(
                  value: '${_heading.toStringAsFixed(1)}°',
                  color: const Color(0xFF27AE60),
                  icon: Icons.explore,
                ),
                const SizedBox(height: 4),
                _TelemetryBox(
                  value: '${(drone?.climbRate ?? 0.0).toStringAsFixed(1)} m/s',
                  color: const Color(0xFFF2C94C),
                  icon: Icons.arrow_upward,
                ),
                const SizedBox(height: 4),
                _TelemetryBox(
                  value: '${(drone?.battery ?? 0.0).toStringAsFixed(0)}%',
                  color: const Color(0xFFEB5757),
                  icon: Icons.battery_charging_full,
                ),
                const SizedBox(height: 4),
                _TelemetryBox(
                  value: '${s.signalStrength}%',
                  color: const Color(0xFF0D8CC6),
                  icon: Icons.signal_cellular_alt,
                ),
                const SizedBox(height: 4),
                _TelemetryBox(
                  value: '${(drone?.windSpeed ?? 0.0).toStringAsFixed(1)} km/h',
                  color: const Color(0xFF00BFA5),
                  icon: Icons.air,
                ),
                const SizedBox(height: 4),
                _TelemetryBox(
                  value: drone?.windDir ?? '--',
                  color: const Color(0xFF00BFA5),
                  icon: Icons.navigation,
                ),
              ],
            ),
          ),

          // ─── 5. BOTTOM LEFT TACTICAL 3D INSTRUMENTATION CLUSTER ───
          Positioned(
            bottom: 14,
            left: 14,
            child: SizedBox(
              width: 415,
              height: 180,
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  // Ground Contact Shadow under 3D Cluster
                  Positioned(
                    bottom: -2,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.85),
                            blurRadius: 22,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Left Dial: Artificial Horizon (Layered Behind Center)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Gauge3dFrame(
                      size: 150.0,
                      child: AttitudeHorizonWidget(
                        pitch: _pitch,
                        roll: _roll,
                        size: 150.0,
                      ),
                    ),
                  ),
                  // Right Dial: Speedometer (Layered Behind Center)
                  Positioned(
                    left: 260,
                    bottom: 0,
                    child: Gauge3dFrame(
                      size: 150.0,
                      child: SpeedometerGaugeWidget(
                        speed: _speed,
                        size: 150.0,
                        minSpeed: 60.0,
                        maxSpeed: 200.0,
                      ),
                    ),
                  ),
                  // Center Dial: Compass / Heading (Larger & Layered ON TOP)
                  Positioned(
                    left: 115,
                    bottom: 0,
                    child: Gauge3dFrame(
                      size: 175.0,
                      child: CompassHeadingWidget(
                        heading: _heading,
                        size: 175.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── 6. BOTTOM RIGHT REAL-TIME AGL ELEVATION PROFILE ───
          Positioned(
            bottom: 14,
            right: 14,
            child: AglElevationProfileWidget(
              aglAltitude: _altitude,
              targetDistance: 78.0,
              width: 250,
              height: 125,
            ),
          ),

          // ─── 8. TOP LEFT DRAWER TOGGLE ───
          Positioned(
            top: 14,
            left: 14,
            child: HudGlassCard(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => setState(() => _showSidePanel = !_showSidePanel),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showSidePanel
                          ? LucideIcons.panelLeftClose
                          : LucideIcons.panelLeftOpen,
                      size: 14,
                      color: AppColors.tacticalCyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showSidePanel ? 'HIDE PANEL' : 'TELEMETRY',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Mock GPS Mode Banner
          if (_mockGpsMode)
            Positioned(
              top: 54,
              left: 14,
              child: HudGlassCard(
                backgroundColor: AppColors.warning.withValues(alpha: 0.9),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.mapPinPlus,
                        size: 14, color: AppColors.background),
                    SizedBox(width: 8),
                    Text(
                      'TAP MAP TO SET MOCK GPS POSITION',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.background,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ─── 9. COLLAPSIBLE LEFT TELEMETRY DRAWER ───
          if (_showSidePanel)
            Positioned(
              top: 54,
              left: 14,
              bottom: 14,
              width: 320,
              child: HudGlassCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _SidePanel(
                    roll: _roll,
                    pitch: _pitch,
                    heading: _heading,
                    altitude: _altitude,
                    speed: _speed,
                    drone: drone,
                    gcs: gcs,
                    onAction: (action) => ref
                        .read(gcsProvider.notifier)
                        .triggerDroneAction(drone?.id ?? '', action),
                    onDroneChange: (id) =>
                        ref.read(gcsProvider.notifier).selectDrone(id ?? ''),
                    drones: s.drones,
                  ),
                ),
              ),
            ),

          // Picture-in-Picture Camera Strip — Displays automatically when mission starts or drone is flying
          if (isFlying)
            Positioned(
              bottom: 150,
              left: 14,
              child: HudGlassCard(
                padding: EdgeInsets.zero,
                width: 395,
                height: 130,
                child: Column(
                  children: [
                    // Camera header bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.accent.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF3B30),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'LIVE CAMERA FEED',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '1080P HD',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 7,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Live camera view
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        child: _CameraStrip(
                          cameraCtrl: _cameraCtrl,
                          drones: s.drones,
                          gcs: gcs,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HUD PANEL (left 180px)
// ─────────────────────────────────────────────
class _OldHudPanel extends StatelessWidget {
  const _OldHudPanel({
    required this.roll,
    required this.pitch,
    required this.heading,
    required this.altitude,
    required this.speed,
    required this.drone,
    required this.gcs,
  });

  final double roll, pitch, heading, altitude, speed;
  final DroneModel? drone;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080E1C),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Mode badge
          if (drone != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(drone!.flightMode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  )),
            ),
          const SizedBox(height: 8),

          // Attitude Indicator
          Expanded(
            child: CustomPaint(
              painter: _AttitudePainter(roll: roll, pitch: pitch),
              child: Container(),
            ),
          ),
          const SizedBox(height: 8),

          // Heading tape
          SizedBox(
            height: 32,
            child: CustomPaint(
              painter: _HeadingTapePainter(heading: heading),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),

          // Alt + speed ladders
          Expanded(
            child: Row(
              children: [
                Expanded(
                    child: CustomPaint(
                  painter: _LadderPainter(
                    value: altitude,
                    unit: 'm',
                    color: AppColors.accent,
                    label: 'ALT',
                  ),
                  child: Container(),
                )),
                const SizedBox(width: 4),
                Expanded(
                    child: CustomPaint(
                  painter: _LadderPainter(
                    value: speed,
                    unit: 'm/s',
                    color: AppColors.success,
                    label: 'SPD',
                  ),
                  child: Container(),
                )),
              ],
            ),
          ),

          const SizedBox(height: 8),
          // Pitch + Roll values
          if (drone != null) ...[
            _OldHudRow('PITCH', '${pitch.toStringAsFixed(1)}°'),
            _OldHudRow('ROLL', '${roll.toStringAsFixed(1)}°'),
            _OldHudRow('SAT', '${drone!.satellites}'),
            _OldHudRow('HDOP', drone!.hdop.toStringAsFixed(2)),
          ],
        ],
      ),
    );
  }
}

class _OldHudRow extends StatelessWidget {
  const _OldHudRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: AppColors.textSecond,
              letterSpacing: 0.8,
            )),
        const Spacer(),
        Text(value,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// RIGHT STATS PANEL
// ─────────────────────────────────────────────
class _OldRightPanel extends StatelessWidget {
  const _OldRightPanel({
    required this.drone,
    required this.gcs,
    required this.onAction,
    required this.onUpload,
  });

  final DroneModel? drone;
  final GcsThemeExtension gcs;
  final void Function(String) onAction;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    if (drone == null) {
      return Container(color: const Color(0xFF080E1C));
    }

    final battColor = drone!.battery > 50
        ? AppColors.success
        : drone!.battery > 20
            ? AppColors.warning
            : AppColors.danger;

    return Container(
      color: const Color(0xFF080E1C),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Selected drone
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(drone!.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                )),
          ),
          const SizedBox(height: 8),

          // Stats
          _OldRStatRow('ALT', '${drone!.altitude.toStringAsFixed(1)}m',
              AppColors.accent),
          _OldRStatRow('SPD', '${drone!.speed.toStringAsFixed(1)}m/s',
              AppColors.success),
          _OldRStatRow(
              'BAT', '${drone!.battery.toStringAsFixed(0)}%', battColor),
          _OldRStatRow('SIG', '${drone!.signal.toStringAsFixed(0)}dBm',
              AppColors.textSecond),
          _OldRStatRow('LAT', '${drone!.latency}ms',
              drone!.latency < 100 ? AppColors.success : AppColors.danger),
          _OldRStatRow('GPS', drone!.gpsQuality, AppColors.success),
          const SizedBox(height: 8),

          // Mission status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(3),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.1)),
            ),
            child: Text(drone!.missionStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9,
                  color: AppColors.textSecond,
                )),
          ),
          const SizedBox(height: 8),

          // Action buttons
          _OldArmBtn(
              label: 'ARM',
              color: AppColors.success,
              onTap: () => onAction('ARM')),
          const SizedBox(height: 4),
          _OldArmBtn(
              label: 'TAKEOFF',
              color: AppColors.accent,
              onTap: () => onAction('TAKEOFF')),
          const SizedBox(height: 4),
          _OldArmBtn(
              label: 'LAND',
              color: AppColors.warning,
              onTap: () => onAction('LAND')),
          const SizedBox(height: 4),
          _OldArmBtn(
              label: 'RTL',
              color: const Color(0xFFFF9800),
              onTap: () => onAction('RTL')),
          const SizedBox(height: 4),
          _OldArmBtn(
              label: 'DISARM',
              color: AppColors.danger,
              onTap: () => onAction('DISARM')),
          const SizedBox(height: 8),
          _OldArmBtn(
              label: 'UPLOAD MISSION',
              color: AppColors.accent,
              onTap: onUpload),
        ],
      ),
    );
  }
}

class _OldRStatRow extends StatelessWidget {
  const _OldRStatRow(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: AppColors.textSecond,
            )),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            )),
      ]),
    );
  }
}

class _OldArmBtn extends StatelessWidget {
  const _OldArmBtn(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            )),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CAMERA STRIP
// ─────────────────────────────────────────────
class _CameraStrip extends StatelessWidget {
  const _CameraStrip({
    required this.cameraCtrl,
    required this.drones,
    required this.gcs,
  });

  final AnimationController cameraCtrl;
  final List<DroneModel> drones;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    final displayDrones = drones.isNotEmpty
        ? drones
        : [
            const DroneModel(
              id: '1',
              name: 'CAM 1',
              battery: 100,
              signal: 100,
              flightMode: 'STABILIZE',
              missionStatus: 'STANDBY',
              gpsQuality: '3D FIX',
              encrypted: true,
              health: 'Healthy',
              lat: 0,
              lng: 0,
              altitude: 0,
              speed: 0,
              heading: 0,
            ),
          ];

    return Container(
      color: gcs.bg,
      child: Row(
        children: displayDrones
            .map((drone) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: gcs.bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.15)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CustomPaint(
                        painter: _CamPainter(anim: cameraCtrl, drone: drone),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _CamPainter extends CustomPainter {
  const _CamPainter({required this.anim, required this.drone})
      : super(repaint: anim);
  final Animation<double> anim;
  final DroneModel drone;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF06090F));

    // Scanlines
    final scanPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // Moving scan line
    final scanY = size.height * t;
    canvas.drawLine(
        Offset(0, scanY),
        Offset(size.width, scanY),
        Paint()
          ..color = const Color(0xFF00D4FF).withValues(alpha: 0.2)
          ..strokeWidth = 1);

    // Crosshair
    final cx = size.width / 2;
    final cy = size.height / 2;
    final cp = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.5)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(cx - 8, cy), Offset(cx - 3, cy), cp);
    canvas.drawLine(Offset(cx + 3, cy), Offset(cx + 8, cy), cp);
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy - 3), cp);
    canvas.drawLine(Offset(cx, cy + 3), Offset(cx, cy + 8), cp);

    // Drone name overlay
    final tp = TextPainter(
      text: TextSpan(
        text: drone.name,
        style: const TextStyle(
          fontFamily: 'Courier',
          fontSize: 8,
          color: Color(0x8800D4FF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(4, 4));

    // Altitude overlay
    final tp2 = TextPainter(
      text: TextSpan(
        text: '${drone.altitude.toStringAsFixed(0)}m',
        style: const TextStyle(
          fontFamily: 'Courier',
          fontSize: 7,
          color: Color(0x8800C853),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(4, size.height - 14));
  }

  @override
  bool shouldRepaint(_CamPainter old) => true;
}

// ─────────────────────────────────────────────
// ATTITUDE INDICATOR CustomPainter
// ─────────────────────────────────────────────
class _AttitudePainter extends CustomPainter {
  const _AttitudePainter({required this.roll, required this.pitch});
  final double roll, pitch;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(cx, cy) - 4;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Rotate for roll
    canvas.translate(cx, cy);
    canvas.rotate(roll * pi / 180);
    canvas.translate(-cx, -cy);

    // Sky
    final pitchOffset = pitch / 90 * radius;
    final skyPaint = Paint()..color = const Color(0xFF0B3D7A);
    canvas.drawRect(
        Rect.fromLTRB(0, 0, size.width, cy - pitchOffset), skyPaint);

    // Ground
    final groundPaint = Paint()..color = const Color(0xFF5C3A1E);
    canvas.drawRect(Rect.fromLTRB(0, cy - pitchOffset, size.width, size.height),
        groundPaint);

    // Horizon line
    canvas.drawLine(
      Offset(0, cy - pitchOffset),
      Offset(size.width, cy - pitchOffset),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 1.5,
    );

    // Pitch lines
    for (int deg in [-20, -10, 10, 20]) {
      final y = cy - pitchOffset - deg / 90 * radius;
      final lineW = deg.abs() == 20 ? 30.0 : 20.0;
      canvas.drawLine(
        Offset(cx - lineW, y),
        Offset(cx + lineW, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 0.8,
      );
    }

    canvas.restore();

    // Fixed aircraft symbol (does not rotate)
    final acPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 28, cy), Offset(cx - 8, cy), acPaint);
    canvas.drawLine(Offset(cx + 8, cy), Offset(cx + 28, cy), acPaint);
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy - 3), acPaint);
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AttitudePainter old) =>
      old.roll != roll || old.pitch != pitch;
}

// ─────────────────────────────────────────────
// HEADING TAPE CustomPainter
// ─────────────────────────────────────────────
class _HeadingTapePainter extends CustomPainter {
  const _HeadingTapePainter({required this.heading});
  final double heading;

  static const _dirs = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF080E1C));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..color = Colors.transparent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    final tickPaint = Paint()
      ..color = AppColors.textSecond
      ..strokeWidth = 1;
    final accentPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.5;

    // Draw ticks from heading - 45 to heading + 45
    for (int d = -45; d <= 45; d += 5) {
      final deg = ((heading + d) % 360).round();
      final x = cx + d / 45 * (cx - 10);
      final isCardinal = deg % 90 == 0;
      final paint = isCardinal ? accentPaint : tickPaint;

      canvas.drawLine(
        Offset(x, cy - 5),
        Offset(x, isCardinal ? cy - 14 : cy - 8),
        paint,
      );

      if (d % 15 == 0) {
        final label = _dirs[deg] ?? '$deg';
        final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 8,
                color: isCardinal ? AppColors.accent : AppColors.textSecond,
              )),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, 1));
      }
    }

    // Center marker triangle
    final triPath = Path()
      ..moveTo(cx, cy - 1)
      ..lineTo(cx - 5, cy - 12)
      ..lineTo(cx + 5, cy - 12)
      ..close();
    canvas.drawPath(triPath, Paint()..color = AppColors.accent);

    // Heading value
    final tp = TextPainter(
      text: TextSpan(
          text: '${heading.round()}°',
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9,
            color: AppColors.accent,
            fontWeight: FontWeight.bold,
          )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 2));
  }

  @override
  bool shouldRepaint(_HeadingTapePainter old) => old.heading != heading;
}

// ─────────────────────────────────────────────
// ALTITUDE / SPEED LADDER CustomPainter
// ─────────────────────────────────────────────
class _LadderPainter extends CustomPainter {
  const _LadderPainter({
    required this.value,
    required this.unit,
    required this.color,
    required this.label,
  });
  final double value;
  final String unit, label;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF080E1C));
    canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.1)
          ..strokeWidth = 1);

    // Draw tick marks
    for (int i = -5; i <= 5; i++) {
      final displayVal = (value + i * 10).round();
      final y = cy - i * (size.height / 12);
      final isMain = i == 0;

      canvas.drawLine(
        Offset(cx - (isMain ? 12 : 8), y),
        Offset(cx, y),
        Paint()
          ..color = isMain ? color : Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = isMain ? 1.5 : 0.8,
      );

      if (i % 2 == 0) {
        final tp = TextPainter(
          text: TextSpan(
              text: '$displayVal',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 7,
                color: isMain ? color : AppColors.textSecond,
              )),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(0, y - tp.height / 2));
      }
    }

    // Current value box
    final valueBox = Rect.fromCenter(
        center: Offset(cx, cy), width: size.width - 4, height: 18);
    canvas.drawRect(valueBox, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawRect(
        valueBox,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    final vtp = TextPainter(
      text: TextSpan(
          text: value.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
          )),
      textDirection: TextDirection.ltr,
    )..layout();
    vtp.paint(canvas, Offset(cx - vtp.width / 2, cy - vtp.height / 2));

    // Label
    final ltp = TextPainter(
      text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 8,
            color: color,
          )),
      textDirection: TextDirection.ltr,
    )..layout();
    ltp.paint(canvas, Offset(cx - ltp.width / 2, size.height - 14));
  }

  @override
  bool shouldRepaint(_LadderPainter old) => old.value != value;
}

// Map overlay button
class _OverlayBtn extends StatelessWidget {
  const _OverlayBtn(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.panels.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 14, color: AppColors.accent),
      ),
    );
  }
}

enum TapeSide { left, right }

class _TapePainter extends CustomPainter {
  const _TapePainter({
    required this.value,
    required this.label,
    required this.color,
    required this.side,
  });
  final double value;
  final String label;
  final Color color;
  final TapeSide side;

  @override
  void paint(Canvas canvas, Size size) {
    final isLeft = side == TapeSide.left;
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    for (int i = -5; i <= 5; i++) {
      final displayVal = (value + i * 5).round();
      if (displayVal < 0) continue;
      final y = cy - i * (size.height / 12);
      final tickLen = i == 0 ? 12.0 : 7.0;
      final xStart = isLeft ? size.width - tickLen : 0.0;
      final xEnd = isLeft ? size.width.toDouble() : tickLen;

      canvas.drawLine(
        Offset(xStart, y),
        Offset(xEnd, y),
        Paint()
          ..color = i == 0 ? color : Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = i == 0 ? 1.5 : 0.7,
      );

      if (i.abs() % 2 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$displayVal',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 8,
              color: i == 0 ? color : Colors.white54,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final xText =
            isLeft ? size.width - tickLen - tp.width - 2 : tickLen + 2;
        tp.paint(canvas, Offset(xText, y - tp.height / 2));
      }
    }

    final vbox = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy), width: size.width - 4, height: 18),
      const Radius.circular(3),
    );
    canvas.drawRRect(vbox, Paint()..color = color.withValues(alpha: 0.2));
    canvas.drawRRect(
        vbox,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    final vtp = TextPainter(
      text: TextSpan(
        text: value.toStringAsFixed(1),
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    vtp.paint(canvas, Offset(cx - vtp.width / 2, cy - vtp.height / 2));

    final ltp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 7,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ltp.paint(canvas, Offset(cx - ltp.width / 2, size.height - ltp.height - 2));
  }

  @override
  bool shouldRepaint(_TapePainter old) => old.value != value;
}

class _HudWidget extends StatelessWidget {
  const _HudWidget({
    required this.roll,
    required this.pitch,
    required this.heading,
    required this.altitude,
    required this.speed,
    required this.drone,
  });

  final double roll, pitch, heading, altitude, speed;
  final DroneModel? drone;

  @override
  Widget build(BuildContext context) {
    final isArmed = drone?.missionStatus == 'Armed' ||
        drone?.flightMode.toUpperCase().contains('ARMED') == true;

    final battColor = drone == null
        ? Colors.grey
        : drone!.battery > 40
            ? AppColors.success
            : drone!.battery > 20
                ? AppColors.warning
                : AppColors.danger;

    final activeRoll = (drone != null && drone!.roll != 0) ? drone!.roll : roll;
    final activePitch =
        (drone != null && drone!.pitch != 0) ? drone!.pitch : pitch;
    final activeHeading =
        (drone != null && drone!.heading != 0) ? drone!.heading : heading;
    final activeAlt =
        (drone != null && drone!.altitude != 0) ? drone!.altitude : altitude;
    final activeSpeed =
        (drone != null && drone!.speed != 0) ? drone!.speed : speed;

    return Container(
      color: const Color(0xFF080E1C),
      child: Stack(
        children: [
          // 1. Full Attitude Indicator
          Positioned.fill(
            child: CustomPaint(
              painter: _AttitudePainter(roll: activeRoll, pitch: activePitch),
            ),
          ),

          // 2. Speed Tape (Left)
          Positioned(
            left: 0,
            top: 28,
            bottom: 24,
            width: 55,
            child: CustomPaint(
              painter: _TapePainter(
                value: activeSpeed,
                label: 'm/s',
                color: AppColors.success,
                side: TapeSide.left,
              ),
            ),
          ),

          // 3. Altitude Tape (Right)
          Positioned(
            right: 0,
            top: 28,
            bottom: 24,
            width: 55,
            child: CustomPaint(
              painter: _TapePainter(
                value: activeAlt,
                label: 'm',
                color: AppColors.accent,
                side: TapeSide.right,
              ),
            ),
          ),

          // 4. Heading Tape (Top Strip)
          Positioned(
            top: 0,
            left: 55,
            right: 55,
            height: 32,
            child: CustomPaint(
              painter: _HeadingTapePainter(heading: activeHeading),
            ),
          ),

          // 5. ARMED / DISARMED Badge (Center Top)
          Positioned(
            top: 36,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: isArmed
                      ? AppColors.success.withValues(alpha: 0.25)
                      : Colors.red.withValues(alpha: 0.25),
                  border: Border.all(
                    color: isArmed ? AppColors.success : Colors.red.shade400,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  isArmed ? 'ARMED' : 'DISARMED',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isArmed ? AppColors.success : Colors.red.shade300,
                  ),
                ),
              ),
            ),
          ),

          // 6. Flight Mode Label
          if (drone != null)
            Positioned(
              top: 68,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  drone!.flightMode,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // 7. Status Message / PreArm Warning
          if (!isArmed && drone != null) ...[
            if (drone!.statusMessage.isNotEmpty)
              Positioned(
                top: 86,
                left: 10,
                right: 10,
                child: Center(
                  child: Text(
                    drone!.statusMessage,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade300,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 3),
                      ],
                    ),
                  ),
                ),
              )
            else if (drone!.gpsQuality == 'NO FIX')
              Positioned(
                top: 86,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'PreArm: No GPS Fix',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade300,
                    ),
                  ),
                ),
              ),
          ],

          // 8. Telemetry Status Footer Line (Bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 22,
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    'AS ${activeSpeed.toStringAsFixed(1)}m/s GS ${activeSpeed.toStringAsFixed(1)}m/s',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 8.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (drone != null) ...[
                    Text(
                      'Bat ${drone!.voltage.toStringAsFixed(1)}v ${drone!.battery.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 8.5,
                        color: battColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      drone!.gpsQuality == 'NO FIX'
                          ? 'GPS: No Fix'
                          : 'GPS: ${drone!.gpsQuality}',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 8.5,
                        color: drone!.gpsQuality == 'NO FIX'
                            ? Colors.red
                            : AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SIDE PANEL (340px)
// ─────────────────────────────────────────────
class _SidePanel extends StatefulWidget {
  const _SidePanel({
    required this.roll,
    required this.pitch,
    required this.heading,
    required this.altitude,
    required this.speed,
    required this.drone,
    required this.gcs,
    required this.onAction,
    required this.onDroneChange,
    required this.drones,
  });

  final double roll, pitch, heading, altitude, speed;
  final DroneModel? drone;
  final GcsThemeExtension gcs;
  final void Function(String) onAction;
  final void Function(String?) onDroneChange;
  final List<DroneModel> drones;

  @override
  State<_SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<_SidePanel> {
  int _activeTab = 0;
  final _tabs = const ['QUICK', 'ACTIONS', 'GAUGES', 'MESSAGES', 'PREFLIGHT'];

  Widget _buildGaugesTab() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: AnalogGaugesWidget(
        altitude: widget.altitude,
        speed: widget.speed,
        heading: widget.heading,
        climbRate: widget.drone?.climbRate ?? 0.0,
        pitch: widget.pitch,
        roll: widget.roll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // ─── HUD TOP HALF ───
          SizedBox(
            height: 320,
            child: _HudWidget(
              roll: widget.roll,
              pitch: widget.pitch,
              heading: widget.heading,
              altitude: widget.altitude,
              speed: widget.speed,
              drone: widget.drone,
            ),
          ),

          // ─── TABS ───
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.panels,
              border: Border(bottom: BorderSide(color: AppColors.accentDim)),
            ),
            child: Row(
              children: _tabs.asMap().entries.map((e) {
                final idx = e.key;
                final label = e.value;
                final isActive = _activeTab == idx;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = idx),
                    child: Container(
                      color: isActive
                          ? const Color(0xFF0D8CC6)
                          : Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : AppColors.textSecond,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ─── TAB CONTENT ───
          Expanded(
            child: _activeTab == 0
                ? _buildQuickTab()
                : _activeTab == 1
                    ? _buildActionsTab()
                    : _activeTab == 2
                        ? _buildGaugesTab()
                        : _buildQuickTab(),
          ),

          // ─── DRONE SELECTOR (BOTTOM) ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.panels,
              border: Border(top: BorderSide(color: AppColors.accentDim)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accentDim),
                      borderRadius: BorderRadius.circular(4),
                      color: AppColors.background,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.drone?.id,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        items: widget.drones.map((d) {
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              '${d.name} (${d.id})',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: widget.onDroneChange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'UAV ID: ${widget.drone?.id ?? '--'}',
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    color: AppColors.textSecond,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickTab() {
    final d = widget.drone ??
        const DroneModel(
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
          climbRate: 0,
          windSpeed: 0,
          windDir: '--',
          motor1Rpm: 0,
          motor2Rpm: 0,
          motor3Rpm: 0,
          motor4Rpm: 0,
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Telemetry Grid
          Row(
            children: [
              Expanded(
                  child: _TelemetryCard('ALTITUDE (M)',
                      d.altitude.toStringAsFixed(2), const Color(0xFF9B51E0))),
              const SizedBox(width: 8),
              Expanded(
                  child: _TelemetryCard('GROUNDSPEED (M/S)',
                      d.speed.toStringAsFixed(2), const Color(0xFFF2994A))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _TelemetryCard('YAW (DEG)',
                      d.heading.toStringAsFixed(2), const Color(0xFF27AE60))),
              const SizedBox(width: 8),
              Expanded(
                  child: _TelemetryCard('VERTICAL SPEED (M/S)',
                      d.climbRate.toStringAsFixed(2), const Color(0xFFF2C94C))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _TelemetryCard(
                      'BATTERY %',
                      '${d.battery.toStringAsFixed(2)}%',
                      const Color(0xFFEB5757))),
              const SizedBox(width: 8),
              Expanded(
                  child: _TelemetryCard(
                      'LINK QUALITY',
                      '${d.signal.abs().toStringAsFixed(0)}%',
                      const Color(0xFF0D8CC6))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _TelemetryCard(
                      'WIND SPEED',
                      '${d.windSpeed.toStringAsFixed(1)} km/h',
                      const Color(0xFF00BFA5))),
              const SizedBox(width: 8),
              Expanded(
                  child: _TelemetryCard(
                      'WIND DIRECTION', d.windDir, const Color(0xFF00BFA5))),
            ],
          ),
          const SizedBox(height: 16),

          // Motors RPM
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accentDim),
              borderRadius: BorderRadius.circular(4),
              color: AppColors.panels,
            ),
            child: Column(
              children: [
                const Text('MOTORS RPM',
                    style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        color: AppColors.textSecond,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _MotorCard('MOTOR 1', d.motor1Rpm.toString())),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _MotorCard('MOTOR 2', d.motor2Rpm.toString())),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _MotorCard('MOTOR 3', d.motor3Rpm.toString())),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _MotorCard('MOTOR 4', d.motor4Rpm.toString())),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _ArmBtn(
              label: 'ARM',
              color: AppColors.success,
              onTap: () => widget.onAction('ARM')),
          const SizedBox(height: 8),
          _ArmBtn(
              label: 'TAKEOFF',
              color: AppColors.accent,
              onTap: () => widget.onAction('TAKEOFF')),
          const SizedBox(height: 8),
          _ArmBtn(
              label: 'LAND',
              color: AppColors.warning,
              onTap: () => widget.onAction('LAND')),
          const SizedBox(height: 8),
          _ArmBtn(
              label: 'RTL',
              color: const Color(0xFFFF9800),
              onTap: () => widget.onAction('RTL')),
          const SizedBox(height: 8),
          _ArmBtn(
              label: 'DISARM',
              color: AppColors.danger,
              onTap: () => widget.onAction('DISARM')),
        ],
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.accentDim),
        borderRadius: BorderRadius.circular(4),
        color: AppColors.panels,
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9,
                  color: AppColors.textSecond,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 18,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MotorCard extends StatelessWidget {
  const _MotorCard(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.accentDim),
        borderRadius: BorderRadius.circular(4),
        color: AppColors.panels,
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9,
                  color: AppColors.textSecond,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 14,
                  color: Color(0xFF4A90E2),
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ArmBtn extends StatelessWidget {
  const _ArmBtn(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            )),
      ),
    );
  }
}

/// Rectangular tactical telemetry box matching user's requested layout.
/// Displays symbol/icon on left and live value on right (no text names).
class _TelemetryBox extends StatelessWidget {
  const _TelemetryBox({
    required this.value,
    required this.color,
    required this.icon,
  });

  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xF209111E), // Solid dark high contrast background
        borderRadius:
            BorderRadius.circular(4), // Sharp tactical rectangular box
        border: Border.all(
          color: color.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 15, color: color),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
