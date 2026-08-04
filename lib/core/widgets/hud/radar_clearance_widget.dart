import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'hud_glass_card.dart';

/// Terrain Clearance Radar Heatmap Sector Widget
class RadarClearanceWidget extends StatelessWidget {
  const RadarClearanceWidget({
    super.key,
    this.width = 160.0,
    this.height = 140.0,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return HudGlassCard(
      width: width,
      height: height,
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          // Background Radar Canvas
          CustomPaint(
            size: Size(width - 12, height - 12),
            painter: _RadarPainter(),
          ),
          // Top Left Distance Badge
          Positioned(
            top: 2,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                '120m',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tacticalCyan,
                ),
              ),
            ),
          ),
          // Top Right REL Mode Badge
          Positioned(
            top: 2,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'REL',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tacticalCyan,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height - 6);
    final radius = size.height - 12;

    // 1. Heatmap Sector Arc Path (-45° to +45° fan sweep)
    const sweepAngle = 90.0 * math.pi / 180.0;
    const startAngle = -135.0 * math.pi / 180.0;

    final sectorPath = Path()
      ..moveTo(origin.dx, origin.dy)
      ..arcTo(
        Rect.fromCircle(center: origin, radius: radius),
        startAngle,
        sweepAngle,
        false,
      )
      ..close();

    canvas.save();
    canvas.clipPath(sectorPath);

    // Render multi-layer terrain elevation heatmap (Green -> Amber -> Red)
    final greenPaint = Paint()..color = const Color(0xFF2E7D32);
    final amberPaint = Paint()..color = const Color(0xFFF57F17);
    final orangePaint = Paint()..color = const Color(0xFFE65100);

    canvas.drawCircle(origin, radius, greenPaint);
    canvas.drawCircle(origin, radius * 0.75, amberPaint);
    canvas.drawCircle(origin, radius * 0.45, orangePaint);

    // Organic heatmap noise blobs
    final heatBlob1 = Path()
      ..addOval(Rect.fromLTWH(size.width * 0.2, size.height * 0.15, size.width * 0.5, size.height * 0.4));
    canvas.drawPath(heatBlob1, Paint()..color = const Color(0xFF4CAF50));

    final heatBlob2 = Path()
      ..addOval(Rect.fromLTWH(size.width * 0.55, size.height * 0.1, size.width * 0.3, size.height * 0.35));
    canvas.drawPath(heatBlob2, Paint()..color = const Color(0xFFFFB300));

    canvas.restore();

    // 2. Radar Distance Concentric Arc Rings & Radial Spoke Lines
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCircle(center: origin, radius: radius);
    final rect75 = Rect.fromCircle(center: origin, radius: radius * 0.66);
    final rect33 = Rect.fromCircle(center: origin, radius: radius * 0.33);

    canvas.drawArc(rect, startAngle, sweepAngle, false, ringPaint);
    canvas.drawArc(rect75, startAngle, sweepAngle, false, ringPaint);
    canvas.drawArc(rect33, startAngle, sweepAngle, false, ringPaint);

    // Outer Sector Side Lines
    canvas.drawLine(
      origin,
      Offset(origin.dx + radius * math.cos(startAngle), origin.dy + radius * math.sin(startAngle)),
      ringPaint,
    );
    canvas.drawLine(
      origin,
      Offset(origin.dx + radius * math.cos(startAngle + sweepAngle), origin.dy + radius * math.sin(startAngle + sweepAngle)),
      ringPaint,
    );
    // Center Spoke
    canvas.drawLine(
      origin,
      Offset(origin.dx, origin.dy - radius),
      ringPaint,
    );

    // Distance Ring Numbers (1200, 2400, 3600)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void drawText(String txt, double yPos) {
      textPainter.text = TextSpan(
        text: txt,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 7,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(origin.dx + 4, yPos - 4));
    }

    drawText('3600', origin.dy - radius);
    drawText('2400', origin.dy - radius * 0.66);
    drawText('1200', origin.dy - radius * 0.33);

    // 3. Aircraft Origin Marker (White Target Ring)
    final originPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(origin, 4, originPaint);
    final originRing = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(origin, 4, originRing);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
