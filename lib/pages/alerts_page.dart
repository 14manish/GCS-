import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  String _filter = 'all';

  static const _severityColors = {
    'critical': AppColors.danger,
    'high': Color(0xFFFF9800),
    'medium': AppColors.warning,
    'low': AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(gcsProvider.select((s) => s.alerts));
    final gcs = context.gcs;

    final filtered = _filter == 'all'
        ? alerts
        : alerts.where((a) => a.severity == _filter).toList();

    final counts = {
      'critical': alerts.where((a) => a.severity == 'critical').length,
      'high': alerts.where((a) => a.severity == 'high').length,
      'medium': alerts.where((a) => a.severity == 'medium').length,
      'low': alerts.where((a) => a.severity == 'low').length,
    };

    return Container(
      color: gcs.bg,
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  bottom:
                      BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.alertOctagon, size: 16, color: gcs.accent),
                const SizedBox(width: 8),
                Text('ALERT MANAGEMENT',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: gcs.accent,
                    )),
                const Spacer(),
                // Severity filter tabs
                ...[
                  ('ALL', 'all', gcs.secText),
                  ('CRITICAL', 'critical', AppColors.danger),
                  ('HIGH', 'high', const Color(0xFFFF9800)),
                  ('MEDIUM', 'medium', AppColors.warning),
                  ('LOW', 'low', AppColors.success),
                ].map((t) => _FilterTab(
                      label:
                          '${t.$1}${t.$2 != 'all' ? ' (${counts[t.$2]})' : ''}',
                      active: _filter == t.$2,
                      color: t.$3,
                      onTap: () => setState(() => _filter = t.$2),
                      gcs: gcs,
                    )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ref.read(gcsProvider.notifier).clearAlerts(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text('CLEAR ALL',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          color: gcs.danger,
                        )),
                  ),
                ),
              ],
            ),
          ),

          // ── Stats Row ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StatCard(
                    label: 'TOTAL',
                    value: '${alerts.length}',
                    color: gcs.accent,
                    gcs: gcs),
                const SizedBox(width: 8),
                _StatCard(
                    label: 'CRITICAL',
                    value: '${counts['critical']}',
                    color: AppColors.danger,
                    gcs: gcs),
                const SizedBox(width: 8),
                _StatCard(
                    label: 'HIGH',
                    value: '${counts['high']}',
                    color: const Color(0xFFFF9800),
                    gcs: gcs),
                const SizedBox(width: 8),
                _StatCard(
                    label: 'UNREAD',
                    value: '${alerts.where((a) => !a.read).length}',
                    color: AppColors.warning,
                    gcs: gcs),
              ],
            ),
          ),

          // ── Alert List ──
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.checkCircle,
                          size: 40, color: gcs.success),
                      const SizedBox(height: 12),
                      Text('No alerts — all systems nominal',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: gcs.secText,
                          )),
                    ],
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final alert = filtered[i];
                      final color =
                          _severityColors[alert.severity] ?? gcs.secText;
                      return GestureDetector(
                        onTap: () => ref
                            .read(gcsProvider.notifier)
                            .markAlertRead(alert.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: alert.read
                                ? gcs.panels
                                : color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: alert.read
                                  ? gcs.accent.withValues(alpha: 0.1)
                                  : color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          alert.severity.toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 9,
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(alert.title,
                                          style: TextStyle(
                                            fontFamily: 'JetBrains Mono',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: gcs.text,
                                          )),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(alert.message,
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 10,
                                          color: gcs.secText,
                                        )),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(alert.timestamp,
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 9,
                                        color: gcs.secText,
                                      )),
                                  const SizedBox(height: 4),
                                  if (!alert.read)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
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
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
    required this.gcs,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
              color: active ? color : gcs.accent.withValues(alpha: 0.1)),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: active ? color : gcs.secText,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.gcs,
  });

  final String label, value;
  final Color color;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: gcs.panels,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              )),
          Text(label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 9,
                color: gcs.secText,
                letterSpacing: 1,
              )),
        ],
      ),
    );
  }
}
