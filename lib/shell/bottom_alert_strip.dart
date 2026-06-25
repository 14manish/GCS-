import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store/gcs_notifier.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class BottomAlertStrip extends ConsumerWidget {
  const BottomAlertStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(gcsProvider.select((s) => s.alerts));
    final gcs = context.gcs;

    final severityColor = {
      'critical': AppColors.danger,
      'high': const Color(0xFFFF9800),
      'medium': AppColors.warning,
      'low': AppColors.success,
    };

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: gcs.panels,
        border:
            Border(top: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          // CONSOLE label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'CONSOLE',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: gcs.secText.withValues(alpha: 0.6),
                letterSpacing: 1.5,
              ),
            ),
          ),
          Container(
              width: 1, height: 20, color: gcs.accent.withValues(alpha: 0.15)),
          const SizedBox(width: 8),

          // Scrollable alert feed
          Expanded(
            child: alerts.isEmpty
                ? Text(
                    'No active alerts — all systems nominal.',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      color: gcs.secText.withValues(alpha: 0.5),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    reverse: false,
                    itemCount: alerts.length,
                    itemBuilder: (context, i) {
                      final alert = alerts[i];
                      final color =
                          severityColor[alert.severity] ?? AppColors.textSecond;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                          border:
                              Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${alert.timestamp} ${alert.title}',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Alert count badge
          if (alerts.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${alerts.length} ALERTS',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9,
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
