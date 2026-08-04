import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import 'gcs_notifier.dart';

class WeatherNotifier extends StateNotifier<WeatherData> {
  WeatherNotifier(this.ref) : super(WeatherData.initial()) {
    refreshWeather();
    // Auto refresh every 10 minutes
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => refreshWeather());
  }

  final Ref ref;
  Timer? _timer;

  Future<void> refreshWeather([double? lat, double? lng]) async {
    state = state.copyWith(isLoading: true, error: null);

    // Get current drone lat/lng if available, otherwise default to home
    final s = ref.read(gcsProvider);
    final drone = s.drones.isNotEmpty
        ? s.drones.firstWhere((d) => d.id == s.selectedDroneId, orElse: () => s.drones.first)
        : null;
    final targetLat = lat ?? drone?.lat ?? 28.6139;
    final targetLng = lng ?? drone?.lng ?? 77.2090;

    final data = await WeatherService.fetchWeather(
      latitude: targetLat,
      longitude: targetLng,
    );

    state = data;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final weatherProvider = StateNotifierProvider<WeatherNotifier, WeatherData>((ref) {
  return WeatherNotifier(ref);
});
