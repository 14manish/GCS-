import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Attitude Indicator (Artificial Horizon) dial widget
class AttitudeHorizonWidget extends StatelessWidget {
  const AttitudeHorizonWidget({
    super.key,
    required this.pitch,
    required this.roll,
    this.size = 140.0,
  });

  /// Pitch in degrees (-90 to +90)
  final double pitch;

  /// Roll in degrees (-180 to +180)
  final double roll;

  /// Diameter of the dial in logical pixels
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _AttitudePainter(pitch: pitch, roll: roll),
      ),
    );
  }
}

class _AttitudePainter extends CustomPainter {
  _AttitudePainter({required this.pitch, required this.roll});

  final double pitch;
  final double roll;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Outer Bezel / Border Ring
    final borderPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // Clip to circle for internal horizon rendering
    canvas.save();
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius - 2));
    canvas.clipPath(circlePath);

    // 2. Rotate canvas around center by Roll angle (in radians)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(roll * math.pi / 180.0);

    // 3. Translate vertically by Pitch (pixels per degree pitch)
    const pitchScale = 1.8; // pixels per degree
    final pitchOffset = pitch * pitchScale;
    canvas.translate(0, pitchOffset);

    // 4. Paint Sky & Ground Rectangles
    final skyPaint = Paint()..color = AppColors.horizonSky;
    final groundPaint = Paint()..color = AppColors.horizonGround;

    // Large bounds for rotated background
    final rectSize = size.width * 2.5;
    canvas.drawRect(
      Rect.fromLTRB(-rectSize, -rectSize, rectSize, 0),
      skyPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(-rectSize, 0, rectSize, rectSize),
      groundPaint,
    );

    // Horizon dividing line
    final horizonPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(-rectSize, 0),
      Offset(rectSize, 0),
      horizonPaint,
    );

    // 5. Pitch Ladder Lines (-30° to +30° in 10° steps)
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5;

    for (int deg = -40; deg <= 40; deg += 10) {
      if (deg == 0) continue; // Skip horizon line already drawn
      final y = -deg * pitchScale;

      final isMajor = (deg % 10 == 0);
      final lineLen = isMajor ? 32.0 : 18.0;

      // Draw ladder bar with end caps
      canvas.drawLine(
          Offset(-lineLen / 2, y), Offset(lineLen / 2, y), linePaint);
      canvas.drawLine(Offset(-lineLen / 2, y),
          Offset(-lineLen / 2, y + (deg > 0 ? 4 : -4)), linePaint);
      canvas.drawLine(Offset(lineLen / 2, y),
          Offset(lineLen / 2, y + (deg > 0 ? 4 : -4)), linePaint);

      // Pitch angle text labels
      if (isMajor && deg.abs() <= 30) {
        textPainter.text = TextSpan(
          text: '${deg.abs()}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(lineLen / 2 + 4, y - 6));
        textPainter.paint(
            canvas, Offset(-lineLen / 2 - textPainter.width - 4, y - 6));
      }
    }

    // Restore roll & pitch transformations
    canvas.restore();

    // 6. Roll Scale Graduation Ticks on Top Circle
    final rollTickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;

    for (final rollDeg in [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60]) {
      final rad = (rollDeg - 90) * math.pi / 180.0;
      final tickLen =
          (rollDeg == 0 || rollDeg.abs() == 30 || rollDeg.abs() == 60)
              ? 8.0
              : 4.0;
      final start = Offset(
        center.dx + (radius - tickLen) * math.cos(rad),
        center.dy + (radius - tickLen) * math.sin(rad),
      );
      final end = Offset(
        center.dx + radius * math.cos(rad),
        center.dy + radius * math.sin(rad),
      );
      canvas.drawLine(start, end, rollTickPaint);
    }

    // Restore circle clip
    canvas.restore();

    // 7. Fixed Center Reticle / Aircraft Symbol (Always upright in center)
    final reticlePaint = Paint()
      ..color = AppColors.horizonReticle
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final fillReticle = Paint()
      ..color = AppColors.horizonReticle
      ..style = PaintingStyle.fill;

    // Center dot
    canvas.drawCircle(center, 3.5, fillReticle);

    // Left & Right Wings
    final wingPath = Path()
      ..moveTo(center.dx - 32, center.dy)
      ..lineTo(center.dx - 12, center.dy)
      ..lineTo(center.dx - 12, center.dy + 6)
      ..moveTo(center.dx + 12, center.dy)
      ..lineTo(center.dx + 32, center.dy)
      ..lineTo(center.dx + 12, center.dy + 6);
    canvas.drawPath(wingPath, reticlePaint);

    // Top Roll Pointer Triangle at (0° top)
    final rollTriangle = Path()
      ..moveTo(center.dx, center.dy - radius + 3)
      ..lineTo(center.dx - 6, center.dy - radius + 11)
      ..lineTo(center.dx + 6, center.dy - radius + 11)
      ..close();
    canvas.drawPath(rollTriangle, fillReticle);

    // Outer circular bezel stroke
    canvas.drawCircle(center, radius - 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _AttitudePainter oldDelegate) {
    return oldDelegate.pitch != pitch || oldDelegate.roll != roll;
  }
}
