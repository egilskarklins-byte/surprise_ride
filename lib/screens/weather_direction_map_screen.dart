import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/app_language_service.dart';
import '../services/weather_direction_service.dart';

class WeatherDirectionMapScreen extends StatelessWidget {
  final double startLat;
  final double startLon;
  final List<DirectionWeatherResult> results;

  const WeatherDirectionMapScreen({
    super.key,
    required this.startLat,
    required this.startLon,
    required this.results,
  });

  // ============================================================
  // ĢEOGRĀFIJA
  // ============================================================

  LatLng _destinationPoint(
      LatLng start,
      double distanceKm,
      double bearingDegrees,
      ) {
    const earthRadiusKm = 6371.0;

    final angularDistance = distanceKm / earthRadiusKm;
    final bearing = bearingDegrees * math.pi / 180.0;

    final lat1 = start.latitude * math.pi / 180.0;
    final lon1 = start.longitude * math.pi / 180.0;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) *
              math.sin(angularDistance) *
              math.cos(bearing),
    );

    final lon2 = lon1 +
        math.atan2(
          math.sin(bearing) *
              math.sin(angularDistance) *
              math.cos(lat1),
          math.cos(angularDistance) -
              math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(
      lat2 * 180.0 / math.pi,
      lon2 * 180.0 / math.pi,
    );
  }

  List<LatLng> _buildSector(
      LatLng center,
      double bearing, {
        double radiusKm = 100,
        double widthDegrees = 45,
      }) {
    final points = <LatLng>[center];

    final startAngle = bearing - widthDegrees / 2;
    final endAngle = bearing + widthDegrees / 2;

    const steps = 24;

    for (int i = 0; i <= steps; i++) {
      final angle =
          startAngle + (endAngle - startAngle) * (i / steps);

      points.add(
        _destinationPoint(
          center,
          radiusKm,
          angle,
        ),
      );
    }

    points.add(center);

    return points;
  }

  // ============================================================
  // SCORE KRĀSAS
  // ============================================================

  Color _scoreColor(double score) {
    if (score >= 85) {
      return const Color(0xFF00C853);
    }

    if (score >= 70) {
      return const Color(0xFF64DD17);
    }

    if (score >= 55) {
      return const Color(0xFFFFD600);
    }

    if (score >= 40) {
      return const Color(0xFFFF9800);
    }

    if (score >= 25) {
      return const Color(0xFFFF5722);
    }

    return const Color(0xFFD50000);
  }

  String _scoreLabel(double score) {
    final isLatvian =
    AppLanguageService.language.value.toLowerCase().startsWith('lv');

    if (score >= 85) {
      return isLatvian ? 'Labākais' : 'Best';
    }

    if (score >= 70) {
      return isLatvian ? 'Labs' : 'Good';
    }

    if (score >= 55) {
      return 'OK';
    }

    if (score >= 40) {
      return isLatvian ? 'Vājš' : 'Poor';
    }

    if (score >= 25) {
      return isLatvian ? 'Slikts' : 'Bad';
    }

    return isLatvian ? 'Ļoti slikts' : 'Terrible';
  }

  // ============================================================
  // VIRZIENU NOSAUKUMI
  // ============================================================

  String _canonicalDirection(String direction) {
    const map = {
      'Z': 'N',
      'ZA': 'NE',
      'A': 'E',
      'DA': 'SE',
      'D': 'S',
      'DR': 'SW',
      'R': 'W',
      'ZR': 'NW',
    };

    return map[direction.toUpperCase()] ??
        direction.toUpperCase();
  }

  String _directionName(String direction) {
    final isLatvian =
    AppLanguageService.language.value.toLowerCase().startsWith('lv');

    final canonical = _canonicalDirection(direction);

    const lvNames = {
      'N': 'Ziemeļi',
      'NE': 'Ziemeļaustrumi',
      'E': 'Austrumi',
      'SE': 'Dienvidaustrumi',
      'S': 'Dienvidi',
      'SW': 'Dienvidrietumi',
      'W': 'Rietumi',
      'NW': 'Ziemeļrietumi',
    };

    const enNames = {
      'N': 'North',
      'NE': 'Northeast',
      'E': 'East',
      'SE': 'Southeast',
      'S': 'South',
      'SW': 'Southwest',
      'W': 'West',
      'NW': 'Northwest',
    };

    return (isLatvian ? lvNames : enNames)[canonical] ??
        canonical;
  }

  String _displayDirectionCode(String direction) {
    final isLatvian =
    AppLanguageService.language.value.toLowerCase().startsWith('lv');

    final canonical = _canonicalDirection(direction);

    if (!isLatvian) {
      return canonical;
    }

    const lvCodes = {
      'N': 'Z',
      'NE': 'ZA',
      'E': 'A',
      'SE': 'DA',
      'S': 'D',
      'SW': 'DR',
      'W': 'R',
      'NW': 'ZR',
    };

    return lvCodes[canonical] ?? canonical;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final center = LatLng(startLat, startLon);

    if (results.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            AppLanguageService.tr(
              lv: 'Nav laikapstākļu datu.',
              en: 'No weather data.',
            ),
          ),
        ),
      );
    }

    // WeatherDirectionService jau sakārto rezultātus
    // no labākā uz sliktāko.
    final best = results.first;

    // ==========================================================
    // 8 KRĀSAINIE SEKTORI
    // ==========================================================

    final polygons = results.map((result) {
      final isBest = identical(result, best);

      return Polygon(
        points: _buildSector(
          center,
          result.bearing,
          radiusKm: 100,
          widthDegrees: 45,
        ),
        color: _scoreColor(result.score).withValues(
          alpha: isBest ? 0.62 : 0.48,
        ),
        borderColor: isBest
            ? Colors.white
            : Colors.white.withValues(alpha: 0.82),
        borderStrokeWidth: isBest ? 3.2 : 1.5,
      );
    }).toList();

    // ==========================================================
    // TEKSTS KATRĀ SEKTORĀ
    // ==========================================================

    final weatherMarkers = results.map((result) {
      final markerPoint = _destinationPoint(
        center,
        67,
        result.bearing,
      );

      final isBest = identical(result, best);

      return Marker(
        point: markerPoint,
        width: 92,
        height: 92,
        child: Container(
          alignment: Alignment.center,
          decoration: isBest
              ? BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.22),
            border: Border.all(
              color: Colors.white,
              width: 2.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 12,
              ),
            ],
          )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _displayDirectionCode(result.direction),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isBest ? 19 : 17,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 1),

              Text(
                '${result.score.round()}/100',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isBest ? 17 : 15,
                  fontWeight: FontWeight.w800,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 1),

              Text(
                _scoreLabel(result.score),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isBest ? 11 : 10,
                  fontWeight: FontWeight.w700,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor:
        const Color(0xFF101522).withValues(alpha: 0.94),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          AppLanguageService.tr(
            lv: 'Labākais virziens šodien',
            en: 'Best direction today',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: Stack(
        children: [
          // ====================================================
          // KARTE
          // ====================================================

          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 7.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'lv.surpriseride.app',
              ),

              // -----------------------------------------------
              // VISI 8 WEATHER SEKTORI
              // -----------------------------------------------

              PolygonLayer(
                polygons: polygons,
              ),

              // -----------------------------------------------
              // 100 KM ĀRĒJAIS APLIS
              // -----------------------------------------------

              CircleLayer(
                circles: [
                  CircleMarker(
                    point: center,
                    radius: 100000,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor:
                    Colors.white.withValues(alpha: 0.95),
                    borderStrokeWidth: 2.5,
                  ),
                ],
              ),

              // -----------------------------------------------
              // VIRZIENU SCORE TEKSTI
              // -----------------------------------------------

              MarkerLayer(
                markers: weatherMarkers,
              ),

              // -----------------------------------------------
              // STARTA / LIETOTĀJA PUNKTS
              // -----------------------------------------------

              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 62,
                    height: 62,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E57C2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ====================================================
          // AUGŠĒJĀ TUMŠĀ / GLASS KARTĪTE
          // ====================================================

          Positioned(
            left: 16,
            right: 16,
            top: 92,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 15,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF101522)
                    .withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: const Color(0xFFB348FF)
                      .withValues(alpha: 0.80),
                  width: 1.6,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC857)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wb_sunny_outlined,
                      color: Color(0xFFFFC857),
                      size: 34,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLanguageService.tr(
                            lv: 'Šodien labākais virziens',
                            en: 'Best direction today',
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          '${_directionName(best.direction)} '
                              '(${_displayDirectionCode(best.direction)})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          AppLanguageService.tr(
                            lv:
                            '⭐ ${best.score.round()}/100 • līdz 100 km',
                            en:
                            '⭐ ${best.score.round()}/100 • up to 100 km',
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ====================================================
          // APAKŠĒJĀ WEATHER KRĀSU SKALA
          // ====================================================

          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  15,
                  16,
                  13,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF101522)
                      .withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF17BEBB)
                        .withValues(alpha: 0.60),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // -----------------------------------------
                    // KRĀSU GRADIENTS
                    // -----------------------------------------

                    Container(
                      height: 17,
                      decoration: BoxDecoration(
                        borderRadius:
                        BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00C853),
                            Color(0xFF64DD17),
                            Color(0xFFFFD600),
                            Color(0xFFFF9800),
                            Color(0xFFFF5722),
                            Color(0xFFD50000),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // -----------------------------------------
                    // SKALAS NOSAUKUMI
                    // -----------------------------------------

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLanguageService.tr(
                            lv: 'Labākais',
                            en: 'Best',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          AppLanguageService.tr(
                            lv: 'Labs',
                            en: 'Good',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFB2FF59),
                            fontSize: 10,
                          ),
                        ),

                        const Text(
                          'OK',
                          style: TextStyle(
                            color: Color(0xFFFFEA00),
                            fontSize: 10,
                          ),
                        ),

                        Text(
                          AppLanguageService.tr(
                            lv: 'Vājš',
                            en: 'Poor',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFFFAB40),
                            fontSize: 10,
                          ),
                        ),

                        Text(
                          AppLanguageService.tr(
                            lv: 'Slikts',
                            en: 'Bad',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFFF7043),
                            fontSize: 10,
                          ),
                        ),

                        Text(
                          AppLanguageService.tr(
                            lv: 'Ļoti slikts',
                            en: 'Terrible',
                          ),
                          style: const TextStyle(
                            color: Color(0xFFFF5252),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      AppLanguageService.tr(
                        lv:
                        'Laikapstākļu novērtējums katrā virzienā • līdz 100 km',
                        en:
                        'Weather rating for each direction • up to 100 km',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}