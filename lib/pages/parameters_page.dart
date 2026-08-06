import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
      'desc': 'Arming check bitmask for pre-arm safety verification'
    },
    {
      'group': 'Flight',
      'key': 'CRUISE_SPEED',
      'value': '15.0',
      'desc': 'Target cruise speed in meters per second (m/s)'
    },
    {
      'group': 'Flight',
      'key': 'TKOFF_FLAP_PCNT',
      'value': '0',
      'desc': 'Flap deployment percentage at automatic takeoff'
    },
    {
      'group': 'Flight',
      'key': 'RTL_ALTITUDE',
      'value': '100',
      'desc': 'Return to Launch (RTL) altitude in centimeters (cm)'
    },
    {
      'group': 'GPS',
      'key': 'GPS_TYPE',
      'value': '1',
      'desc': 'GPS protocol type selection (AUTO / NMEA / UBlox / RTK)'
    },
    {
      'group': 'GPS',
      'key': 'GPS_NAVFILTER',
      'value': '8',
      'desc': 'Navigation filter dynamic engine model setting'
    },
    {
      'group': 'GPS',
      'key': 'GPS_HDOP_GOOD',
      'value': '1.40',
      'desc': 'Maximum HDOP threshold acceptable for good GPS fix'
    },
    {
      'group': 'Telemetry',
      'key': 'SR0_RAW_SENS',
      'value': '2',
      'desc': 'Stream rate of raw IMU & sensor telemetry data (Hz)'
    },
    {
      'group': 'Telemetry',
      'key': 'SR0_EXT_STAT',
      'value': '2',
      'desc': 'Extended vehicle status stream update rate (Hz)'
    },
    {
      'group': 'Telemetry',
      'key': 'SR0_POSITION',
      'value': '3',
      'desc': 'GPS position telemetry stream update rate (Hz)'
    },
    {
      'group': 'Battery',
      'key': 'BATT_MONITOR',
      'value': '3',
      'desc': 'Battery monitoring hardware type (Analog Voltage & Current)'
    },
    {
      'group': 'Battery',
      'key': 'BATT_VOLT_MULT',
      'value': '10.1',
      'desc': 'Voltage sensing pin multiplier scaling factor'
    },
    {
      'group': 'Battery',
      'key': 'BATT_LOW_VOLT',
      'value': '14.0',
      'desc': 'Low battery warning threshold voltage'
    },
    {
      'group': 'Battery',
      'key': 'BATT_CRT_VOLT',
      'value': '12.5',
      'desc': 'Critical battery fail-safe trigger threshold voltage'
    },
    {
      'group': 'MAVLink',
      'key': 'SYSID_THISMAV',
      'value': '1',
      'desc': 'Vehicle MAVLink system identity number'
    },
    {
      'group': 'MAVLink',
      'key': 'SYSID_MYGCS',
      'value': '255',
      'desc': 'Ground Control Station (GCS) MAVLink system identity'
    },
    {
      'group': 'PID',
      'key': 'ACRO_PITCH_RATE',
      'value': '180',
      'desc': 'Maximum pitch rate in Acrobatics mode (deg/s)'
    },
    {
      'group': 'PID',
      'key': 'ACRO_ROLL_RATE',
      'value': '180',
      'desc': 'Maximum roll rate in Acrobatics mode (deg/s)'
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  bottom:
                      BorderSide(color: gcs.accent.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.sliders, size: 18, color: gcs.accent),
                const SizedBox(width: 10),
                Text('PARAMETERS',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: gcs.accent,
                      letterSpacing: 1.1,
                    )),
                const SizedBox(width: 24),
                // Group filter buttons
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: groups.map((g) => GestureDetector(
                            onTap: () => setState(() => _group = g),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _group == g
                                    ? gcs.accent.withValues(alpha: 0.2)
                                    : gcs.bg.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: _group == g
                                        ? gcs.accent
                                        : gcs.accent.withValues(alpha: 0.15)),
                              ),
                              child: Text(g,
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 11,
                                    fontWeight: _group == g
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _group == g ? gcs.accent : gcs.text,
                                  )),
                            ),
                          )).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Search field
                SizedBox(
                  width: 240,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      color: gcs.text,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search parameters...',
                      hintStyle: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          color: gcs.secText),
                      prefixIcon: Icon(LucideIcons.search,
                          size: 16, color: gcs.accent),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      filled: true,
                      fillColor: gcs.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: gcs.accent.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: gcs.accent.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: gcs.accent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: gcs.bg.withValues(alpha: 0.6),
              border: Border(
                  bottom: BorderSide(color: gcs.accent.withValues(alpha: 0.2))),
            ),
            child: Row(children: [
              _ColHeader('GROUP', 140, gcs),
              _ColHeader('PARAMETER', 240, gcs),
              _ColHeader('VALUE', 110, gcs),
              Expanded(child: _ColHeader('DESCRIPTION', null, gcs)),
            ]),
          ),

          // Parameter rows
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final p = filtered[i];
                final isEven = i % 2 == 0;
                return Container(
                  decoration: BoxDecoration(
                    color: isEven
                        ? gcs.panels.withValues(alpha: 0.4)
                        : Colors.transparent,
                    border: Border(
                        bottom: BorderSide(
                            color: gcs.accent.withValues(alpha: 0.08))),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    SizedBox(
                      width: 140,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: gcs.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: gcs.accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(p['group']!,
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: gcs.accent,
                              )),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(p['key']!,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: gcs.text,
                              letterSpacing: 0.5,
                            )),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(p['value']!,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: gcs.success,
                          )),
                    ),
                    Expanded(
                      child: Text(
                        p['desc']!,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.95), // Bright, easily visible description text
                        ),
                      ),
                    ),
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
            fontSize: 11,
            color: gcs.accent,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          )),
    );
  }
}
