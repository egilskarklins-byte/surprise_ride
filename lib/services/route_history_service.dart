import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/geo.dart';
import '../models/poi.dart';

class SavedRoute {
  final String id;
  final DateTime createdAt;
  final LatLon start;
  final List<Poi> pois;

  const SavedRoute({
    required this.id,
    required this.createdAt,
    required this.start,
    required this.pois,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'start': {
        'lat': start.lat,
        'lon': start.lon,
      },
      'pois': pois.map((p) {
        return {
          'id': p.id,
          'name': p.name,
          'lat': p.location.lat,
          'lon': p.location.lon,
          'durationH': p.durationH,
          'visitMinutes': p.visitMinutes,
          'shortDescription': p.shortDescription,
          'infoUrl': p.infoUrl,
          'categories': p.categories.map((c) => c.name).toList(),
          'isIndoor': p.isIndoor,
        };
      }).toList(),
    };
  }

  static SavedRoute fromJson(Map<String, dynamic> json) {
    final startJson = json['start'] as Map<String, dynamic>;
    final poisJson = json['pois'] as List<dynamic>;

    return SavedRoute(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      start: LatLon(
        (startJson['lat'] as num).toDouble(),
        (startJson['lon'] as num).toDouble(),
      ),
      pois: poisJson.map((raw) {
        final p = raw as Map<String, dynamic>;

        final categoryNames =
        (p['categories'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toSet();

        final categories = PoiCategory.values
            .where((c) => categoryNames.contains(c.name))
            .toSet();

        return Poi(
          id: p['id'] as String,
          name: p['name'] as String,
          location: LatLon(
            (p['lat'] as num).toDouble(),
            (p['lon'] as num).toDouble(),
          ),
          durationH: (p['durationH'] as num?)?.toDouble() ?? 1.5,
          visitMinutes: (p['visitMinutes'] as num?)?.toInt() ?? 30,
          shortDescription: p['shortDescription'] as String?,
          infoUrl: p['infoUrl'] as String?,
          categories: categories.isEmpty
              ? const {PoiCategory.mustSee}
              : categories,
          isIndoor: p['isIndoor'] as bool? ?? false,
        );
      }).toList(),
    );
  }
}

class RouteHistoryService {
  static const _key = 'saved_routes_v1';

  Future<List<SavedRoute>> loadRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_key) ?? const [];

    return rawList
        .map((raw) {
      try {
        return SavedRoute.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        return null;
      }
    })
        .whereType<SavedRoute>()
        .toList();
  }

  Future<void> saveRoute({
    required LatLon start,
    required List<Poi> pois,
  }) async {
    if (pois.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? const [];

    final route = SavedRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      start: start,
      pois: pois,
    );

    final updated = [
      jsonEncode(route.toJson()),
      ...existing,
    ].take(50).toList();

    await prefs.setStringList(_key, updated);
  }

  Future<void> clearRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}