$newContent = @
// ---------------------------------------------
// SIDE PANEL (340px)
// ---------------------------------------------
class _SidePanel extends StatefulWidget {
 const _SidePanel({
 required this.roll,
 required this.pitch,
 required this.heading,
 required this.altitude,
 required this.speed,
 required this.drone,
 required this.gcs,
 required this.onAction,
 required this.onDroneChange,
 required this.drones,
 });

 final double roll, pitch, heading, altitude, speed;
 final DroneModel? drone;
 final GcsThemeExtension gcs;
 final void Function(String) onAction;
 final void Function(String?) onDroneChange;
 final List<DroneModel> drones;

 @override
 State<_SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<_SidePanel> {
 int _activeTab = 0;
 final _tabs = ['QUICK', 'ACTIONS', 'MESSAGES', 'PREFLIGHT', 'STAT'];

 @override
 Widget build(BuildContext context) {
 return Container(
 color: Colors.white, // The design mock shows a white background
 child: Column(
 children: [
 // --- HUD TOP HALF ---
 Container(
 height: 180,
 color: const Color(0xFF080E1C),
 padding: const EdgeInsets.all(8),
 child: Column(
 children: [
 // Attitude Indicator
 Expanded(
 child: CustomPaint(
 painter: _AttitudePainter(roll: widget.roll, pitch: widget.pitch),
 child: Container(),
 ),
 ),
 const SizedBox(height: 8),

 // Heading tape
 SizedBox(
 height: 32,
 child: CustomPaint(
 painter: _HeadingTapePainter(heading: widget.heading),
 child: const SizedBox.expand(),
 ),
 ),
 const SizedBox(height: 8),

 // Alt + speed ladders
 Expanded(
 child: Row(
 children: [
 Expanded(
 child: CustomPaint(
 painter: _LadderPainter(
 value: widget.altitude,
 unit: 'm',
 color: AppColors.accent,
 label: 'ALT',
 ),
 child: Container(),
 )),
 const SizedBox(width: 4),
 Expanded(
 child: CustomPaint(
 painter: _LadderPainter(
 value: widget.speed,
 unit: 'm/s',
 color: AppColors.success,
 label: 'SPD',
 ),
 child: Container(),
 )),
 ],
 ),
 ),
 if (widget.drone != null)
 Padding(
 padding: const EdgeInsets.only(top: 4),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('AS m/s', style: const TextStyle(color: Colors.white, fontSize: 8, fontFamily: 'JetBrains Mono')),
 Text('Bat V %', style: const TextStyle(color: Colors.white, fontSize: 8, fontFamily: 'JetBrains Mono')),
 Text('GPS: ', style: const TextStyle(color: Colors.white, fontSize: 8, fontFamily: 'JetBrains Mono')),
 ]
 )
 )
 ],
 ),
 ),
 
 // --- TABS ---
 Container(
 height: 40,
 decoration: const BoxDecoration(
 border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
 ),
 child: Row(
 children: _tabs.asMap().entries.map((e) {
 final idx = e.key;
 final label = e.value;
 final isActive = _activeTab == idx;
 return Expanded(
 child: GestureDetector(
 onTap: () => setState(() => _activeTab = idx),
 child: Container(
 color: isActive ? const Color(0xFF0D8CC6) : Colors.transparent,
 alignment: Alignment.center,
 child: Text(
 label,
 style: TextStyle(
 fontFamily: 'JetBrains Mono',
 fontSize: 10,
 fontWeight: FontWeight.bold,
 color: isActive ? Colors.white : const Color(0xFF444444),
 ),
 ),
 ),
 ),
 );
 }).toList(),
 ),
 ),

 // --- TAB CONTENT ---
 Expanded(
 child: _activeTab == 0 ? _buildQuickTab() : _buildActionsTab(),
 ),

 // --- DRONE SELECTOR (BOTTOM) ---
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: const BoxDecoration(
 color: Color(0xFFF9F9F9),
 border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
 ),
 child: Row(
 children: [
 Expanded(
 child: Container(
 height: 30,
 padding: const EdgeInsets.symmetric(horizontal: 8),
 decoration: BoxDecoration(
 border: Border.all(color: const Color(0xFFDDDDDD)),
 borderRadius: BorderRadius.circular(4),
 color: Colors.white,
 ),
 child: DropdownButtonHideUnderline(
 child: DropdownButton<String>(
 value: widget.drone?.id,
 isExpanded: true,
 icon: const Icon(Icons.keyboard_arrow_down, size: 16),
 items: widget.drones.map((d) {
 return DropdownMenuItem(
 value: d.id,
 child: Text(
 ' ()',
 style: const TextStyle(
 fontFamily: 'JetBrains Mono',
 fontSize: 11,
 color: Colors.black87,
 ),
 ),
 );
 }).toList(),
 onChanged: widget.onDroneChange,
 ),
 ),
 ),
 ),
 const SizedBox(width: 16),
 Text(
 'UAV ID: ',
 style: const TextStyle(
 fontFamily: 'JetBrains Mono',
 fontSize: 10,
 color: Colors.black54,
 ),
 ),
 ],
 ),
 )
 ],
 ),
 );
 }

 Widget _buildQuickTab() {
 if (widget.drone == null) {
 return const Center(child: Text('No Drone Selected', style: TextStyle(color: Colors.black54)));
 }
 final d = widget.drone!;
 return SingleChildScrollView(
 padding: const EdgeInsets.all(12),
 child: Column(
 children: [
 // Telemetry Grid
 Row(
 children: [
 Expanded(child: _TelemetryCard('ALTITUDE (M)', d.altitude.toStringAsFixed(2), const Color(0xFF9B51E0))),
 const SizedBox(width: 8),
 Expanded(child: _TelemetryCard('GROUNDSPEED (M/S)', d.speed.toStringAsFixed(2), const Color(0xFFF2994A))),
 ],
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 Expanded(child: _TelemetryCard('YAW (DEG)', d.heading.toStringAsFixed(2), const Color(0xFF27AE60))),
 const SizedBox(width: 8),
 Expanded(child: _TelemetryCard('VERTICAL SPEED (M/S)', d.climbRate.toStringAsFixed(2), const Color(0xFFF2C94C))),
 ],
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 Expanded(child: _TelemetryCard('BATTERY %', '%', const Color(0xFFEB5757))),
 const SizedBox(width: 8),
 Expanded(child: _TelemetryCard('LINK QUALITY', '%', const Color(0xFF0D8CC6))),
 ],
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 Expanded(child: _TelemetryCard('WIND SPEED', ' km/h', const Color(0xFF00BFA5))),
 const SizedBox(width: 8),
 Expanded(child: _TelemetryCard('WIND DIRECTION', d.windDir, const Color(0xFF00BFA5))),
 ],
 ),
 const SizedBox(height: 16),
 
 // Motors RPM
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 border: Border.all(color: const Color(0xFFEEEEEE)),
 borderRadius: BorderRadius.circular(4),
 color: const Color(0xFFFBFBFB),
 ),
 child: Column(
 children: [
 const Text('MOTORS RPM', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: Color(0xFF555555), fontWeight: FontWeight.bold)),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(child: _MotorCard('MOTOR 1', d.motor1Rpm.toString())),
 const SizedBox(width: 8),
 Expanded(child: _MotorCard('MOTOR 2', d.motor2Rpm.toString())),
 ],
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 Expanded(child: _MotorCard('MOTOR 3', d.motor3Rpm.toString())),
 const SizedBox(width: 8),
 Expanded(child: _MotorCard('MOTOR 4', d.motor4Rpm.toString())),
 ],
 ),
 ],
 ),
 )
 ],
 ),
 );
 }

 Widget _buildActionsTab() {
 return SingleChildScrollView(
 padding: const EdgeInsets.all(12),
 child: Column(
 children: [
 _ArmBtn(label: 'ARM', color: AppColors.success, onTap: () => widget.onAction('ARM')),
 const SizedBox(height: 8),
 _ArmBtn(label: 'TAKEOFF', color: AppColors.accent, onTap: () => widget.onAction('TAKEOFF')),
 const SizedBox(height: 8),
 _ArmBtn(label: 'LAND', color: AppColors.warning, onTap: () => widget.onAction('LAND')),
 const SizedBox(height: 8),
 _ArmBtn(label: 'RTL', color: const Color(0xFFFF9800), onTap: () => widget.onAction('RTL')),
 const SizedBox(height: 8),
 _ArmBtn(label: 'DISARM', color: AppColors.danger, onTap: () => widget.onAction('DISARM')),
 ],
 ),
 );
 }
}

class _TelemetryCard extends StatelessWidget {
 const _TelemetryCard(this.label, this.value, this.color);
 final String label, value;
 final Color color;
 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
 decoration: BoxDecoration(
 border: Border.all(color: const Color(0xFFEEEEEE)),
 borderRadius: BorderRadius.circular(4),
 color: Colors.white,
 ),
 child: Column(
 children: [
 Text(label, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 9, color: Color(0xFF666666), fontWeight: FontWeight.bold)),
 const SizedBox(height: 8),
 Text(value, style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 18, color: color, fontWeight: FontWeight.bold)),
 ],
 ),
 );
 }
}

class _MotorCard extends StatelessWidget {
 const _MotorCard(this.label, this.value);
 final String label, value;
 @override
 Widget build(BuildContext context) {
 return Container(
 padding: const EdgeInsets.symmetric(vertical: 8),
 decoration: BoxDecoration(
 border: Border.all(color: const Color(0xFFEEEEEE)),
 borderRadius: BorderRadius.circular(4),
 color: Colors.white,
 ),
 child: Column(
 children: [
 Text(label, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 9, color: Color(0xFF666666), fontWeight: FontWeight.bold)),
 const SizedBox(height: 8),
 Text(value, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14, color: Color(0xFF4A90E2), fontWeight: FontWeight.bold)),
 ],
 ),
 );
 }
}

class _ArmBtn extends StatelessWidget {
 const _ArmBtn({required this.label, required this.color, required this.onTap});
 final String label;
 final Color color;
 final VoidCallback onTap;

 @override
 Widget build(BuildContext context) {
 return GestureDetector(
 onTap: onTap,
 child: Container(
 width: double.infinity,
 padding: const EdgeInsets.symmetric(vertical: 12),
 decoration: BoxDecoration(
 color: color.withOpacity(0.1),
 borderRadius: BorderRadius.circular(3),
 border: Border.all(color: color.withOpacity(0.35)),
 ),
 child: Text(label,
 textAlign: TextAlign.center,
 style: TextStyle(
 fontFamily: 'JetBrains Mono',
 fontSize: 12,
 color: color,
 fontWeight: FontWeight.bold,
 letterSpacing: 0.8,
 )),
 ),
 );
 }
}

$lines = Get-Content 'lib/pages/fly_view/fly_view.dart'
$startIdx = -1
$endIdx = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($startIdx -eq -1 -and $lines[$i] -match 'HUD PANEL') {
        $startIdx = $i - 1
    }
    if ($startIdx -ne -1 -and $lines[$i] -match 'CAMERA STRIP') {
        $endIdx = $i - 2
        break
    }
}
if ($startIdx -ne -1 -and $endIdx -ne -1) {
    $before = $lines[0..($startIdx - 1)]
    $after = $lines[($endIdx + 1)..($lines.Length - 1)]
    $finalContent = $before -join  

    $finalContent += 
 + $newContent + 

    $finalContent += $after -join 

    [IO.File]::WriteAllText('lib/pages/fly_view/fly_view.dart', $finalContent)
    Write-Output 'Replaced successfully.'
} else {
    Write-Output Error: Start $startIdx End $endIdx
}
