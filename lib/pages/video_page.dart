import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class VideoPage extends ConsumerStatefulWidget {
  const VideoPage({super.key});

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage>
    with SingleTickerProviderStateMixin {
  int _activeStream = 0;
  late AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  static const _streams = [
    {'name': 'Alpha-1 / Camera 1', 'quality': '1080p', 'fps': '30'},
    {'name': 'Beta-2 / FPV', 'quality': '720p', 'fps': '60'},
    {'name': 'Gamma-3 / IR', 'quality': '480p', 'fps': '25'},
    {'name': 'Alpha-1 / Camera 2', 'quality': '4K', 'fps': '24'},
  ];

  @override
  Widget build(BuildContext context) {
    final gcs = context.gcs;

    return Container(
      color: gcs.bg,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  bottom:
                      BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Row(children: [
              Icon(LucideIcons.video, size: 16, color: gcs.accent),
              const SizedBox(width: 8),
              Text('VIDEO STREAMS',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: gcs.accent,
                  )),
              const Spacer(),
              Text('${_streams.length} FEEDS ACTIVE',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    color: gcs.success,
                  )),
            ]),
          ),

          Expanded(
            child: Row(
              children: [
                // Main active stream
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: gcs.accent.withValues(alpha: 0.2)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CustomPaint(
                                painter: _CameraFeedPainter(
                                  animation: _scanCtrl,
                                  label: _streams[_activeStream]['name']!,
                                  quality: _streams[_activeStream]['quality']!,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      color: AppColors.danger,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              const Text('LIVE',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 9,
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Text(_streams[_activeStream]['name']!,
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                color: gcs.text,
                              )),
                          const Spacer(),
                          Text(
                              '${_streams[_activeStream]['quality']} @ ${_streams[_activeStream]['fps']}fps',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                color: gcs.secText,
                              )),
                        ]),
                      ],
                    ),
                  ),
                ),

                // Stream selector panel
                SizedBox(
                  width: 200,
                  child: Container(
                    decoration: BoxDecoration(
                      color: gcs.panels,
                      border: Border(
                          left: BorderSide(
                              color: gcs.accent.withValues(alpha: 0.15))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('STREAM SELECT',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                color: gcs.secText,
                                letterSpacing: 1.5,
                              )),
                        ),
                        ...List.generate(_streams.length, (i) {
                          final isActive = i == _activeStream;
                          return GestureDetector(
                            onTap: () => setState(() => _activeStream = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? gcs.accent.withValues(alpha: 0.1)
                                    : gcs.bg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: isActive
                                        ? gcs.accent
                                        : gcs.accent.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(LucideIcons.video,
                                        size: 12,
                                        color: isActive
                                            ? gcs.accent
                                            : gcs.secText),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Text(_streams[i]['name']!,
                                            style: TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 9,
                                              color: isActive
                                                  ? gcs.accent
                                                  : gcs.text,
                                              fontWeight: isActive
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${_streams[i]['quality']} · ${_streams[i]['fps']}fps',
                                      style: TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 8,
                                        color: gcs.secText,
                                      )),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraFeedPainter extends CustomPainter {
  const _CameraFeedPainter({
    required this.animation,
    required this.label,
    required this.quality,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final String label, quality;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;

    // Dark background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0A0E18));

    // Grid lines (faint)
    final gridPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 8; i++) {
      canvas.drawLine(Offset(size.width / 8 * i, 0),
          Offset(size.width / 8 * i, size.height), gridPaint);
    }
    for (int i = 1; i < 6; i++) {
      canvas.drawLine(Offset(0, size.height / 6 * i),
          Offset(size.width, size.height / 6 * i), gridPaint);
    }

    // Scan line
    final scanY = size.height * t;
    final scanPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.15)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), scanPaint);

    // Center crosshair
    final cx = size.width / 2;
    final cy = size.height / 2;
    final crossPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx - 30, cy), Offset(cx - 10, cy), crossPaint);
    canvas.drawLine(Offset(cx + 10, cy), Offset(cx + 30, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - 30), Offset(cx, cy - 10), crossPaint);
    canvas.drawLine(Offset(cx, cy + 10), Offset(cx, cy + 30), crossPaint);

    // Corner brackets
    final bracketPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const m = 16.0;
    const l = 20.0;
    // TL
    canvas.drawLine(const Offset(m, m), const Offset(m + l, m), bracketPaint);
    canvas.drawLine(const Offset(m, m), const Offset(m, m + l), bracketPaint);
    // TR
    canvas.drawLine(
        Offset(size.width - m, m), Offset(size.width - m - l, m), bracketPaint);
    canvas.drawLine(
        Offset(size.width - m, m), Offset(size.width - m, m + l), bracketPaint);
    // BL
    canvas.drawLine(Offset(m, size.height - m), Offset(m + l, size.height - m),
        bracketPaint);
    canvas.drawLine(Offset(m, size.height - m), Offset(m, size.height - m - l),
        bracketPaint);
    // BR
    canvas.drawLine(Offset(size.width - m, size.height - m),
        Offset(size.width - m - l, size.height - m), bracketPaint);
    canvas.drawLine(Offset(size.width - m, size.height - m),
        Offset(size.width - m, size.height - m - l), bracketPaint);

    // No-signal text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'NO SIGNAL\n$label\n$quality',
        style: const TextStyle(
          fontFamily: 'Courier',
          fontSize: 14,
          color: Color(0x5500D4FF),
          height: 1.6,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(_CameraFeedPainter old) => true;
}
