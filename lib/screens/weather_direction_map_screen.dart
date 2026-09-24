import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/app_language_service.dart';
import '../services/weather_direction_service.dart';
import '../services/city_direction_service.dart';

class WeatherDirectionMapScreen extends StatefulWidget {
  final double startLat;
  final double startLon;
  final List<DirectionWeatherResult> results;

  const WeatherDirectionMapScreen({
    super.key,
    required this.startLat,
    required this.startLon,
    required this.results,
  });

  @override
  State<WeatherDirectionMapScreen> createState() =>
      _WeatherDirectionMapScreenState();
}

class _WeatherDirectionMapScreenState
    extends State<WeatherDirectionMapScreen>
    with TickerProviderStateMixin {
  final CityDirectionService _cityService = const CityDirectionService();

  List<DirectionCity> _cities = [];
  bool _isLoadingCities = false;

  late final AnimationController _bestMarkerController;
  late final Animation<double> _bestMarkerAnimation;
  late final AnimationController _backArrowController;
  final MapController _mapController = MapController();
  late final AnimationController _mapPanController;
  @override
  void initState() {
    super.initState();

    _bestMarkerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _bestMarkerAnimation = CurvedAnimation(
      parent: _bestMarkerController,
      curve: Curves.easeInOutCubic,
    );

    _bestMarkerController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _backArrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    _mapPanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadCities();
  }

  @override
  void dispose() {
    _bestMarkerController.dispose();
    _backArrowController.dispose();
    _mapPanController.dispose();
    super.dispose();
  }

  double _bearingBetween(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaLon = (lon2 - lon1) * math.pi / 180;

    final y = math.sin(deltaLon) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;

    return (bearing + 360) % 360;
  }

  bool _isInBestSector(double cityBearing, double bestBearing) {
    var difference = (cityBearing - bestBearing).abs();

    if (difference > 180) {
      difference = 360 - difference;
    }

    return difference <= 22.5;
  }
  void _panMapToCities(List<DirectionCity> cities) {
    if (cities.isEmpty) return;

    double minLat = cities.first.lat;
    double maxLat = cities.first.lat;
    double minLon = cities.first.lon;
    double maxLon = cities.first.lon;

    for (final city in cities) {
      minLat = math.min(minLat, city.lat);
      maxLat = math.max(maxLat, city.lat);
      minLon = math.min(minLon, city.lon);
      maxLon = math.max(maxLon, city.lon);
    }

    final targetCenter = LatLng(
      (minLat + maxLat) / 2,
      (minLon + maxLon) / 2,
    );

    final startCenter = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;

    _mapPanController.stop();
    _mapPanController.reset();

    void listener() {
      if (!mounted) return;

      final t = Curves.easeInOutCubic.transform(
        _mapPanController.value,
      );

      final lat = startCenter.latitude +
          (targetCenter.latitude - startCenter.latitude) * t;

      final lon = startCenter.longitude +
          (targetCenter.longitude - startCenter.longitude) * t;

      _mapController.move(
        LatLng(lat, lon),
        currentZoom,
      );
    }

    _mapPanController.addListener(listener);

    _mapPanController.forward().whenComplete(() {
      _mapPanController.removeListener(listener);
    });
  }
  Future<void> _loadCities() async {
    debugPrint('🏙️ LOAD CITIES START');

    if (widget.results.isEmpty) return;

    setState(() {
      _isLoadingCities = true;
    });

    try {
      final best = widget.results.first;

      final startPoint = LatLng(
        widget.startLat,
        widget.startLon,
      );

      final searchCenter = _destinationPoint(
        startPoint,
        70,
        best.bearing,
      );

      final cities = await _cityService.fetchCities(
        centerLat: searchCenter.latitude,
        centerLon: searchCenter.longitude,
        radiusKm: 85,
        maxResults: 120,
      );

      final sectorCities = cities.where((city) {
        final cityBearing = _bearingBetween(
          widget.startLat,
          widget.startLon,
          city.lat,
          city.lon,
        );

        return _isInBestSector(
          cityBearing,
          best.bearing,
        );
      }).take(5).toList();

      debugPrint(
        '🏙️ BEST SECTOR CITIES: '
            '${sectorCities.map((e) => e.name).toList()}',
      );

      if (!mounted) return;

      setState(() {
        _cities = sectorCities;
        _isLoadingCities = false;
      });

      // Kad pilsētas ir parādījušās,
      // Best aplis gludi brauc no 67 km uz centru.
      if (sectorCities.isNotEmpty) {
        _bestMarkerController.forward(from: 0);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          _panMapToCities(sectorCities);
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cities = [];
        _isLoadingCities = false;
      });

      debugPrint('🏙️ CITY LOAD ERROR: $e');
    }
  }

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
    final now = DateTime.now();

    final updatedTime =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final center = LatLng(
      widget.startLat,
      widget.startLon,
    );

    if (widget.results.isEmpty) {
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

    final best = widget.results.first;

    // ==========================================================
    // 8 KRĀSAINIE SEKTORI
    // ==========================================================

    final polygons = widget.results.map((result) {
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
    // PILSĒTU MARKERI
    // ==========================================================

    final cityMarkers = _cities.map((city) {
      return Marker(
        point: city.location,
        width: 120,
        height: 38,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF063F35),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: IntrinsicWidth(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF17BEBB),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      child: Text(
                        city.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();

    // ==========================================================
    // WEATHER SCORE MARKERI
    // ==========================================================

    final normalWeatherMarkers = <Marker>[];
    Marker? bestWeatherMarker;

    for (final result in widget.results) {
      final isBest = identical(result, best);

      // Parastie markeri paliek 67 km attālumā.
      // Best markeris pēc pilsētu ielādes animējas 67 -> 0 km.
      double markerDistanceKm = 67.0;

      if (isBest && _cities.isNotEmpty) {
        markerDistanceKm =
            67.0 * (1.0 - _bestMarkerAnimation.value);
      }

      final markerPoint = _destinationPoint(
        center,
        markerDistanceKm,
        result.bearing,
      );

      final marker = Marker(
        point: markerPoint,
        width: 92,
        height: 92,
        child: Container(
          alignment: Alignment.center,
          decoration: isBest
              ? BoxDecoration(
            shape: BoxShape.circle,
            color: _scoreColor(result.score).withValues(alpha: 0.99),
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
                '${(result.score / 10).floor()}/10',
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

      if (isBest) {
        bestWeatherMarker = marker;
      } else {
        normalWeatherMarkers.add(marker);
      }
    }

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
        leading: AnimatedBuilder(
          animation: _backArrowController,
          builder: (context, child) {
            final progress = _backArrowController.value;

            double scale = 1.0;
            double turns = 0.0;
            double glow = 0.25;

            if (progress < 0.50) {
              // 0–3 s: pulsē + mirdz.
              final pulse =
                  (math.sin(progress / 0.50 * math.pi * 4) + 1) / 2;

              scale = 1.0 + (0.12 * pulse);
              glow = 0.25 + (0.55 * pulse);
            } else if (progress < 0.83) {
              // 3–5 s: viens pilns, mierīgs apgrieziens.
              final rotateProgress =
                  (progress - 0.50) / 0.33;

              turns = rotateProgress;
              scale = 1.08;
              glow = 0.65;
            } else {
              // 5–6 s: atkal mierīgi pulsē.
              final pulse =
                  (math.sin((progress - 0.83) / 0.17 * math.pi * 2) + 1) / 2;

              scale = 1.0 + (0.10 * pulse);
              glow = 0.25 + (0.45 * pulse);
            }

            return Center(
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFB348FF).withValues(
                      alpha: 0.12,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB348FF).withValues(
                          alpha: glow,
                        ),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    icon: Transform.rotate(
                      angle: turns * 2 * math.pi,
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
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
            mapController: _mapController,
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

              // 8 WEATHER SEKTORI
              PolygonLayer(
                polygons: polygons,
              ),

              // 100 KM ĀRĒJAIS APLIS
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

              // Pārējo 7 sektoru teksti.
              MarkerLayer(
                markers: normalWeatherMarkers,
              ),

              // Lillā starta punkts tiek zīmēts pirms Best,
              // lai Best aplis animācijas beigās būtu tam virsū.
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

              // PILSĒTAS / GALAMĒRĶI
              MarkerLayer(
                markers: cityMarkers,
              ),

              // Best tiek zīmēts pats pēdējais.
              // Tādēļ centrā tas būs virs lillā punkta.
              if (bestWeatherMarker != null)
                MarkerLayer(
                  markers: [bestWeatherMarker],
                ),
            ],
          ),

          // ====================================================
          // AUGŠĒJĀ TUMŠĀ / GLASS KARTĪTE
          // ====================================================

          Positioned(
            left: 14,
            right: 14,
            top: 92,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC857)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wb_sunny_outlined,
                      color: Color(0xFFFFC857),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppLanguageService.tr(
                                  lv: 'Šodien labākais virziens',
                                  en: 'Best direction today',
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              updatedTime,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                            '⭐ ${(best.score / 10).floor()}/10 • līdz 100 km',
                            en:
                            '⭐ ${(best.score / 10).floor()}/10 • up to 100 km',
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