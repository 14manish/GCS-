import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class VehiclesPage extends ConsumerWidget {
  const VehiclesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;

    return Container(
      color: gcs.bg,
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  bottom:
                      BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.terminal, size: 16, color: gcs.accent),
                const SizedBox(width: 8),
                Text('FLEET MANAGEMENT',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: gcs.accent,
                    )),
                const Spacer(),
                _FleetStat(
                    label: 'TOTAL',
                    value: '${s.drones.length}',
                    color: gcs.accent,
                    gcs: gcs),
                const SizedBox(width: 8),
                _FleetStat(
                    label: 'ACTIVE',
                    value:
                        '${s.drones.where((d) => d.flightMode != 'Standby').length}',
                    color: gcs.success,
                    gcs: gcs),
                const SizedBox(width: 8),
                _FleetStat(
                    label: 'CRITICAL',
                    value:
                        '${s.drones.where((d) => d.health == 'Critical').length}',
                    color: gcs.danger,
                    gcs: gcs),
              ],
            ),
          ),

          // ── Vehicle Grid ──
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                mainAxisExtent: 260,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: s.drones.length,
              itemBuilder: (context, i) {
                final drone = s.drones[i];
                final isSelected = drone.id == s.selectedDroneId;
                return _VehicleCard(
                  drone: drone,
                  isSelected: isSelected,
                  gcs: gcs,
                  onSelect: () =>
                      ref.read(gcsProvider.notifier).selectDrone(drone.id),
                  onAction: (action) => ref
                      .read(gcsProvider.notifier)
                      .triggerDroneAction(drone.id, action),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.drone,
    required this.isSelected,
    required this.gcs,
    required this.onSelect,
    required this.onAction,
  });

  final dynamic drone;
  final bool isSelected;
  final GcsThemeExtension gcs;
  final VoidCallback onSelect;
  final void Function(String action) onAction;

  Color get _healthColor {
    if (drone.health == 'Critical') return gcs.danger;
    if (drone.health == 'Warning') return gcs.warning;
    return gcs.success;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: gcs.panels,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? gcs.accent : gcs.accent.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: gcs.accent.withValues(alpha: 0.1), blurRadius: 12),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Row
            Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: _healthColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(drone.name,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: gcs.text,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: gcs.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(drone.flightMode,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      color: gcs.accent,
                    )),
              ),
            ]),
            const SizedBox(height: 12),

            // Telemetry Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _TelCell(
                      label: 'BAT',
                      value: '${drone.battery.toStringAsFixed(0)}%',
                      color: _battColor(drone.battery),
                      gcs: gcs),
                  _TelCell(
                      label: 'ALT',
                      value: '${drone.altitude.toStringAsFixed(0)}m',
                      color: gcs.accent,
                      gcs: gcs),
                  _TelCell(
                      label: 'SPD',
                      value: '${drone.speed.toStringAsFixed(1)}',
                      color: gcs.accent,
                      gcs: gcs),
                  _TelCell(
                      label: 'GPS',
                      value: drone.gpsQuality,
                      color: gcs.success,
                      gcs: gcs),
                  _TelCell(
                      label: 'SIG',
                      value: '${drone.signal.toStringAsFixed(0)}dBm',
                      color: gcs.secText,
                      gcs: gcs),
                  _TelCell(
                      label: 'LAT',
                      value: '${drone.latency}ms',
                      color: drone.latency > 100 ? gcs.warning : gcs.success,
                      gcs: gcs),
                ],
              ),
            ),

            // Action Buttons
            Row(children: [
              _ActionBtn(
                  label: 'ARM',
                  color: gcs.success,
                  gcs: gcs,
                  onTap: () => onAction('ARM')),
              const SizedBox(width: 4),
              _ActionBtn(
                  label: 'DISARM',
                  color: gcs.danger,
                  gcs: gcs,
                  onTap: () => onAction('DISARM')),
              const SizedBox(width: 4),
              _ActionBtn(
                  label: 'RTL',
                  color: gcs.warning,
                  gcs: gcs,
                  onTap: () => onAction('RTL')),
            ]),
          ],
        ),
      ),
    );
  }

  Color _battColor(double v) {
    if (v > 50) return AppColors.success;
    if (v > 20) return AppColors.warning;
    return AppColors.danger;
  }
}

class _TelCell extends StatelessWidget {
  const _TelCell(
      {required this.label,
      required this.value,
      required this.color,
      required this.gcs});
  final String label, value;
  final Color color;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: gcs.bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 8,
                color: gcs.secText,
                letterSpacing: 0.8,
              )),
          Text(value,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.label,
      required this.color,
      required this.gcs,
      required this.onTap});
  final String label;
  final Color color;
  final GcsThemeExtension gcs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _FleetStat extends StatelessWidget {
  const _FleetStat(
      {required this.label,
      required this.value,
      required this.color,
      required this.gcs});
  final String label, value;
  final Color color;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: RichText(
          text: TextSpan(children: [
        TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            )),
        TextSpan(
            text: ' $label',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: gcs.secText,
            )),
      ])),
    );
  }
}
