import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/store/gcs_notifier.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

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
  bool _isSatellite = false;
  bool _cameraOn = true;
  String _drawMode = 'none';

  // Smooth interpolated HUD values
  double _roll = 0, _pitch = 0, _heading = 0, _altitude = 0, _speed = 0;

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
    final drone = s.drones.isNotEmpty
        ? s.drones.firstWhere((d) => d.id == s.selectedDroneId,
            orElse: () => s.drones.first)
        : null;
    if (drone == null) return;

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

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // ─── MAIN CONTENT ROW ───
          Expanded(
            child: Row(
              children: [
                // ─── LEFT HUD (180px) ───
                SizedBox(
                  width: 180,
                  child: _HudPanel(
                    roll: _roll,
                    pitch: _pitch,
                    heading: _heading,
                    altitude: _altitude,
                    speed: _speed,
                    drone: drone,
                    gcs: gcs,
                  ),
                ),

                // ─── CENTER MAP ───
                Expanded(
                  child: Stack(
                    children: [
                      // Map
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: drone != null
                              ? LatLng(drone.lat, drone.lng)
                              : const LatLng(28.6139, 77.2090),
                          initialZoom: 15,
                          onTap: (_, latlng) {
                            if (_drawMode == 'waypoint') {
                              final idx = s.waypoints.length + 1;
                              ref
                                  .read(gcsProvider.notifier)
                                  .addWaypoint(WaypointModel(
                                    id: 'W${idx.toString().padLeft(2, '0')}',
                                    lat: latlng.latitude,
                                    lng: latlng.longitude,
                                    alt: 50.0,
                                    action: 'Waypoint',
                                  ));
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _isSatellite
                                ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c'],
                          ),

                          // Flight trails
                          PolylineLayer(
                              polylines: s.drones
                                  .map(
                                    (d) => Polyline(
                                      points: d.history
                                          .map((h) =>
                                              LatLng(h['lat']!, h['lng']!))
                                          .toList(),
                                      color: AppColors.accent
                                          .withValues(alpha: 0.4),
                                      strokeWidth: 1.5,
                                    ),
                                  )
                                  .toList()),

                          // Waypoint route
                          if (s.waypoints.length > 1)
                            PolylineLayer<Object>(polylines: [
                              Polyline(
                                points: s.waypoints
                                    .map((wp) => LatLng(wp.lat, wp.lng))
                                    .toList(),
                                color: AppColors.warning.withValues(alpha: 0.6),
                                strokeWidth: 1.5,
                              ),
                            ]),

                          // Geofence
                          if (s.geofence.length > 2)
                            PolygonLayer(polygons: [
                              Polygon(
                                points: s.geofence
                                    .map((g) => LatLng(g['lat']!, g['lng']!))
                                    .toList(),
                                color:
                                    AppColors.warning.withValues(alpha: 0.08),
                                borderColor:
                                    AppColors.warning.withValues(alpha: 0.5),
                                borderStrokeWidth: 1.5,
                              ),
                            ]),

                          // Waypoint markers
                          MarkerLayer(
                              markers: s.waypoints
                                  .asMap()
                                  .entries
                                  .map(
                                    (e) => Marker(
                                      point: LatLng(e.value.lat, e.value.lng),
                                      width: 22,
                                      height: 22,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                            child: Text('${e.key + 1}',
                                                style: const TextStyle(
                                                  fontFamily: 'JetBrains Mono',
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ))),
                                      ),
                                    ),
                                  )
                                  .toList()),

                          // Drone markers
                          MarkerLayer(
                              markers: s.drones.map((d) {
                            final isSelected = d.id == s.selectedDroneId;
                            final healthColor = d.health == 'Healthy'
                                ? AppColors.success
                                : d.health == 'Warning'
                                    ? AppColors.warning
                                    : AppColors.danger;
                            return Marker(
                              point: LatLng(d.lat, d.lng),
                              width: isSelected ? 40 : 30,
                              height: isSelected ? 40 : 30,
                              child: GestureDetector(
                                onTap: () => ref
                                    .read(gcsProvider.notifier)
                                    .selectDrone(d.id),
                                child: Transform.rotate(
                                  angle: d.heading * pi / 180,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: healthColor.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.accent
                                            : healthColor,
                                        width: isSelected ? 2 : 1.5,
                                      ),
                                    ),
                                    child: Icon(LucideIcons.navigation,
                                        size: isSelected ? 20 : 14,
                                        color: isSelected
                                            ? AppColors.accent
                                            : healthColor),
                                  ),
                                ),
                              ),
                            );
                          }).toList()),
                        ],
                      ),

                      // Draw mode + map controls overlay
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Column(children: [
                          _OverlayBtn(
                              LucideIcons.layers,
                              () =>
                                  setState(() => _isSatellite = !_isSatellite)),
                          const SizedBox(height: 4),
                          _OverlayBtn(
                              LucideIcons.mapPin,
                              () => setState(() => _drawMode =
                                  _drawMode == 'waypoint'
                                      ? 'none'
                                      : 'waypoint')),
                          const SizedBox(height: 4),
                          _OverlayBtn(
                              LucideIcons.zoomIn,
                              () => _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom + 1)),
                          const SizedBox(height: 4),
                          _OverlayBtn(
                              LucideIcons.zoomOut,
                              () => _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom - 1)),
                        ]),
                      ),

                      // Draw mode badge
                      if (_drawMode != 'none')
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.4)),
                            ),
                            child: const Text('PLACING WAYPOINT — TAP MAP',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 9,
                                  color: AppColors.warning,
                                )),
                          ),
                        ),
                    ],
                  ),
                ),

                // ─── RIGHT PANEL ───
                SizedBox(
                  width: 200,
                  child: _RightPanel(
                    drone: drone,
                    gcs: gcs,
                    onAction: (action) => ref
                        .read(gcsProvider.notifier)
                        .triggerDroneAction(drone?.id ?? '', action),
                    onUpload: () =>
                        ref.read(gcsProvider.notifier).uploadMission(),
                  ),
                ),
              ],
            ),
          ),

          // ─── CAMERA STRIP (bottom, 120px) ───
          SizedBox(
            height: 120,
            child: _CameraStrip(
              cameraCtrl: _cameraCtrl,
              drones: s.drones,
              cameraOn: _cameraOn,
              onToggle: () => setState(() => _cameraOn = !_cameraOn),
              gcs: gcs,
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
class _HudPanel extends StatelessWidget {
  const _HudPanel({
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
            _HudRow('PITCH', '${pitch.toStringAsFixed(1)}°'),
            _HudRow('ROLL', '${roll.toStringAsFixed(1)}°'),
            _HudRow('SAT', '${drone!.satellites}'),
            _HudRow('HDOP', drone!.hdop.toStringAsFixed(2)),
          ],
        ],
      ),
    );
  }
}

class _HudRow extends StatelessWidget {
  const _HudRow(this.label, this.value);
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
class _RightPanel extends StatelessWidget {
  const _RightPanel({
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
          _RStatRow('ALT', '${drone!.altitude.toStringAsFixed(1)}m',
              AppColors.accent),
          _RStatRow('SPD', '${drone!.speed.toStringAsFixed(1)}m/s',
              AppColors.success),
          _RStatRow('BAT', '${drone!.battery.toStringAsFixed(0)}%', battColor),
          _RStatRow('SIG', '${drone!.signal.toStringAsFixed(0)}dBm',
              AppColors.textSecond),
          _RStatRow('LAT', '${drone!.latency}ms',
              drone!.latency < 100 ? AppColors.success : AppColors.danger),
          _RStatRow('GPS', drone!.gpsQuality, AppColors.success),
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
          _ArmBtn(
              label: 'ARM',
              color: AppColors.success,
              onTap: () => onAction('ARM')),
          const SizedBox(height: 4),
          _ArmBtn(
              label: 'TAKEOFF',
              color: AppColors.accent,
              onTap: () => onAction('TAKEOFF')),
          const SizedBox(height: 4),
          _ArmBtn(
              label: 'LAND',
              color: AppColors.warning,
              onTap: () => onAction('LAND')),
          const SizedBox(height: 4),
          _ArmBtn(
              label: 'RTL',
              color: const Color(0xFFFF9800),
              onTap: () => onAction('RTL')),
          const SizedBox(height: 4),
          _ArmBtn(
              label: 'DISARM',
              color: AppColors.danger,
              onTap: () => onAction('DISARM')),
          const SizedBox(height: 8),
          _ArmBtn(
              label: 'UPLOAD MISSION',
              color: AppColors.accent,
              onTap: onUpload),
        ],
      ),
    );
  }
}

class _RStatRow extends StatelessWidget {
  const _RStatRow(this.label, this.value, this.color);
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
    required this.cameraOn,
    required this.onToggle,
    required this.gcs,
  });

  final AnimationController cameraCtrl;
  final List<DroneModel> drones;
  final bool cameraOn;
  final VoidCallback onToggle;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
            top: BorderSide(color: AppColors.accent.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          // Camera toggle button
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 100,
              height: double.infinity,
              color: const Color(0xFF080E1C),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    cameraOn ? LucideIcons.video : LucideIcons.videoOff,
                    size: 20,
                    color: cameraOn ? AppColors.accent : AppColors.danger,
                  ),
                  const SizedBox(height: 4),
                  Text(cameraOn ? 'CAMERA ON' : 'CAMERA OFF',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 8,
                        color: cameraOn ? AppColors.accent : AppColors.danger,
                      )),
                ],
              ),
            ),
          ),

          // Camera feeds for each drone
          ...drones.map((drone) => Expanded(
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.15)),
                  ),
                  child: cameraOn
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CustomPaint(
                            painter:
                                _CamPainter(anim: cameraCtrl, drone: drone),
                            child: const SizedBox.expand(),
                          ),
                        )
                      : Center(
                          child: Icon(LucideIcons.videoOff,
                              size: 18,
                              color:
                                  AppColors.textSecond.withValues(alpha: 0.3))),
                ),
              )),
        ],
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
