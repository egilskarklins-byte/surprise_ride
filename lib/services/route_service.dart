import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geo.dart';

class RouteService {
  Future<List<LatLon>> fetchDrivingRoute(List<LatLon> points) async {
    if (points.length < 2) return points;

    final coordinates = points
        .map((p) => '${p.lon},${p.lat}')
        .join(';');

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coordinates'
          '?overview=full&geometries=geojson',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return points;
    }

    final data = jsonDecode(response.body);

    if (data['routes'] == null || data['routes'].isEmpty) {
      return points;
    }

    final coords = data['routes'][0]['geometry']['coordinates'] as List;

    return coords.map((c) {
      return LatLon(
        (c[1] as num).toDouble(),
        (c[0] as num).toDouble(),
      );
    }).toList();
  }
}