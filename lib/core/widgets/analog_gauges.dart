import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';

/// Mission Planner style 2x2 Analog Flight Instrument Gauges
/// Includes VSI, Speed, Altimeter, and Heading/Compass gauges.
class AnalogGaugesWidget extends StatefulWidget {
  const AnalogGaugesWidget({
    super.key,
    required this.altitude,
    required this.speed,
    required this.heading,
    required this.climbRate,
    this.pitch = 0.0,
    this.roll = 0.0,
    this.onClose,
  });

  final double altitude;
  final double speed;
  final double heading;
  final double climbRate;
  final double pitch;
  final double roll;
  final VoidCallback? onClose;

  @override
  State<AnalogGaugesWidget> createState() => _AnalogGaugesWidgetState();
}

class _AnalogGaugesWidgetState extends State<AnalogGaugesWidget> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    if (_collapsed) {
      return GestureDetector(
        onTap: () => setState(() => _collapsed = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.panels.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.gauge, size: 14, color: AppColors.accent),
              SizedBox(width: 6),
              Text(
                'GAUGES',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 320,
      height: 350,
      decoration: BoxDecoration(
        color: AppColors.panels.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.6),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.gauge, size: 13, color: AppColors.accent),
                const SizedBox(width: 6),
                const Text(
                  'FLIGHT GAUGES',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _collapsed = true),
                  child: const Icon(
                    LucideIcons.minus,
                    size: 14,
                    color: AppColors.textSecond,
                  ),
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Icon(
                      LucideIcons.x,
                      size: 14,
                      color: AppColors.textSecond,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2x2 Grid of Gauges
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // Top-Left: VSI
                        Expanded(
                          child: _GaugeContainer(
                            title: 'VSI',
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: VsiGaugePainter(
                                climbRate: widget.climbRate,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Top-Right: Speed
                        Expanded(
                          child: _GaugeContainer(
                            title: 'Speed',
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: SpeedGaugePainter(
                                speed: widget.speed,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Row(
                      children: [
                        // Bottom-Left: Alt
                        Expanded(
                          child: _GaugeContainer(
                            title: 'Alt',
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: AltGaugePainter(
                                altitude: widget.altitude,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Bottom-Right: Heading / Compass
                        Expanded(
                          child: _GaugeContainer(
                            title: 'Compass',
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: CompassGaugePainter(
                                heading: widget.heading,
                                pitch: widget.pitch,
                                roll: widget.roll,
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _GaugeContainer extends StatelessWidget {
  const _GaugeContainer({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox.expand(
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. VSI GAUGE PAINTER (Vertical Speed Indicator: -10 to +10 m/s)
// ─────────────────────────────────────────────────────────────────────────────
class VsiGaugePainter extends CustomPainter {
  VsiGaugePainter({required this.climbRate});
  final double climbRate;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;

    // Dial background
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF222222), Color(0xFF0D0D0D)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Bezel
    final bezelPaint = Paint()
      ..color = const Color(0xFF444444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, bezelPaint);

    // Scale ticks and labels
    // 0 is at 180 degrees (left / 9 o'clock)
    // +10 is at ~ 45 degrees (upwards)
    // -10 is at ~ 315 degrees (downwards)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final ticks = [-10, -8, -6, -4, -2, 0, 2, 4, 6, 8, 10];
    for (final val in ticks) {
      // Map val (-10 to +10) to angle in radians.
      // 0 -> pi (180 deg, left)
      // +10 -> pi - 2.2 rad (~ 54 deg)
      // -10 -> pi + 2.2 rad (~ 306 deg)
      final angle = pi - (val / 10.0) * (2.2);

      final isMajor = val % 2 == 0;
      final tickLen = isMajor ? 8.0 : 4.0;

      final p1 = Offset(
        center.dx + (radius - 2) * cos(angle),
        center.dy + (radius - 2) * sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 2 - tickLen) * cos(angle),
        center.dy + (radius - 2 - tickLen) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = isMajor ? 1.5 : 1.0;
      canvas.drawLine(p1, p2, tickPaint);

      // Label for major ticks
      if (val % 2 == 0) {
        final labelPos = Offset(
          center.dx + (radius - 18) * cos(angle),
          center.dy + (radius - 18) * sin(angle),
        );
        textPainter.text = TextSpan(
          text: '${val.abs()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            fontFamily: 'JetBrains Mono',
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          labelPos - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }

    // Title label "VSI"
    textPainter.text = const TextSpan(
      text: 'VSI',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        fontFamily: 'JetBrains Mono',
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + radius * 0.35),
    );

    // Needle
    final clampedRate = climbRate.clamp(-10.0, 10.0);
    final needleAngle = pi - (clampedRate / 10.0) * (2.2);

    final needleLen = radius - 14;
    final tip = Offset(
      center.dx + needleLen * cos(needleAngle),
      center.dy + needleLen * sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, needlePaint);

    // Center pivot cap
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF888888));
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant VsiGaugePainter oldDelegate) =>
      oldDelegate.climbRate != climbRate;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. SPEED GAUGE PAINTER (0 to 60 m/s)
// ─────────────────────────────────────────────────────────────────────────────
class SpeedGaugePainter extends CustomPainter {
  SpeedGaugePainter({required this.speed});
  final double speed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;

    // Dial background
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF222222), Color(0xFF0D0D0D)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Bezel
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF444444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Scale 0 to 60 (Arc from 135 deg to 405 deg = 270 deg total)
    const startAngle = 135.0 * pi / 180.0;
    const totalSweep = 270.0 * pi / 180.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 60; i += 2) {
      final frac = i / 60.0;
      final angle = startAngle + frac * totalSweep;

      final isMajor = i % 10 == 0;
      final tickLen = isMajor ? 8.0 : 4.0;

      final p1 = Offset(
        center.dx + (radius - 2) * cos(angle),
        center.dy + (radius - 2) * sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 2 - tickLen) * cos(angle),
        center.dy + (radius - 2 - tickLen) * sin(angle),
      );

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.white
          ..strokeWidth = isMajor ? 1.5 : 1.0,
      );

      if (isMajor) {
        final labelPos = Offset(
          center.dx + (radius - 18) * cos(angle),
          center.dy + (radius - 18) * sin(angle),
        );
        textPainter.text = TextSpan(
          text: '$i',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            fontFamily: 'JetBrains Mono',
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          labelPos - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }

    // Title label "Speed"
    textPainter.text = const TextSpan(
      text: 'Speed',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        fontFamily: 'JetBrains Mono',
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + radius * 0.35),
    );

    // Red Needle
    final clampedSpeed = speed.clamp(0.0, 60.0);
    final needleAngle = startAngle + (clampedSpeed / 60.0) * totalSweep;
    final needleLen = radius - 12;

    final tip = Offset(
      center.dx + needleLen * cos(needleAngle),
      center.dy + needleLen * sin(needleAngle),
    );

    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = const Color(0xFFFF4444)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // Center pivot cap
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFFCC3333));
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant SpeedGaugePainter oldDelegate) =>
      oldDelegate.speed != speed;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. ALT GAUGE PAINTER (Altimeter: 0 to 9 x 100m)
// ─────────────────────────────────────────────────────────────────────────────
class AltGaugePainter extends CustomPainter {
  AltGaugePainter({required this.altitude});
  final double altitude;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;

    // Dial background
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF222222), Color(0xFF0D0D0D)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Bezel
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF444444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Clock style 0-9 ticks
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < 10; i++) {
      // 0 is at 12 o'clock (-pi/2)
      final angle = -pi / 2 + (i / 10.0) * (2 * pi);

      final p1 = Offset(
        center.dx + (radius - 2) * cos(angle),
        center.dy + (radius - 2) * sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 10) * cos(angle),
        center.dy + (radius - 10) * sin(angle),
      );

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5,
      );

      // Label
      final labelPos = Offset(
        center.dx + (radius - 18) * cos(angle),
        center.dy + (radius - 18) * sin(angle),
      );
      textPainter.text = TextSpan(
        text: '$i',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'JetBrains Mono',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        labelPos - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    // Title label "Alt"
    textPainter.text = const TextSpan(
      text: 'Alt',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        fontFamily: 'JetBrains Mono',
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + radius * 0.35),
    );

    // Needle: 1 full rotation = 100m (hundreds hand)
    final hundredsFrac = (altitude % 100) / 100.0;
    final needleAngle = -pi / 2 + hundredsFrac * (2 * pi);
    final needleLen = radius - 12;

    final tip = Offset(
      center.dx + needleLen * cos(needleAngle),
      center.dy + needleLen * sin(needleAngle),
    );

    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = const Color(0xFFFF4444)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // Center pivot cap
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFFCC3333));
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant AltGaugePainter oldDelegate) =>
      oldDelegate.altitude != altitude;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. COMPASS / HEADING GAUGE PAINTER (Directional Gyro with Crosshair)
// ─────────────────────────────────────────────────────────────────────────────
class CompassGaugePainter extends CustomPainter {
  CompassGaugePainter({
    required this.heading,
    this.pitch = 0.0,
    this.roll = 0.0,
  });

  final double heading;
  final double pitch;
  final double roll;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;

    // Background
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF222222), Color(0xFF0D0D0D)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);

    // Bezel
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF444444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Rotating Compass Card
    // Card rotates opposite to heading so current heading points UP (12 o'clock)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * pi / 180.0);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final compassLabels = {
      0: 'N',
      30: '3',
      60: '6',
      90: 'E',
      120: '12',
      150: '15',
      180: 'S',
      210: '21',
      240: '24',
      270: 'W',
      300: '30',
      330: '33',
    };

    for (int deg = 0; deg < 360; deg += 5) {
      final rad = -pi / 2 + (deg * pi / 180.0);
      final isCardinalOrMajor = deg % 30 == 0;
      final tickLen = isCardinalOrMajor ? 7.0 : 3.5;

      final p1 = Offset((radius - 2) * cos(rad), (radius - 2) * sin(rad));
      final p2 =
          Offset((radius - 2 - tickLen) * cos(rad), (radius - 2 - tickLen) * sin(rad));

      final isNorth = deg == 0;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = isNorth ? const Color(0xFFFF9800) : Colors.white
          ..strokeWidth = isCardinalOrMajor ? 1.5 : 1.0,
      );

      if (isCardinalOrMajor) {
        final labelStr = compassLabels[deg] ?? '$deg';
        final labelPos =
            Offset((radius - 16) * cos(rad), (radius - 16) * sin(rad));

        textPainter.text = TextSpan(
          text: labelStr,
          style: TextStyle(
            color: isNorth
                ? const Color(0xFFFF9800)
                : (deg % 90 == 0 ? Colors.white : Colors.white70),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            fontFamily: 'JetBrains Mono',
          ),
        );
        textPainter.layout();

        // Draw rotated label upright relative to compass card
        canvas.save();
        canvas.translate(labelPos.dx, labelPos.dy);
        canvas.rotate(rad + pi / 2);
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
        canvas.restore();
      }
    }

    canvas.restore(); // Restore unrotated canvas

    // Top Lubber Line (orange triangle pointing down to current heading)
    final lubberPath = Path()
      ..moveTo(center.dx, center.dy - radius + 2)
      ..lineTo(center.dx - 4, center.dy - radius + 8)
      ..lineTo(center.dx + 4, center.dy - radius + 8)
      ..close();
    canvas.drawPath(lubberPath, Paint()..color = const Color(0xFFFF9800));

    // Center Fixed Aircraft Symbol / Crosshair (Orange)
    final orangePaint = Paint()
      ..color = const Color(0xFFFF9800)
      ..strokeWidth = 2.0;

    // Horizontal wing line
    canvas.drawLine(
      Offset(center.dx - 18, center.dy),
      Offset(center.dx + 18, center.dy),
      orangePaint,
    );
    // Vertical tail pip
    canvas.drawLine(
      Offset(center.dx, center.dy - 8),
      Offset(center.dx, center.dy + 8),
      orangePaint,
    );
    // Center ring dot
    canvas.drawCircle(
      center,
      3,
      Paint()
        ..color = const Color(0xFFFF9800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CompassGaugePainter oldDelegate) =>
      oldDelegate.heading != heading ||
      oldDelegate.pitch != pitch ||
      oldDelegate.roll != roll;
}
