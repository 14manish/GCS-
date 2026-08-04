import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Heading Indicator / Compass Dial Widget
class CompassHeadingWidget extends StatelessWidget {
  const CompassHeadingWidget({
    super.key,
    required this.heading,
    this.size = 140.0,
  });

  /// Heading in degrees (0.0 to 360.0)
  final double heading;

  /// Diameter of the compass dial
  final double size;

  @override
  Widget build(BuildContext context) {
    final cardinalStr = _getCardinalDirection(heading);
    final degreeStr = '${heading.round()}°';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _CompassPainter(heading: heading),
          ),
          // Center Badge Readout
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                degreeStr,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFB300), // Amber yellow readout
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                cardinalStr,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCardinalDirection(double deg) {
    final normalized = (deg % 360 + 360) % 360;
    if (normalized >= 337.5 || normalized < 22.5) return 'N';
    if (normalized >= 22.5 && normalized < 67.5) return 'NE';
    if (normalized >= 67.5 && normalized < 112.5) return 'E';
    if (normalized >= 112.5 && normalized < 157.5) return 'SE';
    if (normalized >= 157.5 && normalized < 202.5) return 'S';
    if (normalized >= 202.5 && normalized < 247.5) return 'SW';
    if (normalized >= 247.5 && normalized < 292.5) return 'W';
    return 'NW';
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({required this.heading});

  final double heading;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Dark Slate Inner Background
    final bgPaint = Paint()
      ..color = const Color(0xD90F172A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 2, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius - 2, borderPaint);

    // 2. Rotate dial based on current heading (-heading in radians)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180.0);

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw 360° graduation ticks and labels
    for (int deg = 0; deg < 360; deg += 5) {
      final rad = (deg - 90) * math.pi / 180.0;

      final isCardinal = (deg % 90 == 0);
      final isMajor = (deg % 30 == 0);
      final tickLength = isCardinal ? 10.0 : (isMajor ? 7.0 : 4.0);

      final p1 = Offset(
        (radius - tickLength - 3) * math.cos(rad),
        (radius - tickLength - 3) * math.sin(rad),
      );
      final p2 = Offset(
        (radius - 3) * math.cos(rad),
        (radius - 3) * math.sin(rad),
      );

      tickPaint.color = isCardinal
          ? (deg == 0 ? const Color(0xFFFF1744) : Colors.white)
          : Colors.white.withValues(alpha: isMajor ? 0.8 : 0.4);
      tickPaint.strokeWidth = isCardinal ? 2.0 : (isMajor ? 1.5 : 1.0);

      canvas.drawLine(p1, p2, tickPaint);

      // Draw Cardinal Labels (N, E, S, W) or degree numbers
      if (isCardinal || isMajor) {
        String label = '';
        Color labelColor = Colors.white.withValues(alpha: 0.9);

        if (deg == 0) {
          label = 'N';
          labelColor = const Color(0xFFFF1744); // Red N
        } else if (deg == 90) {
          label = 'E';
        } else if (deg == 180) {
          label = 'S';
        } else if (deg == 270) {
          label = 'W';
        } else {
          label = '${deg ~/ 10}'; // e.g. 3, 6, 12, 15, 21, 24, 30, 33
          labelColor = Colors.white.withValues(alpha: 0.6);
        }

        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color: labelColor,
            fontSize: isCardinal ? 12 : 9,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();

        final textRad = (deg - 90) * math.pi / 180.0;
        final textDist = radius - tickLength - 12;
        final textPos = Offset(
          textDist * math.cos(textRad) - textPainter.width / 2,
          textDist * math.sin(textRad) - textPainter.height / 2,
        );
        textPainter.paint(canvas, textPos);
      }
    }

    // Restore dial rotation
    canvas.restore();

    // 3. Top Fixed Pointer (Target Direction Indicator pointing UP)
    final pointerPath = Path()
      ..moveTo(center.dx, center.dy - radius + 2)
      ..lineTo(center.dx - 6, center.dy - radius + 11)
      ..lineTo(center.dx + 6, center.dy - radius + 11)
      ..close();

    final pointerPaint = Paint()
      ..color = const Color(0xFFFFD600)
      ..style = PaintingStyle.fill;
    canvas.drawPath(pointerPath, pointerPaint);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) {
    return oldDelegate.heading != heading;
  }
}
