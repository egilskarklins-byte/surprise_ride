import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/geo.dart';

class PlaceSuggestion {
  final String name;
  final LatLon location;

  PlaceSuggestion({
    required this.name,
    required this.location,
  });
}

class GeocodingService {
  Future<List<PlaceSuggestion>> search(String query) async {
    if (query.trim().length < 2) return [];

    final uri = Uri.parse(
      'https://photon.komoot.io/api/?q=$query&limit=5',
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) return [];

    final data = json.decode(res.body);
    final features = data['features'] as List;

    return features.map((f) {
      final props = f['properties'];
      final coords = f['geometry']['coordinates'];

      return PlaceSuggestion(
        name: props['name'] ??
            props['city'] ??
            props['country'] ??
            'Unknown',
        location: LatLon(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        ),
      );
    }).toList();
  }
}