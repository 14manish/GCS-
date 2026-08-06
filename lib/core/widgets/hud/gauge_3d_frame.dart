import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A 3D Sports-Car style Metallic Bezel & Glass Lens container for HUD gauges.
/// Replicates premium 3D gauge design with multi-ring metallic bezel,
/// ambient cyan radial backlight, inner bevel depth, and convex glass lens reflection.
class Gauge3dFrame extends StatelessWidget {
  const Gauge3dFrame({
    super.key,
    required this.child,
    this.size = 140.0,
    this.showGlassSheen = true,
  });

  final Widget child;
  final double size;
  final bool showGlassSheen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Deep drop shadow under individual 3D gauge frame
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 16,
            spreadRadius: 3,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF00F2FE).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter:
            _Gauge3dGlassOverlayPainter(showGlassSheen: showGlassSheen),
        painter: const _Gauge3dBezelPainter(),
        child: Padding(
          padding: EdgeInsets.all(size * 0.075), // Inner inset for bezel width
          child: ClipOval(
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(0, 0.15),
                  radius: 0.85,
                  colors: [
                    Color(0x5200F2FE), // Cyan ambient center glow
                    Color(0x1F00B0FF),
                    Color(0xFF070E17), // Dark face background
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _Gauge3dBezelPainter extends CustomPainter {
  const _Gauge3dBezelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final bezelThickness = size.width * 0.08;

    // 1. Multi-stop Metallic Sweep Gradient for outer chrome rim
    final bezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = bezelThickness
      ..shader = SweepGradient(
        colors: const [
          Color(0xFF555555),
          Color(0xFF181818),
          Color(0xFF888888),
          Color(0xFF222222),
          Color(0xFF666666),
          Color(0xFF141414),
          Color(0xFF999999),
          Color(0xFF1A1A1A),
          Color(0xFF555555),
        ],
        stops: const [0.0, 0.15, 0.35, 0.5, 0.65, 0.78, 0.88, 0.95, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius - (bezelThickness / 2), bezelPaint);

    // 2. Inner Metallic Bevel Specular Ring
    final innerSpecularPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6);

    canvas.drawCircle(
        center, radius - bezelThickness + 1.0, innerSpecularPaint);

    // 3. Outer Edge Highlight Ring
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.35);

    canvas.drawCircle(center, radius - 0.6, outerRingPaint);

    // 4. Inset Inner Shadow Ring
    final insetShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = Colors.black.withValues(alpha: 0.7);

    canvas.drawCircle(center, radius - bezelThickness - 1.5, insetShadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Gauge3dGlassOverlayPainter extends CustomPainter {
  const _Gauge3dGlassOverlayPainter({required this.showGlassSheen});
  final bool showGlassSheen;

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGlassSheen) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerR = radius - (size.width * 0.08);

    // Curved Glossy Glass Lens Reflection Highlight across top half
    final glassPath = Path();

    glassPath.addArc(
      Rect.fromCircle(center: center, radius: innerR),
      math.pi * 0.9,
      math.pi * 1.2,
    );

    glassPath.quadraticBezierTo(
      center.dx,
      center.dy - innerR * 0.15,
      center.dx - innerR * math.cos(math.pi * 0.1),
      center.dy - innerR * math.sin(math.pi * 0.1),
    );

    glassPath.close();

    final glassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.38),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: innerR));

    canvas.drawPath(glassPath, glassPaint);

    // Bottom-right subtle edge glow reflection
    final bottomGlowPath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: innerR - 1),
        math.pi * 0.15,
        math.pi * 0.35,
      );

    final bottomGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF00F2FE).withValues(alpha: 0.25);

    canvas.drawPath(bottomGlowPath, bottomGlowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
