import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../services/app_language_service.dart';
import '../../services/drivable_access_service.dart';
import '../../services/route_service.dart';
import '../../services/city_direction_service.dart';

class AlongRoutePreviewScreen extends StatefulWidget {
  final List<LatLon> routePoints;
  final String startName;
  final String destinationName;
  final double distanceKm;
  final double durationMinutes;
  final List<Poi> pois;

  const AlongRoutePreviewScreen({
    super.key,
    required this.routePoints,
    required this.startName,
    required this.destinationName,
    required this.distanceKm,
    required this.durationMinutes,
    required this.pois,
  });

  @override
  State<AlongRoutePreviewScreen> createState() =>
      _AlongRoutePreviewScreenState();
}

class _AlongRoutePreviewScreenState extends State<AlongRoutePreviewScreen> {
  final CityDirectionService _cityDirectionService =
  const CityDirectionService();

  List<DirectionCity> _routeCities = [];
  bool get _isLv => AppLanguageService.isLv;

  String _tr(String lv, String en) => _isLv ? lv : en;

  late List<Poi> _selectedPois;

  final RouteService _routeService = RouteService();

  final DrivableAccessService _drivableAccessService =
  DrivableAccessService();

  List<LatLon> _previewRoutePoints = [];

  double _previewDistanceMeters = 0;
  double _previewDurationSeconds = 0;

  bool _isBuildingPreviewRoute = false;

  final Map<Poi, DrivableAccessResult> _poiAccessResults = {};

  List<LatLon> _navigationWaypoints = [];

  @override
  void initState() {
    super.initState();
    _loadRouteCities();
    _selectedPois = List<Poi>.from(widget.pois);

    // Preview vienmēr A → B virzienā.
    _selectedPois.sort(
          (a, b) => _nearestRouteIndex(a).compareTo(
        _nearestRouteIndex(b),
      ),
    );

    _previewRoutePoints = List<LatLon>.from(widget.routePoints);

    // Kamēr jaunais A → POI → B maršruts būvējas,
    // rādām sākotnējo A → B statistiku.
    _previewDistanceMeters = widget.distanceKm * 1000;
    _previewDurationSeconds = widget.durationMinutes * 60;

    _buildPreviewRoute();
  }
  Future<void> _loadRouteCities() async {
    final route = widget.routePoints
        .map(
          (point) => ll.LatLng(
        point.lat,
        point.lon,
      ),
    )
        .toList();

    final cities =
    await _cityDirectionService.fetchCitiesAlongRoute(
      routePoints: route,
      maxResults: 5,
      maxDistanceFromRouteKm: 25,
      minPopulation: 1000,
    );

    if (!mounted) return;

    String cleanName(String value) {
      return value
          .split(',')
          .first
          .trim()
          .toLowerCase();
    }

    final startCity = cleanName(widget.startName);
    final destinationCity = cleanName(widget.destinationName);

    final filteredCities = cities.where((city) {
      final cityName = cleanName(city.name);

      return cityName != startCity &&
          cityName != destinationCity;
    }).toList();

    setState(() {
      _routeCities = filteredCities;
    });
  }
  int _nearestRouteIndex(Poi poi) {
    var bestIndex = 0;
    var bestDistance = double.infinity;

    for (var i = 0; i < widget.routePoints.length; i++) {
      final routePoint = widget.routePoints[i];

      final dLat = poi.location.lat - routePoint.lat;
      final dLon = poi.location.lon - routePoint.lon;

      final distance = dLat * dLat + dLon * dLon;

      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  Future<void> _buildPreviewRoute() async {
    if (widget.routePoints.length < 2) return;

    setState(() {
      _isBuildingPreviewRoute = true;
    });

    try {
      final waypoints = <LatLon>[
        widget.routePoints.first,
      ];

      final accessSw = Stopwatch()..start();

      for (var i = 0; i < _selectedPois.length; i++) {
        final poi = _selectedPois[i];

        if (!poi.needsDrivableAccess) {
          debugPrint(
            '⚡ PREVIEW POI ${i + 1}: ${poi.name} → direct waypoint',
          );

          waypoints.add(poi.location);
          continue;
        }

        debugPrint(
          '🥾 PREVIEW POI ${i + 1}: ${poi.name} → checking drivable access',
        );

        final lookup =
        await _drivableAccessService.findNearestDrivablePointDetailed(
          poi.location,
        );

        if (!mounted) return;

        if (lookup.status == DrivableAccessLookupStatus.found &&
            lookup.access != null) {
          final access = lookup.access!;

          debugPrint(
            '🚗 PREVIEW POI ${i + 1}: ${poi.name} '
                '→ access ${access.distanceMeters.round()} m',
          );

          _poiAccessResults[poi] = access;

          debugPrint(
            '🥾 ACCESS SAVED ${poi.name}: '
                '${access.distanceMeters.round()} m',
          );

          waypoints.add(access.point);
        } else {
          debugPrint(
            '⚠️ PREVIEW POI ${i + 1}: ${poi.name} '
                '→ using original POI',
          );

          waypoints.add(poi.location);
        }
      }

      accessSw.stop();

      debugPrint(
        '⏱ PREVIEW ACCESS TOTAL: '
            '${accessSw.elapsedMilliseconds} ms, '
            '${_selectedPois.length} POIs',
      );

      waypoints.add(widget.routePoints.last);

      _navigationWaypoints = List<LatLon>.from(waypoints);

      final routeBuildSw = Stopwatch()..start();

      final result =
      await _routeService.fetchDrivingRouteWithStats(waypoints);

      routeBuildSw.stop();

      debugPrint(
        '⏱ PREVIEW ROUTE BUILD: '
            '${routeBuildSw.elapsedMilliseconds} ms, '
            '${waypoints.length} waypoints',
      );

      if (!mounted) return;

      setState(() {
        _previewRoutePoints = List<LatLon>.from(result.points);

        if (result.distanceMeters > 0 &&
            result.durationSeconds > 0) {
          _previewDistanceMeters = result.distanceMeters;
          _previewDurationSeconds = result.durationSeconds;
        }

        _isBuildingPreviewRoute = false;
      });
    } catch (error) {
      debugPrint(
        'Along Route preview route error: $error',
      );

      if (!mounted) return;

      setState(() {
        _previewRoutePoints =
        List<LatLon>.from(widget.routePoints);

        _previewDistanceMeters =
            widget.distanceKm * 1000;

        _previewDurationSeconds =
            widget.durationMinutes * 60;

        _isBuildingPreviewRoute = false;
      });
    }
  }

  Future<void> _removePoi(Poi poi) async {
    setState(() {
      _selectedPois.remove(poi);
    });

    await _buildPreviewRoute();
  }

  Future<void> _openGoogleMapsNavigation() async {
    if (_navigationWaypoints.length < 2) return;

    final origin = _navigationWaypoints.first;
    final destination = _navigationWaypoints.last;

    final middlePoints = _navigationWaypoints
        .skip(1)
        .take(_navigationWaypoints.length - 2)
        .map((p) => '${p.lat},${p.lon}')
        .join('|');

    final params = <String, String>{
      'api': '1',
      'origin': '${origin.lat},${origin.lon}',
      'destination': '${destination.lat},${destination.lon}',
      'travelmode': 'driving',
    };

    if (middlePoints.isNotEmpty) {
      params['waypoints'] = middlePoints;
    }

    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      params,
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Neizdevās atvērt Google Maps',
              'Could not open Google Maps',
            ),
          ),
        ),
      );
    }
  }

  String _formatDurationFromSeconds(double seconds) {
    final totalMinutes = (seconds / 60).round();

    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '$hours h';
    }

    return '$hours h $minutes min';
  }
  Offset _endpointOffsetAwayFromPois(LatLon endpoint) {
    if (_selectedPois.isEmpty) {
      return Offset.zero;
    }

    // Aptuvenais rādiuss, kurā sākam sargāt A/B no POI.
    // Pie mūsu preview zoom tas dod dabisku vizuālo atstarpi.
    const influenceKm = 12.0;
    const maxShiftPx = 72.0;

    double forceX = 0;
    double forceY = 0;
    double strongestWeight = 0;

    Poi? nearestPoi;
    double nearestDistanceKm = double.infinity;

    final latRad = endpoint.lat * 3.141592653589793 / 180.0;
    final cosLat = _cosApprox(latRad);

    for (final poi in _selectedPois) {
      final dLatKm =
          (endpoint.lat - poi.location.lat) * 111.32;

      final dLonKm =
          (endpoint.lon - poi.location.lon) *
              111.32 *
              cosLat;

      final distanceKm =
      _sqrtApprox(
        dLatKm * dLatKm +
            dLonKm * dLonKm,
      );

      if (distanceKm < nearestDistanceKm) {
        nearestDistanceKm = distanceKm;
        nearestPoi = poi;
      }

      if (distanceKm <= 0.001 ||
          distanceKm >= influenceKm) {
        continue;
      }

      // Jo POI tuvāk A/B, jo stiprāk tas "atgrūž".
      final weight =
          1.0 - (distanceKm / influenceKm);

      if (weight > strongestWeight) {
        strongestWeight = weight;
      }

      // X: austrumi/rietumi.
      //
      // Y Flutter ekrānā aug uz leju,
      // tāpēc latitude virzienu apgriežam.
      forceX += (dLonKm / distanceKm) * weight;
      forceY += (-dLatKm / distanceKm) * weight;
    }

    // Neviens POI nav pietiekami tuvu.
    if (strongestWeight == 0 || nearestPoi == null) {
      return Offset.zero;
    }

    var forceLength =
    _sqrtApprox(forceX * forceX + forceY * forceY);

    // Ja vairāku POI spēki gandrīz viens otru nodzēš,
    // izmantojam tuvākā POI virzienu.
    if (forceLength < 0.05) {
      final dLatKm =
          (endpoint.lat - nearestPoi.location.lat) *
              111.32;

      final dLonKm =
          (endpoint.lon - nearestPoi.location.lon) *
              111.32 *
              cosLat;

      final distanceKm =
      _sqrtApprox(
        dLatKm * dLatKm +
            dLonKm * dLonKm,
      );

      if (distanceKm <= 0.001) {
        // Ļoti rets gadījums:
        // A/B un POI praktiski vienā koordinātā.
        return const Offset(0, -maxShiftPx);
      }

      forceX = dLonKm / distanceKm;
      forceY = -dLatKm / distanceKm;
      forceLength = 1.0;
    }

    final normalizedX = forceX / forceLength;
    final normalizedY = forceY / forceLength;

    // Tuvam POI dodam lielāku nobīdi.
    // Minimums jau ir pietiekams, lai apļi nesaskartos.
    final shift =
        46.0 + (26.0 * strongestWeight);

    return Offset(
      normalizedX * shift,
      normalizedY * shift,
    );
  }

  double _sqrtApprox(double value) {
    if (value <= 0) return 0;

    var x = value;

    for (var i = 0; i < 8; i++) {
      x = 0.5 * (x + value / x);
    }

    return x;
  }

  double _cosApprox(double x) {
    // Šeit latitude ir Latvijas diapazonā,
    // tāpēc vienkārša Taylor aproksimācija ir vairāk
    // nekā pietiekama tikai vizuālā virziena aprēķinam.
    final x2 = x * x;

    return 1 -
        x2 / 2 +
        (x2 * x2) / 24 -
        (x2 * x2 * x2) / 720;
  }
  Offset _cityLabelOffset(DirectionCity city) {
    for (final poi in _selectedPois) {
      final latDiff =
      (city.lat - poi.location.lat).abs();

      final lonDiff =
      (city.lon - poi.location.lon).abs();

      if (latDiff < 0.05 && lonDiff < 0.08) {
        return city.lon >= poi.location.lon
            ? const Offset(62, -24)
            : const Offset(-62, -24);
      }
    }

    return Offset.zero;
  }
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF031417),
      body: Stack(
        children: [
          // =========================================================
          // PILNA EKRĀNA AINAVAS FONA BILDE
          // =========================================================
          Positioned.fill(
            child: Image.asset(
              'lib/assets/home/along_route_preview_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // Viegla tumšināšana visam fonam.
          Positioned.fill(
            child: Container(
              color: const Color(0xFF00191E)
                  .withValues(alpha: 0.22),
            ),
          ),

          // =========================================================
          // AUGŠĒJĀ KARTE
          // =========================================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.78,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: ll.LatLng(
                        widget.routePoints.first.lat,
                        widget.routePoints.first.lon,
                      ),
                      initialZoom: 9,

                      // SVARĪGI:
                      // FlutterMap fons ir caurspīdīgs,
                      // tāpēc zem OSM flīzēm redzama ainavas bilde.
                      backgroundColor: Colors.transparent,
                    ),
                    children: [
                      // OSM ir tikai informācijas slānis.
                      Opacity(
                        opacity: 0.08,
                        child: TileLayer(
                          urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                          'com.example.surprise_ride',
                        ),
                      ),

                      // Spilgtais reālais maršruts.
                      PolylineLayer(
                        polylines: [
                          // Neliels tumšs glow zem līnijas.
                          Polyline(
                            points: _previewRoutePoints
                                .map(
                                  (p) => ll.LatLng(
                                p.lat,
                                p.lon,
                              ),
                            )
                                .toList(),
                            strokeWidth: 10,
                            color: const Color(0xFF001F24)
                                .withValues(alpha: 0.55),
                          ),

                          Polyline(
                            points: _previewRoutePoints
                                .map(
                                  (p) => ll.LatLng(
                                p.lat,
                                p.lon,
                              ),
                            )
                                .toList(),
                            strokeWidth: 5.5,
                            color: const Color(0xFF16F2E8),
                          ),
                        ],
                      ),

                      MarkerLayer(
                        markers: [
                          // Tuvākās pilsētas gar maršrutu
                          ..._routeCities.map(
                                (city) => Marker(
                              point: ll.LatLng(
                                city.lat,
                                city.lon,
                              ),
                              width: 110,
                              height: 28,
                                  child: Transform.translate(
                                    offset: _cityLabelOffset(city),
                                    child: Center(
                                      child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF071C25)
                                        .withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                        child: Text(
                                          city.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                          // A + sākumpunkta nosaukums
                          Marker(
                            point: ll.LatLng(
                              widget.routePoints.first.lat,
                              widget.routePoints.first.lon,
                            ),
                            width: 160,
                            height: 100,
                            child: Transform.translate(
                              offset: _endpointOffsetAwayFromPois(
                                widget.routePoints.first,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildPlaceLabel(widget.startName),

                                  const SizedBox(height: 4),

                                  SizedBox(
                                    width: 54,
                                    height: 54,
                                    child: _buildMarker(
                                      text: 'A',
                                      color: const Color(0xFF17BEBB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // POI
                          ..._selectedPois.asMap().entries.map(
                                (entry) {
                              final index = entry.key + 1;
                              final poi = entry.value;

                              return Marker(
                                point: ll.LatLng(
                                  poi.location.lat,
                                  poi.location.lon,
                                ),
                                width: 48,
                                height: 48,
                                child: _buildMarker(
                                  text: '$index',
                                  color:
                                  const Color(0xFF9236D6),
                                ),
                              );
                            },
                          ),

                          // B + galapunkta nosaukums
                          Marker(
                            point: ll.LatLng(
                              widget.routePoints.last.lat,
                              widget.routePoints.last.lon,
                            ),
                            width: 160,
                            height: 100,
                            child: Transform.translate(
                              offset: _endpointOffsetAwayFromPois(
                                widget.routePoints.last,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 54,
                                    height: 54,
                                    child: _buildMarker(
                                      text: 'B',
                                      color: const Color(0xFFFF8A4C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildPlaceLabel(widget.destinationName),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tumšs tirkīza tonis virs kartes.
                // IgnorePointer ļauj karti turpināt pārvietot.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: const Color(0xFF00343B)
                          .withValues(alpha: 0.18),
                    ),
                  ),
                ),

                // Apakšā karte pakāpeniski saplūst ar paneli.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 130,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF041C22)
                                .withValues(alpha: 0.30),
                            const Color(0xFF041C22)
                                .withValues(alpha: 0.92),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =========================================================
          // AUGŠĒJAIS VIRSRaksts
          // =========================================================
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                8,
                4,
                16,
                0,
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF041A20)
                          .withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF16D7D2)
                            .withValues(alpha: 0.40),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF16D7D2),
                        size: 30,
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                          List<Poi>.from(_selectedPois),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      '${_tr(
                        'Maršruta priekšskatījums',
                        'Route preview',
                      )} (${_selectedPois.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // =========================================================
          // APAKŠĒJAIS GLASS PANELIS
          // =========================================================
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.20,
            maxChildSize: 0.88,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xE808252C),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFF16D7D2)
                          .withValues(alpha: 0.42),
                      width: 1.3,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10D9D1)
                          .withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, -8),
                    ),
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: 0.32),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding:
                  const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  children: [
                    // Drag rokturis
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16D7D2)
                              .withValues(alpha: 0.55),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // =================================================
                    // MARŠRUTA KOPSAVILKUMS
                    // =================================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C3037)
                            .withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF16D7D2)
                              .withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF16D7D2)
                                  .withValues(alpha: 0.16),
                              borderRadius:
                              BorderRadius.circular(15),
                              border: Border.all(
                                color:
                                const Color(0xFF16D7D2)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_car_rounded,
                              color: Color(0xFF16F2E8),
                              size: 28,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_cityName(widget.startName)} → ${_cityName(widget.destinationName)}',
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight:
                                    FontWeight.w800,
                                  ),
                                ),

                                const SizedBox(height: 5),

                                Row(
                                  children: [
                                    if (_isBuildingPreviewRoute) ...[
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child:
                                        CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color:
                                          Color(0xFF16F2E8),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],

                                    Flexible(
                                      child: Text(
                                        '${(_previewDistanceMeters / 1000).toStringAsFixed(1)} km'
                                            '  •  '
                                            '${_formatDurationFromSeconds(_previewDurationSeconds)}',
                                        style:
                                        const TextStyle(
                                          color:
                                          Color(0xFF9BC8CA),
                                          fontSize: 14,
                                          fontWeight:
                                          FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // =================================================
                    // IZVĒLĒTĀS VIETAS
                    // =================================================
                    Row(
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          color: Color(0xFF16F2E8),
                          size: 22,
                        ),

                        const SizedBox(width: 8),

                        Text(
                          '${_tr(
                            'Izvēlētās vietas',
                            'Selected places',
                          )} (${_selectedPois.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (_selectedPois.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B2930)
                              .withValues(alpha: 0.72),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: Text(
                          _tr(
                            'Nav izvēlētu pieturvietu',
                            'No selected stops',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF9BC8CA),
                            fontSize: 15,
                          ),
                        ),
                      ),

                    ..._selectedPois.asMap().entries.map(
                          (entry) {
                        final index = entry.key;
                        final poi = entry.value;

                        final access =
                        _poiAccessResults[poi];

                        return Container(
                          margin:
                          const EdgeInsets.only(bottom: 11),
                          padding:
                          const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B2930)
                                .withValues(alpha: 0.82),
                            borderRadius:
                            BorderRadius.circular(20),
                            border: Border.all(
                              color:
                              const Color(0xFF16D7D2)
                                  .withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient:
                                  const LinearGradient(
                                    begin:
                                    Alignment.topLeft,
                                    end:
                                    Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF9C3CE0),
                                      Color(0xFF6A35B5),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white
                                        .withValues(
                                        alpha: 0.80),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                          0xFF9C3CE0)
                                          .withValues(
                                          alpha: 0.30),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style:
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight:
                                    FontWeight.w900,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 13),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      poi.name,
                                      maxLines: 2,
                                      overflow:
                                      TextOverflow.ellipsis,
                                      style:
                                      const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight:
                                        FontWeight.w700,
                                      ),
                                    ),

                                    if (access != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons
                                                .directions_walk_rounded,
                                            color:
                                            Color(0xFF9BC8CA),
                                            size: 15,
                                          ),
                                          const SizedBox(
                                              width: 4),
                                          Text(
                                            '${access.distanceMeters.round()} m',
                                            style:
                                            const TextStyle(
                                              color: Color(
                                                  0xFF9BC8CA),
                                              fontSize: 12,
                                              fontWeight:
                                              FontWeight
                                                  .w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(width: 6),

                              IconButton(
                                onPressed:
                                _isBuildingPreviewRoute
                                    ? null
                                    : () =>
                                    _removePoi(poi),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color:
                                  _isBuildingPreviewRoute
                                      ? Colors.white24
                                      : Colors.white60,
                                ),
                                tooltip: _tr(
                                  'Noņemt',
                                  'Remove',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // =================================================
                    // NAVIGĀCIJAS POGA
                    // =================================================
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed:
                        _isBuildingPreviewRoute ||
                            _navigationWaypoints
                                .length <
                                2
                            ? null
                            : _openGoogleMapsNavigation,
                        icon: _isBuildingPreviewRoute
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.navigation_rounded,
                          size: 24,
                        ),
                        label: Text(
                          _isBuildingPreviewRoute
                              ? _tr(
                            'Veido maršrutu...',
                            'Building route...',
                          )
                              : _tr(
                            'Sākt navigāciju',
                            'Start navigation',
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF16D7D2),
                          foregroundColor:
                          const Color(0xFF032025),
                          disabledBackgroundColor:
                          const Color(0xFF16D7D2)
                              .withValues(alpha: 0.25),
                          disabledForegroundColor:
                          Colors.white54,
                          elevation: 8,
                          shadowColor:
                          const Color(0xFF16D7D2)
                              .withValues(alpha: 0.30),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMarker({
    required String text,
    required Color color,
  }) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.40),
            blurRadius: 14,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
  String _cityName(String name) {
    final clean = name.trim();

    if (clean.isEmpty) return '';

    if (clean.contains(',')) {
      return clean.split(',').first.trim();
    }

    return clean;
  }
  Widget _buildPlaceLabel(String name) {
    var cleanName = name.trim();

    // No pilnas adreses paņemam tikai vietas nosaukumu.
    if (cleanName.contains(',')) {
      cleanName = cleanName.split(',').first.trim();
    }

    if (cleanName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 145,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xE607252B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF16F2E8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16F2E8)
                .withValues(alpha: 0.20),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        cleanName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}