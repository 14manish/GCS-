import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_theme.dart';

class GcsSidebar extends ConsumerWidget {
  const GcsSidebar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gcs = context.gcs;
    final currentLocation = GoRouterState.of(context).uri.toString();

    final items = [
      const _NavItem(
          icon: LucideIcons.radio, path: '/connect', label: 'Connect'),
      const _NavItem(icon: LucideIcons.plane, path: '/fly', label: 'Fly View'),
      const _NavItem(
          icon: LucideIcons.compass, path: '/mission', label: 'Mission'),
      const _NavItem(
          icon: LucideIcons.gamepad2, path: '/simulation', label: 'Simulation'),
      const _NavItem(
          icon: LucideIcons.terminal, path: '/vehicles', label: 'Vehicles'),
      const _NavItem(
          icon: LucideIcons.activity, path: '/telemetry', label: 'Telemetry'),
      const _NavItem(
          icon: LucideIcons.alertOctagon, path: '/alerts', label: 'Alerts'),
      const _NavItem(
          icon: LucideIcons.sliders, path: '/parameters', label: 'Parameters'),
      const _NavItem(icon: LucideIcons.video, path: '/video', label: 'Video'),
      const _NavItem(
          icon: LucideIcons.cpu, path: '/diagnostics', label: 'Diagnostics'),
      const _NavItem(icon: LucideIcons.fileText, path: '/logs', label: 'Logs'),
      const _NavItem(
          icon: LucideIcons.settings, path: '/settings', label: 'Settings'),
    ];

    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: gcs.bg,
        border: Border(
            right: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items.map((item) {
                final isActive = currentLocation.startsWith(item.path);
                return _SidebarItem(item: item, isActive: isActive, gcs: gcs);
              }).toList(),
            ),
          ),
          // Bottom branding rotated text
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                'WSPN GCS',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9,
                  color: gcs.secText.withValues(alpha: 0.5),
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.item,
    required this.isActive,
    required this.gcs,
  });

  final _NavItem item;
  final bool isActive;
  final GcsThemeExtension gcs;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isActive || _hovered ? widget.gcs.accent : widget.gcs.secText;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.item.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.gcs.accent.withValues(alpha: 0.05)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.isActive ? widget.gcs.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.item.icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                widget.item.label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9,
                  color: color,
                  fontWeight:
                      widget.isActive ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.path,
    required this.label,
  });
  final IconData icon;
  final String path;
  final String label;
}
