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
}