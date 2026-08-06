import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class ConnectionPage extends ConsumerStatefulWidget {
  const ConnectionPage({super.key});

  @override
  ConsumerState<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<ConnectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  String _selectedPort = '';
  int _baudRate = 57600;
  String _hostIp = '127.0.0.1';
  int _udpPort = 14550;

  // Dynamic port list — refreshed on demand
  List<String> _availablePorts = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: 1);
    _refreshPorts();
  }

  void _refreshPorts() {
    final ports = SerialPort.availablePorts;
    setState(() {
      _availablePorts = ports;
      if (_selectedPort.isEmpty || !ports.contains(_selectedPort)) {
        _selectedPort = ports.isNotEmpty ? ports.first : '';
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;
    final isConnected = s.connectionStatus == 'Connected';
    final isConnecting = s.connectionStatus == 'Connecting';

    return Container(
      color: gcs.bg,
      child: Row(
        children: [
          // ─── Left Config Panel ───
          Container(
            width: 340,
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  right: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(LucideIcons.radio, size: 16, color: gcs.accent),
                        const SizedBox(width: 8),
                        Text('CONNECT VEHICLE',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: gcs.accent,
                            )),
                        const Spacer(),
                        // Protocol badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: gcs.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: gcs.accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'MAVLink v2',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              color: gcs.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Tab bar
                      Container(
                        decoration: BoxDecoration(
                          color: gcs.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: gcs.accent.withValues(alpha: 0.1)),
                        ),
                        child: TabBar(
                          controller: _tabCtrl,
                          labelStyle: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                          ),
                          labelColor: gcs.accent,
                          unselectedLabelColor: gcs.secText,
                          indicator: BoxDecoration(
                            color: gcs.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          tabs: const [
                            Tab(key: ValueKey('tab_serial'), text: 'SERIAL'),
                            Tab(key: ValueKey('tab_udp'), text: 'UDP'),
                            Tab(key: ValueKey('tab_auto'), text: 'AUTO'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab views
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _SerialPanel(
                        key: const ValueKey('serial'),
                        port: _selectedPort,
                        baud: _baudRate,
                        availablePorts: _availablePorts,
                        gcs: gcs,
                        onPortChanged: (v) => setState(() => _selectedPort = v),
                        onBaudChanged: (v) => setState(() => _baudRate = v),
                        onRefresh: _refreshPorts,
                      ),
                      _UdpPanel(
                        key: const ValueKey('udp'),
                        ip: _hostIp,
                        port: _udpPort,
                        boundPort: s.udpBoundPort,
                        gcs: gcs,
                        onIpChanged: (v) => setState(() => _hostIp = v),
                        onPortChanged: (v) => setState(() => _udpPort = v),
                      ),
                      _AutoPanel(
                        key: const ValueKey('auto'),
                        s: s,
                        gcs: gcs,
                        onScan: () =>
                            ref.read(gcsProvider.notifier).setScanning(true),
                        onConnect: (port) {
                          setState(() => _selectedPort = port);
                          _tabCtrl.animateTo(0);
                        },
                      ),
                    ],
                  ),
                ),

                // Connect / Disconnect button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isConnecting
                            ? null
                            : isConnected
                                ? () =>
                                    ref.read(gcsProvider.notifier).disconnect()
                                : () => ref.read(gcsProvider.notifier).connect(
                                      connectionType: _tabCtrl.index == 0
                                          ? 'Serial'
                                          : 'UDP',
                                      serialPort: _selectedPort,
                                      baudRate: _baudRate,
                                      hostIp: _hostIp,
                                      port: _udpPort,
                                    ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isConnected ? gcs.danger : gcs.accent,
                          foregroundColor: gcs.bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isConnecting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: gcs.bg)),
                                    const SizedBox(width: 8),
                                    Text('CONNECTING...',
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: gcs.bg,
                                        )),
                                  ])
                            : Text(isConnected ? 'DISCONNECT' : 'CONNECT',
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                )),
                      ),
                    ),

                  ]),
                ),
              ],
            ),
          ),

          // ─── Right Info/Status Panel ───
          Expanded(
            child: Column(
              children: [
                // Top status area
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status indicator
                      _ConnectionStatusCard(s: s, gcs: gcs),
                      const SizedBox(height: 12),

                      // Last error banner
                      if (s.lastError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: gcs.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: gcs.danger.withValues(alpha: 0.35)),
                          ),
                          child: Row(children: [
                            Icon(LucideIcons.alertTriangle,
                                size: 14, color: gcs.danger),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(s.lastError!,
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10,
                                    color: gcs.danger,
                                  )),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Fleet summary
                      Text('CONNECTED FLEET',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            color: gcs.secText,
                            letterSpacing: 1.5,
                          )),
                      const SizedBox(height: 8),
                      ...s.drones.map((d) => _DroneStatusRow(drone: d, gcs: gcs)),
                    ],
                  ),
                ),

                // ─── MAVLink Live Log ───
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    decoration: BoxDecoration(
                      color: gcs.panels,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: gcs.accent.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Log header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: gcs.accent.withValues(alpha: 0.12)),
                            ),
                          ),
                          child: Row(children: [
                            Icon(LucideIcons.terminalSquare,
                                size: 13, color: gcs.accent),
                            const SizedBox(width: 8),
                            Text('MAVLINK LIVE LOG',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: gcs.accent,
                                )),
                            const Spacer(),
                            Text('${s.mavlinkLog.length} msgs',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 9,
                                  color: gcs.secText,
                                )),
                          ]),
                        ),
                        // Log entries
                        Expanded(
                          child: s.mavlinkLog.isEmpty
                              ? Center(
                                  child: Text(
                                    'No MAVLink messages yet.\nConnect a vehicle to see live telemetry.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 10,
                                      color: gcs.secText,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  itemCount: s.mavlinkLog.length,
                                  itemBuilder: (context, i) {
                                    final entry = s.mavlinkLog[i];
                                    final isCmd = entry.contains('CMD');
                                    final isErr = entry.contains('FAIL') ||
                                        entry.contains('ERROR') ||
                                        entry.contains('timeout');
                                    final isOk = entry.contains('ACCEPTED') ||
                                        entry.contains('COMPLETE') ||
                                        entry.contains('HEARTBEAT');
                                    Color entryColor = gcs.secText;
                                    if (isErr) entryColor = gcs.danger;
                                    if (isOk) entryColor = gcs.success;
                                    if (isCmd) entryColor = gcs.warning;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 1),
                                      child: Text(
                                        entry,
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 9,
                                          color: entryColor,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Serial Panel ──────────────────────────────────────────────────────────────
class _SerialPanel extends StatelessWidget {
  const _SerialPanel({
    super.key,
    required this.port,
    required this.baud,
    required this.availablePorts,
    required this.gcs,
    required this.onPortChanged,
    required this.onBaudChanged,
    required this.onRefresh,
  });
  final String port;
  final int baud;
  final List<String> availablePorts;
  final GcsThemeExtension gcs;
  final ValueChanged<String> onPortChanged;
  final ValueChanged<int> onBaudChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final portList = availablePorts.isNotEmpty
        ? availablePorts
        : const ['COM3', 'COM4', 'COM5', 'COM8'];
    final effectivePort =
        portList.contains(port) ? port : portList.first;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _Label('SERIAL PORT', gcs)),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gcs.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                  border:
                      Border.all(color: gcs.accent.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(LucideIcons.refreshCw, size: 10, color: gcs.accent),
                  const SizedBox(width: 4),
                  Text('REFRESH',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 8,
                        color: gcs.accent,
                      )),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          _Dropdown<String>(
            key: const ValueKey('dropdown_port'),
            value: effectivePort,
            items: portList,
            gcs: gcs,
            onChanged: (v) => onPortChanged(v!),
          ),
          if (availablePorts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No serial ports detected. Connect device and tap REFRESH.',
                style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 8,
                    color: gcs.danger),
              ),
            ),
          const SizedBox(height: 12),
          _Label('BAUD RATE', gcs),
          _Dropdown<int>(
            key: const ValueKey('dropdown_baud'),
            value: baud,
            items: const [
              9600,
              19200,
              38400,
              57600,
              115200,
              230400,
              460800,
              921600
            ],
            gcs: gcs,
            onChanged: (v) => onBaudChanged(v!),
          ),
          const SizedBox(height: 12),
          _Label('FLOW CONTROL', gcs),
          _Dropdown<String>(
            key: const ValueKey('dropdown_flow'),
            value: 'None',
            items: const ['None', 'Hardware (RTS/CTS)', 'Software (XON/XOFF)'],
            gcs: gcs,
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          // MAVLink info box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: gcs.accent.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: gcs.accent.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MAVLINK v2 — ArduPilotMega dialect',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      color: gcs.accent,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 4),
                Text(
                  '• GCS sysId=255 compId=190\n'
                  '• Heartbeat sent every 1s\n'
                  '• 15s watchdog timeout\n'
                  '• Data streams requested at connect',
                  style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 8,
                      color: gcs.secText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ─── UDP Panel ─────────────────────────────────────────────────────────────────
class _UdpPanel extends StatelessWidget {
  const _UdpPanel({
    super.key,
    required this.ip,
    required this.port,
    required this.boundPort,
    required this.gcs,
    required this.onIpChanged,
    required this.onPortChanged,
  });
  final String ip;
  final int port;
  final int? boundPort;
  final GcsThemeExtension gcs;
  final ValueChanged<String> onIpChanged;
  final ValueChanged<int> onPortChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Label('HOST IP ADDRESS', gcs),
          TextField(
            onChanged: onIpChanged,
            controller: TextEditingController(text: ip),
            style: TextStyle(
                fontFamily: 'JetBrains Mono', fontSize: 11, color: gcs.text),
            decoration: const InputDecoration(hintText: '127.0.0.1'),
          ),
          const SizedBox(height: 12),
          _Label('LOCAL UDP PORT (GCS listens here)', gcs),
          TextField(
            onChanged: (v) => onPortChanged(int.tryParse(v) ?? port),
            controller: TextEditingController(text: '$port'),
            keyboardType: TextInputType.number,
            style: TextStyle(
                fontFamily: 'JetBrains Mono', fontSize: 11, color: gcs.text),
            decoration: const InputDecoration(hintText: '14550'),
          ),
          const SizedBox(height: 12),

          // Bound port status
          if (boundPort != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: gcs.success.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: gcs.success.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(LucideIcons.wifi, size: 11, color: gcs.success),
                const SizedBox(width: 8),
                Text('Listening on UDP port $boundPort',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      color: gcs.success,
                    )),
              ]),
            ),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UDP MAVLink — How it works',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      color: gcs.accent,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 4),
                Text(
                  'GCS binds local port (default 14550) and sends\n'
                  'MAVLink heartbeats. SITL / drone must connect\n'
                  'outbound to this GCS IP:port.\n\n'
                  'SITL: --out udp:127.0.0.1:14550\n'
                  'MAVProxy: --out udpout:127.0.0.1:14550',
                  style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      color: gcs.secText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ─── Auto-Scan Panel ───────────────────────────────────────────────────────────
class _AutoPanel extends StatelessWidget {
  const _AutoPanel(
      {super.key,
      required this.s,
      required this.gcs,
      required this.onScan,
      required this.onConnect});
  final dynamic s;
  final GcsThemeExtension gcs;
  final VoidCallback onScan;
  final ValueChanged<String> onConnect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('AUTO-SCAN DEVICES',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      color: gcs.secText,
                      letterSpacing: 1.2,
                    ))),
            GestureDetector(
              onTap: s.isScanning ? null : onScan,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: gcs.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: gcs.accent.withValues(alpha: 0.3)),
                ),
                child: s.isScanning
                    ? Row(children: [
                        SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: gcs.accent)),
                        const SizedBox(width: 6),
                        Text('SCANNING',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              color: gcs.accent,
                            )),
                      ])
                    : Text('SCAN',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          color: gcs.accent,
                        )),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Probes all serial ports for MAVLink heartbeats at 115200 baud.',
            style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 8,
                color: gcs.secText),
          ),
          const SizedBox(height: 12),
          ...s.autoScanList.map<Widget>((device) => GestureDetector(
                onTap: () => onConnect(device['port']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: gcs.bg,
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: gcs.accent.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    Icon(LucideIcons.cpu, size: 14, color: gcs.accent),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              'Port: ${device['port']}',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: gcs.text,
                              )),
                          Text(
                              'Autopilot: ${device['autopilot']}  Type: ${device['vehicleType']}',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                color: gcs.secText,
                              )),
                        ])),
                    Icon(LucideIcons.arrowRight, size: 14, color: gcs.accent),
                  ]),
                ),
              )),
          if ((s.autoScanList as List).isEmpty && !s.isScanning)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No MAVLink devices found. Tap SCAN to search.',
                style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 9,
                    color: gcs.secText),
              ),
            ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ─── Connection Status Card ────────────────────────────────────────────────────
class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({required this.s, required this.gcs});
  final dynamic s;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    final isConnected = s.connectionStatus == 'Connected';
    final color = isConnected ? gcs.success : gcs.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isConnected ? LucideIcons.wifi : LucideIcons.wifiOff,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.connectionStatus.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                )),
            Text(
                'Type: ${s.connectionType}  |  MAVLink v2',
                style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    color: gcs.secText)),
            if (isConnected && s.remoteSystemId != null)
              Text(
                  'SysId: ${s.remoteSystemId}  CompId: ${s.remoteComponentId}',
                  style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      color: gcs.accent)),
            if (isConnected && s.udpBoundPort != null)
              Text(
                  'UDP port: ${s.udpBoundPort}',
                  style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9,
                      color: gcs.secText)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Drone Status Row ──────────────────────────────────────────────────────────
class _DroneStatusRow extends StatelessWidget {
  const _DroneStatusRow({required this.drone, required this.gcs});
  final dynamic drone;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    final healthColor = drone.health == 'Healthy'
        ? gcs.success
        : drone.health == 'Warning'
            ? gcs.warning
            : gcs.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: gcs.panels,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: healthColor, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(drone.name,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: gcs.text,
            )),
        const Spacer(),
        Text(drone.flightMode,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: gcs.accent,
            )),
        const SizedBox(width: 12),
        Text('${drone.battery.toStringAsFixed(0)}%',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: drone.battery > 30 ? gcs.success : gcs.danger,
            )),
      ]),
    );
  }
}

// ─── Shared helpers ────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  const _Label(this.text, this.gcs);
  final String text;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9,
            color: gcs.secText,
            letterSpacing: 1.2,
          )),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown(
      {super.key,
      required this.value,
      required this.items,
      required this.gcs,
      required this.onChanged});
  final T value;
  final List<T> items;
  final GcsThemeExtension gcs;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gcs.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: gcs.panels,
          style: TextStyle(
              fontFamily: 'JetBrains Mono', fontSize: 11, color: gcs.text),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text('$item'),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
