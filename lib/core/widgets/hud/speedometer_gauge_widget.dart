import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Drone Tactical Speedometer — Scale starts at 60 m/s, goes to 200 m/s.
/// Includes a tap-to-set manual speed override input.
class SpeedometerGaugeWidget extends StatefulWidget {
  const SpeedometerGaugeWidget({
    super.key,
    required this.speed,
    this.minSpeed = 60.0,
    this.maxSpeed = 200.0,
    this.size = 150.0,
    this.unit = 'm/s',
  });

  /// Actual live drone speed in m/s
  final double speed;

  /// Minimum scale value (default 60 m/s — below this drones don't fly)
  final double minSpeed;

  /// Maximum scale speed (default 200 m/s)
  final double maxSpeed;

  /// Diameter of the dial in logical pixels
  final double size;

  /// Speed unit label
  final String unit;

  @override
  State<SpeedometerGaugeWidget> createState() => _SpeedometerGaugeWidgetState();
}

class _SpeedometerGaugeWidgetState extends State<SpeedometerGaugeWidget> {
  double? _manualSpeed; // null = use live speed
  final _controller = TextEditingController();

  void _onTapDial(BuildContext context) {
    _controller.text = (_manualSpeed ?? widget.speed).toStringAsFixed(1);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00F2FE), width: 1),
        ),
        title: const Text(
          'SET MANUAL SPEED',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 13,
            color: Color(0xFF00F2FE),
            letterSpacing: 1.2,
          ),
        ),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            color: Colors.white,
            fontSize: 20,
          ),
          decoration: const InputDecoration(
            suffixText: 'm/s',
            suffixStyle: TextStyle(
              fontFamily: 'JetBrains Mono',
              color: Color(0xFF00F2FE),
              fontSize: 14,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00F2FE)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00F2FE), width: 2),
            ),
            hintText: '60 – 200',
            hintStyle: TextStyle(color: Colors.white38, fontFamily: 'JetBrains Mono'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _manualSpeed = null);
              Navigator.of(context).pop();
            },
            child: const Text('CLEAR', style: TextStyle(color: Colors.white54, fontFamily: 'JetBrains Mono', fontSize: 12)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(_controller.text);
              if (val != null) setState(() => _manualSpeed = val.clamp(widget.minSpeed, widget.maxSpeed));
              Navigator.of(context).pop();
            },
            child: const Text('SET', style: TextStyle(color: Color(0xFF00F2FE), fontFamily: 'JetBrains Mono', fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displaySpeed = _manualSpeed ?? widget.speed;
    final isManual = _manualSpeed != null;

    // Clamp to [minSpeed, maxSpeed] for needle
    final speedClamped = displaySpeed.clamp(widget.minSpeed, widget.maxSpeed);
    final speedDisplayStr = displaySpeed.toStringAsFixed(1);

    return GestureDetector(
      onTap: () => _onTapDial(context),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Gauge face painter
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _SpeedometerPainter(
                speed: speedClamped,
                minSpeed: widget.minSpeed,
                maxSpeed: widget.maxSpeed,
              ),
            ),

            // Center Digital Readout (speed + unit + SPD label)
            Positioned(
              bottom: widget.size * 0.17,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    speedDisplayStr,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: widget.size * 0.135,
                      fontWeight: FontWeight.w900,
                      color: isManual ? const Color(0xFFFFB300) : const Color(0xFF00F2FE),
                      height: 1.0,
                      shadows: [
                        Shadow(
                          color: (isManual ? const Color(0xFFFFB300) : const Color(0xFF00F2FE)).withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isManual ? 'MANUAL' : widget.unit.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: widget.size * 0.065,
                      fontWeight: FontWeight.bold,
                      color: isManual
                          ? const Color(0xFFFFB300).withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.75),
                      height: 1.0,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // SPD label sits below unit — never on top of tick marks
                  Text(
                    'SPD',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: widget.size * 0.068,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFB300),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Tap-to-set hint icon (very bottom)
            Positioned(
              bottom: widget.size * 0.055,
              child: Icon(
                isManual ? Icons.edit : Icons.touch_app,
                size: widget.size * 0.08,
                color: isManual
                    ? const Color(0xFFFFB300).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  _SpeedometerPainter({
    required this.speed,
    required this.minSpeed,
    required this.maxSpeed,
  });

  final double speed;
  final double minSpeed;
  final double maxSpeed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Translucent Face Background
    final bgPaint = Paint()
      ..color = const Color(0x66070E17)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 2, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 2, borderPaint);

    // Arc sweep: 260° from bottom-left to bottom-right
    const startAngle = 140.0 * math.pi / 180.0;
    const totalSweep = 260.0 * math.pi / 180.0;

    // 2. Colored Scale Track Arcs
    final trackRect = Rect.fromCircle(center: center, radius: radius - 10);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // Green zone 60–100 (29% of range 60-200)
    arcPaint.color = const Color(0xFF00E676);
    canvas.drawArc(trackRect, startAngle, totalSweep * 0.29, false, arcPaint);

    // Amber zone 100–160 (42% of range)
    arcPaint.color = const Color(0xFFFFB300);
    canvas.drawArc(trackRect, startAngle + totalSweep * 0.29, totalSweep * 0.43, false, arcPaint);

    // Red zone 160–200 (29% of range)
    arcPaint.color = const Color(0xFFFF1744);
    canvas.drawArc(trackRect, startAngle + totalSweep * 0.72, totalSweep * 0.28, false, arcPaint);

    // 3. Ticks and Number Labels — steps: 60, 80, 100, 120, 140, 160, 180, 200
    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final range = maxSpeed - minSpeed; // 140
    final steps = [60, 80, 100, 120, 140, 160, 180, 200];

    for (final val in steps) {
      final fraction = (val - minSpeed) / range;
      final angle = startAngle + fraction * totalSweep;

      // Major tick line
      final isMajor = (val % 40 == 0); // 80, 120, 160, 200
      final tickLen = isMajor ? 12.0 : 8.0;
      final p1 = Offset(
        center.dx + (radius - tickLen - 4) * math.cos(angle),
        center.dy + (radius - tickLen - 4) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 5) * math.cos(angle),
        center.dy + (radius - 5) * math.sin(angle),
      );
      tickPaint.color = Colors.white.withValues(alpha: isMajor ? 1.0 : 0.7);
      tickPaint.strokeWidth = isMajor ? 2.5 : 1.5;
      canvas.drawLine(p1, p2, tickPaint);

      // Number Labels — larger font
      textPainter.text = TextSpan(
        text: '$val',
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: isMajor ? 12.0 : 10.0,
          fontWeight: isMajor ? FontWeight.bold : FontWeight.w500,
        ),
      );
      textPainter.layout();
      final textDist = radius - 26;
      final textPos = Offset(
        center.dx + textDist * math.cos(angle) - textPainter.width / 2,
        center.dy + textDist * math.sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, textPos);
    }

    // Minor ticks every 10 m/s between major steps
    for (int v = 60; v < 200; v += 10) {
      if (steps.contains(v)) continue;
      final fraction = (v - minSpeed) / range;
      final angle = startAngle + fraction * totalSweep;
      final p1 = Offset(
        center.dx + (radius - 8) * math.cos(angle),
        center.dy + (radius - 8) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 4) * math.cos(angle),
        center.dy + (radius - 4) * math.sin(angle),
      );
      tickPaint.color = Colors.white.withValues(alpha: 0.3);
      tickPaint.strokeWidth = 1.0;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 4. Dynamic Needle
    final speedFraction = ((speed - minSpeed) / range).clamp(0.0, 1.0);
    final needleAngle = startAngle + speedFraction * totalSweep;
    final needleLength = radius - 18;
    final needleTip = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );

    // Needle glow
    final needleGlowPaint = Paint()
      ..color = const Color(0xFF00F2FE).withValues(alpha: 0.35)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needleGlowPaint);

    // Needle solid
    final needlePaint = Paint()
      ..color = const Color(0xFF00F2FE)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needlePaint);

    // Center Hub Cap
    canvas.drawCircle(center, 6.0, Paint()..color = const Color(0xFF00F2FE));
    canvas.drawCircle(center, 6.0, Paint()
      ..color = const Color(0xFF0D1B2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0);
    canvas.drawCircle(center, 3.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.minSpeed != minSpeed ||
        oldDelegate.maxSpeed != maxSpeed;
  }
}
