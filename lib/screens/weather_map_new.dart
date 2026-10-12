
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/app_language_service.dart';
import '../../../services/weather_direction_service.dart';
import '../../../services/city_direction_service.dart';
import '../../../widgets/admob_banner.dart';

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
  final CityDirectionService _cityService =
      const CityDirectionService();

  List<DirectionCity> _cities = [];
  bool _isLoadingCities = false;
  int _selectedHoursAhead = 0;
  bool _showSectorHint = true;

  late List<DirectionWeatherResult> _weatherResults;

  bool _isLoadingWeather = false;
  bool _showWeatherAd = false;
  bool _isFillingMissing = false;
  bool _missingRetryFinished = false;

  int _weatherRequestId = 0;
  int _cityRequestId = 0;

  static const _allBearings = <double>[
    0, 45, 90, 135, 180, 225, 270, 315,
  ];

  late final AnimationController _bestMarkerController;
  late final Animation<double> _bestMarkerAnimation;
  late final AnimationController _backArrowController;

  final MapController _mapController = MapController();
  late final AnimationController _mapPanController;


  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showSectorHint = false;
        });
      }
    });

    _weatherResults =
        List<DirectionWeatherResult>.from(widget.results);

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fillMissingSectors(_weatherRequestId);
      }
    });
  }

  @override
  void dispose() {
    _weatherRequestId++;
    _cityRequestId++;

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
        math.sin(phi1) *
            math.cos(phi2) *
            math.cos(deltaLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;

    return (bearing + 360) % 360;
  }

  bool _isInBestSector(
    double cityBearing,
    double bestBearing,
  ) {
    var difference =
        (cityBearing - bestBearing).abs();

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

  // ============================================================
  // AUTOMĀTISKA TRŪKSTOŠO SEKTORU AIZPILDĪŠANA
  // ============================================================

  List<String> _getMissingDirections() {
    const directionNames = <String>[
      'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW',
    ];

    final existingBearings = _weatherResults
        .map((result) => result.bearing.round())
        .toSet();

    final missing = <String>[];

    for (int i = 0; i < _allBearings.length; i++) {
      if (!existingBearings.contains(_allBearings[i].round())) {
        missing.add(directionNames[i]);
      }
    }

    return missing;
  }

  void _mergeWeatherResults(
    List<DirectionWeatherResult> incoming,
  ) {
    final byBearing = <int, DirectionWeatherResult>{};

    for (final result in _weatherResults) {
      byBearing[result.bearing.round()] = result;
    }

    for (final result in incoming) {
      byBearing[result.bearing.round()] = result;
    }

    _weatherResults = byBearing.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  Future<void> _fillMissingSectors(int requestId) async {
    if (_isFillingMissing || _isLoadingWeather) return;

    final missing = _getMissingDirections();

    if (missing.isEmpty) {
      if (mounted) {
        setState(() {
          _missingRetryFinished = true;
        });
      }
      return;
    }

    final hoursAhead = _selectedHoursAhead;

    setState(() {
      _isFillingMissing = true;
      _missingRetryFinished = false;
    });

    try {
      final service = WeatherDirectionService();

      // Atkārtojam tikai trūkstošos virzienus.
      final recovered = await service.getDirections(
        startLat: widget.startLat,
        startLon: widget.startLon,
        languageCode: AppLanguageService.language.value,
        distanceKm: 100,
        hoursAhead: hoursAhead,
        onlyDirections: missing,
      );

      // Veca pieprasījuma rezultāti nedrīkst pārrakstīt
      // cita izvēlētā laika laikapstākļus.
      if (!mounted ||
          requestId != _weatherRequestId ||
          hoursAhead != _selectedHoursAhead) {
        return;
      }

      if (recovered.isNotEmpty) {
        final previousBest = _weatherResults.isNotEmpty
            ? _weatherResults.first.bearing
            : null;

        setState(() {
          _mergeWeatherResults(recovered);
        });

        final newBest = _weatherResults.first.bearing;

        if (previousBest != newBest) {
          _bestMarkerController.reset();
          _loadCities();
        }
      }
    } catch (error) {
      debugPrint('Missing weather sectors error: $error');
    } finally {
      if (mounted &&
          requestId == _weatherRequestId &&
          hoursAhead == _selectedHoursAhead) {
        setState(() {
          _isFillingMissing = false;
          _missingRetryFinished = true;
        });
      }
    }
  }

  // ============================================================
  // PROGNOZES LAIKA PĀRSLĒGŠANA
  // ============================================================

  Future<void> _changeWeatherHour(int hoursAhead) async {
    if (_isLoadingWeather) return;

    final isRetry = _selectedHoursAhead == hoursAhead;

    if (isRetry && _weatherResults.length == 8) {
      return;
    }

    // Atceļam iepriekšējo fona rezultātu izmantošanu.
    final requestId = ++_weatherRequestId;

    setState(() {
      _selectedHoursAhead = hoursAhead;
      _isLoadingWeather = true;
      _isFillingMissing = false;
      _missingRetryFinished = false;
      _showWeatherAd = !isRetry;
    });

    try {
      final service = WeatherDirectionService();

      final results = await service.getBestDirections(
        startLat: widget.startLat,
        startLon: widget.startLon,
        languageCode: AppLanguageService.language.value,
        distanceKm: 100,
        hoursAhead: hoursAhead,
      );

      if (!mounted || requestId != _weatherRequestId) {
        return;
      }

      if (results.isEmpty) {
        throw Exception('No weather results');
      }

      setState(() {
        _weatherResults = results;
        _cities = [];
        _isLoadingWeather = false;

      });

      _bestMarkerController.reset();
      _loadCities();

      // Karte jau ir redzama, reklāma paslēpta.
      // Trūkstošos sektorus ielādējam fonā.
      _fillMissingSectors(requestId);
    } catch (error) {
      debugPrint('Weather hour change error: $error');

      if (!mounted || requestId != _weatherRequestId) {
        return;
      }

      setState(() {
        _isLoadingWeather = false;
        _showWeatherAd = false;
        _missingRetryFinished = true;
      });
    }
  }

  // ============================================================
  // PILSĒTU IELĀDE LABĀKAJĀ SEKTORĀ
  // ============================================================

  Future<void> _loadCities() async {
    if (_weatherResults.isEmpty) return;

    final requestId = ++_cityRequestId;
    final best = _weatherResults.first;

    debugPrint('🏙️ LOAD CITIES START');

    setState(() {
      _isLoadingCities = true;
    });

    try {
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

      if (!mounted || requestId != _cityRequestId) {
        return;
      }

      debugPrint(
        '🏙️ BEST SECTOR CITIES: '
        '${sectorCities.map((e) => e.name).toList()}',
      );

      setState(() {
        _cities = sectorCities;
        _isLoadingCities = false;
      });

      if (sectorCities.isNotEmpty) {
        _bestMarkerController.forward(from: 0);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || requestId != _cityRequestId) {
            return;
          }

          _panMapToCities(sectorCities);
        });
      }
    } catch (error) {
      if (!mounted || requestId != _cityRequestId) {
        return;
      }

      setState(() {
        _cities = [];
        _isLoadingCities = false;
      });

      debugPrint('🏙️ CITY LOAD ERROR: $error');
    }
  }

  // ============================================================
  // LAIKAPSTĀKĻU DETALIZĒTAIS POPUP
  // ============================================================

  void _showSectorWeather(DirectionWeatherResult result) {
    final isLatvian =
        AppLanguageService.language.value
            .toLowerCase()
            .startsWith('lv');

    final selectedHours = _selectedHoursAhead;

    final timeLabel = selectedHours == 0
        ? (isLatvian ? 'Tagad' : 'Now')
        : '+$selectedHours h';

    String number(double? value, int decimals) {
      return value == null
          ? '—'
          : value.toStringAsFixed(decimals);
    }

    Widget detailRow(
      IconData icon,
      String label,
      String value,
    ) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF17BEBB),
              size: 23,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(
              20, 14, 20, 24,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF101522),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFB348FF),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 24,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _scoreColor(result.score),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '${(result.score / 10).floor()}/10',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _directionName(result.direction),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_displayDirectionCode(result.direction)}'
                              '  •  $timeLabel'
                              '  •  ${_scoreLabel(result.score)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  detailRow(
                    Icons.thermostat,
                    isLatvian
                        ? 'Temperatūra'
                        : 'Temperature',
                    '${number(result.tempC, 1)} °C',
                  ),
                  detailRow(
                    Icons.water_drop_outlined,
                    isLatvian
                        ? 'Nokrišņu iespējamība'
                        : 'Rain probability',
                    '${number(result.precipitationProbability, 0)} %',
                  ),
                  detailRow(
                    Icons.umbrella_outlined,
                    isLatvian
                        ? 'Nokrišņu daudzums'
                        : 'Precipitation',
                    '${number(result.rainMm, 1)} mm',
                  ),
                  detailRow(
                    Icons.air,
                    isLatvian ? 'Vējš' : 'Wind',
                    '${number(result.windMs, 1)} m/s',
                  ),
                  detailRow(
                    Icons.air_outlined,
                    isLatvian
                        ? 'Vēja brāzmas'
                        : 'Wind gusts',
                    '${number(result.windGustMs, 1)} m/s',
                  ),
                  detailRow(
                    Icons.cloud_outlined,
                    isLatvian
                        ? 'Mākoņainība'
                        : 'Cloud cover',
                    '${number(result.cloudCover, 0)} %',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isLatvian
                        ? 'Laikapstākļu novērtējums'
                        : 'Weather assessment',
                    style: const TextStyle(
                      color: Color(0xFF17BEBB),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.reason,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
  // LAIKAPSTĀKĻU VĒRTĒJUMA KRĀSAS
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
        AppLanguageService.language.value
            .toLowerCase()
            .startsWith('lv');

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
    const aliases = {
      'Z': 'N',
      'ZA': 'NE',
      'A': 'E',
      'DA': 'SE',
      'D': 'S',
      'DR': 'SW',
      'R': 'W',
      'ZR': 'NW',
    };

    return aliases[direction.toUpperCase()] ??
        direction.toUpperCase();
  }

  String _directionName(String direction) {
    final isLatvian =
        AppLanguageService.language.value
            .toLowerCase()
            .startsWith('lv');

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
        AppLanguageService.language.value
            .toLowerCase()
            .startsWith('lv');

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
  // TRŪKSTOŠO SEKTORU STATUSS
  // ============================================================

  String _missingSectorLabel() {
    if (_isFillingMissing) {
      return AppLanguageService.tr(
        lv: 'Meklē...',
        en: 'Searching...',
      );
    }

    return AppLanguageService.tr(
      lv: 'Nav datu',
      en: 'No data',
    );
  }

  DirectionWeatherResult? _resultForBearing(double bearing) {
    for (final result in _weatherResults) {
      if (result.bearing.round() == bearing.round()) {
        return result;
      }
    }

    return null;
  }

  // ============================================================
  // SEKTORU KARTES ELEMENTI
  // ============================================================

  List<Polygon> _buildWeatherPolygons(LatLng center) {
    return _allBearings.map((bearing) {
      final result = _resultForBearing(bearing);

      final color = result == null
          ? const Color(0xFF253044)
          : _scoreColor(result.score);

      return Polygon(
        points: _buildSector(
          center,
          bearing,
          radiusKm: 100,
        ),
        color: color.withValues(
          alpha: result == null
              ? 0.22
              : (_weatherResults.isNotEmpty &&
              identical(result, _weatherResults.first)
              ? 0.62
              : 0.48),
        ),
        borderColor: Colors.white,
        borderStrokeWidth: 2.0,
      );
    }).toList();
  }

  // Marķieris atrodas katra sektora vidū, 65 km
  // attālumā no sākumpunkta.
  List<Marker> _buildSectorMarkers(LatLng center) {
    return _allBearings.map((bearing) {
      final result = _resultForBearing(bearing);

      final isBest = result != null &&
          _weatherResults.isNotEmpty &&
          identical(result, _weatherResults.first);

      double markerDistanceKm = 67.0;

      if (isBest) {
        markerDistanceKm =
            67.0 * (1.0 - _bestMarkerAnimation.value);
      }

      final position = _destinationPoint(
        center,
        markerDistanceKm,
        bearing,
      );

      return Marker(
        point: position,
        width: 66,
        height: 66,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_showSectorHint) {
              setState(() {
                _showSectorHint = false;
              });
            }
            if (result != null) {
              _showSectorWeather(result);
            } else {
              _showMissingSectorInfo(bearing);
            }
          },
          child: result == null
              ? _buildMissingSectorMarker(bearing)
              : _buildWeatherSectorMarker(result),
        ),
      );
    }).toList();
  }

  // ============================================================
  // SEKTORS AR SAŅEMTIEM LAIKAPSTĀKĻIEM
  // ============================================================

  Widget _buildWeatherSectorMarker(
      DirectionWeatherResult result,
      ) {
    final score10 = (result.score / 10).floor();
    final isBest = _weatherResults.isNotEmpty &&
        identical(result, _weatherResults.first);
    const textShadow = [
      Shadow(
        color: Colors.black87,
        blurRadius: 4,
      ),
    ];
    if (isBest) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _scoreColor(result.score),
          border: Border.all(
            color: Colors.white,
            width: 2.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Text(
              _displayDirectionCode(result.direction),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '$score10/10',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              _scoreLabel(result.score),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _displayDirectionCode(result.direction),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            shadows: textShadow,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$score10/10',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            shadows: textShadow,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _scoreLabel(result.score),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            shadows: textShadow,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TRŪKSTOŠS SEKTORS
  // ============================================================

  Widget _buildMissingSectorMarker(double bearing) {
    final isSearching =
        _isFillingMissing || _isLoadingWeather;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xE6101522),
        border: Border.all(
          color: const Color(0xFF17BEBB)
              .withValues(alpha: 0.65),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _directionCodeFromBearing(bearing),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          if (isSearching)
            const _SearchingDots()
          else
            const Icon(
              Icons.cloud_off_outlined,
              color: Colors.white54,
              size: 18,
            ),
          const SizedBox(height: 3),
          Text(
            _missingSectorLabel(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  String _directionCodeFromBearing(double bearing) {
    const names = <String>[
      'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW',
    ];

    final index = _allBearings.indexWhere(
      (value) => value.round() == bearing.round(),
    );

    if (index < 0) return '?';

    return _displayDirectionCode(names[index]);
  }

  // ============================================================
  // POPUP TRŪKSTOŠAM SEKTORAM
  // ============================================================

  void _showMissingSectorInfo(double bearing) {
    final isSearching =
        _isFillingMissing || _isLoadingWeather;

    final direction = _directionCodeFromBearing(bearing);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF101522),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFF17BEBB),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_outlined,
                  color: Color(0xFF17BEBB),
                  size: 42,
                ),
                const SizedBox(height: 14),
                Text(
                  direction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isSearching
                      ? AppLanguageService.tr(
                          lv: 'Ielādējam laikapstākļus...',
                          en: 'Loading weather...',
                        )
                      : AppLanguageService.tr(
                          lv: 'Šim virzienam pašlaik nav datu.',
                          en: 'No weather data for this direction.',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // PROGNOZES LAIKA POGAS
  // ============================================================

  Widget _buildForecastButtons() {
    const hours = [0, 2, 4, 8];

    return Row(
      children: hours.map((hour) {
        final selected = _selectedHoursAhead == hour;

        final showRetry = selected &&
            !_isLoadingWeather &&
            _weatherResults.length <= 6;

        final label = showRetry
            ? AppLanguageService.tr(
                lv: 'Vēlreiz?',
                en: 'Retry?',
              )
            : hour == 0
                ? AppLanguageService.tr(
                    lv: 'Tagad',
                    en: 'Now',
                  )
                : '+$hour h';

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 3,
            ),
            child: GestureDetector(
              onTap: _isLoadingWeather
                  ? null
                  : () => _changeWeatherHour(hour),
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 250,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: selected
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFF14BEF),
                            Color(0xFFB742FF),
                            Color(0xFF654CFF),
                          ],
                        )
                      : null,
                  color: selected
                      ? null
                      : const Color(0xCC19243A),
                  border: Border.all(
                    color: selected
                        ? Colors.white70
                        : Colors.white24,
                  ),
                ),
                child: (_isLoadingWeather && selected)
                    ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                )
                    : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: selected
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // PILSĒTU MARĶIERI
  // ============================================================



  List<Marker> _buildCityMarkers() {
    return _cities.map((city) {
      final markerWidth =
      (city.name.length * 8.0 + 28.0).clamp(65.0, 115.0);

      return Marker(
        point: LatLng(city.lat, city.lon),
        width: markerWidth,
        height: 34,
        child: AnimatedBuilder(
          animation: _bestMarkerAnimation,
          builder: (context, child) {
            final progress = _bestMarkerAnimation.value;

            return Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.75 + 0.25 * progress,
                child: child,
              ),
            );
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: const Color(0xEE003D35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00D26A),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              city.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }



  // ============================================================
  // SĀKUMPUNKTA MARĶIERIS
  // ============================================================

  Marker _buildStartMarker(LatLng center) {
    return Marker(
      point: center,
      width: 48,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF17BEBB),
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
            ),
          ],
        ),
        child: const Icon(
          Icons.navigation,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  // ============================================================
  // LABĀKĀ VIRZIENA INFORMĀCIJA
  // ============================================================

  Widget _buildBestDirectionPanel() {
    if (_weatherResults.isEmpty) {
      return const SizedBox.shrink();
    }

    final best = _weatherResults.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xE6101522),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFB742FF),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.explore,
            color: Color(0xFF17BEBB),
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLanguageService.tr(
                    lv: 'Labākais virziens',
                    en: 'Best direction',
                  ),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_directionName(best.direction)}'
                  '  •  ${(best.score / 10).floor()}/10',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingCities)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF17BEBB),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // GALVENAIS EKRĀNS
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.startLat, widget.startLon);

    return Scaffold(
      backgroundColor: const Color(0xFF090E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101522),
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(5),
          child: AnimatedBuilder(
            animation: _backArrowController,
            builder: (context, child) {
              final pulse =
                  0.5 + 0.5 * math.sin(_backArrowController.value * 2 * math.pi);

              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF9D35E8).withValues(
                    alpha: 0.15 + pulse * 0.85,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB742FF).withValues(
                        alpha: 0.15 + pulse * 0.85,
                      ),
                      blurRadius: 12 + pulse * 24,
                      spreadRadius: 2 + pulse * 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: RotationTransition(
                    turns: _backArrowController,
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              );
            },
          ),
        ),
        title: Text(
          AppLanguageService.tr(
            lv: 'Kur šodien braukt?',
            en: 'Where to drive today?',
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 7.0,
              minZoom: 5,
              maxZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'lv.surpriseride.app',
              ),
              PolygonLayer(
                polygons: _buildWeatherPolygons(center),
              ),
              MarkerLayer(
                markers: [
                  _buildStartMarker(center),
                  ..._buildSectorMarkers(center),
                  ..._buildCityMarkers(),
                ],
              ),
            ],
          ),
          if (_showSectorHint)
          Positioned(
            top: 165,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC101522),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF17BEBB),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    '👆 Tap a direction for weather details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Augšējais informācijas panelis.
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBestDirectionPanel(),
                ],
              ),
            ),
          ),
// Apakšējais laikapstākļu vadības panelis.
          Positioned(
            bottom: 60,
            left: 12,
            right: 12,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xE6121830),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF9B5CFF),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildForecastButtons(),
                    const SizedBox(height: 12),
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF22C55E),
                            Color(0xFF84CC16),
                            Color(0xFFFACC15),
                            Color(0xFFF97316),
                            Color(0xFFEF4444),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Best',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                        ),
                        Text(
                          'Terrible',
                          style: TextStyle(color: Colors.redAccent, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Reklāma tikai laikapstākļu ielādes laikā.
          if (true)
            Positioned(
              bottom: 40,
              left: 12,
              right: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xDD101522),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const AdMobBanner(),
                ),
              ),
            ),

        ],
      ),
    );
  }
}

// ============================================================
// TRĪS PULSĒJOŠI PUNKTI TRŪKSTOŠAJIEM SEKTORIEM
// ============================================================

class _SearchingDots extends StatefulWidget {
  const _SearchingDots();

  @override
  State<_SearchingDots> createState() => _SearchingDotsState();
}

class _SearchingDotsState extends State<_SearchingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase =
                (_controller.value + index * 0.22) % 1.0;

            final opacity =
                0.3 + 0.7 * (0.5 + 0.5 * math.sin(
                  phase * 2 * math.pi,
                ));

            return Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(
                horizontal: 2,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF17BEBB)
                    .withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
