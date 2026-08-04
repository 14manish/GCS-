import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/theme/app_theme.dart';

class TelemetryPage extends ConsumerWidget {
  const TelemetryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final drone = s.drones.isNotEmpty
        ? s.drones.firstWhere((d) => d.id == s.selectedDroneId,
            orElse: () => s.drones.first)
        : null;

    if (drone == null) {
      return Center(
          child: Text('No vehicle', style: TextStyle(color: gcs.secText)));
    }

    return Container(
      color: gcs.bg,
      child: Column(
        children: [
          // Header with drone selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  bottom:
                      BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Row(children: [
              Icon(LucideIcons.activity, size: 16, color: gcs.accent),
              const SizedBox(width: 8),
              Text('TELEMETRY',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: gcs.accent,
                  )),
              const Spacer(),
              ...s.drones.map((d) => GestureDetector(
                    onTap: () =>
                        ref.read(gcsProvider.notifier).selectDrone(d.id),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: d.id == s.selectedDroneId
                            ? gcs.accent.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: d.id == s.selectedDroneId
                              ? gcs.accent
                              : gcs.accent.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(d.name,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            color: d.id == s.selectedDroneId
                                ? gcs.accent
                                : gcs.secText,
                          )),
                    ),
                  )),
            ]),
          ),

          // Content
          Expanded(
            child: Row(
              children: [
                // Left stat cards
                SizedBox(
                  width: 220,
                  child: Container(
                    decoration: BoxDecoration(
                      color: gcs.panels,
                      border: Border(
                          right: BorderSide(
                              color: gcs.accent.withValues(alpha: 0.15))),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _TelCard(
                            label: 'ALTITUDE',
                            value: '${drone.altitude.toStringAsFixed(1)} m',
                            icon: LucideIcons.arrowUp,
                            color: gcs.accent,
                            gcs: gcs),
                        _TelCard(
                            label: 'GROUND SPEED',
                            value: '${drone.speed.toStringAsFixed(1)} m/s',
                            icon: LucideIcons.gauge,
                            color: gcs.success,
                            gcs: gcs),
                        _TelCard(
                            label: 'CLIMB RATE',
                            value: '${drone.climbRate.toStringAsFixed(1)} m/s',
                            icon: LucideIcons.trendingUp,
                            color: drone.climbRate >= 0
                                ? gcs.success
                                : gcs.warning,
                            gcs: gcs),
                        _TelCard(
                            label: 'HEADING',
                            value: '${drone.heading.toStringAsFixed(0)}°',
                            icon: LucideIcons.compass,
                            color: gcs.accent,
                            gcs: gcs),
                        _TelCard(
                            label: 'PITCH',
                            value: '${drone.pitch.toStringAsFixed(1)}°',
                            icon: LucideIcons.arrowUpDown,
                            color: gcs.secText,
                            gcs: gcs),
                        _TelCard(
                            label: 'ROLL',
                            value: '${drone.roll.toStringAsFixed(1)}°',
                            icon: LucideIcons.rotateCw,
                            color: gcs.secText,
                            gcs: gcs),
                        _TelCard(
                            label: 'BATTERY',
                            value: '${drone.battery.toStringAsFixed(0)}%',
                            icon: LucideIcons.battery,
                            color:
                                drone.battery > 30 ? gcs.success : gcs.danger,
                            gcs: gcs),
                        _TelCard(
                            label: 'VOLTAGE',
                            value: '${drone.voltage.toStringAsFixed(1)} V',
                            icon: LucideIcons.zap,
                            color: gcs.warning,
                            gcs: gcs),
                        _TelCard(
                            label: 'SATELLITES',
                            value: '${drone.satellites}',
                            icon: LucideIcons.satellite,
                            color: gcs.success,
                            gcs: gcs),
                        _TelCard(
                            label: 'HDOP',
                            value: drone.hdop.toStringAsFixed(2),
                            icon: LucideIcons.mapPin,
                            color: drone.hdop < 1 ? gcs.success : gcs.warning,
                            gcs: gcs),
                      ],
                    ),
                  ),
                ),

                // Right: Speedometer + altitude history chart area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Speedometer
                        SizedBox(
                          height: 180,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _Gauge(
                                label: 'SPEED',
                                value: drone.speed,
                                max: 30,
                                unit: 'm/s',
                                color: gcs.success,
                                gcs: gcs,
                              ),
                              _Gauge(
                                label: 'ALTITUDE',
                                value: drone.altitude,
                                max: 400,
                                unit: 'm',
                                color: gcs.accent,
                                gcs: gcs,
                              ),
                              _Gauge(
                                label: 'BATTERY',
                                value: drone.battery,
                                max: 100,
                                unit: '%',
                                color: drone.battery > 30
                                    ? gcs.success
                                    : gcs.danger,
                                gcs: gcs,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Altitude history (line chart simulation)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: gcs.panels,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: gcs.accent.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ALTITUDE HISTORY',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 10,
                                      color: gcs.secText,
                                      letterSpacing: 1,
                                    )),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: CustomPaint(
                                    painter: _AltChartPainter(
                                      history: drone.history
                                          .take(60)
                                          .map((h) =>
                                              drone.altitude +
                                              (h['lat']! * 100 % 40 - 20))
                                          .toList(),
                                      color: gcs.accent,
                                      bg: gcs.bg,
                                    ),
                                    size: const Size.fromHeight(100),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── MAVLink Inspector Panel ───────────────────────────
          _MavlinkInspector(log: s.mavlinkLog, gcs: gcs),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MAVLink Inspector Panel
// ─────────────────────────────────────────────
class _MavlinkInspector extends StatelessWidget {
  const _MavlinkInspector({required this.log, required this.gcs});
  final List<String> log;
  final GcsThemeExtension gcs;

  // Colour-code by message type
  Color _colorFor(String entry) {
    if (entry.contains('HEARTBEAT')) return const Color(0xFF00E5FF);
    if (entry.contains('ATTITUDE')) return const Color(0xFF69FF47);
    if (entry.contains('VFR_HUD')) return const Color(0xFFFFD740);
    if (entry.contains('GLOBAL_POS')) return const Color(0xFF40C4FF);
    if (entry.contains('SYS_STATUS')) return const Color(0xFFFF6E40);
    if (entry.contains('GPS_RAW')) return const Color(0xFF64FFDA);
    if (entry.contains('RADIO')) return const Color(0xFFE040FB);
    return const Color(0xFFB0BEC5);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF060B14),
        border: Border(
          top: BorderSide(color: gcs.accent.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        children: [
          // Header bar
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                bottom: BorderSide(color: gcs.accent.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: log.isNotEmpty
                        ? const Color(0xFF69FF47)
                        : const Color(0xFF444444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'MAVLINK INSPECTOR',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: gcs.accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: gcs.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${log.length} msgs',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      color: gcs.secText,
                    ),
                  ),
                ),
                const Spacer(),
                // Legend chips
                for (final e in [
                  ('HB', const Color(0xFF00E5FF)),
                  ('ATT', const Color(0xFF69FF47)),
                  ('HUD', const Color(0xFFFFD740)),
                  ('GPS', const Color(0xFF40C4FF)),
                  ('SYS', const Color(0xFFFF6E40)),
                ])
                  Container(
                    margin: const EdgeInsets.only(left: 5),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: e.$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: e.$2.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      e.$1,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 8,
                        color: e.$2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Message list
          Expanded(
            child: log.isEmpty
                ? Center(
                    child: Text(
                      'Waiting for MAVLink frames…',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: gcs.secText.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    itemCount: log.length,
                    itemBuilder: (_, i) {
                      final entry = log[i];
                      final color = _colorFor(entry);
                      // Split: [timestamp] MSGTYPE  detail
                      final parts = entry.split(RegExp(r'\s{2,}'));
                      final tsAndType = parts.isNotEmpty ? parts[0] : entry;
                      final detail =
                          parts.length > 1 ? parts.sublist(1).join('  ') : '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10.5,
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(
                                text: tsAndType,
                                style: TextStyle(
                                    color: color, fontWeight: FontWeight.bold),
                              ),
                              if (detail.isNotEmpty)
                                TextSpan(
                                  text: '  $detail',
                                  style:
                                      const TextStyle(color: Color(0xFF90A4AE)),
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

class _TelCard extends StatelessWidget {
  const _TelCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.gcs});
  final String label, value;
  final IconData icon;
  final Color color;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: gcs.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9,
                  color: gcs.secText,
                  letterSpacing: 0.8,
                ))),
        Text(value,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            )),
      ]),
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge(
      {required this.label,
      required this.value,
      required this.max,
      required this.unit,
      required this.color,
      required this.gcs});
  final String label, unit;
  final double value, max;
  final Color color;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _GaugePainter(
              fraction: (value / max).clamp(0.0, 1.0),
              color: color,
              bg: gcs.bg,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value.toStringAsFixed(1),
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      )),
                  Text(unit,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9,
                        color: gcs.secText,
                      )),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: gcs.secText,
              letterSpacing: 1,
            )),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(
      {required this.fraction, required this.color, required this.bg});
  final double fraction;
  final Color color, bg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final bgPaint = Paint()
      ..color = bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi * 0.75,
        pi * 1.5, false, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi * 0.75,
        pi * 1.5 * fraction, false, fgPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.fraction != fraction;
}

class _AltChartPainter extends CustomPainter {
  const _AltChartPainter(
      {required this.history, required this.color, required this.bg});
  final List<double> history;
  final Color color, bg;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final minV = history.reduce(min);
    final maxV = history.reduce(max).clamp(minV + 1, double.infinity);
    final range = maxV - minV;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final step = size.width / (history.length - 1).clamp(1, 999);
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < history.length; i++) {
      final x = i * step;
      final y = size.height - ((history[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_AltChartPainter old) => old.history != history;
}
