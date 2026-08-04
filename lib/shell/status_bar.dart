import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/store/gcs_notifier.dart';
import '../core/store/weather_provider.dart';
import '../core/widgets/weather_dialog.dart';
import '../core/theme/app_theme.dart';

class GcsStatusBar extends ConsumerWidget {
  const GcsStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final drone = s.drones.isNotEmpty ? s.drones.first : null;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: gcs.panels,
        border: Border(
            bottom: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Left: Logo only ──
          _buildLogo(gcs),

          const Spacer(),

          // ── Right: WEATHER + CLOCK ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildWeatherButton(context, ref, drone, gcs),
              const SizedBox(width: 12),
              Container(
                width: 1,
                height: 20,
                color: gcs.secText.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 12),
              _buildClock(s.utcTime, gcs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(GcsThemeExtension gcs) {
    return Row(
      children: [
        CustomPaint(
          size: const Size(18, 18),
          painter: _LogoPainter(color: gcs.accent),
        ),
        const SizedBox(width: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'WINGSPANN ',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: gcs.text,
                ),
              ),
              TextSpan(
                text: 'GCS',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: gcs.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherButton(BuildContext context, WidgetRef ref, drone, GcsThemeExtension gcs) {
    final weather = ref.watch(weatherProvider);
    final lat = drone?.lat ?? 28.6139;
    final lng = drone?.lng ?? 77.2090;

    return _pillButton(
      onTap: () => showWeatherDialog(context, lat, lng),
      child: Row(children: [
        Icon(weather.icon, size: 10, color: gcs.warning),
        const SizedBox(width: 4),
        Text('${weather.temperature.toStringAsFixed(0)}°C | ${weather.locationName}',
            style: _monoStyle(gcs.secText, 10)),
      ]),
      gcs: gcs,
    );
  }


  Widget _buildClock(String time, GcsThemeExtension gcs) {
    return SizedBox(
      width: 100,
      child: Text(
        time,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: gcs.text,
        ),
      ),
    );
  }

  Widget _pillButton({
    required VoidCallback onTap,
    required Widget child,
    required GcsThemeExtension gcs,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: gcs.panels,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: gcs.accent.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  TextStyle _monoStyle(Color color, double size, {bool bold = false}) {
    return TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: size,
      color: color,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      letterSpacing: 0.5,
    );
  }
}

// Custom painter for the WINGSPANN logo triangle
class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Triangle: M2 22 L12 2 L22 22
    final path = Path()
      ..moveTo(w * 0.08, h * 0.92)
      ..lineTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.92, h * 0.92)
      ..moveTo(w * 0.5, h * 0.08) // vertical center line
      ..lineTo(w * 0.5, h * 0.92)
      ..moveTo(w * 0.08, h * 0.92) // base
      ..lineTo(w * 0.92, h * 0.92);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}
