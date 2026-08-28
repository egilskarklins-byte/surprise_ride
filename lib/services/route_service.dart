import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geo.dart';

class RouteResult {
  final List<LatLon> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class RouteService {
  Future<List<LatLon>> fetchDrivingRoute(List<LatLon> points) async {
    final result = await fetchDrivingRouteWithStats(points);
    return result.points;
  }

  Future<RouteResult> fetchDrivingRouteWithStats(List<LatLon> points) async {
    if (points.length < 2) {
      return RouteResult(
        points: points,
        distanceMeters: 0,
        durationSeconds: 0,
      );
    }

    final coordinates = points.map((p) => '${p.lon},${p.lat}').join(';');

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coordinates'
          '?overview=full&geometries=geojson',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return RouteResult(
        points: points,
        distanceMeters: 0,
        durationSeconds: 0,
      );
    }

    final data = jsonDecode(response.body);

    if (data['routes'] == null || data['routes'].isEmpty) {
      return RouteResult(
        points: points,
        distanceMeters: 0,
        durationSeconds: 0,
      );
    }

    final route = data['routes'][0];

    final coords = route['geometry']['coordinates'] as List;

    final routePoints = coords.map((c) {
      return LatLon(
        (c[1] as num).toDouble(),
        (c[0] as num).toDouble(),
      );
    }).toList();

    return RouteResult(
      points: routePoints,
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
    );
  }
  Future<RouteResult> fetchWalkingRouteWithStats(
      LatLon start,
      LatLon destination,
      ) async {
    final coordinates =
        '${start.lon},${start.lat};${destination.lon},${destination.lat}';

    final uri = Uri.parse(
      'https://routing.openstreetmap.de/routed-foot/route/v1/driving/$coordinates'
          '?overview=full&geometries=geojson',
    );

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print(
          '🚶 WALKING ROUTE HTTP: ${response.statusCode}',
        );

        return RouteResult(
          points: [start, destination],
          distanceMeters: 0,
          durationSeconds: 0,
        );
      }

      final data = jsonDecode(response.body);

      if (data['routes'] == null || data['routes'].isEmpty) {
        print('🚶 WALKING ROUTE: no route');

        return RouteResult(
          points: [start, destination],
          distanceMeters: 0,
          durationSeconds: 0,
        );
      }

      final route = data['routes'][0];

      final coords = route['geometry']['coordinates'] as List;

      final routePoints = coords.map((c) {
        return LatLon(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        );
      }).toList();

      final distanceMeters =
          (route['distance'] as num?)?.toDouble() ?? 0;

      final durationSeconds =
          (route['duration'] as num?)?.toDouble() ?? 0;

      print(
        '🚶 WALKING ROUTE: '
            '${distanceMeters.toStringAsFixed(0)} m, '
            '${(durationSeconds / 60).toStringAsFixed(0)} min',
      );

      return RouteResult(
        points: routePoints,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      print('🚶 WALKING ROUTE ERROR: $e');

      return RouteResult(
        points: [start, destination],
        distanceMeters: 0,
        durationSeconds: 0,
      );
    }
  }
}