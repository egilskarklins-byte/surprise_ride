import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/geo.dart';

class DrivableAccessResult {
  final LatLon point;
  final double distanceMeters;

  const DrivableAccessResult({
    required this.point,
    required this.distanceMeters,
  });
}

enum DrivableAccessLookupStatus {
  found,
  noDrivableRoad,
  lookupFailed,
}

class DrivableAccessLookupResult {
  final DrivableAccessLookupStatus status;
  final DrivableAccessResult? access;

  const DrivableAccessLookupResult({
    required this.status,
    this.access,
  });
}

class DrivableAccessService {
  static const List<String> _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
  ];

  /// Atrod POI tuvumā punktu uz ceļa, kas paredzēts auto satiksmei.
  ///
  /// Atgriež atrasto ceļa punktu + attālumu līdz POI metros.
  /// Ja piemērots ceļš netiek atrasts, atgriež null.
  Future<DrivableAccessResult?> findNearestDrivablePoint(
      LatLon poi, {
        double searchRadiusMeters = 1500,
      }) async {
    final query = '''
[out:json][timeout:20];
way(around:${searchRadiusMeters.round()},${poi.lat},${poi.lon})
  ["highway"]
  ["highway"!~"footway|path|pedestrian|steps|cycleway|bridleway|corridor|construction|proposed|raceway"];
out geom;
''';

    for (final url in _overpassUrls) {
      try {
        final response = await http
            .post(
          Uri.parse(url),
          headers: const {
            'Accept': 'application/json',
            'Content-Type':
            'application/x-www-form-urlencoded; charset=UTF-8',
            'User-Agent': 'SurpriseRide/1.0',
          },
          body: {
            'data': query,
          },
        )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode != 200) {
          print(
            '🚗 ACCESS HTTP [$url]: ${response.statusCode} '
                '${response.body.substring(
              0,
              response.body.length > 200 ? 200 : response.body.length,
            )}',
          );
          continue;
        }

        final data = jsonDecode(response.body);
        final elements = data['elements'];

        if (elements is! List) {
          continue;
        }

        print(
          '🚗 ACCESS DEBUG: Overpass returned ${elements.length} ways',
        );

        final highwayTypes = <String, int>{};

        for (final element in elements) {
          if (element is! Map<String, dynamic>) continue;

          final tags = element['tags'];
          if (tags is! Map<String, dynamic>) continue;

          final highway =
              tags['highway']?.toString() ?? 'UNKNOWN';

          highwayTypes[highway] =
              (highwayTypes[highway] ?? 0) + 1;
        }

        print(
          '🚗 ACCESS DEBUG highway types: $highwayTypes',
        );

        LatLon? bestPoint;
        double bestDistanceMeters = double.infinity;

        for (final element in elements) {
          if (element is! Map<String, dynamic>) continue;

          final tags = element['tags'];

          if (tags is! Map<String, dynamic>) continue;

          if (!_isDrivable(tags)) continue;

          final geometry = element['geometry'];

          if (geometry is! List) continue;

          for (final node in geometry) {
            if (node is! Map<String, dynamic>) continue;

            final lat = node['lat'];
            final lon = node['lon'];

            if (lat is! num || lon is! num) continue;

            final point = LatLon(
              lat.toDouble(),
              lon.toDouble(),
            );

            final distanceMeters = _distanceMeters(
              poi,
              point,
            );

            if (distanceMeters < bestDistanceMeters) {
              bestDistanceMeters = distanceMeters;
              bestPoint = point;
            }
          }
        }

        if (bestPoint != null) {
          print(
            '🚗 ACCESS DEBUG nearest distance: '
                '${bestDistanceMeters.toStringAsFixed(0)} m',
          );

          return DrivableAccessResult(
            point: bestPoint,
            distanceMeters: bestDistanceMeters,
          );
        }
      } catch (e) {
        print('🚗 ACCESS ERROR [$url]: $e');
      }
    }

    return null;
  }

  Future<DrivableAccessLookupResult>
  findNearestDrivablePointDetailed(
      LatLon poi, {
        double searchRadiusMeters = 1500,
      }) async {
    final query = '''
[out:json][timeout:20];
way(around:${searchRadiusMeters.round()},${poi.lat},${poi.lon})
  ["highway"]
  ["highway"!~"footway|path|pedestrian|steps|cycleway|bridleway|corridor|construction|proposed|raceway"];
out geom;
''';

    var hadSuccessfulResponse = false;

    for (final url in _overpassUrls) {
      try {
        final response = await http
            .post(
          Uri.parse(url),
          headers: const {
            'Accept': 'application/json',
            'Content-Type':
            'application/x-www-form-urlencoded; charset=UTF-8',
            'User-Agent': 'SurpriseRide/1.0',
          },
          body: {
            'data': query,
          },
        )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode != 200) {
          print(
            '🚗 ACCESS HTTP [$url]: ${response.statusCode}',
          );
          continue;
        }

        final data = jsonDecode(response.body);
        final elements = data['elements'];

        if (elements is! List) {
          continue;
        }

        hadSuccessfulResponse = true;

        LatLon? bestPoint;
        double bestDistanceMeters = double.infinity;

        String? bestHighway;
        String? bestAccess;
        String? bestMotorVehicle;
        String? bestMotorcar;
        String? bestService;
        String? bestSurface;

        for (final element in elements) {
          if (element is! Map<String, dynamic>) continue;

          final tags = element['tags'];
          if (tags is! Map<String, dynamic>) continue;

          if (!_isDrivable(tags)) continue;

          final geometry = element['geometry'];
          if (geometry is! List) continue;

          for (final node in geometry) {
            if (node is! Map<String, dynamic>) continue;

            final lat = node['lat'];
            final lon = node['lon'];

            if (lat is! num || lon is! num) continue;

            final point = LatLon(
              lat.toDouble(),
              lon.toDouble(),
            );

            final distanceMeters =
            _distanceMeters(poi, point);

            if (distanceMeters < bestDistanceMeters) {
              bestDistanceMeters = distanceMeters;
              bestPoint = point;

              bestHighway =
                  tags['highway']?.toString();
              bestAccess =
                  tags['access']?.toString();
              bestMotorVehicle =
                  tags['motor_vehicle']?.toString();
              bestMotorcar =
                  tags['motorcar']?.toString();
              bestService =
                  tags['service']?.toString();
              bestSurface =
                  tags['surface']?.toString();
            }
          }
        }

        if (bestPoint != null) {
          print(
            '🚗 ACCESS CHOSEN: '
                'highway=$bestHighway, '
                'service=$bestService, '
                'access=$bestAccess, '
                'motor_vehicle=$bestMotorVehicle, '
                'motorcar=$bestMotorcar, '
                'surface=$bestSurface, '
                'lat=${bestPoint.lat}, '
                'lon=${bestPoint.lon}, '
                'distance=${bestDistanceMeters.toStringAsFixed(0)} m',
          );

          return DrivableAccessLookupResult(
            status: DrivableAccessLookupStatus.found,
            access: DrivableAccessResult(
              point: bestPoint,
              distanceMeters: bestDistanceMeters,
            ),
          );
        }
      } catch (e) {
        print('🚗 ACCESS ERROR [$url]: $e');
      }
    }

    if (hadSuccessfulResponse) {
      return const DrivableAccessLookupResult(
        status:
        DrivableAccessLookupStatus.noDrivableRoad,
      );
    }

    return const DrivableAccessLookupResult(
      status: DrivableAccessLookupStatus.lookupFailed,
    );
  }

  bool _isDrivable(Map<String, dynamic> tags) {
    final highway = tags['highway']?.toString();

    if (highway == null || highway.isEmpty) {
      return false;
    }

    const allowedHighways = {
      'motorway',
      'motorway_link',
      'trunk',
      'trunk_link',
      'primary',
      'primary_link',
      'secondary',
      'secondary_link',
      'tertiary',
      'tertiary_link',
      'unclassified',
      'residential',
      'living_street',
      'service',
      'road',

    };

    if (!allowedHighways.contains(highway)) {
      return false;
    }

    final access = tags['access']?.toString();

    // Skaidri aizliegtu piekļuvi neizmantojam.
    if (access == 'private' || access == 'no') {
      return false;
    }

    final motorVehicle =
    tags['motor_vehicle']?.toString();

    if (motorVehicle == 'no' ||
        motorVehicle == 'private') {
      return false;
    }

    final motorcar = tags['motorcar']?.toString();

    if (motorcar == 'no' ||
        motorcar == 'private') {
      return false;
    }

    return true;
  }

  double _distanceMeters(
      LatLon a,
      LatLon b,
      ) {
    const earthRadiusMeters = 6371000.0;

    final lat1 = _toRadians(a.lat);
    final lat2 = _toRadians(b.lat);

    final deltaLat = _toRadians(
      b.lat - a.lat,
    );

    final deltaLon = _toRadians(
      b.lon - a.lon,
    );

    final sinLat = sin(deltaLat / 2);
    final sinLon = sin(deltaLon / 2);

    final haversine =
        sinLat * sinLat +
            cos(lat1) *
                cos(lat2) *
                sinLon *
                sinLon;

    final centralAngle = 2 *
        atan2(
          sqrt(haversine),
          sqrt(1 - haversine),
        );

    return earthRadiusMeters * centralAngle;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }
}