import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/models/models.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/hud/hud_glass_card.dart';

class MotorTestPage extends ConsumerStatefulWidget {
  const MotorTestPage({super.key});

  @override
  ConsumerState<MotorTestPage> createState() => _MotorTestPageState();
}

class _MotorTestPageState extends ConsumerState<MotorTestPage> {
  bool _safetyPropsRemoved = false;
  double _throttlePercent = 10.0;
  int _durationSec = 2;
  String _selectedFrame = 'Quad X';

  void _onMotorTestClick(int motorIndex) {
    if (!_safetyPropsRemoved) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(LucideIcons.triangleAlert, color: Colors.black, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SAFETY LOCKED: Please check the "Props Removed" box at top right first!',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.tacticalAmber,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final labels = ['A', 'B', 'C', 'D'];
    final label = motorIndex >= 1 && motorIndex <= 4 ? labels[motorIndex - 1] : '$motorIndex';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚡ COMMAND SENT: Spinning Motor $label at ${_throttlePercent.round()}% for ${_durationSec}s',
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: AppColors.tacticalCyan,
        duration: Duration(seconds: _durationSec),
      ),
    );
    ref.read(gcsProvider.notifier).testMotor(
          motorIndex: motorIndex,
          throttlePercent: _throttlePercent,
          durationSec: _durationSec,
        );
  }

  void _onTestAllTogetherClick() {
    if (!_safetyPropsRemoved) {
      _onMotorTestClick(1);
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚡ COMMAND SENT: Spinning ALL 4 Motors Together at ${_throttlePercent.round()}% for ${_durationSec}s',
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: AppColors.tacticalCyan,
        duration: Duration(seconds: _durationSec),
      ),
    );
    ref.read(gcsProvider.notifier).testAllMotorsTogether(
          throttlePercent: _throttlePercent,
          durationSec: _durationSec,
        );
  }

  void _onTestSequenceClick() {
    if (!_safetyPropsRemoved) {
      _onMotorTestClick(1);
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '⚡ COMMAND SENT: Running Motor Sequence A → B → C → D',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: AppColors.tacticalGreen,
        duration: Duration(seconds: 3),
      ),
    );
    ref.read(gcsProvider.notifier).testAllMotors(
          throttlePercent: _throttlePercent,
          durationSec: _durationSec,
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final drone = s.drones.isNotEmpty
        ? s.drones.firstWhere((d) => d.id == s.selectedDroneId,
            orElse: () => s.drones.first)
        : null;

    return Container(
      color: gcs.bg,
      child: Column(
        children: [
          // ── 1. HEADER BAR ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.tacticalCyan.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.fan, size: 18, color: AppColors.tacticalCyan),
                const SizedBox(width: 10),
                const Text(
                  'MOTOR TEST & ESC CALIBRATION',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.tacticalCyan,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                // Vehicle Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.glassPanel,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.plane, size: 12, color: AppColors.textSecond),
                      const SizedBox(width: 6),
                      Text(
                        drone?.name ?? 'VEHICLE D1',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // ESC Protocol Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.glassPanel,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.tacticalGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'DSHOT600 • 400Hz',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.tacticalGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 2. SAFETY WARNING BANNER ──
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _safetyPropsRemoved
                  ? AppColors.tacticalGreen.withValues(alpha: 0.1)
                  : AppColors.tacticalAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _safetyPropsRemoved
                    ? AppColors.tacticalGreen
                    : AppColors.tacticalAmber,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _safetyPropsRemoved
                      ? LucideIcons.shieldCheck
                      : LucideIcons.triangleAlert,
                  color: _safetyPropsRemoved
                      ? AppColors.tacticalGreen
                      : AppColors.tacticalAmber,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _safetyPropsRemoved
                            ? 'SAFETY CHECKLIST CONFIRMED'
                            : 'SAFETY WARNING: PROPELLERS MUST BE REMOVED!',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _safetyPropsRemoved
                              ? AppColors.tacticalGreen
                              : AppColors.tacticalAmber,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _safetyPropsRemoved
                            ? 'Motor outputs are armed for testing. Maintain safe distance from vehicle frame.'
                            : 'Disconnect battery or remove all propellers prior to spinning motors to prevent accidental injury.',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9.5,
                          color: AppColors.textSecond,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Safety Checkbox Toggle
                InkWell(
                  onTap: () => setState(() => _safetyPropsRemoved = !_safetyPropsRemoved),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _safetyPropsRemoved,
                        activeColor: AppColors.tacticalGreen,
                        onChanged: (val) =>
                            setState(() => _safetyPropsRemoved = val ?? false),
                      ),
                      const Text(
                        'Props Removed',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 3. MAIN WORKSPACE CONTENT ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── LEFT: 2D FRAME SCHEMATIC VISUALIZER ──
                  Expanded(
                    flex: 5,
                    child: HudGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '2D FRAME MOTOR LAYOUT',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.tacticalCyan,
                                ),
                              ),
                              // Frame Selector Dropdown
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.glassPanel,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.glassBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedFrame,
                                    dropdownColor: AppColors.glassBg,
                                    style: const TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 10,
                                      color: Colors.white,
                                    ),
                                    items: ['Quad X', 'Quad +', 'Hexa X', 'Octo X', 'VTOL']
                                        .map((f) => DropdownMenuItem(
                                              value: f,
                                              child: Text(f),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedFrame = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Canvas 2D Motor Frame Representation
                          Expanded(
                            child: Center(
                              child: CustomPaint(
                                size: const Size(320, 320),
                                painter: _FrameSchematicPainter(
                                  drone: drone,
                                  frameType: _selectedFrame,
                                ),
                              ),
                            ),
                          ),
                          // Frame Motor Spin Legend
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 6,
                            children: const [
                              _LegendDot(
                                color: AppColors.tacticalCyan,
                                label: 'Motor 1 / A (CCW)',
                              ),
                              _LegendDot(
                                color: AppColors.tacticalGreen,
                                label: 'Motor 2 / B (CW)',
                              ),
                              _LegendDot(
                                color: AppColors.tacticalAmber,
                                label: 'Motor 3 / C (CCW)',
                              ),
                              _LegendDot(
                                color: AppColors.tacticalRed,
                                label: 'Motor 4 / D (CW)',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // ── CENTER: MOTOR TEST CONTROLS & SLIDERS ──
                  Expanded(
                    flex: 4,
                    child: HudGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MOTOR CONTROL PANEL',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.tacticalCyan,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Safety Throttle Slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TEST THROTTLE LEVEL',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  color: AppColors.textSecond,
                                ),
                              ),
                              Text(
                                '${_throttlePercent.round()}%',
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.tacticalCyan,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _throttlePercent,
                            min: 5.0,
                            max: 50.0,
                            divisions: 45,
                            activeColor: AppColors.tacticalCyan,
                            inactiveColor: AppColors.glassPanel,
                            onChanged: _safetyPropsRemoved
                                ? (v) => setState(() => _throttlePercent = v)
                                : null,
                          ),

                          const SizedBox(height: 10),

                          // Duration Slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TEST DURATION (SECONDS)',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  color: AppColors.textSecond,
                                ),
                              ),
                              Text(
                                '${_durationSec}s',
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _durationSec.toDouble(),
                            min: 1.0,
                            max: 10.0,
                            divisions: 9,
                            activeColor: AppColors.tacticalGreen,
                            inactiveColor: AppColors.glassPanel,
                            onChanged: _safetyPropsRemoved
                                ? (v) => setState(() => _durationSec = v.round())
                                : null,
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: AppColors.glassBorder),
                          const SizedBox(height: 10),

                          // Individual Motor Action Grid
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'INDIVIDUAL MOTOR TESTS (ONE BY ONE)',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.tacticalCyan,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _safetyPropsRemoved
                                    ? 'TAP ANY MOTOR TO TEST'
                                    : 'SAFETY LOCKED',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 8.5,
                                  color: _safetyPropsRemoved
                                      ? AppColors.tacticalGreen
                                      : AppColors.tacticalAmber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          GridView(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 54,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _MotorTestBtn(
                                label: 'TEST MOTOR A',
                                subLabel: 'Motor 1 • Top Right (CCW)',
                                color: AppColors.tacticalCyan,
                                enabled: true,
                                isSpinning: (drone?.motor1Rpm ?? 0) > 0,
                                rpm: drone?.motor1Rpm ?? 0,
                                onPressed: () => _onMotorTestClick(1),
                              ),
                              _MotorTestBtn(
                                label: 'TEST MOTOR B',
                                subLabel: 'Motor 2 • Bottom Right (CW)',
                                color: AppColors.tacticalGreen,
                                enabled: true,
                                isSpinning: (drone?.motor2Rpm ?? 0) > 0,
                                rpm: drone?.motor2Rpm ?? 0,
                                onPressed: () => _onMotorTestClick(2),
                              ),
                              _MotorTestBtn(
                                label: 'TEST MOTOR C',
                                subLabel: 'Motor 3 • Bottom Left (CCW)',
                                color: AppColors.tacticalAmber,
                                enabled: true,
                                isSpinning: (drone?.motor3Rpm ?? 0) > 0,
                                rpm: drone?.motor3Rpm ?? 0,
                                onPressed: () => _onMotorTestClick(3),
                              ),
                              _MotorTestBtn(
                                label: 'TEST MOTOR D',
                                subLabel: 'Motor 4 • Top Left (CW)',
                                color: AppColors.tacticalRed,
                                enabled: true,
                                isSpinning: (drone?.motor4Rpm ?? 0) > 0,
                                rpm: drone?.motor4Rpm ?? 0,
                                onPressed: () => _onMotorTestClick(4),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // SPIN ALL 4 MOTORS TOGETHER (Simultaneous Action Button)
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.tacticalCyan,
                                foregroundColor: Colors.black,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(LucideIcons.fan, size: 16),
                              label: const Text(
                                'SPIN ALL 4 MOTORS TOGETHER (SIMULTANEOUS)',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              onPressed: _onTestAllTogetherClick,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // TEST MOTORS IN SEQUENCE (A -> B -> C -> D)
                          SizedBox(
                            width: double.infinity,
                            height: 34,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _safetyPropsRemoved
                                      ? AppColors.tacticalGreen
                                      : AppColors.glassBorder,
                                ),
                                foregroundColor: _safetyPropsRemoved
                                    ? AppColors.tacticalGreen
                                    : AppColors.textSecond,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(LucideIcons.play, size: 14),
                              label: const Text(
                                'TEST IN SEQUENCE (A → B → C → D)',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _onTestSequenceClick,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Emergency Stop All Motors Kill Switch
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.tacticalRed,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(LucideIcons.octagonAlert, size: 16),
                              label: const Text(
                                'EMERGENCY STOP ALL MOTORS',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              onPressed: () => ref
                                  .read(gcsProvider.notifier)
                                  .emergencyStopAllMotors(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // ── RIGHT: LIVE RPM & ESC TELEMETRY ──
                  Expanded(
                    flex: 3,
                    child: HudGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LIVE ESC & RPM TELEMETRY',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.tacticalCyan,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _RpmProgressCard(
                            label: 'MOTOR 1 (A)',
                            rpm: drone?.motor1Rpm ?? 0,
                            color: AppColors.tacticalCyan,
                          ),
                          const SizedBox(height: 12),
                          _RpmProgressCard(
                            label: 'MOTOR 2 (B)',
                            rpm: drone?.motor2Rpm ?? 0,
                            color: AppColors.tacticalGreen,
                          ),
                          const SizedBox(height: 12),
                          _RpmProgressCard(
                            label: 'MOTOR 3 (C)',
                            rpm: drone?.motor3Rpm ?? 0,
                            color: AppColors.tacticalAmber,
                          ),
                          const SizedBox(height: 12),
                          _RpmProgressCard(
                            label: 'MOTOR 4 (D)',
                            rpm: drone?.motor4Rpm ?? 0,
                            color: AppColors.tacticalRed,
                          ),

                          const Spacer(),
                          const Divider(color: AppColors.glassBorder),
                          const SizedBox(height: 10),

                          // ESC Status Metrics
                          _EscMetricRow(
                            label: 'ESC VOLTAGE',
                            value: '${(drone?.voltage ?? 22.2).toStringAsFixed(1)} V',
                          ),
                          const SizedBox(height: 6),
                          _EscMetricRow(
                            label: 'ESC TOTAL CURRENT',
                            value: '${(drone?.current ?? 18.5).toStringAsFixed(1)} A',
                          ),
                          const SizedBox(height: 6),
                          _EscMetricRow(
                            label: 'ESC TEMPERATURE',
                            value: '34.2 °C',
                          ),
                          const SizedBox(height: 6),
                          _EscMetricRow(
                            label: 'PWM SIGNAL FREQ',
                            value: '400 Hz',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 2D FRAME SCHEMATIC CUSTOM PAINTER
// ─────────────────────────────────────────────
class _FrameSchematicPainter extends CustomPainter {
  _FrameSchematicPainter({
    required this.drone,
    required this.frameType,
  });

  final DroneModel? drone;
  final String frameType;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final armLen = size.width * 0.34;

    final armPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final centerPaint = Paint()
      ..color = AppColors.glassPanel
      ..style = PaintingStyle.fill;

    final centerBorder = Paint()
      ..color = AppColors.tacticalCyan
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw Central Drone Hub
    canvas.drawCircle(center, 28, centerPaint);
    canvas.drawCircle(center, 28, centerBorder);

    // Forward Direction Arrow Indicator
    final arrowPath = Path()
      ..moveTo(center.dx, center.dy - 18)
      ..lineTo(center.dx - 8, center.dy - 6)
      ..lineTo(center.dx + 8, center.dy - 6)
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = AppColors.tacticalCyan);

    // Motor Offsets (Quad X default)
    final motorPositions = [
      Offset(center.dx + armLen * 0.707, center.dy - armLen * 0.707), // M1: Top Right
      Offset(center.dx + armLen * 0.707, center.dy + armLen * 0.707), // M2: Bottom Right
      Offset(center.dx - armLen * 0.707, center.dy + armLen * 0.707), // M3: Bottom Left
      Offset(center.dx - armLen * 0.707, center.dy - armLen * 0.707), // M4: Top Left
    ];

    final motorColors = [
      AppColors.tacticalCyan,
      AppColors.tacticalGreen,
      AppColors.tacticalAmber,
      AppColors.tacticalRed,
    ];

    final rpms = [
      drone?.motor1Rpm ?? 0,
      drone?.motor2Rpm ?? 0,
      drone?.motor3Rpm ?? 0,
      drone?.motor4Rpm ?? 0,
    ];

    // Draw Arms & Motors
    for (int i = 0; i < 4; i++) {
      final pos = motorPositions[i];
      final color = motorColors[i];
      final rpm = rpms[i];

      // Draw Arm Line
      canvas.drawLine(center, pos, armPaint);

      // Spinning pulse animation glow if active
      if (rpm > 0) {
        canvas.drawCircle(
          pos,
          26,
          Paint()..color = color.withValues(alpha: 0.35),
        );
      }

      // Motor Circle Node
      canvas.drawCircle(pos, 18, Paint()..color = AppColors.glassBg);
      canvas.drawCircle(
        pos,
        18,
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );

      // Spin Direction Arrow (CCW for 1 & 3, CW for 2 & 4)
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      final label = 'M${i + 1}';
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FrameSchematicPainter oldDelegate) => true;
}

class _MotorTestBtn extends StatelessWidget {
  const _MotorTestBtn({
    required this.label,
    required this.subLabel,
    required this.color,
    required this.enabled,
    required this.isSpinning,
    required this.rpm,
    required this.onPressed,
  });

  final String label;
  final String subLabel;
  final Color color;
  final bool enabled;
  final bool isSpinning;
  final int rpm;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isSpinning ? color.withValues(alpha: 0.28) : AppColors.glassPanel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSpinning
                ? color
                : (enabled ? color.withValues(alpha: 0.7) : color.withValues(alpha: 0.2)),
            width: isSpinning ? 2.0 : 1.2,
          ),
          boxShadow: isSpinning
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 10,
                  )
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          splashColor: color.withValues(alpha: 0.3),
          highlightColor: color.withValues(alpha: 0.15),
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isSpinning ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: enabled ? color : AppColors.textSecond, width: 1.5),
                  ),
                  child: Icon(
                    LucideIcons.fan,
                    size: 13,
                    color: isSpinning
                        ? Colors.black
                        : (enabled ? color : AppColors.textSecond),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: enabled
                                    ? (isSpinning ? Colors.white : color)
                                    : AppColors.textSecond,
                              ),
                            ),
                          ),
                          if (isSpinning) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$rpm RPM',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSpinning ? 'SPINNING ACTIVE...' : subLabel,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 7.5,
                          fontWeight:
                              isSpinning ? FontWeight.bold : FontWeight.normal,
                          color: isSpinning
                              ? AppColors.tacticalGreen
                              : AppColors.textSecond,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RpmProgressCard extends StatelessWidget {
  const _RpmProgressCard({
    required this.label,
    required this.rpm,
    required this.color,
  });

  final String label;
  final int rpm;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (rpm / 9600.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.glassPanel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: rpm > 0 ? color : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '$rpm RPM',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: rpm > 0 ? Colors.white : AppColors.textSecond,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EscMetricRow extends StatelessWidget {
  const _EscMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9.5,
            color: AppColors.textSecond,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9,
            color: AppColors.textSecond,
          ),
        ),
      ],
    );
  }
}
