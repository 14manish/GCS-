import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../store/weather_provider.dart';
import '../store/gcs_notifier.dart';
import '../theme/app_theme.dart';

void showWeatherDialog(BuildContext context, double lat, double lng) {
  showDialog(
    context: context,
    builder: (ctx) => WeatherDialog(lat: lat, lng: lng),
  );
}

class WeatherDialog extends ConsumerWidget {
  const WeatherDialog({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gcs = context.gcs;
    final weather = ref.watch(weatherProvider);
    final s = ref.watch(gcsProvider);
    final drone = s.drones.isNotEmpty
        ? s.drones.firstWhere((d) => d.id == s.selectedDroneId, orElse: () => s.drones.first)
        : null;

    final currentLat = drone?.lat ?? lat;
    final currentLng = drone?.lng ?? lng;

    Color safetyColor;
    if (weather.flightSafetyStatus.startsWith('SUITABLE')) {
      safetyColor = gcs.success;
    } else if (weather.flightSafetyStatus.startsWith('MARGINAL')) {
      safetyColor = gcs.warning;
    } else {
      safetyColor = gcs.danger;
    }

    final formattedTime =
        '${weather.updatedAt.hour.toString().padLeft(2, '0')}:${weather.updatedAt.minute.toString().padLeft(2, '0')}:${weather.updatedAt.second.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: gcs.panels,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: gcs.accent.withValues(alpha: 0.3)),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Bar
            Row(
              children: [
                Icon(LucideIcons.cloudSun, size: 22, color: gcs.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LIVE WEATHER FORECAST',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: gcs.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Location: ${weather.locationName} (${currentLat.toStringAsFixed(4)}°N, ${currentLng.toStringAsFixed(4)}°E)',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          color: gcs.secText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, size: 18, color: gcs.secText),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main Weather Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: gcs.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gcs.accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(weather.icon, size: 48, color: gcs.accent),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weather.temperature.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: gcs.text,
                        ),
                      ),
                      Text(
                        weather.conditionText.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: gcs.accent,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Flight Safety Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: safetyColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: safetyColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    safetyColor == gcs.success
                        ? LucideIcons.checkCircle2
                        : (safetyColor == gcs.warning
                            ? LucideIcons.alertTriangle
                            : LucideIcons.alertOctagon),
                    size: 16,
                    color: safetyColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'FLIGHT SAFETY: ${weather.flightSafetyStatus}',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: safetyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Detailed Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    icon: LucideIcons.wind,
                    label: 'WIND SPEED',
                    value: '${weather.windSpeed.toStringAsFixed(1)} km/h',
                    subValue: '${weather.windDirection.toStringAsFixed(0)}° Dir',
                    gcs: gcs,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    icon: LucideIcons.droplets,
                    label: 'HUMIDITY',
                    value: '${weather.humidity}%',
                    subValue: 'Relative',
                    gcs: gcs,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Footer (Timestamp + Refresh Button)
            Row(
              children: [
                Text(
                  'Updated at $formattedTime UTC',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    color: gcs.secText,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: weather.isLoading
                      ? null
                      : () => ref
                          .read(weatherProvider.notifier)
                          .refreshWeather(currentLat, currentLng),
                  icon: weather.isLoading
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(LucideIcons.refreshCw, size: 12),
                  label: Text(
                    weather.isLoading ? 'REFRESHING...' : 'REFRESH NOW',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gcs.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required GcsThemeExtension gcs,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gcs.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: gcs.accent.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: gcs.accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: gcs.secText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: gcs.text,
            ),
          ),
          Text(
            subValue,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: gcs.secText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
