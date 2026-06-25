import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class GcsStatusBar extends ConsumerStatefulWidget {
  const GcsStatusBar({super.key});

  @override
  ConsumerState<GcsStatusBar> createState() => _GcsStatusBarState();
}

class _GcsStatusBarState extends ConsumerState<GcsStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 1.0).animate(_pulseCtrl);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final drone = s.drones.isNotEmpty ? s.drones.first : null;
    final activeCount = s.drones.where((d) => d.flightMode != 'Standby').length;

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
          // ── Left: Logo + Status Pills ──
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLogo(gcs),
                  const SizedBox(width: 20),
                  _buildConnectionPill(s.connectionStatus, gcs),
                  const SizedBox(width: 8),
                  _buildPill('GPS:', '3D FIX', AppColors.success, gcs),
                  const SizedBox(width: 8),
                  _buildEncryptionPill(s.encryption, gcs),
                  const SizedBox(width: 8),
                  _buildPill(
                    '${s.drones.length} FLEET',
                    '($activeCount ACT)',
                    gcs.accent,
                    gcs,
                  ),
                ],
              ),
            ),
          ),

          // ── Right: CONFLICT + WEATHER + THEME TOGGLE + CLOCK ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildConflictButton(gcs),
              const SizedBox(width: 8),
              _buildWeatherButton(drone, gcs),
              const SizedBox(width: 8),
              _buildThemeToggle(s.themeMode, ref, gcs),
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
                text: 'WINGSPAN ',
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

  Widget _buildConnectionPill(String status, GcsThemeExtension gcs) {
    Color color;
    String label;
    Widget indicator;

    if (status == 'Connected') {
      color = gcs.success;
      label = 'CONNECTED';
      indicator = AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Opacity(
          opacity: _pulse.value,
          child: Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: gcs.success, shape: BoxShape.circle),
          ),
        ),
      );
    } else if (status == 'Connecting') {
      color = gcs.warning;
      label = 'CONNECTING';
      indicator = SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: gcs.warning),
      );
    } else {
      color = gcs.secText;
      label = 'DISCONNECTED';
      indicator = Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: gcs.danger, shape: BoxShape.circle),
      );
    }

    return _pill(
      child: Row(children: [
        indicator,
        const SizedBox(width: 4),
        Text(label, style: _monoStyle(color, 10)),
      ]),
      gcs: gcs,
    );
  }

  Widget _buildPill(
      String label, String value, Color valueColor, GcsThemeExtension gcs) {
    return _pill(
      child: Row(children: [
        Text(label, style: _monoStyle(gcs.accent, 10)),
        const SizedBox(width: 3),
        Text(value, style: _monoStyle(valueColor, 10, bold: true)),
      ]),
      gcs: gcs,
    );
  }

  Widget _buildEncryptionPill(bool enc, GcsThemeExtension gcs) {
    return _pill(
      child: Row(children: [
        Icon(
          enc ? LucideIcons.lock : LucideIcons.unlock,
          size: 10,
          color: enc ? gcs.success : gcs.danger,
        ),
        const SizedBox(width: 4),
        Text(
          enc ? 'AES-256' : 'UNENCRYPTED',
          style: _monoStyle(enc ? gcs.secText : gcs.danger, 10),
        ),
      ]),
      gcs: gcs,
    );
  }

  Widget _buildConflictButton(GcsThemeExtension gcs) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => GestureDetector(
        onTap: () {},
        child: Opacity(
          opacity: 0.6 + _pulse.value * 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: gcs.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: gcs.danger),
            ),
            child: Row(children: [
              Icon(LucideIcons.alertTriangle, size: 10, color: gcs.danger),
              const SizedBox(width: 4),
              Text('CONFLICT', style: _monoStyle(gcs.danger, 10)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherButton(drone, GcsThemeExtension gcs) {
    final loc = drone != null
        ? '${drone.lat.toStringAsFixed(4)}°N, ${drone.lng.toStringAsFixed(4)}°E'
        : '28.6139°N, 77.2090°E';
    return _pillButton(
      onTap: () {},
      child: Row(children: [
        Icon(LucideIcons.cloudSun, size: 10, color: gcs.warning),
        const SizedBox(width: 4),
        Text('28°C | $loc', style: _monoStyle(gcs.secText, 10)),
      ]),
      gcs: gcs,
    );
  }

  Widget _buildThemeToggle(String mode, WidgetRef ref, GcsThemeExtension gcs) {
    final isDark = mode == 'dark';
    return _pillButton(
      onTap: () => ref
          .read(gcsProvider.notifier)
          .setThemeMode(isDark ? 'light' : 'dark'),
      child: Row(children: [
        Icon(
          isDark ? LucideIcons.sun : LucideIcons.moon,
          size: 10,
          color: isDark ? gcs.warning : gcs.accent,
        ),
        const SizedBox(width: 4),
        Text(
          isDark ? 'DAY' : 'NIGHT',
          style: _monoStyle(gcs.secText, 10),
        ),
      ]),
      gcs: gcs,
    );
  }

  Widget _buildClock(String time, GcsThemeExtension gcs) {
    return SizedBox(
      width: 90,
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

  Widget _pill({required Widget child, required GcsThemeExtension gcs}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: gcs.panels,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.1)),
      ),
      child: child,
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

// Custom painter for the WINGSPAN logo triangle
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
