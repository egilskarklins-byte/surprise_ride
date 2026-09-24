import 'dart:math' as math;

import 'surprise_weather_service.dart';

class DirectionWeatherResult {
  final String direction;
  final double bearing;
  final double lat;
  final double lon;
  final double score;
  final String reason;

  const DirectionWeatherResult({
    required this.direction,
    required this.bearing,
    required this.lat,
    required this.lon,
    required this.score,
    required this.reason,
  });
}

class WeatherDirectionService {
  final SurpriseWeatherService weatherService;

  const WeatherDirectionService({
    this.weatherService = const SurpriseWeatherService(),
  });

  static const List<_DirectionPoint> _directions = [
    _DirectionPoint('N', 0),
    _DirectionPoint('NE', 45),
    _DirectionPoint('E', 90),
    _DirectionPoint('SE', 135),
    _DirectionPoint('S', 180),
    _DirectionPoint('SW', 225),
    _DirectionPoint('W', 270),
    _DirectionPoint('NW', 315),
  ];

  ({double lat, double lon}) pointAtDistance({
    required double startLat,
    required double startLon,
    required double bearingDegrees,
    required double distanceKm,
  }) {
    const earthRadiusKm = 6371.0;

    final lat1 = _degreesToRadians(startLat);
    final lon1 = _degreesToRadians(startLon);
    final bearing = _degreesToRadians(bearingDegrees);
    final angularDistance = distanceKm / earthRadiusKm;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) *
              math.sin(angularDistance) *
              math.cos(bearing),
    );

    final lon2 = lon1 +
        math.atan2(
          math.sin(bearing) *
              math.sin(angularDistance) *
              math.cos(lat1),
          math.cos(angularDistance) -
              math.sin(lat1) * math.sin(lat2),
        );

    return (
    lat: _radiansToDegrees(lat2),
    lon: _radiansToDegrees(lon2),
    );
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  double _radiansToDegrees(double radians) {
    return radians * 180 / math.pi;
  }

  Future<List<DirectionWeatherResult>> getBestDirections({
    required double startLat,
    required double startLon,
    required String languageCode,
    double distanceKm = 100,
  }) async {
    // Visi 8 virzieni tiek pieprasīti paralēli.
    // Ja viens virziens neizdodas, pārējie turpina strādāt.
    final futures = _directions.map((direction) async {
      final point = pointAtDistance(
        startLat: startLat,
        startLon: startLon,
        bearingDegrees: direction.bearing,
        distanceKm: distanceKm,
      );

      try {
        final weather = await weatherService
            .getTodayWeather(
          lat: point.lat,
          lon: point.lon,
          languageCode: languageCode,
        )
            .timeout(const Duration(seconds: 10));

        double score = 100;

        score -= weather.rainMm * 8;

        if (weather.windMs > 6) {
          score -= (weather.windMs - 6) * 5;
        }

        if (weather.tempC < 0) {
          score -= 15;
        }

        if (weather.tempC > 30) {
          score -= 10;
        }

        score = score.clamp(0.0, 100.0).toDouble();

        final isLatvian =
        languageCode.toLowerCase().startsWith('lv');

        final directionName = isLatvian
            ? {
          'N': 'Z',
          'NE': 'ZA',
          'E': 'A',
          'SE': 'DA',
          'S': 'D',
          'SW': 'DR',
          'W': 'R',
          'NW': 'ZR',
        }[direction.name] ??
            direction.name
            : direction.name;

        final reason =
            '${weather.description}, '
            '${weather.tempC.toStringAsFixed(0)}°C, '
            '${isLatvian ? 'lietus' : 'rain'} '
            '${weather.rainMm.toStringAsFixed(1)} mm, '
            '${isLatvian ? 'vējš' : 'wind'} '
            '${weather.windMs.toStringAsFixed(1)} m/s';

        return DirectionWeatherResult(
          direction: directionName,
          bearing: direction.bearing,
          lat: point.lat,
          lon: point.lon,
          score: score,
          reason: reason,
        );
      } catch (e) {
        print(
          '⚠️ Weather first attempt failed for ${direction.name}: $e',
        );

        // Retry tikai šim konkrētajam neveiksmīgajam virzienam.
        try {
          print(
            '🔄 Retrying weather for ${direction.name}...',
          );

          final weather = await weatherService
              .getTodayWeather(
            lat: point.lat,
            lon: point.lon,
            languageCode: languageCode,
          )
              .timeout(const Duration(seconds: 10));

          double score = 100;

          score -= weather.rainMm * 8;

          if (weather.windMs > 6) {
            score -= (weather.windMs - 6) * 5;
          }

          if (weather.tempC < 0) {
            score -= 15;
          }

          if (weather.tempC > 30) {
            score -= 10;
          }

          score = score.clamp(0.0, 100.0).toDouble();

          final isLatvian =
          languageCode.toLowerCase().startsWith('lv');

          final directionName = isLatvian
              ? {
            'N': 'Z',
            'NE': 'ZA',
            'E': 'A',
            'SE': 'DA',
            'S': 'D',
            'SW': 'DR',
            'W': 'R',
            'NW': 'ZR',
          }[direction.name] ??
              direction.name
              : direction.name;

          final reason =
              '${weather.description}, '
              '${weather.tempC.toStringAsFixed(0)}°C, '
              '${isLatvian ? 'lietus' : 'rain'} '
              '${weather.rainMm.toStringAsFixed(1)} mm, '
              '${isLatvian ? 'vējš' : 'wind'} '
              '${weather.windMs.toStringAsFixed(1)} m/s';

          print(
            '✅ Weather retry succeeded for ${direction.name}',
          );

          return DirectionWeatherResult(
            direction: directionName,
            bearing: direction.bearing,
            lat: point.lat,
            lon: point.lon,
            score: score,
            reason: reason,
          );
        } catch (retryError) {
          print(
            '❌ Weather retry failed for ${direction.name}: $retryError',
          );

          return null;
        }
      }
    }).toList();

    final rawResults = await Future.wait(futures);

    // Izmetam tikai tos virzienus, kuriem neizdevās iegūt laikapstākļus.
    final results = rawResults
        .whereType<DirectionWeatherResult>()
        .toList();

    results.sort(
          (a, b) => b.score.compareTo(a.score),
    );

    return results;
  }
}

class _DirectionPoint {
  final String name;
  final double bearing;

  const _DirectionPoint(
      this.name,
      this.bearing,
      );
}