import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/geo.dart';
import '../models/poi.dart';
import 'poi_history_service.dart';

class SurprisePoiService {
  SurprisePoiService({
    this.apiKey,
  });

  // Atstājam, lai nekas nelūztu citos failos.
  // OSM variantā tas netiek izmantots.
  final String? apiKey;

  static const List<String> _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
  ];

  Future<List<Poi>> fetchPois({
    required LatLon center,
    required double radiusKm,
    double minRating = 4.0,
    int maxResults = 30,
  }) async {
    return fetchPoisInRadius(
      center: center,
      radiusKm: radiusKm,
      minRating: minRating,
      maxResults: maxResults,
    );
  }

  Future<List<Poi>> fetchPoisInRadius({
    required LatLon center,
    required double radiusKm,
    double minRating = 4.0,
    int maxResults = 30,
  }) async {
    final searchCenters = _buildSearchCenters(center, radiusKm);

    final localRadiusMeters = min(
      25000,
      max(3000, (min(radiusKm, 25) * 1000).round()),
    );

    final futures = searchCenters.map((searchCenter) {
      return _fetchOverpassPlaces(
        center: searchCenter,
        radiusMeters: localRadiusMeters,
      );
    }).toList();

    final results = await Future.wait(
      futures.map((f) async {
        try {
          return await f;
        } catch (_) {
          return <_OsmPlace>[];
        }
      }),
    );

    final allCandidates = <_OsmPlace>[
      for (final list in results) ...list,
    ];

    final deduped = _dedupePlaces(allCandidates);

    final withinRequestedRadius = deduped.where((p) {
      final distKm = _haversineKm(center.lat, center.lon, p.lat, p.lon);
      return distKm <= radiusKm;
    }).toList();

    final filtered = withinRequestedRadius.where((p) {
      return _looksInteresting(p);
    }).toList();

    final history = await PoiHistoryService().loadHistory();

    filtered.sort((a, b) {
      final scoreA = _scorePlace(a, center, history);
      final scoreB = _scorePlace(b, center, history);
      return scoreB.compareTo(scoreA);
    });

    final remembered = filtered.where((place) {
      final entry = history[_historyKeyForOsmPlace(place)];

      if (entry == null) {
        return false;
      }

      return entry.selectedCount > 0 || entry.visited;
    }).toList();

    final fresh = filtered.where((place) {
      final entry = history[_historyKeyForOsmPlace(place)];

      if (entry == null) {
        return true;
      }

      return entry.selectedCount == 0 && !entry.visited;
    }).toList();

    final limited = <_OsmPlace>[
      ...remembered.take(maxResults),
      ...fresh.take(max(0, maxResults - remembered.length)),
    ];

    return limited.take(maxResults).map(_osmPlaceToPoi).toList();
  }

  Future<List<_OsmPlace>> _fetchOverpassPlaces({
    required LatLon center,
    required int radiusMeters,
  }) async {
    final query = '''
[out:json][timeout:25];
(
  node(around:$radiusMeters,${center.lat},${center.lon})["tourism"="attraction"];
  way(around:$radiusMeters,${center.lat},${center.lon})["tourism"="attraction"];
  relation(around:$radiusMeters,${center.lat},${center.lon})["tourism"="attraction"];

  node(around:$radiusMeters,${center.lat},${center.lon})["tourism"="museum"];
  way(around:$radiusMeters,${center.lat},${center.lon})["tourism"="museum"];
  relation(around:$radiusMeters,${center.lat},${center.lon})["tourism"="museum"];

  node(around:$radiusMeters,${center.lat},${center.lon})["tourism"="gallery"];
  way(around:$radiusMeters,${center.lat},${center.lon})["tourism"="gallery"];
  relation(around:$radiusMeters,${center.lat},${center.lon})["tourism"="gallery"];

  node(around:$radiusMeters,${center.lat},${center.lon})["tourism"="viewpoint"];
  way(around:$radiusMeters,${center.lat},${center.lon})["tourism"="viewpoint"];
  relation(around:$radiusMeters,${center.lat},${center.lon})["tourism"="viewpoint"];

  node(around:$radiusMeters,${center.lat},${center.lon})["leisure"="park"];
  way(around:$radiusMeters,${center.lat},${center.lon})["leisure"="park"];
  relation(around:$radiusMeters,${center.lat},${center.lon})["leisure"="park"];

  node(around:$radiusMeters,${center.lat},${center.lon})["natural"];
  way(around:$radiusMeters,${center.lat},${center.lon})["natural"];
  relation(around:$radiusMeters,${center.lat},${center.lon})["natural"];

  node(around:$radiusMeters,${center.lat},${center.lon})["historic"];
  way(around:$radiusMeters,${center.lat},${center.lon})["historic"];
  relation(around:$radiusMeters,${center.lat},${center.lon})["historic"];
);
out center tags;
''';

    Object? lastError;

    for (final baseUrl in _overpassUrls) {
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          if (attempt > 0) {
            await Future.delayed(const Duration(seconds: 2));
          }

          final response = await http.post(
            Uri.parse(baseUrl),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'User-Agent': 'FunWeatherRide/1.0',
            },
            body: {
              'data': query,
            },
          );

          if (response.statusCode == 429) {
            lastError = Exception('OSM Overpass kļūda: 429');
            continue;
          }

          if (response.statusCode != 200) {
            lastError =
                Exception('OSM Overpass kļūda: ${response.statusCode}');
            continue;
          }

          final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
          final elements =
          (jsonMap['elements'] as List<dynamic>? ?? const <dynamic>[]);

          return elements
              .map((e) => _OsmPlace.fromOverpass(e as Map<String, dynamic>))
              .whereType<_OsmPlace>()
              .toList();
        } catch (e) {
          lastError = e;
        }
      }
    }

    throw lastError ?? Exception('OSM Overpass nav pieejams');
  }

  List<LatLon> _buildSearchCenters(LatLon center, double radiusKm) {
    final centers = <LatLon>[center];

    if (radiusKm <= 35) {
      return centers;
    }

    final offsetKm = min(radiusKm * 0.45, 22.0);

    centers.add(_offsetLatLon(center, 0, offsetKm));
    centers.add(_offsetLatLon(center, 90, offsetKm));
    centers.add(_offsetLatLon(center, 180, offsetKm));
    centers.add(_offsetLatLon(center, 270, offsetKm));

    if (radiusKm > 90) {
      final diag = min(radiusKm * 0.35, 18.0);
      centers.add(_offsetLatLon(center, 45, diag));
      centers.add(_offsetLatLon(center, 135, diag));
      centers.add(_offsetLatLon(center, 225, diag));
      centers.add(_offsetLatLon(center, 315, diag));
    }

    return centers;
  }

  LatLon _offsetLatLon(LatLon start, double bearingDeg, double distanceKm) {
    const earthRadiusKm = 6371.0;
    final bearing = _degToRad(bearingDeg);

    final lat1 = _degToRad(start.lat);
    final lon1 = _degToRad(start.lon);
    final angularDistance = distanceKm / earthRadiusKm;

    final lat2 = asin(
      sin(lat1) * cos(angularDistance) +
          cos(lat1) * sin(angularDistance) * cos(bearing),
    );

    final lon2 = lon1 +
        atan2(
          sin(bearing) * sin(angularDistance) * cos(lat1),
          cos(angularDistance) - sin(lat1) * sin(lat2),
        );

    return LatLon(_radToDeg(lat2), _radToDeg(lon2));
  }

  List<_OsmPlace> _dedupePlaces(List<_OsmPlace> input) {
    final result = <_OsmPlace>[];

    for (final place in input) {
      final placeName = _normalizePoiName(place.name);

      final duplicateIndex = result.indexWhere((existing) {
        final existingName = _normalizePoiName(existing.name);

        final sameName = existingName == placeName;

        final verySimilarName =
            existingName.contains(placeName) ||
                placeName.contains(existingName);

        final distKm = _haversineKm(
          existing.lat,
          existing.lon,
          place.lat,
          place.lon,
        );

        return (sameName || verySimilarName) && distKm <= 0.5;
      });

      if (duplicateIndex == -1) {
        result.add(place);
        continue;
      }

      final existing = result[duplicateIndex];

      if (_dedupeQualityScore(place) >
          _dedupeQualityScore(existing)) {
        result[duplicateIndex] = place;
      }
    }

    return result;
  }

  String _normalizePoiName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('the ', '')
        .replaceAll('der ', '')
        .replaceAll('die ', '')
        .replaceAll('das ', '');
  }

  int _dedupeQualityScore(_OsmPlace place) {
    var score = 0;
    final tags = place.tags;

    if (tags['tourism'] == 'attraction') score += 50;
    if (tags['tourism'] == 'viewpoint') score += 35;
    if (tags['tourism'] == 'museum') score += 30;

    if (tags.containsKey('wikipedia')) score += 40;
    if (tags.containsKey('wikidata')) score += 35;
    if (tags.containsKey('website')) score += 20;
    if (tags.containsKey('image')) score += 15;
    if (tags.containsKey('description')) score += 10;

    if (tags['natural'] == 'waterfall') score += 60;
    if (tags['historic'] != null) score += 20;

    return score;
  }

  bool _looksInteresting(_OsmPlace p) {
    final tags = p.tags;
    final name = p.name.toLowerCase();
    final hasNumber = RegExp(r'\d').hasMatch(name);

    if ((name.contains('kraater') || name.contains('crater')) && hasNumber) {
      return false;
    }

    const blockedWords = [
      'traktor',
      'kombain',
      'ekskavator',
      'buldozer',
      'lokomobil',
      'mašīn',
      'iekārta',
      'tehnik',
      'tank',
      'tractor',
      'machine',
      'equipment',
      'mi-',
      'helicopter',
      'helikopter',
      'l-',
      'il-',
      'mig',
      'su-',
      'fighter',
      'aircraft',
      'airplane',
      'plane',
      'jet',
      'aviation',
      'military',
      'weapon',
      'cannon',
      'gun',
      'rocket',
      'missile',
    ];

    for (final w in blockedWords) {
      if (name.contains(w)) return false;
    }

    const blockedTourism = {
      'hotel',
      'hostel',
      'guest_house',
      'apartment',
      'camp_site',
      'motel',
      'information',
      'picnic_site',
    };

    const blockedAmenities = {
      'restaurant',
      'cafe',
      'bar',
      'fast_food',
      'pub',
      'biergarten',
      'nightclub',
      'casino',
      'bank',
      'fuel',
      'pharmacy',
      'clinic',
      'hospital',
      'school',
      'parking',
    };

    const blockedShopValues = {
      'mall',
      'supermarket',
      'convenience',
      'clothes',
      'hardware',
    };

    final tourism = (tags['tourism'] ?? '').toLowerCase();
    final amenity = (tags['amenity'] ?? '').toLowerCase();
    final leisure = (tags['leisure'] ?? '').toLowerCase();
    final natural = (tags['natural'] ?? '').toLowerCase();
    final historic = (tags['historic'] ?? '').toLowerCase();
    final geological = (tags['geological'] ?? '').toLowerCase();
    final waterway = (tags['waterway'] ?? '').toLowerCase();
    final shop = (tags['shop'] ?? '').toLowerCase();

    if (blockedTourism.contains(tourism)) return false;
    if (blockedAmenities.contains(amenity)) return false;
    if (blockedShopValues.contains(shop)) return false;

    if (tourism == 'attraction') return true;
    if (tourism == 'museum') return true;
    if (tourism == 'gallery') return true;
    if (tourism == 'viewpoint') return true;

    if (leisure == 'park') return true;

    if (waterway == 'waterfall') return true;

    if (natural == 'cliff') return true;
    if (natural == 'rock') return true;
    if (natural == 'peak') return true;
    if (natural == 'cave_entrance') return true;
    if (natural == 'waterfall') return true;

    if (geological.isNotEmpty) return true;
    if (historic.isNotEmpty) return true;
    if (natural.isNotEmpty) return true;

    if (name.contains('castle')) return true;
    if (name.contains('pils')) return true;
    if (name.contains('muiža')) return true;
    if (name.contains('manor')) return true;
    if (name.contains('museum')) return true;
    if (name.contains('muzej')) return true;
    if (name.contains('park')) return true;
    if (name.contains('viewpoint')) return true;
    if (name.contains('skatu')) return true;
    if (name.contains('trail')) return true;
    if (name.contains('taka')) return true;
    if (name.contains('rock')) return true;
    if (name.contains('waterfall')) return true;
    if (name.contains('ūdenskrit')) return true;
    if (name.contains('cliff')) return true;
    if (name.contains('memorial')) return true;
    if (name.contains('monument')) return true;
    if (name.contains('bazn')) return true;
    if (name.contains('church')) return true;

    return false;
  }

  double _scorePlace(
      _OsmPlace p,
      LatLon center,
      Map<String, PoiHistoryEntry> history,
      ) {
    final distKm = _haversineKm(center.lat, center.lon, p.lat, p.lon);

    double score = 0;

    final tags = p.tags;
    final tourism = (tags['tourism'] ?? '').toLowerCase();
    final natural = (tags['natural'] ?? '').toLowerCase();
    final waterway = (tags['waterway'] ?? '').toLowerCase();
    final geological = (tags['geological'] ?? '').toLowerCase();
    final historic = (tags['historic'] ?? '').toLowerCase();

    final name = p.name.toLowerCase();

    if (tourism == 'attraction') score += 80;
    if (tourism == 'viewpoint') score += 75;
    if (tourism == 'museum') score += 60;
    if (tourism == 'gallery') score += 45;

    if (waterway == 'waterfall') score += 120;

    if (natural == 'waterfall') score += 120;
    if (natural == 'cliff') score += 90;
    if (natural == 'rock') score += 70;
    if (natural == 'peak') score += 55;
    if (natural == 'cave_entrance') score += 65;

    if (geological.isNotEmpty) score += 55;
    if (historic.isNotEmpty) score += 35;

    if (tags.containsKey('wikipedia')) score += 45;
    if (tags.containsKey('wikidata')) score += 40;
    if (tags.containsKey('website')) score += 12;
    if (tags.containsKey('image')) score += 10;
    if (tags.containsKey('description')) score += 8;

    if (name.contains('waterfall')) score += 100;
    if (name.contains('ūdenskrit')) score += 100;
    if (name.contains('cliff')) score += 80;
    if (name.contains('viewpoint')) score += 60;
    if (name.contains('skatu')) score += 60;

    if (name.contains('castle')) score += 50;
    if (name.contains('pils')) score += 50;

    if (name.contains('muiža')) score += 45;
    if (name.contains('manor')) score += 45;

    if (name.contains('museum')) score += 40;
    if (name.contains('muzej')) score += 40;

    if (name.contains('park')) score += 20;

    if (name.contains('trail')) score += 20;
    if (name.contains('taka')) score += 20;

    if (name.contains('church')) score += 15;
    if (name.contains('bazn')) score += 15;

    score += max(0, 25 - distKm * 0.15);
    score -= distKm * 0.03;

    return score;
  }
  String _historyKeyForOsmPlace(_OsmPlace p) {
    final name = p.name.trim().toLowerCase();
    final lat = p.lat.toStringAsFixed(5);
    final lon = p.lon.toStringAsFixed(5);

    return '$name|$lat|$lon';
  }
  Poi _osmPlaceToPoi(_OsmPlace p) {
    final category = _mapCategory(p);
    final visitMinutes = _estimateVisitMinutes(category, p);

    return Poi(
      id: p.id,
      name: p.name,
      location: LatLon(p.lat, p.lon),
      durationH: visitMinutes / 60.0,
      visitMinutes: visitMinutes,
      shortDescription: _buildShortDescription(p),
      categories: {category},
      isIndoor: _inferIndoor(p, category),
    );
  }

  PoiCategory _mapCategory(_OsmPlace p) {
    final tags = p.tags;
    final tourism = (tags['tourism'] ?? '').toLowerCase();
    final leisure = (tags['leisure'] ?? '').toLowerCase();
    final natural = (tags['natural'] ?? '').toLowerCase();
    final historic = (tags['historic'] ?? '').toLowerCase();
    final name = p.name.toLowerCase();

    if (tourism == 'museum' || name.contains('museum') || name.contains('muzej')) {
      return PoiCategory.museum;
    }

    if (tourism == 'viewpoint' ||
        name.contains('viewpoint') ||
        name.contains('lookout') ||
        name.contains('skatu')) {
      return PoiCategory.viewpoint;
    }

    if (leisure == 'park' ||
        natural.isNotEmpty ||
        name.contains('trail') ||
        name.contains('taka') ||
        name.contains('waterfall') ||
        name.contains('rock') ||
        name.contains('beach')) {
      return PoiCategory.nature;
    }

    if (name.contains('beach')) {
      return PoiCategory.beach;
    }

    if (historic.isNotEmpty ||
        tourism == 'attraction' ||
        tourism == 'gallery' ||
        name.contains('castle') ||
        name.contains('pils') ||
        name.contains('muiža') ||
        name.contains('manor') ||
        name.contains('church') ||
        name.contains('bazn')) {
      return PoiCategory.mustSee;
    }

    return PoiCategory.mustSee;
  }

  bool _inferIndoor(_OsmPlace p, PoiCategory category) {
    final tourism = (p.tags['tourism'] ?? '').toLowerCase();
    if (tourism == 'museum') return true;
    if (tourism == 'gallery') return true;
    if (category == PoiCategory.museum) return true;
    return false;
  }

  int _estimateVisitMinutes(PoiCategory category, _OsmPlace p) {
    switch (category) {
      case PoiCategory.museum:
        return 60;
      case PoiCategory.nature:
        return 35;
      case PoiCategory.viewpoint:
        return 20;
      case PoiCategory.beach:
        return 45;
      case PoiCategory.indoor:
        return 60;
      case PoiCategory.food:
        return 45;
      case PoiCategory.city:
        return 40;
      case PoiCategory.mustSee:
        final tourism = (p.tags['tourism'] ?? '').toLowerCase();
        final historic = (p.tags['historic'] ?? '').toLowerCase();

        if (tourism == 'gallery') return 45;
        if (historic.isNotEmpty) return 40;
        return 35;
    }
  }
  String _buildShortDescription(_OsmPlace p) {
    final tags = p.tags;

    final description = tags['description'];
    if (description != null && description.trim().isNotEmpty) {
      return description.trim();
    }

    final tourism = (tags['tourism'] ?? '').toLowerCase();
    final historic = (tags['historic'] ?? '').toLowerCase();
    final natural = (tags['natural'] ?? '').toLowerCase();
    final leisure = (tags['leisure'] ?? '').toLowerCase();

    if (tourism == 'museum') return 'Muzejs';
    if (tourism == 'gallery') return 'Galerija';
    if (tourism == 'viewpoint') return 'Skatu vieta';
    if (leisure == 'park') return 'Parks';
    if (historic.isNotEmpty) return 'Vēsturisks objekts';
    if (natural.isNotEmpty) return 'Dabas objekts';

    return 'Interesants apskates objekts';
  }
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _degToRad(double deg) => deg * pi / 180.0;
  double _radToDeg(double rad) => rad * 180.0 / pi;
}

class _OsmPlace {
  _OsmPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.tags,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final Map<String, String> tags;

  static _OsmPlace? fromOverpass(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    final osmId = (json['id'] ?? '').toString();

    final tagsRaw = (json['tags'] as Map<String, dynamic>? ?? const {});
    final tags = tagsRaw.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
    );

    final lat = (json['lat'] as num?)?.toDouble() ??
        (json['center']?['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble() ??
        (json['center']?['lon'] as num?)?.toDouble();

    if (lat == null || lon == null) {
      throw const FormatException('OSM elementam nav koordinātu');
    }

    final name = _bestNameFromTags(tags);
    if (name == null || name.trim().isEmpty) {
      return null;
    }

    return _OsmPlace(
      id: 'osm_${type}_$osmId',
      name: name.trim(),
      lat: lat,
      lon: lon,
      tags: tags,
    );
  }

  static String? _bestNameFromTags(Map<String, String> tags) {
    return tags['name:lv'] ??
        tags['name:en'] ??
        tags['name'] ??
        tags['official_name'] ??
        tags['loc_name'];
  }
}