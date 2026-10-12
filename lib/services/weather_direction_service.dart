
import 'dart:math' as math;

import 'surprise_weather_service.dart';

class DirectionWeatherResult {
  final String direction;
  final double bearing;
  final double lat;
  final double lon;
  final double score;
  final String reason;

  // Detalizētie laikapstākļi sektora popup logam.
  final String description;
  final double? tempC;
  final double? rainMm;
  final double? precipitationProbability;
  final double? windMs;
  final double? windGustMs;
  final double? cloudCover;
  final bool? isFoggy;
  final bool? isSnowy;
  final bool? isFreezingRain;
  final bool? isThunderstorm;

  const DirectionWeatherResult({
    required this.direction,
    required this.bearing,
    required this.lat,
    required this.lon,
    required this.score,
    required this.reason,
    this.description = '',
    this.tempC,
    this.rainMm,
    this.precipitationProbability,
    this.windMs,
    this.windGustMs,
    this.cloudCover,
    this.isFoggy,
    this.isSnowy,
    this.isFreezingRain,
    this.isThunderstorm,
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

  String _canonicalDirection(String direction) {
    const aliases = {
      'Z': 'N',
      'ZA': 'NE',
      'A': 'E',
      'DA': 'SE',
      'D': 'S',
      'DR': 'SW',
      'R': 'W',
      'ZR': 'NW',
    };

    final upper = direction.toUpperCase();
    return aliases[upper] ?? upper;
  }

  Future<List<DirectionWeatherResult>> getBestDirections({
    required double startLat,
    required double startLon,
    required String languageCode,
    double distanceKm = 100,
    int hoursAhead = 0,
  }) {
    return getDirections(
      startLat: startLat,
      startLon: startLon,
      languageCode: languageCode,
      distanceKm: distanceKm,
      hoursAhead: hoursAhead,
    );
  }

  // Var pieprasīt visus 8 virzienus vai tikai norādītos.
  Future<List<DirectionWeatherResult>> getDirections({
    required double startLat,
    required double startLon,
    required String languageCode,
    double distanceKm = 100,
    int hoursAhead = 0,
    Iterable<String>? onlyDirections,
  }) async {
    final selected = onlyDirections == null
        ? null
        : onlyDirections.map(_canonicalDirection).toSet();

    final directions = selected == null
        ? _directions
        : _directions
        .where((direction) => selected.contains(direction.name))
        .toList();

    final futures = directions.map((direction) {
      return _fetchDirection(
        direction: direction,
        startLat: startLat,
        startLon: startLon,
        languageCode: languageCode,
        distanceKm: distanceKm,
        hoursAhead: hoursAhead,
      );
    }).toList();

    final rawResults = await Future.wait(futures);

    final results = rawResults
        .whereType<DirectionWeatherResult>()
        .toList();

    results.sort((a, b) => b.score.compareTo(a.score));

    return results;
  }

  Future<DirectionWeatherResult?> _fetchDirection({
    required _DirectionPoint direction,
    required double startLat,
    required double startLon,
    required String languageCode,
    required double distanceKm,
    required int hoursAhead,
  }) async {
    final point = pointAtDistance(
      startLat: startLat,
      startLon: startLon,
      bearingDegrees: direction.bearing,
      distanceKm: distanceKm,
    );

    // Sākotnējais mēģinājums un viens atkārtots mēģinājums.
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final weather = await weatherService
            .getHourlyWeather(
          lat: point.lat,
          lon: point.lon,
          languageCode: languageCode,
          hoursAhead: hoursAhead,
        )
            .timeout(const Duration(seconds: 10));

        double score = 100;

        // Temperatūras komforts.
        if (weather.tempC < 15) {
          score -= (15 - weather.tempC) * 1.5;
        }
        if (weather.tempC > 25) {
          score -= (weather.tempC - 25) * 2;
        }

        // Nokrišņi un to varbūtība.
        score -= weather.rainMm * 18;
        score -= weather.precipitationProbability * 0.12;

        // Vējš un brāzmas.
        if (weather.windMs > 4) {
          score -= (weather.windMs - 4) * 5;
        }
        if (weather.windGustMs > 8) {
          score -= (weather.windGustMs - 8) * 3;
        }

        // Mākoņainība.
        if (weather.cloudCover > 80) {
          score -= 5;
        }

        // Bīstami laikapstākļi.
        if (weather.isFoggy) score = math.min(score, 40);
        if (weather.isSnowy) score = math.min(score, 35);
        if (weather.isFreezingRain) score = math.min(score, 15);
        if (weather.isThunderstorm) score = math.min(score, 10);

        score = score.clamp(0.0, 100.0).toDouble();

        final isLatvian =
        languageCode.toLowerCase().startsWith('lv');

        const lvDirections = {
          'N': 'Z',
          'NE': 'ZA',
          'E': 'A',
          'SE': 'DA',
          'S': 'D',
          'SW': 'DR',
          'W': 'R',
          'NW': 'ZR',
        };

        final directionName = isLatvian
            ? (lvDirections[direction.name] ?? direction.name)
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
          description: weather.description,
          tempC: weather.tempC.toDouble(),
          rainMm: weather.rainMm.toDouble(),
          precipitationProbability:
          weather.precipitationProbability.toDouble(),
          windMs: weather.windMs.toDouble(),
          windGustMs: weather.windGustMs.toDouble(),
          cloudCover: weather.cloudCover.toDouble(),
          isFoggy: weather.isFoggy,
          isSnowy: weather.isSnowy,
          isFreezingRain: weather.isFreezingRain,
          isThunderstorm: weather.isThunderstorm,
        );
      } catch (error) {
        if (attempt == 1) {
          print(
            '🔄 Retrying weather for ${direction.name}: $error',
          );
        } else {
          print(
            '❌ Weather failed for ${direction.name}: $error',
          );
        }
      }
    }

    return null;
  }
}

class _DirectionPoint {
  final String name;
  final double bearing;

  const _DirectionPoint(this.name, this.bearing);
}
