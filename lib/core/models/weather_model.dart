import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WeatherData {
  final double temperature; // °C
  final int humidity; // %
  final double windSpeed; // km/h
  final double windDirection; // degrees
  final int weatherCode; // WMO Weather Code
  final String conditionText;
  final String locationName;
  final IconData icon;
  final DateTime updatedAt;
  final bool isLoading;
  final String? error;

  const WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    required this.conditionText,
    required this.locationName,
    required this.icon,
    required this.updatedAt,
    this.isLoading = false,
    this.error,
  });

  factory WeatherData.initial() {
    return WeatherData(
      temperature: 28.0,
      humidity: 55,
      windSpeed: 12.0,
      windDirection: 180.0,
      weatherCode: 0,
      conditionText: 'Clear',
      locationName: 'New Delhi',
      icon: LucideIcons.sun,
      updatedAt: DateTime.now(),
      isLoading: false,
    );
  }

  WeatherData copyWith({
    double? temperature,
    int? humidity,
    double? windSpeed,
    double? windDirection,
    int? weatherCode,
    String? conditionText,
    String? locationName,
    IconData? icon,
    DateTime? updatedAt,
    bool? isLoading,
    String? error,
  }) {
    return WeatherData(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      weatherCode: weatherCode ?? this.weatherCode,
      conditionText: conditionText ?? this.conditionText,
      locationName: locationName ?? this.locationName,
      icon: icon ?? this.icon,
      updatedAt: updatedAt ?? this.updatedAt,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Maps WMO Weather Code (Open-Meteo) to human text & Lucide Icon
  static (String, IconData) parseWmoCode(int code) {
    switch (code) {
      case 0:
        return ('Clear Sky', LucideIcons.sun);
      case 1:
        return ('Mainly Clear', LucideIcons.cloudSun);
      case 2:
        return ('Partly Cloudy', LucideIcons.cloudSun);
      case 3:
        return ('Overcast', LucideIcons.cloud);
      case 45:
      case 48:
        return ('Foggy', LucideIcons.cloudFog);
      case 51:
      case 53:
      case 55:
        return ('Drizzle', LucideIcons.cloudDrizzle);
      case 61:
      case 63:
      case 65:
        return ('Rain', LucideIcons.cloudRain);
      case 66:
      case 67:
        return ('Freezing Rain', LucideIcons.cloudSnow);
      case 71:
      case 73:
      case 75:
      case 77:
        return ('Snow', LucideIcons.cloudSnow);
      case 80:
      case 81:
      case 82:
        return ('Rain Showers', LucideIcons.cloudRain);
      case 85:
      case 86:
        return ('Snow Showers', LucideIcons.cloudSnow);
      case 95:
      case 96:
      case 99:
        return ('Thunderstorm', LucideIcons.cloudLightning);
      default:
        return ('Clear', LucideIcons.sun);
    }
  }

  /// Flight Suitability Rating
  String get flightSafetyStatus {
    if (windSpeed > 35 || weatherCode >= 95 || weatherCode == 65 || weatherCode == 75) {
      return 'UNSUITABLE (High Risk)';
    } else if (windSpeed > 20 || (weatherCode >= 51 && weatherCode <= 82)) {
      return 'MARGINAL (Caution Required)';
    }
    return 'SUITABLE (Optimal Conditions)';
  }
}
