import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/geo.dart';
import '../models/poi.dart';
import 'poi_history_service.dart';
import 'app_language_service.dart';
import 'package:flutter/foundation.dart';
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

    final localRadiusMeters = max(
      3000,
      (radiusKm * 1000).round(),
    );

    final futures = searchCenters.map((searchCenter) {
      return _fetchOverpassPlaces(
        center: searchCenter,
        radiusMeters: localRadiusMeters,
      );
    }).toList();
    final totalSw = Stopwatch()..start();
    final overpassSw = Stopwatch()..start();
    final results = await Future.wait(
      futures.map((f) async {
        try {
          return await f;
        } catch (_) {
          return <_OsmPlace>[];
        }
      }),
    );
    overpassSw.stop();
    debugPrint('⏱ POI PERF 1 Overpass: ${overpassSw.elapsedMilliseconds} ms');
    final dedupeSw = Stopwatch()..start();
    final allCandidates = <_OsmPlace>[
      for (final list in results) ...list,
    ];
    debugPrint('📊 All candidates: ${allCandidates.length}');
    final deduped = _dedupePlaces(allCandidates);
    debugPrint('📊 Deduped: ${deduped.length}');
    dedupeSw.stop();
    debugPrint('⏱ POI PERF 2 Dedupe: ${dedupeSw.elapsedMilliseconds} ms');
    final filterSw = Stopwatch()..start();
    final withinRequestedRadius = deduped.where((p) {
      final distKm = _haversineKm(center.lat, center.lon, p.lat, p.lon);
      return distKm <= radiusKm;
    }).toList();
    debugPrint('📊 Within radius: ${withinRequestedRadius.length}');
    final filtered = withinRequestedRadius.where((p) {
      return _looksInteresting(p);
    }).toList();
    debugPrint('📊 Filtered: ${filtered.length}');
    filterSw.stop();
    debugPrint('⏱ POI PERF 3 Filter: ${filterSw.elapsedMilliseconds} ms');
    final sortSw = Stopwatch()..start();
    final historySw = Stopwatch()..start();
    final history = await PoiHistoryService().loadHistory();
    historySw.stop();
    debugPrint('⏱ POI PERF 4a History: ${historySw.elapsedMilliseconds} ms');

    final scoreSw = Stopwatch()..start();

    final scores = <_OsmPlace, double>{
      for (final place in filtered)
        place: _scorePlace(place, center, history),
    };

    scoreSw.stop();
    debugPrint(
      '⏱ POI PERF 4b Score: ${scoreSw.elapsedMilliseconds} ms',
    );

    final sortOnlySw = Stopwatch()..start();

    filtered.sort((a, b) {
      return scores[b]!.compareTo(scores[a]!);
    });

    sortOnlySw.stop();
    debugPrint(
      '⏱ POI PERF 4c Sort only: ${sortOnlySw.elapsedMilliseconds} ms',
    );

    final diversifySw = Stopwatch()..start();

    final diversifiedRaw = _diversifyResults(
      filtered,
      limit: max(maxResults * 10, 300),
    );

    diversifySw.stop();
    debugPrint(
      '⏱ POI PERF 4d Diversify: ${diversifySw.elapsedMilliseconds} ms',
    );

    final duplicateLimitSw = Stopwatch()..start();

    final diversified = _limitSensitiveDuplicates(diversifiedRaw);

    duplicateLimitSw.stop();
    debugPrint(
      '⏱ POI PERF 4e Duplicate limit: '
          '${duplicateLimitSw.elapsedMilliseconds} ms',
    );

    final finalSelectionSw = Stopwatch()..start();

    final remembered = diversified.where((place) {
      final entry = history[_historyKeyForOsmPlace(place)];

      if (entry == null) {
        return false;
      }

      return entry.selectedCount > 0 || entry.visited;
    }).toList();

    final fresh = diversified.where((place) {
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
    finalSelectionSw.stop();
    debugPrint(
      '⏱ POI PERF 4f Final selection: '
          '${finalSelectionSw.elapsedMilliseconds} ms',
    );
    sortSw.stop();
    debugPrint('⏱ POI PERF 4 Sort: ${sortSw.elapsedMilliseconds} ms');

    totalSw.stop();
    debugPrint('⏱ POI PERF 5 TOTAL: ${totalSw.elapsedMilliseconds} ms');
    return limited.take(maxResults).map(_osmPlaceToPoi).toList();
  }

  Future<List<_OsmPlace>> _fetchOverpassPlaces({
    required LatLon center,
    required int radiusMeters,
  }) async {
    final query = '''
[out:json][timeout:45];
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
    return <LatLon>[center];
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
    final byKey = <String, _OsmPlace>{};

    for (final place in input) {
      final normalizedName = _normalizePoiName(place.name);

      final key = place.id.isNotEmpty
          ? 'id:${place.id}'
          : 'fallback:$normalizedName:${place.lat.toStringAsFixed(4)}:${place.lon.toStringAsFixed(4)}';

      final existing = byKey[key];

      if (existing == null) {
        byKey[key] = place;
        continue;
      }

      if (_dedupeQualityScore(place) > _dedupeQualityScore(existing)) {
        byKey[key] = place;
      }
    }

    return byKey.values.toList();
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

    String tag(String key) => (tags[key] ?? '').toLowerCase();

    final tourism = tag('tourism');
    final amenity = tag('amenity');
    final leisure = tag('leisure');
    final natural = tag('natural');
    final historic = tag('historic');
    final geological = tag('geological');
    final waterway = tag('waterway');
    final shop = tag('shop');
    final manMade = tag('man_made');
    final attraction = tag('attraction');
    final heritage = tag('heritage');

    final hasStrongMeta =
        tags.containsKey('wikipedia') ||
            tags.containsKey('wikidata') ||
            tags.containsKey('website') ||
            tags.containsKey('image') ||
            tags.containsKey('description') ||
            heritage.isNotEmpty;

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
      'tractor',
      'machine',
      'equipment',
      'mi-',
      'helicopter',
      'helikopter',
      'fighter',
      'aircraft',
      'airplane',
      'plane',
      'jet',
      'aviation',
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

    if (blockedTourism.contains(tourism)) return false;
    if (blockedAmenities.contains(amenity)) return false;
    if (blockedShopValues.contains(shop)) return false;

    if (tourism == 'attraction') return true;
    if (tourism == 'museum') return true;
    if (tourism == 'gallery') return true;
    if (tourism == 'viewpoint') return true;

    if (waterway == 'waterfall') return true;

    if (natural == 'waterfall') return true;
    if (natural == 'cliff') return true;
    if (natural == 'rock') return true;
    if (natural == 'peak') return true;
    if (natural == 'cave_entrance') return true;
    if (natural == 'spring' && hasStrongMeta) return true;
    if (natural == 'beach' && hasStrongMeta) return true;

    if (geological == 'outcrop') return true;
    if (geological == 'moraine') return true;
    if (geological == 'palaeontological_site') return true;
    if (geological.isNotEmpty && hasStrongMeta) return true;

    const goodHistoric = {
      'castle',
      'manor',
      'ruins',
      'archaeological_site',
      'monument',
      'memorial',
      'wayside_cross',
      'church',
      'fort',
      'tower',
    };

    if (goodHistoric.contains(historic)) return true;
    if (historic.isNotEmpty && hasStrongMeta) return true;

    if (leisure == 'park' && hasStrongMeta) return true;

    if (manMade == 'tower' && hasStrongMeta) return true;
    if (attraction.isNotEmpty && attraction != 'animal') return true;

    final importantName =
        name.contains('castle') ||
            name.contains('pils') ||
            name.contains('muiža') ||
            name.contains('manor') ||
            name.contains('museum') ||
            name.contains('muzej') ||
            name.contains('viewpoint') ||
            name.contains('skatu') ||
            name.contains('waterfall') ||
            name.contains('ūdenskrit') ||
            name.contains('cliff') ||
            name.contains('panga') ||
            name.contains('rock') ||
            name.contains('cave') ||
            name.contains('ala') ||
            name.contains('memorial') ||
            name.contains('monument') ||
            name.contains('bazn') ||
            name.contains('church');

    if (importantName) return true;

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

    String tag(String key) => (tags[key] ?? '').toLowerCase();

    final tourism = tag('tourism');
    final natural = tag('natural');
    final waterway = tag('waterway');
    final geological = tag('geological');
    final historic = tag('historic');
    final leisure = tag('leisure');
    final manMade = tag('man_made');
    final heritage = tag('heritage');

    final name = p.name.toLowerCase();

    if (tourism == 'attraction') score += 85;
    if (tourism == 'viewpoint') score += 90;
    if (tourism == 'museum') score += 75;
    if (tourism == 'gallery') score += 45;

    if (waterway == 'waterfall') score += 130;

    if (natural == 'waterfall') score += 130;
    if (natural == 'cliff') score += 115;
    if (natural == 'rock') score += 75;
    if (natural == 'peak') score += 60;
    if (natural == 'cave_entrance') score += 75;
    if (natural == 'spring') score += 25;
    if (natural == 'beach') score += 25;

    if (geological == 'outcrop') score += 70;
    if (geological == 'moraine') score += 45;
    if (geological == 'palaeontological_site') score += 60;
    if (geological.isNotEmpty) score += 25;

    if (historic == 'castle') score += 95;
    if (historic == 'manor') score += 90;
    if (historic == 'ruins') score += 65;
    if (historic == 'archaeological_site') score += 55;
    if (historic == 'monument') score += 50;
    if (historic == 'memorial') score += 40;
    if (historic == 'fort') score += 55;
    if (historic == 'tower') score += 45;
    if (historic.isNotEmpty) score += 20;

    if (leisure == 'park') score += 25;
    if (manMade == 'tower') score += 35;
    if (heritage.isNotEmpty) score += 35;

    if (tags.containsKey('wikipedia')) score += 55;
    if (tags.containsKey('wikidata')) score += 45;
    if (tags.containsKey('website')) score += 12;
    if (tags.containsKey('image')) score += 12;
    if (tags.containsKey('description')) score += 10;

    if (name.contains('panga')) score += 120;
    if (name.contains('waterfall')) score += 80;
    if (name.contains('ūdenskrit')) score += 80;
    if (name.contains('cliff')) score += 70;
    if (name.contains('viewpoint')) score += 50;
    if (name.contains('skatu')) score += 50;

    if (name.contains('castle')) score += 45;
    if (name.contains('pils')) score += 45;
    if (name.contains('muiža')) score += 40;
    if (name.contains('manor')) score += 40;

    if (name.contains('museum')) score += 35;
    if (name.contains('muzej')) score += 35;

    if (name.contains('cave')) score += 35;
    if (name.contains('ala')) score += 35;
    if (name.contains('church')) score += 20;
    if (name.contains('bazn')) score += 20;

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
  String? _buildInfoUrl(_OsmPlace p) {
    final tags = p.tags;

    final website = tags['website'];
    if (website != null && website.trim().isNotEmpty) {
      return website.trim();
    }

    final wikipedia = tags['wikipedia'];
    if (wikipedia != null && wikipedia.trim().isNotEmpty) {
      final parts = wikipedia.split(':');

      if (parts.length >= 2) {
        final lang = parts.first;
        final title = parts.sublist(1).join(':').replaceAll(' ', '_');
        return 'https://$lang.wikipedia.org/wiki/$title';
      }
    }

    final wikidata = tags['wikidata'];
    if (wikidata != null && wikidata.trim().isNotEmpty) {
      return 'https://www.wikidata.org/wiki/${wikidata.trim()}';
    }

    return null;
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
      infoUrl: _buildInfoUrl(p),
      categories: {category},
      isIndoor: _inferIndoor(p, category),
    );
  }

  PoiCategory _mapCategory(_OsmPlace p) {
    final tags = p.tags;

    final tourism = (tags['tourism'] ?? '').toLowerCase();
    final natural = (tags['natural'] ?? '').toLowerCase();
    final historic = (tags['historic'] ?? '').toLowerCase();

    final name = p.name.toLowerCase();

    // 🏛 Muzeji
    if (tourism == 'museum' ||
        tourism == 'gallery' ||
        name.contains('museum') ||
        name.contains('muzej')) {
      return PoiCategory.museum;
    }

    // 🏰 Pils / Muiža / Pilskalns
    if (name.contains('castle') ||
        name.contains('pils') ||
        name.contains('muiža') ||
        name.contains('manor') ||
        name.contains('pilskalns') ||
        name.contains('hillfort') ||
        name.contains('piliakalnis')) {
      return PoiCategory.castle;
    }

    // ⛪ Baznīcas
    if (name.contains('church') ||
        name.contains('cathedral') ||
        name.contains('bazn')) {
      return PoiCategory.church;
    }

    // 🗿 Pieminekļi
    if (historic == 'monument' ||
        historic == 'memorial' ||
        name.contains('monument') ||
        name.contains('memorial')) {
      return PoiCategory.monument;
    }

    // 🌲 Daba
    if (natural.isNotEmpty) {
      return PoiCategory.nature;
    }

    if (tourism == 'viewpoint') {
      return PoiCategory.nature;
    }

    // ⭐ Viss pārējais interesantais
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
      case PoiCategory.castle:
        return 50;

      case PoiCategory.museum:
        return 60;

      case PoiCategory.nature:
        return 35;

      case PoiCategory.church:
        return 25;

      case PoiCategory.monument:
        return 20;

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
    if (description != null && description
        .trim()
        .isNotEmpty) {
      return description.trim();
    }

    final tourism = (tags['tourism'] ?? '').toLowerCase();
    final historic = (tags['historic'] ?? '').toLowerCase();
    final natural = (tags['natural'] ?? '').toLowerCase();
    final leisure = (tags['leisure'] ?? '').toLowerCase();

    if (tourism == 'museum') {
      return AppLanguageService.tr(
        lv: 'Muzejs',
        en: 'Museum',
      );
    }

    if (tourism == 'gallery') {
      return AppLanguageService.tr(
        lv: 'Galerija',
        en: 'Gallery',
      );
    }

    if (tourism == 'viewpoint') {
      return AppLanguageService.tr(
        lv: 'Skatu vieta',
        en: 'Viewpoint',
      );
    }

    if (leisure == 'park') {
      return AppLanguageService.tr(
        lv: 'Parks',
        en: 'Park',
      );
    }

    if (historic.isNotEmpty) {
      return AppLanguageService.tr(
        lv: 'Vēsturisks objekts',
        en: 'Historical place',
      );
    }

    if (natural.isNotEmpty) {
      return AppLanguageService.tr(
        lv: 'Dabas objekts',
        en: 'Natural place',
      );
    }

    return AppLanguageService.tr(
      lv: 'Interesants apskates objekts',
      en: 'Interesting place',
    );
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
List<_OsmPlace> _diversifyResults(
    List<_OsmPlace> input, {
      required int limit,
    }) {
  final remaining = List<_OsmPlace>.from(input);
  final result = <_OsmPlace>[];

  final categoryCounts = <String, int>{};
  final subtypeCounts = <String, int>{};

  final targetCount = min(limit, remaining.length);

  while (remaining.isNotEmpty && result.length < targetCount) {
    _OsmPlace? bestPlace;
    double bestScore = double.negativeInfinity;

    for (final place in remaining) {
      final category = _diversityCategory(place);
      final subtype = _diversitySubtype(place);

      final categoryCount = categoryCounts[category] ?? 0;
      final subtypeCount = subtypeCounts[subtype] ?? 0;

      var score = 1000.0;

      score -= categoryCount * 80;
      score -= subtypeCount * 140;

      if (result.isNotEmpty) {
        final previousSubtype = _diversitySubtype(result.last);

        if (previousSubtype == subtype) {
          score -= 220;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestPlace = place;
      }
    }

    if (bestPlace == null) break;

    result.add(bestPlace);
    remaining.remove(bestPlace);

    final category = _diversityCategory(bestPlace);
    final subtype = _diversitySubtype(bestPlace);

    categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    subtypeCounts[subtype] = (subtypeCounts[subtype] ?? 0) + 1;
  }

  return result;
}
List<_OsmPlace> _limitSensitiveDuplicates(List<_OsmPlace> input) {
  final result = <_OsmPlace>[];

  var cemeteryCount = 0;

  for (final place in input) {
    if (_isCemeteryLike(place)) {
      cemeteryCount++;

      if (cemeteryCount > 1) {
        continue;
      }
    }

    result.add(place);
  }

  return result;
}

bool _isCemeteryLike(_OsmPlace place) {
  final name = place.name.toLowerCase();
  final historic = (place.tags['historic'] ?? '').toLowerCase();
  final cemetery = (place.tags['cemetery'] ?? '').toLowerCase();
  final landuse = (place.tags['landuse'] ?? '').toLowerCase();

  return name.contains('kapi') ||
      name.contains('kapu') ||
      name.contains('cemetery') ||
      name.contains('grave') ||
      name.contains('graves') ||
      historic == 'cemetery' ||
      cemetery.isNotEmpty ||
      landuse == 'cemetery';
}
String _diversityCategory(_OsmPlace p) {
  final tags = p.tags;

  final tourism = (tags['tourism'] ?? '').toLowerCase();
  final natural = (tags['natural'] ?? '').toLowerCase();
  final historic = (tags['historic'] ?? '').toLowerCase();

  final name = p.name.toLowerCase();

  if (tourism == 'museum' || tourism == 'gallery') {
    return 'museum';
  }

  if (tourism == 'viewpoint') {
    return 'viewpoint';
  }

  if (natural.isNotEmpty) {
    return 'nature';
  }

  if (name.contains('pils') ||
      name.contains('castle') ||
      name.contains('muiža') ||
      name.contains('manor') ||
      name.contains('pilskalns') ||
      name.contains('hillfort') ||
      name.contains('piliakalnis')) {
    return 'castle';
  }

  if (historic == 'monument' ||
      historic == 'memorial') {
    return 'monument';
  }

  return 'other';
}

String _diversitySubtype(_OsmPlace p) {
  final tags = p.tags;

  final tourism = (tags['tourism'] ?? '').toLowerCase();
  final natural = (tags['natural'] ?? '').toLowerCase();
  final historic = (tags['historic'] ?? '').toLowerCase();
  final name = p.name.toLowerCase();

  if (name.contains('piliakalnis') ||
      name.contains('pilskalns') ||
      name.contains('hillfort') ||
      historic == 'archaeological_site') {
    return 'hillfort';
  }

  if (tourism == 'museum') return 'museum';
  if (tourism == 'gallery') return 'gallery';
  if (tourism == 'viewpoint') return 'viewpoint';

  if (natural == 'waterfall') return 'waterfall';
  if (natural == 'cliff') return 'cliff';
  if (natural == 'rock') return 'rock';
  if (natural == 'peak') return 'peak';
  if (natural.isNotEmpty) return 'nature';

  if (name.contains('church') || name.contains('bazn')) {
    return 'church';
  }

  if (historic == 'monument' ||
      historic == 'memorial' ||
      name.contains('monument') ||
      name.contains('memorial')) {
    return 'monument';
  }

  if (name.contains('castle') ||
      name.contains('pils') ||
      name.contains('muiža') ||
      name.contains('manor')) {
    return 'castle';
  }

  return 'other';
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