import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/theme/app_theme.dart';

class DiagnosticsPage extends ConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final drone = s.drones.isNotEmpty
        ? s.drones.firstWhere((d) => d.id == s.selectedDroneId,
            orElse: () => s.drones.first)
        : null;

    return Container(
      color: gcs.bg,
      child: Column(
        children: [
          // Header
          _header('DIAGNOSTICS', LucideIcons.cpu, gcs),

          Expanded(
            child: drone == null
                ? Center(
                    child: Text('No vehicle selected',
                        style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: gcs.secText)))
                : Row(
                    children: [
                      // Left panel
                      SizedBox(
                        width: 280,
                        child: Container(
                          decoration: BoxDecoration(
                            color: gcs.panels,
                            border: Border(
                                right: BorderSide(
                                    color: gcs.accent.withValues(alpha: 0.15))),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _SectionTitle('SYSTEM HEALTH', gcs),
                              const SizedBox(height: 8),
                              _HealthRow('Overall', drone.health, gcs),
                              _HealthRow(
                                  'GPS Signal',
                                  drone.satellites > 12 ? 'Healthy' : 'Warning',
                                  gcs),
                              _HealthRow(
                                  'Comms Link',
                                  drone.latency < 100 ? 'Healthy' : 'Critical',
                                  gcs),
                              _HealthRow(
                                  'Battery',
                                  drone.battery > 30 ? 'Healthy' : 'Critical',
                                  gcs),
                              _HealthRow('Encryption',
                                  drone.encrypted ? 'Healthy' : 'Warning', gcs),
                              const SizedBox(height: 20),
                              _SectionTitle('LINK QUALITY', gcs),
                              const SizedBox(height: 8),
                              _MetricRow(
                                  'Latency',
                                  '${drone.latency} ms',
                                  drone.latency < 100
                                      ? gcs.success
                                      : gcs.danger,
                                  gcs),
                              _MetricRow(
                                  'Packet Loss',
                                  '${drone.packetLoss.toStringAsFixed(1)}%',
                                  drone.packetLoss < 1
                                      ? gcs.success
                                      : gcs.warning,
                                  gcs),
                              _MetricRow(
                                  'Signal',
                                  '${drone.signal.toStringAsFixed(0)} dBm',
                                  gcs.accent,
                                  gcs),
                              _MetricRow(
                                  'Satellites',
                                  '${drone.satellites}',
                                  drone.satellites > 12
                                      ? gcs.success
                                      : gcs.warning,
                                  gcs),
                              _MetricRow(
                                  'HDOP',
                                  drone.hdop.toStringAsFixed(2),
                                  drone.hdop < 1 ? gcs.success : gcs.warning,
                                  gcs),
                            ],
                          ),
                        ),
                      ),

                      // Right panel
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _SectionTitle('MOTOR RPM', gcs),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child:
                                      _MotorGauge('M1', drone.motor1Rpm, gcs)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child:
                                      _MotorGauge('M2', drone.motor2Rpm, gcs)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child:
                                      _MotorGauge('M3', drone.motor3Rpm, gcs)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child:
                                      _MotorGauge('M4', drone.motor4Rpm, gcs)),
                            ]),
                            const SizedBox(height: 20),
                            _SectionTitle('POWER SYSTEM', gcs),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: _StatBox(
                                      'VOLTAGE',
                                      '${drone.voltage.toStringAsFixed(1)} V',
                                      drone.voltage > 21
                                          ? gcs.success
                                          : gcs.danger,
                                      gcs)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _StatBox(
                                      'CURRENT',
                                      '${drone.current.toStringAsFixed(1)} A',
                                      gcs.warning,
                                      gcs)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _StatBox(
                                      'BATTERY',
                                      '${drone.battery.toStringAsFixed(0)}%',
                                      drone.battery > 30
                                          ? gcs.success
                                          : gcs.danger,
                                      gcs)),
                            ]),
                            const SizedBox(height: 20),
                            _SectionTitle('NAVIGATION', gcs),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: _StatBox(
                                      'ALTITUDE',
                                      '${drone.altitude.toStringAsFixed(1)} m',
                                      gcs.accent,
                                      gcs)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _StatBox(
                                      'SPEED',
                                      '${drone.speed.toStringAsFixed(1)} m/s',
                                      gcs.accent,
                                      gcs)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _StatBox(
                                      'CLIMB',
                                      '${drone.climbRate.toStringAsFixed(1)} m/s',
                                      drone.climbRate >= 0
                                          ? gcs.success
                                          : gcs.warning,
                                      gcs)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _StatBox(
                                      'HEADING',
                                      '${drone.heading.toStringAsFixed(0)}°',
                                      gcs.accent,
                                      gcs)),
                            ]),
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

  Widget _header(String title, IconData icon, GcsThemeExtension gcs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: gcs.panels,
        border: Border(
            bottom: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: gcs.accent),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: gcs.accent,
            )),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.gcs);
  final String title;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          color: gcs.secText,
          letterSpacing: 1.5,
        ));
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow(this.label, this.status, this.gcs);
  final String label, status;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    final color = status == 'Healthy'
        ? gcs.success
        : status == 'Warning'
            ? gcs.warning
            : gcs.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: gcs.text,
                ))),
        Text(status,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            )),
      ]),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value, this.color, this.gcs);
  final String label, value;
  final Color color;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: gcs.secText,
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

class _MotorGauge extends StatelessWidget {
  const _MotorGauge(this.label, this.rpm, this.gcs);
  final String label;
  final int rpm;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    final fraction = (rpm / 8000).clamp(0.0, 1.0);
    final color = fraction > 0.8
        ? gcs.danger
        : fraction > 0.6
            ? gcs.warning
            : gcs.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gcs.panels.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.1)),
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: gcs.secText,
              letterSpacing: 1,
            )),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          width: 60,
          child: CustomPaint(
              painter:
                  _ArcPainter(fraction: fraction, color: color, bg: gcs.bg)),
        ),
        const SizedBox(height: 6),
        Text('$rpm RPM',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: color,
            )),
      ]),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(
      {required this.fraction, required this.color, required this.bg});
  final double fraction;
  final Color color, bg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final bgPaint = Paint()
      ..color = bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const startAngle = 2.36; // ~135 deg
    const sweepFull = 4.71; // ~270 deg
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepFull, false, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepFull * fraction, false, fgPaint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.color != color;
}

class _StatBox extends StatelessWidget {
  const _StatBox(this.label, this.value, this.color, this.gcs);
  final String label, value;
  final Color color;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gcs.panels,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 16,
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
      ]),
    );
  }
}
