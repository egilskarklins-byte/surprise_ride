import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/poi.dart';

class PoiHistoryEntry {
  final String key;
  final String name;
  final double lat;
  final double lon;
  final int generatedCount;
  final int selectedCount;
  final bool visited;

  const PoiHistoryEntry({
    required this.key,
    required this.name,
    required this.lat,
    required this.lon,
    required this.generatedCount,
    required this.selectedCount,
    required this.visited,
  });

  PoiHistoryEntry copyWith({
    int? generatedCount,
    int? selectedCount,
    bool? visited,
  }) {
    return PoiHistoryEntry(
      key: key,
      name: name,
      lat: lat,
      lon: lon,
      generatedCount: generatedCount ?? this.generatedCount,
      selectedCount: selectedCount ?? this.selectedCount,
      visited: visited ?? this.visited,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'lat': lat,
      'lon': lon,
      'generatedCount': generatedCount,
      'selectedCount': selectedCount,
      'visited': visited,
    };
  }

  factory PoiHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PoiHistoryEntry(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0,
      generatedCount: json['generatedCount'] as int? ?? 0,
      selectedCount: json['selectedCount'] as int? ?? 0,
      visited: json['visited'] as bool? ?? false,
    );
  }
}

class PoiHistoryService {
  static const String _storageKey = 'poi_history_v1';

  Future<Map<String, PoiHistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    return decoded.map((key, value) {
      return MapEntry(
        key,
        PoiHistoryEntry.fromJson(value as Map<String, dynamic>),
      );
    });
  }

  Future<void> saveHistory(Map<String, PoiHistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = history.map((key, value) {
      return MapEntry(key, value.toJson());
    });

    await prefs.setString(_storageKey, jsonEncode(encoded));
  }

  Future<PoiHistoryEntry?> getEntry(Poi poi) async {
    final history = await loadHistory();
    return history[_poiKey(poi)];
  }

  Future<void> markGenerated(List<Poi> pois) async {
    final history = await loadHistory();

    for (final poi in pois) {
      final key = _poiKey(poi);
      final existing = history[key];

      if (existing == null) {
        history[key] = PoiHistoryEntry(
          key: key,
          name: poi.name,
          lat: poi.location.lat,
          lon: poi.location.lon,
          generatedCount: 1,
          selectedCount: 0,
          visited: false,
        );
      } else {
        history[key] = existing.copyWith(
          generatedCount: existing.generatedCount + 1,
        );
      }
    }

    await saveHistory(history);
  }

  Future<PoiHistoryEntry> markSelected(Poi poi) async {
    final history = await loadHistory();
    final key = _poiKey(poi);
    final existing = history[key];

    final updated = existing == null
        ? PoiHistoryEntry(
      key: key,
      name: poi.name,
      lat: poi.location.lat,
      lon: poi.location.lon,
      generatedCount: 0,
      selectedCount: 1,
      visited: false,
    )
        : existing.copyWith(
      selectedCount: existing.selectedCount + 1,
    );

    history[key] = updated;
    await saveHistory(history);

    return updated;
  }

  Future<void> markVisited(Poi poi) async {
    final history = await loadHistory();
    final key = _poiKey(poi);
    final existing = history[key];

    history[key] = existing == null
        ? PoiHistoryEntry(
      key: key,
      name: poi.name,
      lat: poi.location.lat,
      lon: poi.location.lon,
      generatedCount: 0,
      selectedCount: 0,
      visited: true,
    )
        : existing.copyWith(visited: true);

    await saveHistory(history);
  }

  String _poiKey(Poi poi) {
    final name = poi.name.trim().toLowerCase();
    final lat = poi.location.lat.toStringAsFixed(5);
    final lon = poi.location.lon.toStringAsFixed(5);

    return '$name|$lat|$lon';
  }
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}