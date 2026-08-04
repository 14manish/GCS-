import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../core/store/gcs_notifier.dart';
import '../core/models/models.dart';
import '../core/models/map_providers.dart';
import '../core/widgets/map_provider_selector.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class MissionPage extends ConsumerStatefulWidget {
  const MissionPage({super.key});

  @override
  ConsumerState<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends ConsumerState<MissionPage> {
  String _activeTool = 'Waypoint';
  final _mapController = MapController();
  final List<LatLng> _geofencePoints = [];

  // Table header style
  final _thStyle = const TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 9,
      fontWeight: FontWeight.bold,
      color: Colors.black87);
  final _tdStyle = const TextStyle(
      fontFamily: 'JetBrains Mono', fontSize: 10, color: Colors.black54);

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
          // ─── LEFT PANEL (MISSION CONTROLS) ───
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
                      _textField(
                          s.missionName,
                          (v) => notifier.setMissionConfig({'missionName': v}),
                          gcs),
                      const SizedBox(height: 10),
                      _sectionLabel('MISSION TYPE', gcs),
                      _DropSel(
                        value: s.missionType,
                        items: const [
                          'Survey Grid',
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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('ALT FRAME', gcs),
                                _DropSel(
                                  value: s.altitudeFrame,
                                  items: const [
                                    'Relative',
                                    'Absolute (AMSL)',
                                    'Terrain (AGL)'
                                  ],
                                  gcs: gcs,
                                  onChanged: (v) => notifier
                                      .setMissionConfig({'altitudeFrame': v}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('DEFAULT ALT (m)', gcs),
                                _textField(
                                    s.defaultAltitude.toStringAsFixed(0),
                                    (v) => notifier.setMissionConfig({
                                          'defaultAltitude':
                                              double.tryParse(v) ?? 100
                                        }),
                                    gcs,
                                    isNumber: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _sectionLabel('DESIGNER TOOLS', gcs),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: gcs.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.mapPin,
                                      size: 10, color: gcs.accent),
                                  const SizedBox(width: 4),
                                  Text('WP TOOL',
                                      style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 9,
                                          color: gcs.accent,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: gcs.bg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: gcs.accent.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.hexagon,
                                      size: 10, color: gcs.secText),
                                  const SizedBox(width: 4),
                                  Text('SURVEY GRID',
                                      style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 9,
                                          color: gcs.secText,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _statRow(
                          'WAYPOINTS:', '${s.waypoints.length}', gcs.text, gcs),
                      _statRow('EST DISTANCE:', '$totalDist km', gcs.text, gcs),
                      _statRow(
                          'EST FLIGHT TIME:', '$estTime mins', gcs.text, gcs),
                    ],
                  ),
                ),
                // Bottom Actions
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _actionButton('+ ADD WAYPOINT', gcs.accent, null, () {
                        final idx = s.waypoints.length + 1;
                        notifier.addWaypoint(WaypointModel(
                            id: 'W${idx.toString().padLeft(2, '0')}',
                            lat: 28.6139,
                            lng: 77.2090,
                            alt: s.defaultAltitude,
                            action: 'Waypoint'));
                      }, gcs, filled: true),
                      const SizedBox(height: 8),
                      _actionButton(
                          'CLEAR MISSION', gcs.danger, LucideIcons.trash2, () {
                        notifier.setWaypoints([]);
                        notifier.setGeofence([]);
                        setState(() => _geofencePoints.clear());
                      }, gcs, filled: false, outlineOnly: true),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── CENTER AREA (MAP + TABLE) ───
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // MAP (Top)
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
                              notifier.addWaypoint(WaypointModel(
                                  id: 'W${idx.toString().padLeft(2, '0')}',
                                  lat: latlng.latitude,
                                  lng: latlng.longitude,
                                  alt: s.defaultAltitude,
                                  action: 'Waypoint'));
                            } else if (_activeTool == 'Polygon') {
                              setState(() => _geofencePoints.add(latlng));
                              notifier.setGeofence(_geofencePoints
                                  .map((p) =>
                                      {"lat": p.latitude, "lng": p.longitude})
                                  .toList());
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                MapProviders.get(s.mapProvider).urlTemplate,
                            subdomains:
                                MapProviders.get(s.mapProvider).subdomains,
                          ),
                          if (s.waypoints.length > 1)
                            PolylineLayer<Object>(polylines: [
                              Polyline(
                                  points: s.waypoints
                                      .map((wp) => LatLng(wp.lat, wp.lng))
                                      .toList(),
                                  color: gcs.warning.withValues(alpha: 0.6),
                                  strokeWidth: 2),
                            ]),
                          if (_geofencePoints.length > 2)
                            PolygonLayer<Object>(polygons: [
                              Polygon(
                                  points: _geofencePoints,
                                  color: gcs.accent.withValues(alpha: 0.1),
                                  borderColor: gcs.accent,
                                  borderStrokeWidth: 1.5),
                            ]),
                          MarkerLayer(
                            markers: s.waypoints.asMap().entries.map((e) {
                              return Marker(
                                point: LatLng(e.value.lat, e.value.lng),
                                width: 28,
                                height: 28,
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5)),
                                  child: Center(
                                      child: Text('${e.key + 1}',
                                          style: const TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.background))),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      // Map Tools overlay
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: ['Waypoint', 'Polygon', 'None'].map((tool) {
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
                                      : AppColors.panels
                                          .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: isActive
                                          ? AppColors.accent
                                          : AppColors.accent
                                              .withValues(alpha: 0.2)),
                                ),
                                child: Row(children: [
                                  Icon(
                                      tool == 'Select'
                                          ? LucideIcons.mousePointer2
                                          : tool == 'Polygon'
                                              ? LucideIcons.hexagon
                                              : LucideIcons.mapPin,
                                      size: 14,
                                      color: isActive ? gcs.bg : gcs.text),
                                  const SizedBox(width: 5),
                                  Text(tool.toUpperCase(),
                                      style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 9,
                                          color: isActive
                                              ? gcs.bg
                                              : AppColors.accent)),
                                ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Column(children: [
                          _mapBtn(LucideIcons.layers,
                              () => showMapProviderSelector(context, ref)),
                          const SizedBox(height: 4),
                          _mapBtn(
                              LucideIcons.zoomIn,
                              () => _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom + 1)),
                          const SizedBox(height: 4),
                          _mapBtn(
                              LucideIcons.zoomOut,
                              () => _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom - 1)),
                        ]),
                      ),
                    ],
                  ),
                ),

                // TABLE (Bottom)
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        top: BorderSide(
                            color: gcs.accent.withValues(alpha: 0.2))),
                  ),
                  child: Column(
                    children: [
                      // Table Toolbar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color:
                                          gcs.accent.withValues(alpha: 0.1)))),
                          child: Row(
                            children: [
                              _tbStat('WP RADIUS:', '3.00'),
                              const SizedBox(width: 16),
                              _tbStat('LOITER RADIUS:', '45'),
                              const SizedBox(width: 16),
                              _tbStat('DEFAULT ALT:', '100'),
                              const SizedBox(width: 8),
                              _DropSel(
                                  value: 'Relative',
                                  items: const ['Relative'],
                                  gcs: gcs,
                                  onChanged: (_) {},
                                  compact: true),
                              const SizedBox(width: 16),
                              Row(children: [
                                Icon(Icons.check_box,
                                    color: gcs.accent, size: 14),
                                const SizedBox(width: 4),
                                Text('VERIFY HEIGHT',
                                    style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 9,
                                        color: gcs.text,
                                        fontWeight: FontWeight.bold)),
                              ]),
                              const SizedBox(width: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: gcs.success,
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text('ADD BELOW',
                                    style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 16),
                              _tbStat('ALT WARN:', '0'),
                              const SizedBox(width: 16),
                              Row(children: [
                                Icon(Icons.check_box_outline_blank,
                                    color: gcs.secText, size: 14),
                                const SizedBox(width: 4),
                                Text('NAVTIP',
                                    style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 9,
                                        color: gcs.secText,
                                        fontWeight: FontWeight.bold)),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      // Table Content (Header + Rows horizontally scrollable)
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 950,
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              color: gcs.accent
                                                  .withValues(alpha: 0.1)))),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                          width: 25,
                                          child: Text('#', style: _thStyle)),
                                      SizedBox(
                                          width: 95,
                                          child:
                                              Text('COMMAND', style: _thStyle)),
                                      SizedBox(
                                          width: 45,
                                          child:
                                              Text('DELAY', style: _thStyle)),
                                      SizedBox(
                                          width: 35,
                                          child: Text('P1', style: _thStyle)),
                                      SizedBox(
                                          width: 35,
                                          child: Text('P2', style: _thStyle)),
                                      SizedBox(
                                          width: 35,
                                          child: Text('P3', style: _thStyle)),
                                      SizedBox(
                                          width: 35,
                                          child: Text('P4', style: _thStyle)),
                                      SizedBox(
                                          width: 75,
                                          child: Text('LAT', style: _thStyle)),
                                      SizedBox(
                                          width: 75,
                                          child: Text('LONG', style: _thStyle)),
                                      SizedBox(
                                          width: 60,
                                          child:
                                              Text('ALT (M)', style: _thStyle)),
                                      SizedBox(
                                          width: 80,
                                          child:
                                              Text('FRAME', style: _thStyle)),
                                      SizedBox(
                                          width: 30,
                                          child: Text('DEL', style: _thStyle)),
                                      SizedBox(
                                          width: 45,
                                          child: Text('MOVE', style: _thStyle)),
                                      SizedBox(
                                          width: 55,
                                          child:
                                              Text('GRAD %', style: _thStyle)),
                                      SizedBox(
                                          width: 50,
                                          child:
                                              Text('ANGLE', style: _thStyle)),
                                      SizedBox(
                                          width: 60,
                                          child: Text('DIST (M)',
                                              style: _thStyle)),
                                      SizedBox(
                                          width: 40,
                                          child: Text('AZ', style: _thStyle)),
                                    ],
                                  ),
                                ),
                                // Table Body
                                Expanded(
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: s.waypoints.length,
                                    itemBuilder: (context, i) {
                                      final wp = s.waypoints[i];
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                            border: Border(
                                                bottom: BorderSide(
                                                    color: gcs.accent
                                                        .withValues(
                                                            alpha: 0.05)))),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                                width: 25,
                                                child: Text('${i + 1}',
                                                    style: _tdStyle.copyWith(
                                                        color: gcs.accent,
                                                        fontWeight:
                                                            FontWeight.bold))),
                                            SizedBox(
                                                width: 95,
                                                child: _DropSel(
                                                    value: 'WAYPOINT',
                                                    items: const ['WAYPOINT'],
                                                    gcs: gcs,
                                                    onChanged: (_) {},
                                                    compact: true)),
                                            SizedBox(
                                                width: 45,
                                                child:
                                                    Text('0', style: _tdStyle)),
                                            SizedBox(
                                                width: 35,
                                                child:
                                                    Text('0', style: _tdStyle)),
                                            SizedBox(
                                                width: 35,
                                                child:
                                                    Text('0', style: _tdStyle)),
                                            SizedBox(
                                                width: 35,
                                                child:
                                                    Text('0', style: _tdStyle)),
                                            SizedBox(
                                                width: 35,
                                                child:
                                                    Text('0', style: _tdStyle)),
                                            SizedBox(
                                                width: 75,
                                                child: Text(
                                                    wp.lat.toStringAsFixed(4),
                                                    style: _tdStyle)),
                                            SizedBox(
                                                width: 75,
                                                child: Text(
                                                    wp.lng.toStringAsFixed(4),
                                                    style: _tdStyle)),
                                            SizedBox(
                                                width: 60,
                                                child: Text(
                                                    wp.alt.toStringAsFixed(0),
                                                    style: _tdStyle)),
                                            SizedBox(
                                                width: 80,
                                                child: _DropSel(
                                                    value: 'Relative',
                                                    items: const ['Relative'],
                                                    gcs: gcs,
                                                    onChanged: (_) {},
                                                    compact: true)),
                                            SizedBox(
                                                width: 30,
                                                child: GestureDetector(
                                                    onTap: () => notifier
                                                        .deleteWaypoint(wp.id),
                                                    child: Icon(LucideIcons.x,
                                                        size: 14,
                                                        color: gcs.danger))),
                                            const SizedBox(
                                                width: 45,
                                                child: Row(children: [
                                                  Icon(Icons.arrow_upward,
                                                      size: 12,
                                                      color: Colors.black26),
                                                  SizedBox(width: 4),
                                                  Icon(Icons.arrow_downward,
                                                      size: 12,
                                                      color: Colors.blue)
                                                ])),
                                            SizedBox(
                                                width: 55,
                                                child: Text('0.0%',
                                                    style: _tdStyle)),
                                            SizedBox(
                                                width: 50,
                                                child: Text('0.0°',
                                                    style: _tdStyle)),
                                            SizedBox(
                                                width: 60,
                                                child: Text('200.5',
                                                    style: _tdStyle)),
                                            SizedBox(
                                                width: 40,
                                                child: Text('71°',
                                                    style: _tdStyle)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── RIGHT PANEL (VALIDATION WIZARD) ───
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  left: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelHeader('VALIDATION WIZARD', gcs),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    children: [
                      _valStep('Check Airspace', 'Clear / Caution / Blocked',
                          LucideIcons.checkCircle2, gcs.success),
                      _valStep(
                          'Check weather',
                          'Suitable / Marginal / Unsuitable',
                          LucideIcons.checkCircle2,
                          gcs.success),
                      _valStep(
                          'NPNT Compliance',
                          'PA Valid / PA Expired / NO PA',
                          LucideIcons.helpCircle,
                          gcs.secText),
                      _valStep('Validate Mission', 'Checks pending',
                          LucideIcons.helpCircle, gcs.secText),
                      _valStep('Upload Mission', 'Ready to upload',
                          LucideIcons.helpCircle, gcs.secText),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _actionButton('VALIDATE MISSION', gcs.accent, null,
                          () => notifier.runValidation(), gcs,
                          filled: false, outlineOnly: true),
                      const SizedBox(height: 8),
                      _actionButton('UPLOAD MISSION', gcs.accent, null,
                          () => notifier.uploadMission(), gcs,
                          filled: true),
                      const SizedBox(height: 8),
                      _actionButton(
                          'START MISSION', gcs.success, LucideIcons.play, () {
                        notifier.triggerDroneAction(
                            s.selectedDroneId, 'MISSION');
                        context.go('/fly');
                      }, gcs, filled: true),
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
              bottom: BorderSide(color: gcs.accent.withValues(alpha: 0.15)))),
      child: Text(title,
          style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: gcs.accent)),
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
              letterSpacing: 1.2)),
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
                    color: gcs.secText))),
        Text(value,
            style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _tbStat(String label, String value) {
    return Row(children: [
      Text(label,
          style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: Colors.black54)),
      const SizedBox(width: 4),
      Text(value,
          style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black)),
    ]);
  }

  Widget _textField(
      String hint, ValueChanged<String> onChanged, GcsThemeExtension gcs,
      {bool isNumber = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: gcs.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.2)),
      ),
      child: TextField(
        onChanged: onChanged,
        keyboardType: isNumber ? TextInputType.number : null,
        style: TextStyle(
            fontFamily: 'JetBrains Mono', fontSize: 11, color: gcs.text),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
              fontFamily: 'JetBrains Mono', fontSize: 11, color: gcs.secText),
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, IconData? icon,
      VoidCallback onTap, GcsThemeExtension gcs,
      {bool filled = false, bool outlineOnly = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: outlineOnly
              ? Colors.transparent
              : (filled
                  ? color.withValues(alpha: 0.8)
                  : color.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: outlineOnly
                  ? color
                  : (filled
                      ? Colors.transparent
                      : color.withValues(alpha: 0.3))),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon,
                size: 14,
                color: outlineOnly ? color : (filled ? Colors.white : color)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  color: outlineOnly ? color : (filled ? Colors.white : color),
                  fontWeight: FontWeight.bold)),
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

  Widget _valStep(String title, String subtitle, IconData icon, Color color) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9,
                        color: color)),
              ]))
        ]));
  }
}

class _DropSel extends StatelessWidget {
  const _DropSel(
      {required this.value,
      required this.items,
      required this.gcs,
      required this.onChanged,
      this.compact = false});
  final String value;
  final List<String> items;
  final GcsThemeExtension gcs;
  final ValueChanged<String?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : items.first;
    return Container(
      decoration: BoxDecoration(
        color: compact ? Colors.transparent : gcs.bg,
        borderRadius: BorderRadius.circular(4),
        border: compact
            ? null
            : Border.all(color: gcs.accent.withValues(alpha: 0.2)),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: !compact,
          icon: Icon(LucideIcons.chevronDown,
              size: compact ? 12 : 16, color: gcs.text),
          dropdownColor: gcs.panels,
          style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: compact ? 10 : 11,
              color: gcs.text),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
