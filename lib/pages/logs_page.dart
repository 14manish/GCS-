import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class LogsPage extends ConsumerWidget {
  const LogsPage({super.key});

  static const _logs = [
    {
      'time': '10:23:44',
      'level': 'INFO',
      'msg': 'Mission uploaded to Alpha-1 (12 waypoints)'
    },
    {'time': '10:22:01', 'level': 'WARN', 'msg': 'Battery below 40% — Beta-2'},
    {
      'time': '10:20:59',
      'level': 'INFO',
      'msg': 'GPS 3D Fix acquired — Alpha-1'
    },
    {
      'time': '10:19:34',
      'level': 'CRIT',
      'msg': 'Geofence breach detected — Gamma-3'
    },
    {'time': '10:18:11', 'level': 'INFO', 'msg': 'Arm command sent to Alpha-1'},
    {
      'time': '10:17:02',
      'level': 'INFO',
      'msg': 'Connection established — UDP:14550'
    },
    {
      'time': '10:16:44',
      'level': 'WARN',
      'msg': 'Satellite count below threshold (9 SVs)'
    },
    {
      'time': '10:15:55',
      'level': 'INFO',
      'msg': 'Session started — AES-256 active'
    },
    {'time': '10:15:01', 'level': 'INFO', 'msg': 'WINGSPANN GCS started'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gcs = context.gcs;

    return Container(
      color: gcs.bg,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  bottom:
                      BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Row(children: [
              Icon(LucideIcons.fileText, size: 16, color: gcs.accent),
              const SizedBox(width: 8),
              Text('FLIGHT LOGS & REPLAY',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: gcs.accent,
                  )),
              const Spacer(),
              _PillBtn(
                  label: 'EXPORT',
                  icon: LucideIcons.download,
                  color: gcs.accent,
                  gcs: gcs,
                  onTap: () {}),
              const SizedBox(width: 8),
              _PillBtn(
                  label: 'CLEAR',
                  icon: LucideIcons.trash2,
                  color: gcs.danger,
                  gcs: gcs,
                  onTap: () {}),
            ]),
          ),

          // Log list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, i) {
                final log = _logs[i];
                final color = log['level'] == 'CRIT'
                    ? AppColors.danger
                    : log['level'] == 'WARN'
                        ? AppColors.warning
                        : AppColors.success;

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: gcs.panels.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border(
                      left: BorderSide(color: color, width: 2),
                    ),
                  ),
                  child: Row(children: [
                    Text(log['time']!,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          color: gcs.secText,
                        )),
                    const SizedBox(width: 12),
                    Container(
                      width: 36,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(log['level']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 9,
                            color: color,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(log['msg']!,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              color: gcs.text,
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

class _PillBtn extends StatelessWidget {
  const _PillBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.gcs,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final GcsThemeExtension gcs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                color: color,
              )),
        ]),
      ),
    );
  }
}
