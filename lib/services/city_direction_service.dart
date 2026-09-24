import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class DirectionCity {
  final String name;
  final double lat;
  final double lon;
  final String placeType;
  final int? population;

  const DirectionCity({
    required this.name,
    required this.lat,
    required this.lon,
    required this.placeType,
    this.population,
  });

  LatLng get location => LatLng(lat, lon);
}

class CityDirectionService {
  const CityDirectionService();

  // Ielādējam pasaules pilsētu datubāzi tikai vienu reizi.
  static List<DirectionCity>? _cachedCities;

  Future<List<DirectionCity>> _loadCities() async {
    if (_cachedCities != null) {
      return _cachedCities!;
    }

    debugPrint('🏙️ Loading local world cities...');

    final jsonText = await rootBundle.loadString(
      'assets/data/cities_world.json',
    );

    final rawList = jsonDecode(jsonText) as List<dynamic>;

    final cities = <DirectionCity>[];

    for (final item in rawList) {
      if (item is! Map<String, dynamic>) continue;

      final name = item['n']?.toString().trim();
      final lat = (item['lat'] as num?)?.toDouble();
      final lon = (item['lon'] as num?)?.toDouble();
      final population = (item['p'] as num?)?.toInt();
      final featureCode = item['t']?.toString() ?? 'PPL';

      if (name == null ||
          name.isEmpty ||
          lat == null ||
          lon == null) {
        continue;
      }

      cities.add(
        DirectionCity(
          name: name,
          lat: lat,
          lon: lon,
          placeType: featureCode,
          population: population,
        ),
      );
    }

    _cachedCities = cities;

    debugPrint(
      '🏙️ Local city database loaded: ${cities.length}',
    );

    return cities;
  }

  Future<List<DirectionCity>> fetchCities({
    required double centerLat,
    required double centerLon,
    double radiusKm = 120,
    int maxResults = 5,
  }) async {
    final stopwatch = Stopwatch()..start();

    final allCities = await _loadCities();

    final candidates = <_CityCandidate>[];

    for (final city in allCities) {
      // Ātrs aptuvens filtrs pirms precīzā distance aprēķina.
      final latDifference = (city.lat - centerLat).abs();

      if (latDifference > radiusKm / 100.0 + 0.5) {
        continue;
      }

      final lonScale = math.cos(
        centerLat * math.pi / 180.0,
      ).abs();

      final safeLonScale =
      lonScale < 0.15 ? 0.15 : lonScale;

      final maxLonDifference =
          radiusKm / (111.0 * safeLonScale);

      if ((city.lon - centerLon).abs() >
          maxLonDifference + 0.5) {
        continue;
      }

      final distanceKm = _distanceKm(
        centerLat,
        centerLon,
        city.lat,
        city.lon,
      );

      if (distanceKm > radiusKm) {
        continue;
      }

      candidates.add(
        _CityCandidate(
          city: city,
          distanceKm: distanceKm,
        ),
      );
    }

    // Priekšroka apdzīvotākām vietām.
    // Ja population vienāds, tuvākā vieta ir augstāk.
    candidates.sort((a, b) {
      final populationCompare =
      (b.city.population ?? 0).compareTo(
        a.city.population ?? 0,
      );

      if (populationCompare != 0) {
        return populationCompare;
      }

      return a.distanceKm.compareTo(b.distanceKm);
    });

    final result = candidates
        .take(maxResults)
        .map((candidate) => candidate.city)
        .toList();

    stopwatch.stop();

    debugPrint(
      '🏙️ LOCAL CITIES FOUND in '
          '${stopwatch.elapsedMilliseconds} ms: '
          '${result.map((city) => city.name).toList()}',
    );

    return result;
  }

  double _distanceKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const earthRadiusKm = 6371.0;

    final dLat =
        (lat2 - lat1) * math.pi / 180.0;

    final dLon =
        (lon2 - lon1) * math.pi / 180.0;

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(lat1 * math.pi / 180.0) *
                math.cos(lat2 * math.pi / 180.0) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final c = 2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadiusKm * c;
  }
}

class _CityCandidate {
  final DirectionCity city;
  final double distanceKm;

  const _CityCandidate({
    required this.city,
    required this.distanceKm,
  });
}