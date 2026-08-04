import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/map_providers.dart';
import '../store/gcs_notifier.dart';
import '../theme/app_theme.dart';

void showMapProviderSelector(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => const MapProviderDialog(),
  );
}

class MapProviderDialog extends ConsumerWidget {
  const MapProviderDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gcs = context.gcs;
    final currentProviderId = ref.watch(gcsProvider).mapProvider;

    return Dialog(
      backgroundColor: gcs.panels,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: gcs.accent.withValues(alpha: 0.3)),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.layers, size: 20, color: gcs.accent),
                const SizedBox(width: 10),
                Text(
                  'SELECT MAP PROVIDER',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: gcs.text,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 18, color: gcs.secText),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select map tile source (Mission Planner standard satellite & maps)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: gcs.secText,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: MapProviders.providers.values.map((p) {
                    final isSelected = p.id == currentProviderId;
                    return InkWell(
                      onTap: () {
                        ref
                            .read(gcsProvider.notifier)
                            .setMapProvider(p.id);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? gcs.accent.withValues(alpha: 0.12)
                              : gcs.bg.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? gcs.accent
                                : gcs.secText.withValues(alpha: 0.15),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              p.id.contains('sat') || p.id.contains('hybrid')
                                  ? LucideIcons.satellite
                                  : p.id.contains('dark')
                                      ? LucideIcons.moon
                                      : LucideIcons.map,
                              size: 18,
                              color: isSelected ? gcs.accent : gcs.secText,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? gcs.accent
                                              : gcs.text,
                                        ),
                                      ),
                                      if (p.id == 'google_hybrid') ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: gcs.success
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: gcs.success, width: 0.8),
                                          ),
                                          child: Text(
                                            'MISSION PLANNER',
                                            style: TextStyle(
                                              fontFamily: 'JetBrains Mono',
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: gcs.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.description,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      color: gcs.secText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                LucideIcons.checkCircle2,
                                size: 18,
                                color: gcs.accent,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
