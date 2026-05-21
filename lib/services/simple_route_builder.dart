import 'dart:math';

import '../models/geo.dart';
import '../models/poi.dart';

class SimpleRouteBuilder {
  static List<Poi> buildRoute({
    required LatLon start,
    required List<Poi> pois,
    bool returnToStart = false,
  }) {
    if (pois.length <= 2) {
      return _buildNearestRoute(
        start: start,
        pois: pois,
        returnToStart: returnToStart,
      );
    }

    final loopRoute = _buildLoopRoute(
      start: start,
      pois: pois,
    );

    final nearestRoute = _buildNearestRoute(
      start: start,
      pois: pois,
      returnToStart: false,
    );

    final loopDistance = _routeDistanceKm(
      start: start,
      route: loopRoute,
      returnToStart: returnToStart,
    );

    final nearestDistance = _routeDistanceKm(
      start: start,
      route: nearestRoute,
      returnToStart: returnToStart,
    );

    final selectedRoute = loopDistance <= nearestDistance * 1.25
        ? loopRoute
        : nearestRoute;

    final result = List<Poi>.from(selectedRoute);

    if (returnToStart) {
      result.add(_returnToStartPoi(start));
    }

    return result;
  }

  static List<Poi> _buildNearestRoute({
    required LatLon start,
    required List<Poi> pois,
    required bool returnToStart,
  }) {
    final remaining = List<Poi>.from(pois);
    final result = <Poi>[];

    var currentLat = start.lat;
    var currentLon = start.lon;

    while (remaining.isNotEmpty) {
      Poi? nearest;
      double bestDist = double.infinity;

      for (final poi in remaining) {
        final d = _distanceKm(
          currentLat,
          currentLon,
          poi.location.lat,
          poi.location.lon,
        );

        if (d < bestDist) {
          bestDist = d;
          nearest = poi;
        }
      }

      if (nearest == null) break;

      result.add(nearest);
      remaining.remove(nearest);

      currentLat = nearest.location.lat;
      currentLon = nearest.location.lon;
    }

    if (returnToStart) {
      result.add(_returnToStartPoi(start));
    }

    return result;
  }

  static List<Poi> _buildLoopRoute({
    required LatLon start,
    required List<Poi> pois,
  }) {
    final sorted = List<Poi>.from(pois);

    sorted.sort((a, b) {
      final angleA = _bearingDeg(start, a.location);
      final angleB = _bearingDeg(start, b.location);
      return angleA.compareTo(angleB);
    });

    return _bestRotation(
      start: start,
      sortedByBearing: sorted,
    );
  }

  static List<Poi> _bestRotation({
    required LatLon start,
    required List<Poi> sortedByBearing,
  }) {
    if (sortedByBearing.length <= 2) {
      return List<Poi>.from(sortedByBearing);
    }

    List<Poi> bestRoute = List<Poi>.from(sortedByBearing);
    double bestDistance = double.infinity;

    for (var i = 0; i < sortedByBearing.length; i++) {
      final candidate = <Poi>[
        ...sortedByBearing.sublist(i),
        ...sortedByBearing.sublist(0, i),
      ];

      final distance = _routeDistanceKm(
        start: start,
        route: candidate,
        returnToStart: true,
      );

      if (distance < bestDistance) {
        bestDistance = distance;
        bestRoute = candidate;
      }
    }

    return bestRoute;
  }

  static double _routeDistanceKm({
    required LatLon start,
    required List<Poi> route,
    required bool returnToStart,
  }) {
    if (route.isEmpty) return 0;

    double total = 0;
    var current = start;

    for (final poi in route) {
      total += _distanceKm(
        current.lat,
        current.lon,
        poi.location.lat,
        poi.location.lon,
      );

      current = poi.location;
    }

    if (returnToStart) {
      total += _distanceKm(
        current.lat,
        current.lon,
        start.lat,
        start.lon,
      );
    }

    return total;
  }

  static Poi _returnToStartPoi(LatLon start) {
    return Poi(
      id: 'return_to_start',
      name: 'Atpakaļ uz sākumpunktu',
      location: start,
      durationH: 0,
      categories: {PoiCategory.mustSee},
      isIndoor: false,
    );
  }

  static double _bearingDeg(LatLon from, LatLon to) {
    final lat1 = _degToRad(from.lat);
    final lat2 = _degToRad(to.lat);
    final dLon = _degToRad(to.lon - from.lon);

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) -
        sin(lat1) * cos(lat2) * cos(dLon);

    final bearing = atan2(y, x);
    return (_radToDeg(bearing) + 360) % 360;
  }

  static double _distanceKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const R = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
            cos(_degToRad(lat1)) *
                cos(_degToRad(lat2)) *
                (sin(dLon / 2) * sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _degToRad(double deg) => deg * pi / 180.0;

  static double _radToDeg(double rad) => rad * 180.0 / pi;
}