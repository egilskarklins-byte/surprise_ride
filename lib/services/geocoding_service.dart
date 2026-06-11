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
  static const List<_LocalPlace> _localPlaces = [
    _LocalPlace('Rīga, Latvia', LatLon(56.9496, 24.1052)),
    _LocalPlace('Liepāja, Latvia', LatLon(56.5047, 21.0108)),
    _LocalPlace('Daugavpils, Latvia', LatLon(55.8750, 26.5356)),
    _LocalPlace('Jelgava, Latvia', LatLon(56.6511, 23.7214)),
    _LocalPlace('Jūrmala, Latvia', LatLon(56.9680, 23.7704)),
    _LocalPlace('Ventspils, Latvia', LatLon(57.3899, 21.5729)),
    _LocalPlace('Rēzekne, Latvia', LatLon(56.5099, 27.3331)),
    _LocalPlace('Valmiera, Latvia', LatLon(57.5385, 25.4264)),
    _LocalPlace('Jēkabpils, Latvia', LatLon(56.4990, 25.8574)),
    _LocalPlace('Ogre, Latvia', LatLon(56.8162, 24.6140)),
    _LocalPlace('Olaine, Latvia', LatLon(56.7947, 23.9358)),
    _LocalPlace('Tukums, Latvia', LatLon(56.9669, 23.1536)),
    _LocalPlace('Cēsis, Latvia', LatLon(57.3127, 25.2747)),
    _LocalPlace('Kuldīga, Latvia', LatLon(56.9687, 21.9688)),
    _LocalPlace('Sigulda, Latvia', LatLon(57.1538, 24.8595)),
    _LocalPlace('Talsi, Latvia', LatLon(57.2456, 22.5876)),
    _LocalPlace('Bauska, Latvia', LatLon(56.4075, 24.1906)),
    _LocalPlace('Madona, Latvia', LatLon(56.8533, 26.2169)),
    _LocalPlace('Alūksne, Latvia', LatLon(57.4216, 27.0466)),
    _LocalPlace('Gulbene, Latvia', LatLon(57.1777, 26.7529)),
    _LocalPlace('Saldus, Latvia', LatLon(56.6636, 22.4881)),
    _LocalPlace('Dobele, Latvia', LatLon(56.6237, 23.2751)),
    _LocalPlace('Limbaži, Latvia', LatLon(57.5129, 24.7194)),
    _LocalPlace('Aizkraukle, Latvia', LatLon(56.6048, 25.2553)),
    _LocalPlace('Balvi, Latvia', LatLon(57.1329, 27.2646)),
    _LocalPlace('Ludza, Latvia', LatLon(56.5396, 27.7189)),
    _LocalPlace('Krāslava, Latvia', LatLon(55.8951, 27.1676)),
    _LocalPlace('Preiļi, Latvia', LatLon(56.2944, 26.7246)),
    _LocalPlace('Līvāni, Latvia', LatLon(56.3543, 26.1758)),
    _LocalPlace('Smiltene, Latvia', LatLon(57.4245, 25.9017)),
    _LocalPlace('Valka, Latvia', LatLon(57.7752, 26.0101)),
    _LocalPlace('Saulkrasti, Latvia', LatLon(57.2622, 24.4147)),
    _LocalPlace('Ainaži, Latvia', LatLon(57.8635, 24.3581)),
    _LocalPlace('Salacgrīva, Latvia', LatLon(57.7531, 24.3589)),
    _LocalPlace('Pāvilosta, Latvia', LatLon(56.8879, 21.1859)),
  ];

  Future<List<PlaceSuggestion>> search(
      String query, {
        LatLon? biasCenter,
      }) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final localResults = _searchLocalPlaces(q);

    var photonResults = await _searchPhoton(
      query: _normalize(q),
      originalQuery: q,
      biasCenter: biasCenter,
    );

    if (photonResults.isEmpty) {
      photonResults = await _searchPhoton(
        query: '${_normalize(q)}, latvia',
        originalQuery: '$q Latvia',
        biasCenter: biasCenter,
      );
    }

    if (photonResults.isEmpty) {
      photonResults = await _searchNominatim(
        query: q,
        biasCenter: biasCenter,
      );
    }

    final merged = <PlaceSuggestion>[];
    final seen = <String>{};

    for (final item in [...localResults, ...photonResults]) {
      final key =
          '${_normalize(item.name)}_${item.location.lat.toStringAsFixed(4)}_${item.location.lon.toStringAsFixed(4)}';

      if (seen.contains(key)) continue;
      seen.add(key);
      merged.add(item);
    }

    return merged;
  }

  List<PlaceSuggestion> _searchLocalPlaces(String query) {
    final qNorm = _normalize(query);

    final matches = <PlaceSuggestion>[];

    for (final place in _localPlaces) {
      final nameNorm = _normalize(place.name);

      if (nameNorm.startsWith(qNorm) || nameNorm.contains(qNorm)) {
        matches.add(
          PlaceSuggestion(
            name: place.name,
            location: place.location,
          ),
        );
      }
    }

    return matches;
  }

  Future<List<PlaceSuggestion>> _searchPhoton({
    required String query,
    required String originalQuery,
    required LatLon? biasCenter,
  }) async {
    final params = <String, String>{
      'q': query,
      'limit': '30',
      if (biasCenter != null) 'lat': biasCenter.lat.toString(),
      if (biasCenter != null) 'lon': biasCenter.lon.toString(),
    };

    final uri = Uri.https(
      'photon.komoot.io',
      '/api/',
      params,
    );

    final res = await http.get(uri).timeout(
      const Duration(seconds: 8),
    );

    if (res.statusCode != 200) return [];

    final data = json.decode(res.body);
    final features = data['features'];

    if (features is! List) return [];

    final scored = <_ScoredSuggestion>[];
    final seen = <String>{};

    for (final f in features) {
      final props = f['properties'];
      final geometry = f['geometry'];

      if (props is! Map) continue;
      if (geometry is! Map) continue;

      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) continue;

      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();

      final name = _buildName(props);
      if (name.trim().isEmpty) continue;

      final key =
          '${_normalize(name)}_${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';

      if (seen.contains(key)) continue;
      seen.add(key);

      final suggestion = PlaceSuggestion(
        name: name,
        location: LatLon(lat, lon),
      );

      scored.add(
        _ScoredSuggestion(
          suggestion: suggestion,
          score: _scoreSuggestion(
            query: originalQuery,
            props: props,
            suggestion: suggestion,
            biasCenter: biasCenter,
          ),
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((e) => e.suggestion).toList();
  }
  Future<List<PlaceSuggestion>> _searchNominatim({
    required String query,
    required LatLon? biasCenter,
  }) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '10',
      },
    );

    final res = await http.get(
      uri,
      headers: const {
        'User-Agent': 'SurpriseRide/1.0',
      },
    ).timeout(
      const Duration(seconds: 8),
    );

    if (res.statusCode != 200) return [];

    final data = json.decode(res.body);

    if (data is! List) return [];

    final results = <PlaceSuggestion>[];

    for (final item in data) {
      if (item is! Map) continue;

      final latText = item['lat']?.toString();
      final lonText = item['lon']?.toString();
      final displayName = item['display_name']?.toString() ?? '';

      if (latText == null || lonText == null || displayName.isEmpty) {
        continue;
      }

      final lat = double.tryParse(latText);
      final lon = double.tryParse(lonText);

      if (lat == null || lon == null) continue;

      results.add(
        PlaceSuggestion(
          name: displayName,
          location: LatLon(lat, lon),
        ),
      );
    }

    if (biasCenter != null) {
      results.sort((a, b) {
        final da = haversineKm(biasCenter, a.location);
        final db = haversineKm(biasCenter, b.location);
        return da.compareTo(db);
      });
    }

    return results;
  }
  int _scoreSuggestion({
    required String query,
    required Map props,
    required PlaceSuggestion suggestion,
    required LatLon? biasCenter,
  }) {
    final qNorm = _normalize(query);
    final nameNorm = _normalize(_clean(props['name']));
    final fullNorm = _normalize(suggestion.name);

    final osmKey = _normalize(_clean(props['osm_key']));
    final osmValue = _normalize(_clean(props['osm_value']));
    final type = _normalize(_clean(props['type']));

    int score = 0;

    if (nameNorm == qNorm) score += 10000;
    if (nameNorm.startsWith(qNorm)) score += 7000;
    if (fullNorm.startsWith(qNorm)) score += 5000;
    if (nameNorm.contains(qNorm)) score += 2500;
    if (fullNorm.contains(qNorm)) score += 1200;

    if (_isCityLike(osmKey, osmValue, type)) score += 5000;
    if (_isVillageLike(osmKey, osmValue, type)) score += 2500;
    if (_isStreetLike(osmKey, osmValue, type)) score -= 4000;
    if (_isHouseLike(osmKey, osmValue, type)) score -= 6000;

    if (biasCenter != null) {
      final distanceKm = haversineKm(biasCenter, suggestion.location);

      if (distanceKm < 30) {
        score += 300;
      } else if (distanceKm < 100) {
        score += 150;
      } else if (distanceKm < 300) {
        score += 50;
      }

      score -= (distanceKm / 25).round();
    }

    return score;
  }

  bool _isCityLike(String osmKey, String osmValue, String type) {
    return osmKey == 'place' &&
        (osmValue == 'city' ||
            osmValue == 'town' ||
            type == 'city' ||
            type == 'town' ||
            type == 'locality');
  }

  bool _isVillageLike(String osmKey, String osmValue, String type) {
    return osmKey == 'place' &&
        (osmValue == 'village' ||
            osmValue == 'hamlet' ||
            osmValue == 'suburb' ||
            type == 'village' ||
            type == 'hamlet' ||
            type == 'suburb');
  }

  bool _isStreetLike(String osmKey, String osmValue, String type) {
    return osmKey == 'highway' ||
        osmValue == 'residential' ||
        osmValue == 'primary' ||
        osmValue == 'secondary' ||
        osmValue == 'tertiary' ||
        osmValue == 'service' ||
        osmValue == 'unclassified' ||
        type == 'street' ||
        type == 'road';
  }

  bool _isHouseLike(String osmKey, String osmValue, String type) {
    return osmKey == 'building' ||
        osmValue == 'house' ||
        osmValue == 'building' ||
        osmValue == 'yes' ||
        type == 'house' ||
        type == 'building';
  }

  String _buildName(Map props) {
    final name = _clean(props['name']);
    final city = _clean(props['city']);
    final state = _clean(props['state']);
    final country = _clean(props['country']);

    final parts = <String>[];

    if (name.isNotEmpty) parts.add(name);
    if (city.isNotEmpty && city != name) parts.add(city);
    if (state.isNotEmpty && state != city && state != name) {
      parts.add(state);
    }
    if (country.isNotEmpty) parts.add(country);

    return parts.join(', ');
  }

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('ā', 'a')
        .replaceAll('ē', 'e')
        .replaceAll('ī', 'i')
        .replaceAll('ū', 'u')
        .replaceAll('ļ', 'l')
        .replaceAll('ņ', 'n')
        .replaceAll('ģ', 'g')
        .replaceAll('ķ', 'k')
        .replaceAll('č', 'c')
        .replaceAll('š', 's')
        .replaceAll('ž', 'z');
  }
}

class _LocalPlace {
  final String name;
  final LatLon location;

  const _LocalPlace(this.name, this.location);
}

class _ScoredSuggestion {
  final PlaceSuggestion suggestion;
  final int score;

  _ScoredSuggestion({
    required this.suggestion,
    required this.score,
  });
}