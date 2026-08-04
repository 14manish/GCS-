import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/models/map_providers.dart';
import '../core/widgets/map_provider_selector.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/hud/hud_glass_card.dart';

class SimulationPage extends ConsumerStatefulWidget {
  const SimulationPage({super.key});

  @override
  ConsumerState<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends ConsumerState<SimulationPage> {
  final _mapController = MapController();
  final _scrollController = ScrollController();

  bool _showConsole = false;
  int _heading = 0;
  String _version = 'Latest (Dev)';
  String _selectedModel = 'Quad';
  String _extraCmdLine = '';
  bool _wipeEeprom = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final notifier = ref.read(gcsProvider.notifier);

    final homeLatLng = LatLng(
      s.simHome['lat'] ?? 28.6139,
      s.simHome['lng'] ?? 77.2090,
    );

    return Container(
      color: gcs.bg,
      child: Stack(
        children: [
          // ─── 1. FULL-BLEED SATELLITE MAP ───
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: homeLatLng,
                initialZoom: 14,
                onTap: (_, latlng) {
                  notifier.setSimConfig({
                    'simHome': {
                      'lat': latlng.latitude,
                      'lng': latlng.longitude,
                    },
                  });
                  notifier.addSimLog(
                    'Home set: ${latlng.latitude.toStringAsFixed(6)}, ${latlng.longitude.toStringAsFixed(6)}',
                  );
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: MapProviders.get(s.mapProvider).urlTemplate,
                  subdomains: MapProviders.get(s.mapProvider).subdomains,
                ),
                // Home Marker Layer with "Home Location - Drag Me" Pin
                MarkerLayer(
                  markers: [
                    Marker(
                      point: homeLatLng,
                      width: 140,
                      height: 60,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.glassBg,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: AppColors.tacticalGreen,
                                width: 1.2,
                              ),
                            ),
                            child: const Text(
                              'Home Location - Drag Me',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.tacticalGreen,
                              ),
                            ),
                          ),
                          const Icon(
                            LucideIcons.mapPin,
                            size: 26,
                            color: AppColors.tacticalGreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── 2. TOP OVERLAY TOOLBAR ───
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // Top Left Title Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.glassBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.gamepad2,
                          size: 16, color: AppColors.tacticalCyan),
                      const SizedBox(width: 8),
                      const Text(
                        'SITL SIMULATION CONTROL',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tacticalCyan,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.simStatus == 'running'
                              ? AppColors.tacticalGreen.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: s.simStatus == 'running'
                                ? AppColors.tacticalGreen
                                : AppColors.glassBorder,
                          ),
                        ),
                        child: Text(
                          s.simStatus.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: s.simStatus == 'running'
                                ? AppColors.tacticalGreen
                                : AppColors.textSecond,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Map Layers Selector Button
                GestureDetector(
                  onTap: () => showMapProviderSelector(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.glassBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.layers,
                            size: 14, color: AppColors.tacticalCyan),
                        SizedBox(width: 6),
                        Text(
                          'MAP LAYERS',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tacticalCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Console Drawer Toggle Button
                GestureDetector(
                  onTap: () => setState(() => _showConsole = !_showConsole),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showConsole
                          ? AppColors.tacticalCyan.withValues(alpha: 0.25)
                          : AppColors.glassBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _showConsole
                            ? AppColors.tacticalCyan
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.terminal,
                            size: 14, color: AppColors.tacticalCyan),
                        SizedBox(width: 6),
                        Text(
                          'CONSOLE LOGS',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── 3. FLOATING CONSOLE LOG DRAWER (TOP RIGHT) ───
          if (_showConsole)
            Positioned(
              top: 52,
              right: 12,
              width: 340,
              height: 280,
              child: HudGlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SITL CONSOLE OUTPUT',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tacticalCyan,
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _showConsole = false),
                          child: const Icon(LucideIcons.x,
                              size: 14, color: AppColors.textSecond),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.glassBorder),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: s.simConsoleLogs.length,
                        itemBuilder: (_, i) {
                          final log = s.simConsoleLogs[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                color: log.contains('Error')
                                    ? AppColors.tacticalRed
                                    : log.contains('started')
                                        ? AppColors.tacticalGreen
                                        : Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ─── 4. BOTTOM MISSION PLANNER OPTIONS & VEHICLE DOCK ───
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: HudGlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── ROW 1: MISSION PLANNER OPTIONS & SWARM CONTROLS ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Options Box: Heading
                        _SimOptionBox(
                          label: 'Heading',
                          child: Row(
                            children: [
                              Text(
                                '$_heading°',
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => setState(
                                    () => _heading = (_heading + 45) % 360),
                                child: const Icon(LucideIcons.rotateCw,
                                    size: 12, color: AppColors.tacticalCyan),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Options Box: Sim Speed
                        _SimOptionBox(
                          label: 'Sim Speed',
                          child: Row(
                            children: [1.0, 2.0, 5.0, 10.0].map((sp) {
                              final isSelected = s.simSpeed == sp;
                              return InkWell(
                                onTap: () => notifier
                                    .setSimConfig({'simSpeed': sp}),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.tacticalCyan
                                        : AppColors.glassPanel,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '${sp.toInt()}x',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Options Box: Firmware Version
                        _SimOptionBox(
                          label: 'Version',
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _version,
                              dropdownColor: AppColors.glassBg,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                color: Colors.white,
                              ),
                              items: ['Latest (Dev)', 'Stable', 'Beta']
                                  .map((v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _version = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Options Box: Model
                        _SimOptionBox(
                          label: 'Model',
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedModel,
                              dropdownColor: AppColors.glassBg,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                color: Colors.white,
                              ),
                              items: [
                                'Quad',
                                'Hexa',
                                'Octo',
                                'Tri',
                                'VTOL',
                                'FixedWing',
                                'Rover'
                              ]
                                  .map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedModel = val);
                                }
                              },
                            ),
                          ),
                        ),
                         // Options Box: Extra command line
                        _SimOptionBox(
                          label: 'Extra command line',
                          child: SizedBox(
                            width: 110,
                            height: 20,
                            child: TextField(
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9.5,
                                color: Colors.white,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: '--wipe',
                                hintStyle: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 9,
                                  color: AppColors.textSecond,
                                ),
                              ),
                              onChanged: (val) => _extraCmdLine = val,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Wipe EEPROM Checkbox
                        Row(
                          children: [
                            Checkbox(
                              value: _wipeEeprom,
                              activeColor: AppColors.tacticalGreen,
                              onChanged: (val) =>
                                  setState(() => _wipeEeprom = val ?? false),
                            ),
                            const Text(
                              'Wipe',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                color: AppColors.textSecond,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Swarm MultiLink Presets (Mission Planner Swarm Buttons)
                        _SwarmBtn(
                          label: 'Copter Swarm - Single Link',
                          onPressed: () => notifier.addSimLog(
                              'Swarm: Copter Swarm Single Link selected'),
                        ),
                        const SizedBox(width: 6),
                        _SwarmBtn(
                          label: 'Copter Swarm - MultiLink',
                          onPressed: () => notifier.addSimLog(
                              'Swarm: Copter Swarm MultiLink selected'),
                        ),
                        const SizedBox(width: 6),
                        _SwarmBtn(
                          label: 'Plane Swarm - MultiLink',
                          onPressed: () => notifier.addSimLog(
                              'Swarm: Plane Swarm MultiLink selected'),
                        ),
                        const SizedBox(width: 6),
                        _SwarmBtn(
                          label: 'Rover Swarm - MultiLink',
                          onPressed: () => notifier.addSimLog(
                              'Swarm: Rover Swarm MultiLink selected'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Divider(color: AppColors.glassBorder, height: 1),
                  const SizedBox(height: 10),

                  // ── ROW 2: MISSION PLANNER GRAPHICAL VEHICLE DOCK ──
                  Row(
                    children: [
                      // Vehicle Card: Plane
                      Expanded(
                        child: _VehicleDockCard(
                          title: 'Plane',
                          vehicleType: 'plane',
                          isSelected: s.simFirmware == 'ArduPlane',
                          onTap: () => notifier
                              .setSimConfig({'simFirmware': 'ArduPlane'}),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Vehicle Card: Rover
                      Expanded(
                        child: _VehicleDockCard(
                          title: 'Rover',
                          vehicleType: 'rover',
                          isSelected: s.simFirmware == 'ArduRover',
                          onTap: () => notifier
                              .setSimConfig({'simFirmware': 'ArduRover'}),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Vehicle Card: Multirotor
                      Expanded(
                        child: _VehicleDockCard(
                          title: 'Multirotor',
                          vehicleType: 'multirotor',
                          isSelected: s.simFirmware == 'ArduCopter',
                          onTap: () => notifier
                              .setSimConfig({'simFirmware': 'ArduCopter'}),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Vehicle Card: Helicopter
                      Expanded(
                        child: _VehicleDockCard(
                          title: 'Helicopter',
                          vehicleType: 'helicopter',
                          isSelected: s.simFirmware == 'PX4',
                          onTap: () =>
                              notifier.setSimConfig({'simFirmware': 'PX4'}),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // START / STOP SITL SIMULATION BUTTON
                      SizedBox(
                        height: 52,
                        width: 160,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: s.simStatus == 'running'
                                ? AppColors.tacticalRed
                                : AppColors.tacticalGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          icon: Icon(
                            s.simStatus == 'running'
                                ? LucideIcons.square
                                : LucideIcons.play,
                            size: 18,
                            color: Colors.black,
                          ),
                          label: Text(
                            s.simStatus == 'running'
                                ? 'STOP SITL'
                                : 'START SITL',
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          onPressed: () {
                            if (s.simStatus == 'running') {
                              notifier.stopSimulation();
                            } else {
                              if (_extraCmdLine.isNotEmpty) {
                                notifier.addSimLog('CLI Args: $_extraCmdLine');
                              }
                              notifier.startSimulation();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimOptionBox extends StatelessWidget {
  const _SimOptionBox({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9.5,
              color: AppColors.textSecond,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SwarmBtn extends StatelessWidget {
  const _SwarmBtn({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4D7C0F), // Mission Planner Green
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _VehicleDockCard extends StatelessWidget {
  const _VehicleDockCard({
    required this.title,
    required this.vehicleType,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String vehicleType;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.tacticalCyan.withValues(alpha: 0.18)
              : const Color(0xFF1E293B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppColors.tacticalCyan
                : AppColors.glassBorder,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 54,
              height: 40,
              child: CustomPaint(
                painter: _getPainter(vehicleType, isSelected),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textSecond,
              ),
            ),
          ],
        ),
      ),
    );
  }

  CustomPainter _getPainter(String type, bool isSelected) {
    switch (type) {
      case 'plane':
        return _MpPlanePainter(isSelected: isSelected);
      case 'rover':
        return _MpRoverPainter(isSelected: isSelected);
      case 'multirotor':
        return _MpMultirotorPainter(isSelected: isSelected);
      case 'helicopter':
      default:
        return _MpHelicopterPainter(isSelected: isSelected);
    }
  }
}

// ─────────────────────────────────────────────
// MISSION PLANNER GRAPHICAL VEHICLE DRAWINGS
// ─────────────────────────────────────────────

// 1. Plane Drawing (Top View Silver Airplane)
class _MpPlanePainter extends CustomPainter {
  const _MpPlanePainter({required this.isSelected});
  final bool isSelected;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isSelected
            ? [const Color(0xFFF1F5F9), const Color(0xFF94A3B8)]
            : [const Color(0xFFCBD5E1), const Color(0xFF64748B)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(w * 0.5, 0);
    path.cubicTo(w * 0.54, h * 0.15, w * 0.55, h * 0.3, w * 0.56, h * 0.35);
    path.quadraticBezierTo(w * 0.85, h * 0.36, w * 0.98, h * 0.38);
    path.quadraticBezierTo(w * 0.99, h * 0.44, w * 0.95, h * 0.48);
    path.lineTo(w * 0.54, h * 0.46);
    path.lineTo(w * 0.53, h * 0.82);
    path.lineTo(w * 0.72, h * 0.88);
    path.quadraticBezierTo(w * 0.72, h * 0.95, w * 0.65, h * 0.98);
    path.lineTo(w * 0.5, h * 0.94);
    path.lineTo(w * 0.35, h * 0.98);
    path.quadraticBezierTo(w * 0.28, h * 0.95, w * 0.28, h * 0.88);
    path.lineTo(w * 0.47, h * 0.82);
    path.lineTo(w * 0.46, h * 0.46);
    path.lineTo(w * 0.05, h * 0.48);
    path.quadraticBezierTo(w * 0.01, h * 0.44, w * 0.02, h * 0.38);
    path.quadraticBezierTo(w * 0.15, h * 0.36, w * 0.44, h * 0.35);
    path.cubicTo(w * 0.45, h * 0.3, w * 0.46, h * 0.15, w * 0.5, 0);
    path.close();

    canvas.drawPath(path, paint);

    final outline = Paint()
      ..color = isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 2. Rover Drawing (Side View Silver Offroad Truck)
class _MpRoverPainter extends CustomPainter {
  const _MpRoverPainter({required this.isSelected});
  final bool isSelected;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isSelected
            ? [const Color(0xFFF1F5F9), const Color(0xFF94A3B8)]
            : [const Color(0xFFCBD5E1), const Color(0xFF64748B)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final body = Path();
    body.moveTo(w * 0.1, h * 0.45);
    body.lineTo(w * 0.35, h * 0.43);
    body.lineTo(w * 0.45, h * 0.20);
    body.lineTo(w * 0.75, h * 0.20);
    body.lineTo(w * 0.78, h * 0.40);
    body.lineTo(w * 0.95, h * 0.40);
    body.quadraticBezierTo(w * 0.99, h * 0.45, w * 0.98, h * 0.58);
    body.lineTo(w * 0.88, h * 0.58);
    body.arcToPoint(Offset(w * 0.62, h * 0.58), radius: Radius.circular(w * 0.13), clockwise: false);
    body.lineTo(w * 0.38, h * 0.58);
    body.arcToPoint(Offset(w * 0.12, h * 0.58), radius: Radius.circular(w * 0.13), clockwise: false);
    body.lineTo(w * 0.05, h * 0.58);
    body.quadraticBezierTo(w * 0.02, h * 0.48, w * 0.1, h * 0.45);
    body.close();

    canvas.drawPath(body, bodyPaint);

    _drawWheel(canvas, Offset(w * 0.25, h * 0.65), w * 0.17, bodyPaint);
    _drawWheel(canvas, Offset(w * 0.75, h * 0.65), w * 0.17, bodyPaint);
  }

  void _drawWheel(Canvas canvas, Offset center, double radius, Paint fill) {
    canvas.drawCircle(center, radius, fill);

    final treadPaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius * 0.75, treadPaint);

    final rimPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.4, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 3. Multirotor Drawing (Top View Silver Quadcopter)
class _MpMultirotorPainter extends CustomPainter {
  const _MpMultirotorPainter({required this.isSelected});
  final bool isSelected;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isSelected
            ? [const Color(0xFFF1F5F9), const Color(0xFF94A3B8)]
            : [const Color(0xFFCBD5E1), const Color(0xFF64748B)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final strokePaint = Paint()
      ..color = isSelected ? Colors.white : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawLine(Offset(w * 0.2, h * 0.2), Offset(w * 0.8, h * 0.8), strokePaint);
    canvas.drawLine(Offset(w * 0.8, h * 0.2), Offset(w * 0.2, h * 0.8), strokePaint);

    final ringRadius = w * 0.16;
    _drawRotorRing(canvas, Offset(w * 0.2, h * 0.2), ringRadius, paint);
    _drawRotorRing(canvas, Offset(w * 0.8, h * 0.2), ringRadius, paint);
    _drawRotorRing(canvas, Offset(w * 0.2, h * 0.8), ringRadius, paint);
    _drawRotorRing(canvas, Offset(w * 0.8, h * 0.8), ringRadius, paint);

    final canopy = Path();
    canopy.moveTo(w * 0.5, h * 0.25);
    canopy.lineTo(w * 0.62, h * 0.5);
    canopy.lineTo(w * 0.5, h * 0.72);
    canopy.lineTo(w * 0.38, h * 0.5);
    canopy.close();

    canvas.drawPath(canopy, paint);
  }

  void _drawRotorRing(Canvas canvas, Offset center, double radius, Paint fill) {
    final ringPaint = Paint()
      ..shader = fill.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    canvas.drawCircle(center, radius, ringPaint);

    final hubPaint = Paint()
      ..shader = fill.shader
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.35, hubPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 4. Helicopter Drawing (Side View Silver Helicopter)
class _MpHelicopterPainter extends CustomPainter {
  const _MpHelicopterPainter({required this.isSelected});
  final bool isSelected;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isSelected
            ? [const Color(0xFFF1F5F9), const Color(0xFF94A3B8)]
            : [const Color(0xFFCBD5E1), const Color(0xFF64748B)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final cabin = Path();
    cabin.moveTo(w * 0.15, h * 0.55);
    cabin.cubicTo(w * 0.2, h * 0.32, w * 0.45, h * 0.32, w * 0.58, h * 0.42);
    cabin.lineTo(w * 0.88, h * 0.48);
    cabin.lineTo(w * 0.90, h * 0.28);
    cabin.lineTo(w * 0.95, h * 0.30);
    cabin.lineTo(w * 0.92, h * 0.58);
    cabin.lineTo(w * 0.58, h * 0.62);
    cabin.cubicTo(w * 0.45, h * 0.72, w * 0.25, h * 0.72, w * 0.15, h * 0.55);
    cabin.close();

    canvas.drawPath(cabin, paint);

    final rotorPaint = Paint()
      ..color = isSelected ? Colors.white : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawLine(Offset(w * 0.05, h * 0.28), Offset(w * 0.85, h * 0.28), rotorPaint);
    canvas.drawLine(Offset(w * 0.42, h * 0.28), Offset(w * 0.42, h * 0.36), rotorPaint);
    canvas.drawLine(Offset(w * 0.92, h * 0.22), Offset(w * 0.92, h * 0.52), rotorPaint);

    final skidPaint = Paint()
      ..color = isSelected ? Colors.white : const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawLine(Offset(w * 0.20, h * 0.82), Offset(w * 0.62, h * 0.82), skidPaint);
    canvas.drawLine(Offset(w * 0.30, h * 0.68), Offset(w * 0.28, h * 0.82), skidPaint);
    canvas.drawLine(Offset(w * 0.52, h * 0.68), Offset(w * 0.50, h * 0.82), skidPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
