import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/weather_model.dart';

class WeatherService {
  static Future<String> fetchLocationName(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(url);
      request.headers.set('User-Agent', 'WingspannGCS/1.0');
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);
        final address = json['address'];
        if (address != null) {
          final suburb = address['suburb'] ?? address['neighbourhood'] ?? address['suburb_district'];
          final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'] ?? address['state'];
          if (suburb != null && city != null && suburb != city) {
            return '$suburb, $city';
          } else if (city != null) {
            return '$city';
          } else if (suburb != null) {
            return '$suburb';
          }
        }
      }
      client.close();
    } catch (e) {
      debugPrint('Location name fetch error: $e');
    }
    return 'New Delhi';
  }

  static Future<WeatherData> fetchWeather({
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?'
      'latitude=$latitude&longitude=$longitude'
      '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m',
    );

    // Fetch area name concurrently
    final locationNameFuture = fetchLocationName(latitude, longitude);

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody);
        
        final current = json['current'];
        if (current != null) {
          final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 28.0;
          final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 50;
          final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
          final windSpeed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 10.0;
          final windDirection = (current['wind_direction_10m'] as num?)?.toDouble() ?? 0.0;

          final (conditionText, icon) = WeatherData.parseWmoCode(weatherCode);
          final locationName = await locationNameFuture;

          return WeatherData(
            temperature: temp,
            humidity: humidity,
            windSpeed: windSpeed,
            windDirection: windDirection,
            weatherCode: weatherCode,
            conditionText: conditionText,
            locationName: locationName,
            icon: icon,
            updatedAt: DateTime.now(),
            isLoading: false,
          );
        }
      }
      client.close();
    } catch (e) {
      debugPrint('WeatherService fetch error: $e');
    }

    final locationName = await locationNameFuture;
    final (fallbackText, fallbackIcon) = WeatherData.parseWmoCode(0);
    return WeatherData(
      temperature: 28.0,
      humidity: 55,
      windSpeed: 12.0,
      windDirection: 180.0,
      weatherCode: 0,
      conditionText: fallbackText,
      locationName: locationName,
      icon: fallbackIcon,
      updatedAt: DateTime.now(),
      isLoading: false,
      error: 'Unable to connect to weather server',
    );
  }
}
