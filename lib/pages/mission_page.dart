import 'dart:math' as math;
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

const List<String> kCommandTypes = [
  'Waypoint',
  'Takeoff',
  'Loiter',
  'Land',
  'RTL',
  'Spline Waypoint',
];

const double kAssumedCruiseSpeedMps = 10.0;

class MissionPage extends ConsumerStatefulWidget {
  const MissionPage({super.key});

  @override
  ConsumerState<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends ConsumerState<MissionPage> {
  String _activeTool = 'Waypoint';
  final _mapController = MapController();
  final List<LatLng> _geofencePoints = [];
  int? _selectedIndex;

  // ─── GEO HELPERS ───

  double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  double _bearingDegrees(LatLng a, LatLng b) {
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = _rad2deg(math.atan2(y, x));
    return (brng + 360) % 360;
  }

  double _deg2rad(double d) => d * math.pi / 180.0;
  double _rad2deg(double r) => r * 180.0 / math.pi;

  ({double distM, double bearingDeg, double gradePct}) _legStats(
      List<WaypointModel> wps, int i) {
    if (i == 0) return (distM: 0, bearingDeg: 0, gradePct: 0);
    final a = LatLng(wps[i - 1].lat, wps[i - 1].lng);
    final b = LatLng(wps[i].lat, wps[i].lng);
    final dist = _haversineMeters(a, b);
    final bearing = _bearingDegrees(a, b);
    final altDiff = wps[i].alt - wps[i - 1].alt;
    final grade = dist > 0 ? (altDiff / dist) * 100 : 0.0;
    return (distM: dist, bearingDeg: bearing, gradePct: grade);
  }

  double _totalDistanceKm(List<WaypointModel> wps) {
    double total = 0;
    for (var i = 1; i < wps.length; i++) {
      total += _haversineMeters(
          LatLng(wps[i - 1].lat, wps[i - 1].lng), LatLng(wps[i].lat, wps[i].lng));
    }
    return total / 1000.0;
  }

  // ─── STATE MUTATION HELPERS ───

  void _replaceWaypoint(WidgetRef ref, int index,
      {double? lat, double? lng, double? alt, String? action}) {
    final s = ref.read(gcsProvider);
    final notifier = ref.read(gcsProvider.notifier);
    final wp = s.waypoints[index];
    final updated = WaypointModel(
      id: wp.id,
      lat: lat ?? wp.lat,
      lng: lng ?? wp.lng,
      alt: alt ?? wp.alt,
      action: action ?? wp.action,
    );
    final newList = [...s.waypoints];
    newList[index] = updated;
    notifier.setWaypoints(newList);
  }

  void _moveWaypoint(WidgetRef ref, int index, int delta) {
    final s = ref.read(gcsProvider);
    final target = index + delta;
    if (target < 0 || target >= s.waypoints.length) return;
    final newList = [...s.waypoints];
    final item = newList.removeAt(index);
    newList.insert(target, item);
    ref.read(gcsProvider.notifier).setWaypoints(newList);
    setState(() => _selectedIndex = target);
  }

  void _insertBelowSelected(WidgetRef ref, LatLng at) {
    final s = ref.read(gcsProvider);
    final notifier = ref.read(gcsProvider.notifier);
    final insertAt = (_selectedIndex ?? s.waypoints.length - 1) + 1;
    final idx = s.waypoints.length + 1;
    final newWp = WaypointModel(
        id: 'W${idx.toString().padLeft(2, '0')}',
        lat: at.latitude,
        lng: at.longitude,
        alt: s.defaultAltitude,
        action: 'Waypoint');
    final newList = [...s.waypoints];
    newList.insert(insertAt.clamp(0, newList.length), newWp);
    notifier.setWaypoints(newList);
    setState(() => _selectedIndex = insertAt);
  }

  Future<void> _openEditDialog(BuildContext context, WidgetRef ref, int index) async {
    final s = ref.read(gcsProvider);
    final gcs = context.gcs;
    final wp = s.waypoints[index];
    final latCtrl = TextEditingController(text: wp.lat.toStringAsFixed(6));
    final lngCtrl = TextEditingController(text: wp.lng.toStringAsFixed(6));
    final altCtrl = TextEditingController(text: wp.alt.toStringAsFixed(1));
    String action = kCommandTypes.contains(wp.action) ? wp.action : kCommandTypes.first;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: gcs.panels,
          title: Text('Edit Waypoint ${wp.id}', style: TextStyle(color: gcs.accent, fontFamily: 'JetBrains Mono')),
          content: StatefulBuilder(
            builder: (ctx, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: latCtrl, style: TextStyle(color: gcs.text), decoration: InputDecoration(labelText: 'Latitude', labelStyle: TextStyle(color: gcs.secText))),
                TextField(controller: lngCtrl, style: TextStyle(color: gcs.text), decoration: InputDecoration(labelText: 'Longitude', labelStyle: TextStyle(color: gcs.secText))),
                TextField(controller: altCtrl, style: TextStyle(color: gcs.text), decoration: InputDecoration(labelText: 'Altitude (m)', labelStyle: TextStyle(color: gcs.secText))),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: action,
                  isExpanded: true,
                  dropdownColor: gcs.panels,
                  style: TextStyle(color: gcs.text, fontFamily: 'JetBrains Mono'),
                  items: kCommandTypes
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => action = v ?? action),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: gcs.secText))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: gcs.accent),
              onPressed: () {
                _replaceWaypoint(
                  ref,
                  index,
                  lat: double.tryParse(latCtrl.text),
                  lng: double.tryParse(lngCtrl.text),
                  alt: double.tryParse(altCtrl.text),
                  action: action,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final notifier = ref.read(gcsProvider.notifier);

    final totalDist = _totalDistanceKm(s.waypoints);
    final estTimeMin = kAssumedCruiseSpeedMps > 0
        ? ((totalDist * 1000) / kAssumedCruiseSpeedMps / 60).ceil()
        : 0;

    final thStyle = TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: gcs.accent);
    final tdStyle = TextStyle(
        fontFamily: 'JetBrains Mono', fontSize: 10, color: gcs.text);

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
                            child: GestureDetector(
                              onTap: () => setState(() => _activeTool = 'Waypoint'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: _activeTool == 'Waypoint'
                                      ? gcs.accent.withValues(alpha: 0.15)
                                      : gcs.bg,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: gcs.accent.withValues(alpha: 0.2)),
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
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _activeTool = 'Polygon'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: _activeTool == 'Polygon'
                                      ? gcs.accent.withValues(alpha: 0.15)
                                      : gcs.bg,
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _statRow(
                          'WAYPOINTS:', '${s.waypoints.length}', gcs.text, gcs),
                      _statRow('EST DISTANCE:', '${totalDist.toStringAsFixed(2)} km', gcs.text, gcs),
                      _statRow(
                          'EST FLIGHT TIME:', '$estTimeMin mins', gcs.text, gcs),
                    ],
                  ),
                ),
                // Bottom Actions
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _actionButton('+ ADD WAYPOINT', gcs.accent, null, () {
                        final center = _mapController.camera.center;
                        final idx = s.waypoints.length + 1;
                        notifier.addWaypoint(WaypointModel(
                            id: 'W${idx.toString().padLeft(2, '0')}',
                            lat: center.latitude,
                            lng: center.longitude,
                            alt: s.defaultAltitude,
                            action: 'Waypoint'));
                      }, gcs, filled: true),
                      const SizedBox(height: 8),
                      _actionButton(
                          'CLEAR MISSION', gcs.danger, LucideIcons.trash2, () {
                        notifier.setWaypoints([]);
                        notifier.setGeofence([]);
                        setState(() {
                          _geofencePoints.clear();
                          _selectedIndex = null;
                        });
                      }, gcs, filled: false, outlineOnly: true),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── CENTER AREA (MAP + FULL-WIDTH DARK TACTICAL TABLE) ───
          Expanded(
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
                            userAgentPackageName: 'com.example.gcs_flutter',
                          ),
                          if (s.waypoints.length > 1)
                            PolylineLayer<Object>(polylines: [
                              Polyline(
                                  points: s.waypoints
                                      .map((wp) => LatLng(wp.lat, wp.lng))
                                      .toList(),
                                  color: gcs.warning.withValues(alpha: 0.8),
                                  strokeWidth: 2.5),
                            ]),
                          if (_geofencePoints.length > 2)
                            PolygonLayer<Object>(polygons: [
                              Polygon(
                                  points: _geofencePoints,
                                  color: gcs.accent.withValues(alpha: 0.15),
                                  borderColor: gcs.accent,
                                  borderStrokeWidth: 2.0),
                            ]),
                          MarkerLayer(
                            markers: s.waypoints.asMap().entries.map((e) {
                              final i = e.key;
                              final selected = i == _selectedIndex;
                              return Marker(
                                point: LatLng(e.value.lat, e.value.lng),
                                width: 30,
                                height: 30,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedIndex = i),
                                  onDoubleTap: () => _openEditDialog(context, ref, i),
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: selected ? gcs.warning : AppColors.accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white,
                                            width: selected ? 2.5 : 1.5)),
                                    child: Center(
                                        child: Text('${i + 1}',
                                            style: const TextStyle(
                                                fontFamily: 'JetBrains Mono',
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.background))),
                                  ),
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
                                          .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: isActive
                                          ? AppColors.accent
                                          : AppColors.accent
                                              .withValues(alpha: 0.3)),
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
                                              : AppColors.accent,
                                          fontWeight: FontWeight.bold)),
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

                // ─── WAYPOINTS TABLE (FULL-WIDTH DARK TACTICAL PANEL) ───
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: gcs.panels,
                    border: Border(
                        top: BorderSide(
                            color: gcs.accent.withValues(alpha: 0.2))),
                  ),
                  child: Column(
                    children: [
                      // Table Toolbar (Full width dark bar)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: gcs.bg.withValues(alpha: 0.6),
                            border: Border(
                                bottom: BorderSide(
                                    color:
                                        gcs.accent.withValues(alpha: 0.15)))),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _tbStat('DEFAULT ALT:', '${s.defaultAltitude.toStringAsFixed(0)} m', gcs),
                              const SizedBox(width: 20),
                              _tbStat('CRUISE SPD:', '${kAssumedCruiseSpeedMps.toStringAsFixed(0)} m/s', gcs),
                              const SizedBox(width: 24),
                              GestureDetector(
                                onTap: () {
                                  final center = _mapController.camera.center;
                                  _insertBelowSelected(ref, center);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: gcs.success,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: gcs.success.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                        ),
                                      ]),
                                  child: const Row(
                                    children: [
                                      Icon(LucideIcons.plus, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('ADD BELOW',
                                          style: TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 9,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              if (_selectedIndex != null)
                                _tbStat('SELECTED:', 'WP ${_selectedIndex! + 1}', gcs, isHighlight: true),
                            ],
                          ),
                        ),
                      ),
                      // Table Content Layout (Full Width stretchable, bounded layout)
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: math.max(constraints.maxWidth, 850.0),
                                height: constraints.maxHeight,
                                child: Column(
                                  children: [
                                    // Table Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                          color: gcs.bg.withValues(alpha: 0.3),
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: gcs.accent
                                                      .withValues(alpha: 0.2)))),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 30, child: Text('#', style: thStyle)),
                                          SizedBox(width: 120, child: Text('COMMAND', style: thStyle)),
                                          SizedBox(width: 90, child: Text('LATITUDE', style: thStyle)),
                                          SizedBox(width: 90, child: Text('LONGITUDE', style: thStyle)),
                                          SizedBox(width: 70, child: Text('ALT (M)', style: thStyle)),
                                          SizedBox(width: 40, child: Text('DEL', style: thStyle)),
                                          SizedBox(width: 55, child: Text('MOVE', style: thStyle)),
                                          SizedBox(width: 70, child: Text('GRAD %', style: thStyle)),
                                          SizedBox(width: 70, child: Text('BEARING', style: thStyle)),
                                          SizedBox(width: 90, child: Text('LEG DIST (m)', style: thStyle)),
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
                                          final leg = _legStats(s.waypoints, i);
                                          final selected = i == _selectedIndex;
                                          return GestureDetector(
                                            onTap: () => setState(() => _selectedIndex = i),
                                            onDoubleTap: () => _openEditDialog(context, ref, i),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 8),
                                              decoration: BoxDecoration(
                                                  color: selected
                                                      ? gcs.accent.withValues(alpha: 0.15)
                                                      : (i % 2 == 0 ? Colors.transparent : gcs.bg.withValues(alpha: 0.2)),
                                                  border: Border(
                                                      left: BorderSide(
                                                          color: selected ? gcs.warning : Colors.transparent,
                                                          width: 3),
                                                      bottom: BorderSide(
                                                          color: gcs.accent
                                                              .withValues(alpha: 0.08)))),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                      width: 30,
                                                      child: Text('${i + 1}',
                                                          style: tdStyle.copyWith(
                                                              color: selected ? gcs.warning : gcs.accent,
                                                              fontWeight: FontWeight.bold))),
                                                  SizedBox(
                                                      width: 120,
                                                      child: _DropSel(
                                                          value: kCommandTypes.contains(wp.action)
                                                              ? wp.action
                                                              : kCommandTypes.first,
                                                          items: kCommandTypes,
                                                          gcs: gcs,
                                                          onChanged: (v) =>
                                                              _replaceWaypoint(ref, i, action: v),
                                                          compact: true)),
                                                  SizedBox(
                                                      width: 90,
                                                      child: Text(
                                                          wp.lat.toStringAsFixed(4),
                                                          style: tdStyle)),
                                                  SizedBox(
                                                      width: 90,
                                                      child: Text(
                                                          wp.lng.toStringAsFixed(4),
                                                          style: tdStyle)),
                                                  SizedBox(
                                                      width: 70,
                                                      child: Text(
                                                          '${wp.alt.toStringAsFixed(0)} m',
                                                          style: tdStyle.copyWith(fontWeight: FontWeight.bold))),
                                                  SizedBox(
                                                      width: 40,
                                                      child: GestureDetector(
                                                          onTap: () {
                                                            notifier.deleteWaypoint(wp.id);
                                                            if (_selectedIndex == i) {
                                                              setState(() => _selectedIndex = null);
                                                            }
                                                          },
                                                          child: Container(
                                                            padding: const EdgeInsets.all(3),
                                                            decoration: BoxDecoration(
                                                              color: gcs.danger.withValues(alpha: 0.15),
                                                              borderRadius: BorderRadius.circular(3),
                                                            ),
                                                            child: Icon(LucideIcons.x,
                                                                size: 13,
                                                                color: gcs.danger),
                                                          ))),
                                                  SizedBox(
                                                      width: 55,
                                                      child: Row(children: [
                                                        GestureDetector(
                                                          onTap: () => _moveWaypoint(ref, i, -1),
                                                          child: Icon(Icons.arrow_upward,
                                                              size: 14,
                                                              color: i == 0
                                                                  ? gcs.secText.withValues(alpha: 0.3)
                                                                  : gcs.accent),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        GestureDetector(
                                                          onTap: () => _moveWaypoint(ref, i, 1),
                                                          child: Icon(Icons.arrow_downward,
                                                              size: 14,
                                                              color: i == s.waypoints.length - 1
                                                                  ? gcs.secText.withValues(alpha: 0.3)
                                                                  : gcs.accent),
                                                        ),
                                                      ])),
                                                  SizedBox(
                                                      width: 70,
                                                      child: Text(
                                                          '${leg.gradePct.toStringAsFixed(1)}%',
                                                          style: tdStyle.copyWith(color: leg.gradePct > 15 ? gcs.warning : gcs.text))),
                                                  SizedBox(
                                                      width: 70,
                                                      child: Text(
                                                          '${leg.bearingDeg.toStringAsFixed(0)}°',
                                                          style: tdStyle)),
                                                  SizedBox(
                                                      width: 90,
                                                      child: Text(
                                                          '${leg.distM.toStringAsFixed(1)} m',
                                                          style: tdStyle.copyWith(color: gcs.accent))),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
                    children: s.validationSteps.isNotEmpty
                        ? s.validationSteps.map((step) {
                            IconData icon;
                            Color color;
                            if (step.status == 'pass') {
                              icon = LucideIcons.checkCircle2;
                              color = gcs.success;
                            } else if (step.status == 'fail') {
                              icon = LucideIcons.xCircle;
                              color = gcs.danger;
                            } else if (step.status == 'in_progress') {
                              icon = LucideIcons.loader2;
                              color = gcs.accent;
                            } else {
                              icon = LucideIcons.helpCircle;
                              color = gcs.secText;
                            }
                            return _valStep(
                                step.name,
                                step.result.isEmpty ? step.status.toUpperCase() : step.result,
                                icon,
                                color,
                                gcs);
                          }).toList()
                        : [
                            _valStep(
                                'Waypoint Count',
                                s.waypoints.isEmpty
                                    ? 'No waypoints added'
                                    : '${s.waypoints.length} waypoints ready',
                                s.waypoints.isEmpty
                                    ? LucideIcons.alertCircle
                                    : LucideIcons.checkCircle2,
                                s.waypoints.isEmpty ? gcs.danger : gcs.success,
                                gcs),
                            _valStep(
                                'Geofence Boundary',
                                _geofencePoints.length > 2
                                    ? '${_geofencePoints.length}-point polygon set'
                                    : 'No Geofence Restriction',
                                _geofencePoints.length > 2
                                    ? LucideIcons.checkCircle2
                                    : LucideIcons.helpCircle,
                                _geofencePoints.length > 2
                                    ? gcs.success
                                    : gcs.secText,
                                gcs),
                            _valStep('Airspace Clearance', 'Pending Validation',
                                LucideIcons.helpCircle, gcs.secText, gcs),
                            _valStep('NPNT Digital Sky', 'Pending Validation',
                                LucideIcons.helpCircle, gcs.secText, gcs),
                            _valStep(
                                'Mission Status',
                                s.selectedDrone?.missionStatus ?? 'Not Uploaded',
                                LucideIcons.info,
                                gcs.accent,
                                gcs),
                          ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if (s.uploadProgress > 0 && s.uploadProgress < 100) ...[
                        LinearProgressIndicator(
                          value: s.uploadProgress / 100.0,
                          backgroundColor: gcs.accent.withValues(alpha: 0.2),
                          color: gcs.accent,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'UPLOADING WAYPOINTS: ${s.uploadProgress.toInt()}%',
                          style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              color: gcs.accent,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _actionButton(
                          s.isValidating ? 'VALIDATING...' : 'VALIDATE MISSION',
                          gcs.accent,
                          s.isValidating ? LucideIcons.loader2 : LucideIcons.shieldCheck,
                          () => notifier.runValidation(),
                          gcs,
                          filled: false,
                          outlineOnly: true),
                      const SizedBox(height: 8),
                      _actionButton(
                          s.uploadProgress == 100
                              ? 'RE-UPLOAD MISSION'
                              : 'UPLOAD MISSION',
                          gcs.accent,
                          LucideIcons.uploadCloud, () {
                        notifier.uploadMission();
                      }, gcs, filled: true),
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

  Widget _tbStat(String label, String value, GcsThemeExtension gcs, {bool isHighlight = false}) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: gcs.secText)),
      const SizedBox(width: 5),
      Text(value,
          style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isHighlight ? gcs.warning : gcs.text)),
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
                  ? color.withValues(alpha: 0.85)
                  : color.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: outlineOnly
                  ? color
                  : (filled
                      ? Colors.transparent
                      : color.withValues(alpha: 0.3))),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
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
          color: AppColors.panels.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 14, color: AppColors.accent),
      ),
    );
  }

  Widget _valStep(String title, String subtitle, IconData icon, Color color, GcsThemeExtension gcs) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: gcs.text)),
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
              size: compact ? 12 : 16, color: gcs.accent),
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
