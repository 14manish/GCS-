import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/models/models.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class MissionPage extends ConsumerStatefulWidget {
  const MissionPage({super.key});

  @override
  ConsumerState<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends ConsumerState<MissionPage> {
  bool _isSatellite = false;
  String _activeTool = 'Waypoint';
  final _mapController = MapController();
  final List<LatLng> _geofencePoints = [];

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final notifier = ref.read(gcsProvider.notifier);

    final totalDist = s.waypoints.length > 1
        ? (s.waypoints.length * 0.47).toStringAsFixed(2)
        : '0.00';
    final estTime =
        s.waypoints.length > 1 ? (s.waypoints.length * 0.47 * 3.5).ceil() : 0;

    return Container(
      color: gcs.bg,
      child: Row(
        children: [
          // ─── LEFT PANEL ───
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  right: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelHeader('MISSION CONTROLS', gcs),
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      _sectionLabel('MISSION NAME', gcs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: gcs.bg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: gcs.accent.withValues(alpha: 0.2)),
                        ),
                        child: TextField(
                          onChanged: (v) =>
                              notifier.setMissionConfig({'missionName': v}),
                          style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              color: gcs.text),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: s.missionName,
                            hintStyle: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                color: gcs.secText),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      _sectionLabel('MISSION TYPE', gcs),
                      _DropSel(
                        value: s.missionType,
                        items: const [
                          'Survey',
                          'Point to Point',
                          'Inspection',
                          'Search & Rescue',
                          'Delivery'
                        ],
                        gcs: gcs,
                        onChanged: (v) =>
                            notifier.setMissionConfig({'missionType': v}),
                      ),
                      const SizedBox(height: 10),

                      _sectionLabel('ALTITUDE FRAME', gcs),
                      _DropSel(
                        value: s.altitudeFrame,
                        items: const [
                          'Relative',
                          'Absolute (AMSL)',
                          'Terrain (AGL)'
                        ],
                        gcs: gcs,
                        onChanged: (v) =>
                            notifier.setMissionConfig({'altitudeFrame': v}),
                      ),
                      const SizedBox(height: 10),

                      _sectionLabel('DEFAULT ALT (m)', gcs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: gcs.bg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: gcs.accent.withValues(alpha: 0.2)),
                        ),
                        child: TextField(
                          onChanged: (v) => notifier.setMissionConfig(
                              {'defaultAltitude': double.tryParse(v)}),
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              color: gcs.text),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: s.defaultAltitude.toStringAsFixed(0),
                            hintStyle: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                color: gcs.secText),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Mission stats
                      _sectionLabel('MISSION STATS', gcs),
                      _statRow('Waypoints', '${s.waypoints.length}', gcs.accent,
                          gcs),
                      _statRow('Distance', '$totalDist km', gcs.text, gcs),
                      _statRow('Est. Time', '$estTime min', gcs.text, gcs),
                    ],
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    _actionButton(
                        'VALIDATE MISSION',
                        gcs.warning,
                        LucideIcons.shieldCheck,
                        () => notifier.runValidation(),
                        gcs),
                    const SizedBox(height: 6),
                    _actionButton(
                        'UPLOAD MISSION',
                        gcs.accent,
                        LucideIcons.upload,
                        () => notifier.uploadMission(),
                        gcs),
                    const SizedBox(height: 6),
                    _actionButton('CLEAR ALL', gcs.danger, LucideIcons.trash2,
                        () {
                      notifier.setWaypoints([]);
                      notifier.setGeofence([]);
                      setState(() => _geofencePoints.clear());
                    }, gcs),
                  ]),
                ),
              ],
            ),
          ),

          // ─── CENTER MAP ───
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(28.6139, 77.2090),
                    initialZoom: 14,
                    onTap: (_, latlng) {
                      if (_activeTool == 'Waypoint') {
                        final idx = s.waypoints.length + 1;
                        final wp = WaypointModel(
                          id: 'W${idx.toString().padLeft(2, '0')}',
                          lat: latlng.latitude,
                          lng: latlng.longitude,
                          alt: s.defaultAltitude,
                          action: 'Waypoint',
                        );
                        notifier.addWaypoint(wp);
                      } else if (_activeTool == 'Polygon') {
                        setState(() => _geofencePoints.add(latlng));
                        notifier.setGeofence(_geofencePoints
                            .map(
                              (p) => {'lat': p.latitude, 'lng': p.longitude},
                            )
                            .toList());
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

                    // Route polyline
                    if (s.waypoints.length > 1)
                      PolylineLayer<Object>(polylines: [
                        Polyline(
                          points: s.waypoints
                              .map((wp) => LatLng(wp.lat, wp.lng))
                              .toList(),
                          color: gcs.warning.withValues(alpha: 0.6),
                          strokeWidth: 2,
                        ),
                      ]),

                    // Geofence polygon
                    if (_geofencePoints.length > 2)
                      PolygonLayer<Object>(polygons: [
                        Polygon(
                          points: _geofencePoints,
                          color: gcs.accent.withValues(alpha: 0.1),
                          borderColor: gcs.accent,
                          borderStrokeWidth: 1.5,
                        ),
                      ]),

                    // Waypoint markers
                    MarkerLayer(
                      markers: s.waypoints.asMap().entries.map((e) {
                        final i = e.key;
                        final wp = e.value;
                        return Marker(
                          point: LatLng(wp.lat, wp.lng),
                          width: 28,
                          height: 28,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Center(
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ))),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Map tools overlay
                Positioned(
                  top: 12,
                  left: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...['Waypoint', 'Polygon', 'None'].map((tool) {
                        final isActive = _activeTool == tool;
                        return GestureDetector(
                          onTap: () => setState(() => _activeTool = tool),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.accent
                                  : AppColors.panels.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.accent
                                    : AppColors.accent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(children: [
                              Icon(
                                tool == 'Select'
                                    ? LucideIcons.mousePointer2
                                    : tool == 'Polygon'
                                        ? LucideIcons.hexagon
                                        : LucideIcons.mapPin,
                                size: 14,
                                color: isActive ? gcs.bg : gcs.text,
                              ),
                              const SizedBox(width: 5),
                              Text(tool.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 9,
                                    color: isActive ? gcs.bg : AppColors.accent,
                                  )),
                            ]),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Map type + zoom controls
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(children: [
                    _mapBtn(LucideIcons.layers,
                        () => setState(() => _isSatellite = !_isSatellite)),
                    const SizedBox(height: 4),
                    _mapBtn(
                        LucideIcons.zoomIn,
                        () => _mapController.move(_mapController.camera.center,
                            _mapController.camera.zoom + 1)),
                    const SizedBox(height: 4),
                    _mapBtn(
                        LucideIcons.zoomOut,
                        () => _mapController.move(_mapController.camera.center,
                            _mapController.camera.zoom - 1)),
                  ]),
                ),

                // Upload progress
                if (s.uploadProgress > 0 && s.uploadProgress < 100)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.panels.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('UPLOADING MISSION — ${s.uploadProgress}%',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                color: AppColors.accent,
                              )),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: s.uploadProgress / 100,
                              backgroundColor: AppColors.background,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.accent),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ─── RIGHT PANEL: Waypoint List + Validation ───
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  left: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelHeader('WAYPOINTS (${s.waypoints.length})', gcs),
                Expanded(
                  child: s.waypoints.isEmpty
                      ? Center(
                          child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.mapPin,
                                size: 28,
                                color: gcs.secText.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text('Click map to add',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  color: gcs.secText,
                                )),
                          ],
                        ))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: s.waypoints.length,
                          itemBuilder: (context, i) {
                            final wp = s.waypoints[i];
                            return Container(
                              margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: gcs.bg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: gcs.accent.withValues(alpha: 0.1)),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                      child: Text('${i + 1}',
                                          style: const TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ))),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(wp.id,
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: gcs.text,
                                        )),
                                    Text(
                                        '${wp.lat.toStringAsFixed(4)}, ${wp.lng.toStringAsFixed(4)} | ${wp.alt}m',
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 8,
                                          color: gcs.secText,
                                        )),
                                  ],
                                )),
                                GestureDetector(
                                  onTap: () => notifier.deleteWaypoint(wp.id),
                                  child: Icon(LucideIcons.x,
                                      size: 14, color: gcs.danger),
                                ),
                              ]),
                            );
                          },
                        ),
                ),

                // Validation panel
                if (s.validationSteps.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: gcs.accent.withValues(alpha: 0.15))),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VALIDATION',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              color: gcs.secText,
                              letterSpacing: 1.5,
                            )),
                        const SizedBox(height: 6),
                        ...s.validationSteps.map((step) {
                          final color = step.status == 'pass'
                              ? gcs.success
                              : step.status == 'fail'
                                  ? gcs.danger
                                  : step.status == 'loading'
                                      ? gcs.warning
                                      : gcs.secText;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              step.status == 'loading'
                                  ? SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5, color: gcs.warning))
                                  : Icon(
                                      step.status == 'pass'
                                          ? LucideIcons.check
                                          : step.status == 'fail'
                                              ? LucideIcons.x
                                              : LucideIcons.clock,
                                      size: 12,
                                      color: color),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(step.name,
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 9,
                                        color: color,
                                      ))),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelHeader(String title, GcsThemeExtension gcs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
      ),
      child: Text(title,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: gcs.accent,
          )),
    );
  }

  Widget _sectionLabel(String text, GcsThemeExtension gcs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9,
            color: gcs.secText,
            letterSpacing: 1.2,
          )),
    );
  }

  Widget _statRow(
      String label, String value, Color color, GcsThemeExtension gcs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  color: gcs.secText,
                ))),
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

  Widget _actionButton(String label, Color color, IconData icon,
      VoidCallback onTap, GcsThemeExtension gcs) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              )),
        ]),
      ),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) {
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

class _DropSel extends StatelessWidget {
  const _DropSel(
      {required this.value,
      required this.items,
      required this.gcs,
      required this.onChanged});
  final String value;
  final List<String> items;
  final GcsThemeExtension gcs;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : items.first;
    return Container(
      decoration: BoxDecoration(
        color: gcs.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          dropdownColor: gcs.panels,
          style: TextStyle(
              fontFamily: 'JetBrains Mono', fontSize: 11, color: gcs.text),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
