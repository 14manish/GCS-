import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/store/gcs_notifier.dart';
import '../core/models/map_providers.dart';
import '../core/widgets/map_provider_selector.dart';
import '../core/theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gcsProvider);
    final gcs = context.gcs;

    return Container(
      color: gcs.bg,
      child: Row(
        children: [
          // ─── Left Config Panel ───
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: gcs.panels,
              border: Border(
                  right: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('SYSTEM SETTINGS', gcs),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _settingsGroup(
                          'APPEARANCE',
                          [
                            _ActionRow(
                              label: 'Map Provider',
                              value: MapProviders.get(s.mapProvider).name.split(' (').first,
                              onTap: () => showMapProviderSelector(context, ref),
                              gcs: gcs,
                            ),
                          ],
                          gcs),
                      const SizedBox(height: 16),
                      _settingsGroup(
                          'TELEMETRY',
                          [
                            _InfoRow(
                                label: 'Refresh Rate', value: '1 Hz', gcs: gcs),
                            _InfoRow(
                                label: 'History Depth',
                                value: '100 ticks',
                                gcs: gcs),
                            _InfoRow(
                                label: 'Alert Interval',
                                value: '20 sec',
                                gcs: gcs),
                          ],
                          gcs),
                      const SizedBox(height: 16),
                      _settingsGroup(
                          'SECURITY',
                          [
                            _ToggleSetting(
                              label: 'Encryption',
                              value: s.encryption,
                              trueLabel: 'AES-256',
                              falseLabel: 'OFF',
                              onChanged: (_) {},
                              gcs: gcs,
                            ),

                          ],
                          gcs),
                      const SizedBox(height: 16),
                      _settingsGroup(
                          'ABOUT',
                          [
                            _InfoRow(
                                label: 'App', value: 'WINGSPANN GCS', gcs: gcs),
                            _InfoRow(
                                label: 'Version',
                                value: '2.1.0-flutter',
                                gcs: gcs),
                            _InfoRow(
                                label: 'Platform',
                                value: 'Flutter Multi-Platform',
                                gcs: gcs),
                            _InfoRow(
                                label: 'MAVLink',
                                value: 'v2 (UDP/Serial)',
                                gcs: gcs),
                          ],
                          gcs),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Right Info Panel ───
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WINGSPANN GCS',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: gcs.accent,
                        letterSpacing: 2,
                      )),
                  const SizedBox(height: 4),
                  Text('Ground Control Station — Multi-Platform Edition',
                      style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          color: gcs.secText)),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _PlatformChip(label: '🌐 Web', gcs: gcs),
                      _PlatformChip(label: '🖥️ Windows', gcs: gcs),
                      _PlatformChip(label: '🐧 Linux', gcs: gcs),
                      _PlatformChip(label: '🍎 macOS', gcs: gcs),
                      _PlatformChip(label: '📱 Android', gcs: gcs),
                      _PlatformChip(label: '📱 iOS', gcs: gcs),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildInfoCard(
                      'MAVLink Integration',
                      'Real MAVLink v2 UDP/Serial connectivity available. Connect via Connection page.',
                      LucideIcons.radio,
                      gcs),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                      'Data Security',
                      'AES-256 encrypted telemetry stream. Session tokens auto-expire.',
                      LucideIcons.shield,
                      gcs),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                      'Multi-Vehicle',
                      'Manage up to 32 simultaneous vehicles. Independent telemetry feeds.',
                      LucideIcons.plane,
                      gcs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, GcsThemeExtension gcs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: gcs.accent.withValues(alpha: 0.15))),
      ),
      child: Text(title,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: gcs.accent,
            letterSpacing: 1,
          )),
    );
  }

  Widget _settingsGroup(
      String title, List<Widget> children, GcsThemeExtension gcs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: gcs.secText,
              letterSpacing: 1.5,
            )),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: gcs.bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: gcs.accent.withValues(alpha: 0.1)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
      String title, String desc, IconData icon, GcsThemeExtension gcs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gcs.panels,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: gcs.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: gcs.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: gcs.text,
                    )),
                const SizedBox(height: 4),
                Text(desc,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      color: gcs.secText,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSetting extends StatelessWidget {
  const _ToggleSetting({
    required this.label,
    required this.value,
    required this.trueLabel,
    required this.falseLabel,
    required this.onChanged,
    required this.gcs,
  });

  final String label;
  final bool value;
  final String trueLabel, falseLabel;
  final ValueChanged<bool> onChanged;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    color: gcs.text,
                  ))),
          Text(value ? trueLabel : falseLabel,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                color: gcs.accent,
              )),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: gcs.accent,
            inactiveTrackColor: gcs.panels,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.gcs});

  final String label, value;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    color: gcs.secText,
                  ))),
          Text(value,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                color: gcs.text,
              )),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.gcs,
  });

  final String label, value;
  final VoidCallback onTap;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: gcs.secText,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: gcs.accent,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 14, color: gcs.accent),
          ],
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({required this.label, required this.gcs});

  final String label;
  final GcsThemeExtension gcs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: gcs.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.2)),
      ),
      child: Text(label,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            color: gcs.accent,
          )),
    );
  }
}
