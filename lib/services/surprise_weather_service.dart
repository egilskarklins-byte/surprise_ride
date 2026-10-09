import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

class SurpriseWeatherService {
  const SurpriseWeatherService();
  Future<WeatherDay> getHourlyWeather({
    required double lat,
    required double lon,
    required String languageCode,
    int hoursAhead = 0,
  }) async {
    if (![0, 2, 4, 8].contains(hoursAhead)) {
      throw ArgumentError.value(hoursAhead, 'hoursAhead');
    }

    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': '$lat',
        'longitude': '$lon',
        'hourly': [
          'temperature_2m',
          'precipitation',
          'wind_speed_10m',
          'weather_code',
        ].join(','),
        'wind_speed_unit': 'ms',
        'timezone': 'auto',
        'forecast_days': '2',
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      throw Exception('Open-Meteo HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>;
    final times = hourly['time'] as List;

    // Open-Meteo atgriež arī atrašanās vietas laika zonas nobīdi.
    final offsetSeconds =
    (data['utc_offset_seconds'] as num).toInt();

    final targetTime = DateTime.now()
        .toUtc()
        .add(Duration(seconds: offsetSeconds))
        .add(Duration(hours: hoursAhead));

    // Izvēlamies tuvāko pieejamo prognozes stundu.
    int closestIndex = 0;
    int smallestDifference = 1 << 62;

    for (int i = 0; i < times.length; i++) {
      final hour = DateTime.parse(times[i] as String);
      final difference =
      hour.difference(targetTime).inSeconds.abs();

      if (difference < smallestDifference) {
        smallestDifference = difference;
        closestIndex = i;
      }
    }

    double hourlyDouble(String key) {
      final value = (hourly[key] as List)[closestIndex];
      return (value as num).toDouble();
    }

    final weatherCode =
    (hourly['weather_code'] as List)[closestIndex] as num;

    return WeatherDay(
      date: DateTime.parse(times[closestIndex] as String),
      tempC: hourlyDouble('temperature_2m'),
      windMs: hourlyDouble('wind_speed_10m'),
      rainMm: hourlyDouble('precipitation'),
      description: _weatherDescription(
        weatherCode.toInt(),
        languageCode: languageCode,
      ),
    );
  }

  Future<WeatherDay> getTodayWeather({
    required double lat,
    required double lon,
    required String languageCode,
  }) async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': '$lat',
        'longitude': '$lon',
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
          'precipitation_sum',
          'wind_speed_10m_max',
        ].join(','),
        'wind_speed_unit': 'ms',
        'timezone': 'auto',
        'forecast_days': '1',
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      throw Exception(
        'Open-Meteo HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = data['daily'] as Map<String, dynamic>;

    final maxTemp = _firstDouble(daily['temperature_2m_max']);
    final minTemp = _firstDouble(daily['temperature_2m_min']);
    final rainMm = _firstDouble(daily['precipitation_sum']);
    final windMs = _firstDouble(daily['wind_speed_10m_max']);
    final weatherCode = _firstInt(daily['weather_code']);

    final dateText = (daily['time'] as List).first as String;
    final date = DateTime.parse(dateText);

    return WeatherDay(
      date: date,
      tempC: (maxTemp + minTemp) / 2,
      windMs: windMs,
      rainMm: rainMm,
      description: _weatherDescription(
        weatherCode,
        languageCode: languageCode,
      ),
    );
  }

  double _firstDouble(dynamic value) {
    if (value is! List || value.isEmpty) return 0;
    return (value.first as num).toDouble();
  }

  int _firstInt(dynamic value) {
    if (value is! List || value.isEmpty) return 0;
    return (value.first as num).toInt();
  }

  String _weatherDescription(
      int code, {
        required String languageCode,
      }) {
    final isLatvian = languageCode.toLowerCase().startsWith('lv');

    if (code == 0) {
      return isLatvian ? 'Skaidrs laiks' : 'Clear sky';
    }

    if (code == 1 || code == 2) {
      return isLatvian ? 'Daļēji mākoņains' : 'Partly cloudy';
    }

    if (code == 3) {
      return isLatvian ? 'Apmācies' : 'Overcast';
    }

    if (code == 45 || code == 48) {
      return isLatvian ? 'Migla' : 'Fog';
    }

    if (code >= 51 && code <= 57) {
      return isLatvian ? 'Smidzina' : 'Drizzle';
    }

    if (code >= 61 && code <= 67) {
      return isLatvian ? 'Lietus' : 'Rain';
    }

    if (code >= 71 && code <= 77) {
      return isLatvian ? 'Sniegs' : 'Snow';
    }

    if (code >= 80 && code <= 82) {
      return isLatvian ? 'Lietusgāzes' : 'Rain showers';
    }

    if (code >= 85 && code <= 86) {
      return isLatvian ? 'Sniega brāzmas' : 'Snow showers';
    }

    if (code >= 95) {
      return isLatvian ? 'Pērkona negaiss' : 'Thunderstorm';
    }

    return isLatvian ? 'Mainīgi laikapstākļi' : 'Variable weather';
  }
}