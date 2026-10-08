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

  Future<List<DirectionCity>> fetchCitiesAlongRoute({
    required List<LatLng> routePoints,
    int maxResults = 5,
    double maxDistanceFromRouteKm = 25,
    int minPopulation = 1000,
  }) async {
    if (routePoints.isEmpty || maxResults <= 0) {
      return [];
    }

    final allCities = await _loadCities();

    // Maršrutu retinām, lai pilsētu atlase būtu ātra.
    // Aptuveni līdz 100 punktiem.
    final step = math.max(
      1,
      routePoints.length ~/ 100,
    );

    final sampledRoute = <LatLng>[
      for (
      int i = 0;
      i < routePoints.length;
      i += step
      )
        routePoints[i],

      if (routePoints.length > 1)
        routePoints.last,
    ];

    final candidates = <_RouteCityCandidate>[];

    for (final city in allCities) {
      final population = city.population ?? 0;

      if (population < minPopulation) {
        continue;
      }

      double nearestRouteDistance = double.infinity;
      int nearestRouteIndex = 0;

      for (int i = 0; i < sampledRoute.length; i++) {
        final point = sampledRoute[i];

        final distance = _distanceKm(
          point.latitude,
          point.longitude,
          city.lat,
          city.lon,
        );

        if (distance < nearestRouteDistance) {
          nearestRouteDistance = distance;
          nearestRouteIndex = i;
        }
      }

      // Pārāk tālu no maršruta.
      if (nearestRouteDistance >
          maxDistanceFromRouteKm) {
        continue;
      }



      final routeFraction =
      sampledRoute.length <= 1
          ? 0.0
          : nearestRouteIndex /
          (sampledRoute.length - 1);

      candidates.add(
        _RouteCityCandidate(
          city: city,
          distanceKm: nearestRouteDistance,
          routeFraction: routeFraction,
        ),
      );
    }

    final result = <DirectionCity>[];

    // Maršrutu sadalām zonās.
    // Ja maxResults = 5, tad:
    // 0–20%, 20–40%, 40–60%, 60–80%, 80–100%.
    for (int zone = 0; zone < maxResults; zone++) {
      final zoneStart = zone / maxResults;
      final zoneEnd = (zone + 1) / maxResults;
      final zoneCenter =
          (zoneStart + zoneEnd) / 2.0;

      final zoneCandidates =
      candidates.where((candidate) {
        final isLastZone =
            zone == maxResults - 1;

        final insideZone =
            candidate.routeFraction >= zoneStart &&
                (
                    isLastZone
                        ? candidate.routeFraction <= zoneEnd
                        : candidate.routeFraction < zoneEnd
                );

        if (!insideZone) {
          return false;
        }

        // Vienu un to pašu pilsētu divreiz nerādām.
        final alreadySelected = result.any(
              (selected) =>
          selected.name.toLowerCase().trim() ==
              candidate.city.name
                  .toLowerCase()
                  .trim(),
        );

        return !alreadySelected;
      }).toList();

      if (zoneCandidates.isEmpty) {
        continue;
      }

      zoneCandidates.sort((a, b) {
        // 0 = ideālais orientieris 3–15 km no maršruta.
// 1 = fallback pilsēta tuvāk par 3 km.
        final aDistanceGroup =
        a.distanceKm >= 3.0 ? 0 : 1;

        final bDistanceGroup =
        b.distanceKm >= 3.0 ? 0 : 1;

        final distanceGroupCompare =
        aDistanceGroup.compareTo(bDistanceGroup);

        if (distanceGroupCompare != 0) {
          return distanceGroupCompare;
        }
        // 1. Priekšroka pilsētai tuvāk zonas centram.
        // Tas palīdz orientierus sadalīt pa visu maršrutu.
        final aZoneDistance =
        (a.routeFraction - zoneCenter).abs();

        final bZoneDistance =
        (b.routeFraction - zoneCenter).abs();

        final zoneCompare =
        aZoneDistance.compareTo(
          bZoneDistance,
        );

        if (zoneCompare != 0) {
          return zoneCompare;
        }

        // 2. Ja abas līdzīgi novietotas,
        // priekšroka lielākai pilsētai.
        final populationCompare =
        (b.city.population ?? 0).compareTo(
          a.city.population ?? 0,
        );

        if (populationCompare != 0) {
          return populationCompare;
        }

        // 3. Beigās priekšroka tai,
        // kas tuvāk maršrutam.
        return a.distanceKm.compareTo(
          b.distanceKm,
        );
      });

      result.add(
        zoneCandidates.first.city,
      );
    }

    debugPrint(
      '🏙️ ROUTE CITIES BY ZONES: '
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
        math.sin(dLat / 2) *
            math.sin(dLat / 2) +
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

class _RouteCityCandidate {
  final DirectionCity city;
  final double distanceKm;
  final double routeFraction;

  const _RouteCityCandidate({
    required this.city,
    required this.distanceKm,
    required this.routeFraction,
  });
}