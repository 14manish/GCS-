import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'hud_glass_card.dart';

/// Real-time AGL (Above Ground Level) & Terrain Elevation Profile Widget
class AglElevationProfileWidget extends StatelessWidget {
  const AglElevationProfileWidget({
    super.key,
    required this.aglAltitude,
    required this.targetDistance,
    this.width = 240.0,
    this.height = 120.0,
  });

  /// Current AGL altitude in meters (e.g. 105.0)
  final double aglAltitude;

  /// Target / waypoints distance in meters (e.g. 78.0)
  final double targetDistance;

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return HudGlassCard(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: [
          // Header Readout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    'AGL ',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.tacticalCyan,
                    ),
                  ),
                  Text(
                    '${aglAltitude.round()} m',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    '► ',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.tacticalCyan,
                    ),
                  ),
                  Text(
                    '${targetDistance.round()} m',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Chart Canvas Area
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _AglChartPainter(aglAltitude: aglAltitude),
            ),
          ),
        ],
      ),
    );
  }
}

class _AglChartPainter extends CustomPainter {
  _AglChartPainter({required this.aglAltitude});

  final double aglAltitude;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Grid Axes & Labels
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    void drawAxisLabel(String text, Offset pos) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 8,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, pos);
    }

    drawAxisLabel('0', Offset(2, h * 0.2));
    drawAxisLabel('-50', Offset(2, h * 0.5));
    drawAxisLabel('-100', Offset(2, h * 0.8));

    drawAxisLabel('1000', Offset(w * 0.4, h - 9));
    drawAxisLabel('0', Offset(w * 0.2, h - 9));
    drawAxisLabel('2000', Offset(w * 0.8, h - 9));

    // Horizontal Grid Lines
    canvas.drawLine(Offset(20, h * 0.2), Offset(w, h * 0.2), gridPaint);
    canvas.drawLine(Offset(20, h * 0.5), Offset(w, h * 0.5), gridPaint);
    canvas.drawLine(Offset(20, h * 0.8), Offset(w, h * 0.8), gridPaint);

    // 2. Terrain Profile Path
    final terrainPath = Path();
    terrainPath.moveTo(20, h * 0.85);
    terrainPath.cubicTo(w * 0.25, h * 0.88, w * 0.45, h * 0.70, w * 0.65, h * 0.75);
    terrainPath.cubicTo(w * 0.75, h * 0.80, w * 0.85, h * 0.65, w, h * 0.70);

    // Fill Terrain Area under ground line
    final fillPath = Path.from(terrainPath);
    fillPath.lineTo(w, h - 10);
    fillPath.lineTo(20, h - 10);
    fillPath.close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF8D6E63).withValues(alpha: 0.5),
        const Color(0xFF4E342E).withValues(alpha: 0.8),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final terrainStroke = Paint()
      ..color = const Color(0xFFBCAAA4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(terrainPath, terrainStroke);

    // 3. Planned Flight Path (Top Dashed Cyan Line)
    final flightY = h * 0.25;
    final dashedPaint = Paint()
      ..color = AppColors.tacticalCyan
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    double dashW = 4, spaceW = 4;
    double currentX = 20;
    while (currentX < w) {
      canvas.drawLine(
        Offset(currentX, flightY),
        Offset(currentX + dashW, flightY),
        dashedPaint,
      );
      currentX += dashW + spaceW;
    }

    // 4. Interactive Scrubber Target Dot & Dotted Line
    final scrubberX = w * 0.45;
    final dotPaint = Paint()
      ..color = AppColors.tacticalCyan
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(scrubberX, flightY), 4.5, dotPaint);

    // Inner ring
    final ringPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(scrubberX, flightY), 6.5, ringPaint);

    // Vertical dashed connection line down to terrain ground
    double currentY = flightY + 6.5;
    final vertDash = Paint()
      ..color = AppColors.tacticalCyan.withValues(alpha: 0.7)
      ..strokeWidth = 1.0;
    while (currentY < h * 0.72) {
      canvas.drawLine(
        Offset(scrubberX, currentY),
        Offset(scrubberX, currentY + 3),
        vertDash,
      );
      currentY += 6;
    }
  }

  @override
  bool shouldRepaint(covariant _AglChartPainter oldDelegate) {
    return oldDelegate.aglAltitude != aglAltitude;
  }
}
