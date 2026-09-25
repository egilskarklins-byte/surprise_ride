import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/geo.dart';
import '../models/poi.dart';
import 'dart:math' as math;

class LocalPoiDatabase {
  LocalPoiDatabase._();

  static final LocalPoiDatabase instance = LocalPoiDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'surprise_ride_pois.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pois (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,

            lat REAL NOT NULL,
            lon REAL NOT NULL,

            duration_h REAL NOT NULL DEFAULT 1.5,
            visit_minutes INTEGER NOT NULL DEFAULT 30,

            short_description TEXT,
            info_url TEXT,

            categories TEXT NOT NULL,
            is_indoor INTEGER NOT NULL DEFAULT 0,
            needs_drivable_access INTEGER NOT NULL DEFAULT 0,

            cached_at INTEGER NOT NULL
          )
        ''');

        // Ātrākai meklēšanai pēc koordinātām.
        await db.execute(
          'CREATE INDEX idx_pois_lat_lon ON pois(lat, lon)',
        );

        await db.execute(
          'CREATE INDEX idx_pois_cached_at ON pois(cached_at)',
        );
      },
    );
  }

  // ------------------------------------------------------------
  // POI -> SQLite
  // ------------------------------------------------------------

  Map<String, Object?> _poiToMap(Poi poi) {
    return {
      'id': poi.id,
      'name': poi.name,
      'lat': poi.location.lat,
      'lon': poi.location.lon,
      'duration_h': poi.durationH,
      'visit_minutes': poi.visitMinutes,
      'short_description': poi.shortDescription,
      'info_url': poi.infoUrl,

      // Saglabājam enum nosaukumus, piem.:
      // castle,museum,viewpoint
      'categories': poi.categories.map((e) => e.name).join(','),

      'is_indoor': poi.isIndoor ? 1 : 0,
      'needs_drivable_access': poi.needsDrivableAccess ? 1 : 0,

      'cached_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // ------------------------------------------------------------
  // SQLite -> POI
  // ------------------------------------------------------------

  Poi _mapToPoi(Map<String, Object?> map) {
    final categoryString = map['categories'] as String? ?? '';

    final categories = categoryString
        .split(',')
        .where((value) => value.isNotEmpty)
        .map(
          (value) => PoiCategory.values.firstWhere(
            (category) => category.name == value,
        orElse: () => PoiCategory.mustSee,
      ),
    )
        .toSet();

    return Poi(
      id: map['id'] as String,
      name: map['name'] as String,
      location: LatLon(
        (map['lat'] as num).toDouble(),
        (map['lon'] as num).toDouble(),
      ),
      durationH:
      (map['duration_h'] as num?)?.toDouble() ?? 1.5,
      visitMinutes:
      (map['visit_minutes'] as num?)?.toInt() ?? 30,
      shortDescription: map['short_description'] as String?,
      infoUrl: map['info_url'] as String?,
      categories: categories.isEmpty
          ? const {PoiCategory.mustSee}
          : categories,
      isIndoor: (map['is_indoor'] as int? ?? 0) == 1,
      needsDrivableAccess:
      (map['needs_drivable_access'] as int? ?? 0) == 1,
    );
  }

  // ------------------------------------------------------------
  // SAGLABĀ VIENU POI
  // ------------------------------------------------------------

  Future<void> savePoi(Poi poi) async {
    final db = await database;

    await db.insert(
      'pois',
      _poiToMap(poi),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ------------------------------------------------------------
  // SAGLABĀ VAIRĀKUS POI
  // ------------------------------------------------------------

  Future<void> savePois(Iterable<Poi> pois) async {
    if (pois.isEmpty) return;

    final db = await database;
    final batch = db.batch();

    final now = DateTime.now().millisecondsSinceEpoch;

    for (final poi in pois) {
      final data = _poiToMap(poi);

      // Visiem šīs porcijas POI viens cache laiks.
      data['cached_at'] = now;

      batch.insert(
        'pois',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ------------------------------------------------------------
  // ATROD POI AP CENTRU
  // ------------------------------------------------------------

  Future<List<Poi>> getPoisNear({
    required LatLon center,
    required double radiusKm,
    int limit = 200,
  }) async {
    final db = await database;

    // Vispirms paņemam kandidātus no taisnstūra.
    // Precīzo attālumu pārbaudām Dart pusē.
    final latDelta = radiusKm / 111.32;

    final cosLat = _cosDegrees(center.lat).abs();
    final safeCos = cosLat < 0.01 ? 0.01 : cosLat;

    final lonDelta = radiusKm / (111.32 * safeCos);

    final rows = await db.query(
      'pois',
      where: '''
        lat BETWEEN ? AND ?
        AND lon BETWEEN ? AND ?
      ''',
      whereArgs: [
        center.lat - latDelta,
        center.lat + latDelta,
        center.lon - lonDelta,
        center.lon + lonDelta,
      ],
      limit: limit * 3,
    );

    final result = <_PoiDistance>[];

    for (final row in rows) {
      final poi = _mapToPoi(row);

      final distanceKm = _distanceKm(
        center.lat,
        center.lon,
        poi.location.lat,
        poi.location.lon,
      );

      if (distanceKm <= radiusKm) {
        result.add(
          _PoiDistance(
            poi: poi,
            distanceKm: distanceKm,
          ),
        );
      }
    }

    // Tuvākie vispirms.
    result.sort(
          (a, b) => a.distanceKm.compareTo(b.distanceKm),
    );

    return result
        .take(limit)
        .map((item) => item.poi)
        .toList();
  }

  // ------------------------------------------------------------
  // CACHE VECUMS
  // ------------------------------------------------------------

  Future<bool> hasFreshPoisNear({
    required LatLon center,
    required double radiusKm,
    Duration maxAge = const Duration(days: 30),
    int minimumCount = 5,
  }) async {
    final db = await database;

    final oldestAllowed =
        DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

    final latDelta = radiusKm / 111.32;

    final cosLat = _cosDegrees(center.lat).abs();
    final safeCos = cosLat < 0.01 ? 0.01 : cosLat;

    final lonDelta = radiusKm / (111.32 * safeCos);

    final rows = await db.query(
      'pois',
      columns: [
        'lat',
        'lon',
      ],
      where: '''
        cached_at >= ?
        AND lat BETWEEN ? AND ?
        AND lon BETWEEN ? AND ?
      ''',
      whereArgs: [
        oldestAllowed,
        center.lat - latDelta,
        center.lat + latDelta,
        center.lon - lonDelta,
        center.lon + lonDelta,
      ],
    );

    var count = 0;

    for (final row in rows) {
      final lat = (row['lat'] as num).toDouble();
      final lon = (row['lon'] as num).toDouble();

      if (_distanceKm(
        center.lat,
        center.lon,
        lat,
        lon,
      ) <=
          radiusKm) {
        count++;

        if (count >= minimumCount) {
          return true;
        }
      }
    }

    return false;
  }

  // ------------------------------------------------------------
  // DZĒŠ VECO CACHE
  // ------------------------------------------------------------

  Future<int> deleteOlderThan(
      Duration age,
      ) async {
    final db = await database;

    final cutoff =
        DateTime.now().subtract(age).millisecondsSinceEpoch;

    return db.delete(
      'pois',
      where: 'cached_at < ?',
      whereArgs: [cutoff],
    );
  }

  // ------------------------------------------------------------
  // DEBUG / STATISTIKA
  // ------------------------------------------------------------

  Future<int> countPois() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM pois',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ------------------------------------------------------------
  // ATTĀLUMS
  // ------------------------------------------------------------

  double _distanceKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
            _cosDegrees(lat1) *
                _cosDegrees(lat2) *
                _sin(dLon / 2) *
                _sin(dLon / 2);

    final c = 2 * _atan2(
      _sqrt(a),
      _sqrt(1 - a),
    );

    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * 0.017453292519943295;
  }

  double _sin(double value) => math.sin(value);

  double _sqrt(double value) => math.sqrt(value);

  double _atan2(double y, double x) => math.atan2(y, x);

  double _cosDegrees(double degrees) {
    return math.cos(_degreesToRadians(degrees));
  }
}

// ----------------------------------------------------------------
// Mazs iekšējais modelis POI + attālums.
// ----------------------------------------------------------------

class _PoiDistance {
  final Poi poi;
  final double distanceKm;

  const _PoiDistance({
    required this.poi,
    required this.distanceKm,
  });
}