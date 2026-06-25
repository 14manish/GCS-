import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class SimulationPage extends ConsumerStatefulWidget {
  const SimulationPage({super.key});

  @override
  ConsumerState<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends ConsumerState<SimulationPage> {
  bool _isSatellite = true;
  final _mapController = MapController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final notifier = ref.read(gcsProvider.notifier);

    final homeLatLng = LatLng(
      s.simHome['lat'] ?? 28.6139,
      s.simHome['lng'] ?? 77.2090,
    );

    return Container(
      color: gcs.bg,
      child: Row(
        children: [
          // ─── Left Config Panel ───
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  right: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(LucideIcons.gamepad2, size: 16, color: gcs.accent),
                    const SizedBox(width: 8),
                    Text('SIMULATION',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: gcs.accent,
                        )),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: s.simStatus == 'running'
                            ? gcs.success.withValues(alpha: 0.15)
                            : gcs.secText.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: s.simStatus == 'running'
                              ? gcs.success
                              : gcs.secText.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        s.simStatus.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9,
                          color: s.simStatus == 'running'
                              ? gcs.success
                              : gcs.secText,
                        ),
                      ),
                    ),
                  ]),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _ConfigLabel('FIRMWARE', gcs),
                      _DropdownField<String>(
                        value: s.simFirmware,
                        items: const [
                          'ArduPlane',
                          'ArduCopter',
                          'ArduRover',
                          'PX4'
                        ],
                        gcs: gcs,
                        onChanged: (v) =>
                            notifier.setSimConfig({'simFirmware': v}),
                      ),
                      const SizedBox(height: 12),
                      _ConfigLabel('SIMULATION SPEED', gcs),
                      Row(
                          children: [1.0, 2.0, 5.0, 10.0]
                              .map((sp) => Expanded(
                                    child: GestureDetector(
                                      onTap: () => notifier
                                          .setSimConfig({'simSpeed': sp}),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        decoration: BoxDecoration(
                                          color: s.simSpeed == sp
                                              ? gcs.accent
                                                  .withValues(alpha: 0.15)
                                              : gcs.bg,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          border: Border.all(
                                              color: s.simSpeed == sp
                                                  ? gcs.accent
                                                  : gcs.accent
                                                      .withValues(alpha: 0.1)),
                                        ),
                                        child: Text('${sp.toStringAsFixed(0)}x',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 10,
                                              color: s.simSpeed == sp
                                                  ? gcs.accent
                                                  : gcs.secText,
                                            )),
                                      ),
                                    ),
                                  ))
                              .toList()),
                      const SizedBox(height: 12),
                      _ConfigLabel('HOME POSITION', gcs),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: gcs.bg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: gcs.accent.withValues(alpha: 0.1)),
                        ),
                        child: Column(children: [
                          Row(children: [
                            Text('LAT',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 9,
                                  color: gcs.secText,
                                )),
                            const Spacer(),
                            Text(homeLatLng.latitude.toStringAsFixed(4),
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  color: gcs.accent,
                                )),
                          ]),
                          Row(children: [
                            Text('LNG',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 9,
                                  color: gcs.secText,
                                )),
                            const Spacer(),
                            Text(homeLatLng.longitude.toStringAsFixed(4),
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  color: gcs.accent,
                                )),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Text('Tap on map to set home position',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 9,
                            color: gcs.secText,
                          )),
                    ],
                  ),
                ),

                // Start / Stop buttons
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                            s.simStatus == 'running'
                                ? LucideIcons.square
                                : LucideIcons.play,
                            size: 14),
                        label:
                            Text(s.simStatus == 'running' ? 'STOP' : 'START'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: s.simStatus == 'running'
                              ? gcs.danger
                              : gcs.success,
                          foregroundColor: gcs.bg,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          if (s.simStatus == 'running') {
                            notifier.stopSimulation();
                          } else {
                            notifier.startSimulation();
                          }
                        },
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ─── Center: Map ───
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: homeLatLng,
                    initialZoom: 14,
                    onTap: (_, latlng) {
                      notifier.setSimConfig({
                        'simHome': {
                          'lat': latlng.latitude,
                          'lng': latlng.longitude
                        },
                      });
                      notifier.addSimLog(
                          'Home set: ${latlng.latitude.toStringAsFixed(4)}, ${latlng.longitude.toStringAsFixed(4)}');
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _isSatellite
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: homeLatLng,
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.success, width: 2),
                          ),
                          child: const Icon(LucideIcons.home,
                              size: 14, color: AppColors.success),
                        ),
                      ),
                    ]),
                  ],
                ),

                // Map type toggle
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => setState(() => _isSatellite = !_isSatellite),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: gcs.panels.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: gcs.accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Icon(LucideIcons.layers, size: 12, color: gcs.accent),
                        const SizedBox(width: 4),
                        Text(_isSatellite ? 'STREET' : 'SATELLITE',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: gcs.accent,
                            )),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Right: Console ───
          SizedBox(
            width: 280,
            child: Container(
              decoration: BoxDecoration(
                color: gcs.panels,
                border: Border(
                    left:
                        BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('CONSOLE',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          color: gcs.secText,
                          letterSpacing: 1.5,
                        )),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: s.simConsoleLogs.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(s.simConsoleLogs[i],
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              color: s.simConsoleLogs[i].contains('Error')
                                  ? AppColors.danger
                                  : s.simConsoleLogs[i].contains('started')
                                      ? AppColors.success
                                      : gcs.text,
                            )),
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

class _ConfigLabel extends StatelessWidget {
  const _ConfigLabel(this.text, this.gcs);
  final String text;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
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
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField(
      {required this.value,
      required this.items,
      required this.gcs,
      required this.onChanged});
  final T value;
  final List<T> items;
  final GcsThemeExtension gcs;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gcs.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: gcs.panels,
          style: TextStyle(
              fontFamily: 'JetBrains Mono', fontSize: 11, color: gcs.text),
          items: items
              .map((i) => DropdownMenuItem<T>(
                    value: i,
                    child: Text('$i'),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
