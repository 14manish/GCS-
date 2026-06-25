import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class ParametersPage extends ConsumerStatefulWidget {
  const ParametersPage({super.key});

  @override
  ConsumerState<ParametersPage> createState() => _ParametersPageState();
}

class _ParametersPageState extends ConsumerState<ParametersPage> {
  String _search = '';
  String _group = 'All';

  static const _params = [
    {
      'group': 'Flight',
      'key': 'ARMING_CHECK',
      'value': '1',
      'desc': 'Arming check bitmask'
    },
    {
      'group': 'Flight',
      'key': 'CRUISE_SPEED',
      'value': '15.0',
      'desc': 'Target cruise speed m/s'
    },
    {
      'group': 'Flight',
      'key': 'TKOFF_FLAP_PCNT',
      'value': '0',
      'desc': 'Flap percentage at takeoff'
    },
    {
      'group': 'Flight',
      'key': 'RTL_ALTITUDE',
      'value': '100',
      'desc': 'RTL altitude in cm'
    },
    {
      'group': 'GPS',
      'key': 'GPS_TYPE',
      'value': '1',
      'desc': 'GPS type selection'
    },
    {
      'group': 'GPS',
      'key': 'GPS_NAVFILTER',
      'value': '8',
      'desc': 'Navigation filter setting'
    },
    {
      'group': 'GPS',
      'key': 'GPS_HDOP_GOOD',
      'value': '1.40',
      'desc': 'HDOP threshold for good GPS'
    },
    {
      'group': 'Telemetry',
      'key': 'SR0_RAW_SENS',
      'value': '2',
      'desc': 'Rate of raw sensor stream'
    },
    {
      'group': 'Telemetry',
      'key': 'SR0_EXT_STAT',
      'value': '2',
      'desc': 'Extended status stream rate'
    },
    {
      'group': 'Telemetry',
      'key': 'SR0_POSITION',
      'value': '3',
      'desc': 'Position stream rate'
    },
    {
      'group': 'Battery',
      'key': 'BATT_MONITOR',
      'value': '3',
      'desc': 'Battery monitoring type'
    },
    {
      'group': 'Battery',
      'key': 'BATT_VOLT_MULT',
      'value': '10.1',
      'desc': 'Voltage multiplier'
    },
    {
      'group': 'Battery',
      'key': 'BATT_LOW_VOLT',
      'value': '14.0',
      'desc': 'Low battery voltage'
    },
    {
      'group': 'Battery',
      'key': 'BATT_CRT_VOLT',
      'value': '12.5',
      'desc': 'Critical battery voltage'
    },
    {
      'group': 'MAVLink',
      'key': 'SYSID_THISMAV',
      'value': '1',
      'desc': 'Vehicle MAVLink system ID'
    },
    {
      'group': 'MAVLink',
      'key': 'SYSID_MYGCS',
      'value': '255',
      'desc': 'GCS MAVLink system ID'
    },
    {
      'group': 'PID',
      'key': 'ACRO_PITCH_RATE',
      'value': '180',
      'desc': 'Pitch rate in acro mode'
    },
    {
      'group': 'PID',
      'key': 'ACRO_ROLL_RATE',
      'value': '180',
      'desc': 'Roll rate in acro mode'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final gcs = context.gcs;
    final groups = [
      'All',
      ...{..._params.map((p) => p['group']!)}
    ];

    final filtered = _params.where((p) {
      final matchGroup = _group == 'All' || p['group'] == _group;
      final matchSearch = _search.isEmpty ||
          p['key']!.toLowerCase().contains(_search.toLowerCase()) ||
          p['desc']!.toLowerCase().contains(_search.toLowerCase());
      return matchGroup && matchSearch;
    }).toList();

    return Container(
      color: gcs.bg,
      child: Column(
        children: [
          // Header + Search
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  bottom:
                      BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.sliders, size: 16, color: gcs.accent),
                const SizedBox(width: 8),
                Text('PARAMETERS',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: gcs.accent,
                    )),
                const SizedBox(width: 16),
                // Group filter
                ...groups.map((g) => GestureDetector(
                      onTap: () => setState(() => _group = g),
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _group == g
                              ? gcs.accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: _group == g
                                  ? gcs.accent
                                  : gcs.accent.withValues(alpha: 0.1)),
                        ),
                        child: Text(g,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: _group == g ? gcs.accent : gcs.secText,
                            )),
                      ),
                    )),
                const Spacer(),
                // Search
                SizedBox(
                  width: 200,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: gcs.text,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search parameters...',
                      prefixIcon: Icon(LucideIcons.search,
                          size: 14, color: gcs.secText),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: gcs.panels.withValues(alpha: 0.5),
            child: Row(children: [
              _ColHeader('GROUP', 100, gcs),
              _ColHeader('PARAMETER', 180, gcs),
              _ColHeader('VALUE', 100, gcs),
              Expanded(child: _ColHeader('DESCRIPTION', null, gcs)),
            ]),
          ),

          // Parameter rows
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final p = filtered[i];
                final isEven = i % 2 == 0;
                return Container(
                  color: isEven
                      ? gcs.panels.withValues(alpha: 0.3)
                      : Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    SizedBox(
                      width: 100,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: gcs.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(p['group']!,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              color: gcs.accent,
                            )),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: Text(p['key']!,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: gcs.text,
                          )),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(p['value']!,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: AppColors.success,
                          )),
                    ),
                    Expanded(
                        child: Text(p['desc']!,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: gcs.secText,
                            ))),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.label, this.width, this.gcs);
  final String label;
  final double? width;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(label,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9,
            color: gcs.secText,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          )),
    );
  }
}
