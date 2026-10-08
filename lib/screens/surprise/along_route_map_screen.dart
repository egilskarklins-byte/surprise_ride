import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../services/app_language_service.dart';
import '../../services/surprise_poi_service.dart';
import 'along_route_results_screen.dart';
import 'dart:async';
import 'along_route_preview_screen.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:url_launcher/url_launcher.dart';
import '../../services/along_route_session.dart';

class AlongRouteMapScreen extends StatefulWidget {
  
  final List<LatLon> routePoints;
  final String startName;
  final String destinationName;
  final double distanceKm;
  final double durationMinutes;
  final double corridorKm;
  final List<Poi>? initialPois;


  const AlongRouteMapScreen({
    super.key,
    required this.routePoints,
    required this.startName,
    required this.destinationName,
    required this.distanceKm,
    required this.durationMinutes,
    this.corridorKm = 5.0,
    this.initialPois,
  });

  @override
  State<AlongRouteMapScreen> createState() =>
      _AlongRouteMapScreenState();
}

class _AlongRouteMapScreenState extends State<AlongRouteMapScreen>
    with TickerProviderStateMixin {
  late final Future<vt.Style> _mapStyleFuture;


  final Set<Poi> _selectedRoutePois = {};
  final SurprisePoiService _poiService = SurprisePoiService();
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();


  List<Poi> _pois = [];

  bool _isSearching = true;
  bool _searchFailed = false;
  bool _isSearchingFarther = false;
  bool _hasSearchedFarther = false;
  bool _useOldMap = false;

  int _processedCenters = 0;
  int _totalCenters = 0;


  List<Poi> _targetPois = [];
  Timer? _revealTimer;
  final Map<Poi, AnimationController> _poiAnimationControllers = {};
  final Map<Poi, Offset> _poiStartOffsets = {};
  @override
  void initState() {
    super.initState();

    _mapStyleFuture = vt.StyleReader(
      uri: 'https://tiles.openfreemap.org/styles/liberty',
    ).read();

    if (widget.initialPois != null && widget.initialPois!.isNotEmpty) {
      _pois = List<Poi>.from(widget.initialPois!);
      _targetPois = List<Poi>.from(widget.initialPois!);
      _isSearching = false;

      debugPrint(
        '♻️ ALONG ROUTE SESSION RESTORED: ${_pois.length} POI',
      );
    } else {
      _startPoiSearch();
    }
  }
  void _updateVisiblePois(List<Poi> newPois) {
    // Meklēšanas laikā saglabājam jau parādītos POI.
    // Jaunos pievienojam, neizdzēšot iepriekšējos.
    final merged = List<Poi>.from(_targetPois);

    for (final poi in newPois) {
      if (!merged.contains(poi)) {
        merged.add(poi);
      }
    }

    _targetPois = merged;

    if (_targetPois.length > _pois.length) {
      _startRevealTimer();
    }
  }

  void _startRevealTimer() {
    if (_revealTimer?.isActive ?? false) return;

    _revealTimer = Timer.periodic(
      const Duration(milliseconds: 450),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_pois.length >= _targetPois.length) {
          timer.cancel();
          return;
        }

        final nextCount =
        (_pois.length + 1).clamp(0, _targetPois.length);

        final oldCount = _pois.length;
        final newPois = _targetPois.take(nextCount).toList();

        for (int i = oldCount; i < newPois.length; i++) {
          final poi = newPois[i];

          final controller = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1200),
          );

          _poiAnimationControllers[poi] = controller;

          // POI pēc kārtas ienāk no dažādām ekrāna malām.
          switch (i % 4) {
            case 0:
              _poiStartOffsets[poi] = const Offset(-6.0, 0.0); // no kreisās
              break;
            case 1:
              _poiStartOffsets[poi] = const Offset(6.0, 0.0); // no labās
              break;
            case 2:
              _poiStartOffsets[poi] = const Offset(0.0, -8.0); // no augšas
              break;
            default:
              _poiStartOffsets[poi] = const Offset(0.0, 8.0); // no apakšas
          }
        }

        setState(() {
          _pois = newPois;
        });

        for (int i = oldCount; i < newPois.length; i++) {
          _poiAnimationControllers[newPois[i]]?.forward();
        }
      },
    );
  }
  Future<void> _startPoiSearch() async {
    try {
      final finalPois = await _poiService.fetchPoisAlongRoute(
        routePoints: widget.routePoints,
        corridorKm: widget.corridorKm,
        maxResults: 30,
        onProgress: (
            progressPois,
            processedCenters,
            totalCenters,
            ) {
          if (!mounted) return;

          setState(() {
            _processedCenters = processedCenters;
            _totalCenters = totalCenters;
          });

          _updateVisiblePois(progressPois.take(30).toList());
        },
      );

      if (!mounted) return;

      if (!mounted) return;

      setState(() {
        _targetPois = [
          ..._pois,
          ...finalPois.where((poi) => !_pois.contains(poi)),
        ].take(30).toList();

        if (_totalCenters > 0) {
          _processedCenters = _totalCenters;
        }

        _isSearching = false;
        _searchFailed = false;
      });
      final session = AlongRouteSession.instance;

      session.routePoints = List<LatLon>.from(widget.routePoints);
      session.startName = widget.startName;
      session.destinationName = widget.destinationName;
      session.distanceKm = widget.distanceKm;
      session.durationMinutes = widget.durationMinutes;
      session.corridorKm = widget.corridorKm;
      session.pois = List<Poi>.from(_targetPois.take(30));
      session.selectedPois = Set<Poi>.from(_selectedRoutePois);

      debugPrint(
        '💾 ALONG ROUTE SESSION SAVED: ${session.pois.length} POI',
      );
      _startRevealTimer();
    } catch (error) {
      debugPrint('Along Route map POI search error: $error');

      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _searchFailed = true;
      });
    }
  }
  Future<void> _searchFarther() async {
    if (_isSearchingFarther || _hasSearchedFarther) {
      return;
    }

    setState(() {
      _isSearchingFarther = true;
      _searchFailed = false;
    });

    try {
      final fartherPois = await _poiService.fetchPoisAlongRoute(
        routePoints: widget.routePoints,
        corridorKm: 10.0,
        maxResults: 30,
        onProgress: (
            progressPois,
            processedCenters,
            totalCenters,
            ) {
          if (!mounted) return;

          setState(() {
            _processedCenters = processedCenters;
            _totalCenters = totalCenters;
          });

          _updateVisiblePois(progressPois);
        },
      );

      if (!mounted) return;

      _targetPois = List<Poi>.from(fartherPois);

      if (_totalCenters > 0) {
        setState(() {
          _processedCenters = _totalCenters;
        });
      }

      _startRevealTimer();

      while (mounted && _pois.length < _targetPois.length) {
        await Future.delayed(
          const Duration(milliseconds: 100),
        );
      }

      if (!mounted) return;

      setState(() {
        _isSearchingFarther = false;
        _hasSearchedFarther = true;

      });
    } catch (error) {
      debugPrint('Along Route farther search error: $error');

      if (!mounted) return;

      setState(() {
        _isSearchingFarther = false;
        _searchFailed = true;
      });
    }
  }
  void _togglePoiSelection(Poi poi) {
    setState(() {
      if (_selectedRoutePois.contains(poi)) {
        _selectedRoutePois.remove(poi);
      } else {
        _selectedRoutePois.add(poi);
      }
    });
  }
  @override
  void dispose() {
    _revealTimer?.cancel();

    for (final controller in _poiAnimationControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }
  String _formatDuration(double minutes) {
    final totalMinutes = minutes.round();

    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }

    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    if (mins == 0) {
      return '$hours h';
    }

    return '$hours h $mins min';
  }
  String _cityName(String name) {
    final clean = name.trim();

    if (clean.isEmpty) return '';

    if (clean.contains(',')) {
      return clean.split(',').first.trim();
    }

    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final routeLatLngs = widget.routePoints
        .map(
          (point) => ll.LatLng(
        point.lat,
        point.lon,
      ),
    )
        .toList();

    final bounds = LatLngBounds.fromPoints(routeLatLngs);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.fromLTRB(
                  42,
                  150,
                  42,
                  190,
                ),
              ),
            ),
            children: [
              _useOldMap
                  ? TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'lv.surpriseride.app',
                maxZoom: 19,
              )
                  : FutureBuilder<vt.Style>(
                future: _mapStyleFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final style = snapshot.data!;

                  return vt.VectorTileLayer(
                    theme: style.theme,
                    tileProviders: style.providers,
                    rasterSources: style.rasterSources,
                    sprites: style.sprites,
                    logger: const vt.Logger.console(),
                  );
                },
              ),

              // A → B maršruts
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routeLatLngs,
                    color: const Color(0xFF6B52E5),
                    strokeWidth: 6.0,
                    borderColor: const Color(0xFF4B35B8),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

              MarkerLayer(
                markers: [
                  // ====================================================
                  // NEATZĪMĒTIE POI
                  // ====================================================
                  ..._pois.asMap().entries
                      .where(
                        (entry) => !_selectedRoutePois.contains(entry.value),
                  )
                      .map((entry) {
                    final number = entry.key + 1;
                    final poi = entry.value;

                    return Marker(
                      point: ll.LatLng(
                        poi.location.lat,
                        poi.location.lon,
                      ),
                      width: 42,
                      height: 42,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: _poiStartOffsets[poi] ?? Offset.zero,
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _poiAnimationControllers[poi] ??
                                const AlwaysStoppedAnimation<double>(1.0),
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: GestureDetector(
                        onTap: () {
                          _showPoiSheet(
                            context,
                            poi,
                            number,
                          );
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B52E5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '$number',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                          ),
                        ),
                    );
                  }),

                  // ====================================================
                  // ATZĪMĒTIE POI — ZĪMĒJAM PĒC TAM, LAI BŪTU VIRSŪ
                  // ====================================================
                  ..._pois.asMap().entries
                      .where(
                        (entry) => _selectedRoutePois.contains(entry.value),
                  )
                      .map((entry) {
                    final number = entry.key + 1;
                    final poi = entry.value;

                    return Marker(
                      point: ll.LatLng(
                        poi.location.lat,
                        poi.location.lon,
                      ),
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () {
                          _showPoiSheet(
                            context,
                            poi,
                            number,
                          );
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10D9D1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10D9D1).withValues(
                                  alpha: 0.45,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '$number',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // ====================================================
                  // A — PAŠĀS BEIGĀS, LAI VIENMĒR BŪTU VIRS POI
                  // ====================================================
                  Marker(
                    point: routeLatLngs.first,
                    width: 56,
                    height: 56,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF17BEBB),
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  // ====================================================
                  // B
                  // ====================================================
                  Marker(
                    point: routeLatLngs.last,
                    width: 56,
                    height: 56,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF8A4C),
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'B',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Augšējā Home Screen stila informācijas kartīte
// UI 2.0 — kartes augšējā navigācija
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: Row(
                  children: [
                    // BACK
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF062631).withValues(alpha: 0.88),
                        border: Border.all(
                          color: const Color(0xFF10D9D1),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10D9D1)
                                .withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // TITLE GLASS CAPSULE
                    Expanded(
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF073746).withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10D9D1)
                                  .withValues(alpha: 0.16),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLanguageService.tr(
                                  lv: 'Izvēlies vietas',
                                  en: 'Choose places',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                AppLanguageService.tr(
                                  lv: 'pa maršrutu',
                                  en: 'along the route',
                                ),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // MAP LAYERS
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _useOldMap = !_useOldMap;
                        });
                      },
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF062631).withValues(alpha: 0.88),
                          border: Border.all(
                            color: _useOldMap
                                ? const Color(0xFFFF8A4C)
                                : const Color(0xFF10D9D1),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.layers_outlined,
                          color: _useOldMap
                              ? const Color(0xFFFF8A4C)
                              : Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize:
            MediaQuery.orientationOf(context) == Orientation.landscape
                ? 0.59
                : 0.34,
            minChildSize:
            MediaQuery.orientationOf(context) == Orientation.landscape
                ? 0.59
                : 0.34,
            maxChildSize: 0.72,
            snap: true,
            snapSizes: MediaQuery.orientationOf(context) == Orientation.landscape
                ? const [0.59, 0.72]
                : const [0.34, 0.72],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF06252D).withValues(alpha: 0.97),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(38),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFF10D9D1).withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.34),
                      blurRadius: 30,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Velkamā augšējā zona
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,

                      onVerticalDragUpdate: (details) {
                        if (!_sheetController.isAttached) return;

                        final screenHeight = MediaQuery.sizeOf(context).height;

                        final newSize =
                            _sheetController.size -
                                (details.delta.dy / screenHeight);

                        _sheetController.jumpTo(
                            newSize.clamp(0.28, 0.72)
                        );
                      },

                      onVerticalDragEnd: (details) {
                        if (!_sheetController.isAttached) return;

                        final target =
                        _sheetController.size > 0.35 ? 0.72 : 0.28;

                        _sheetController.animateTo(
                          target,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                      child: SizedBox(
                        height: 30,
                        width: double.infinity,
                        child: Center(
                          child: Container(
                            width: 54,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // POI izvēles 2.0 header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // A → B + maršruta informācija
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10D9D1)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF10D9D1)
                                        .withValues(alpha: 0.32),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.route_rounded,
                                  color: Color(0xFF10D9D1),
                                  size: 23,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_cityName(widget.startName)} → '
                                          '${_cityName(widget.destinationName)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                    ),

                                    const SizedBox(height: 5),

                                    Text(
                                      '${widget.distanceKm.toStringAsFixed(1)} km'
                                          '  •  '
                                          '${_formatDuration(widget.durationMinutes)}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.62),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Atrastās vietas
                          Row(
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                color: Color(0xFF10D9D1),
                                size: 21,
                              ),

                              const SizedBox(width: 8),

                              Text(
                                AppLanguageService.tr(
                                  lv: '${_pois.length} interesantas vietas',
                                  en: '${_pois.length} interesting places',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
// Meklēšanas progress / kļūda / Search farther
                    if (_isSearching || _searchFailed || (_pois.length < 6 && !_hasSearchedFarther))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                          child: _buildSearchStatus(),
                        ),
                      ),

                    const SizedBox(height: 10),

// UI 2.0 — kategorijas
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        children: [
                          _buildCategoryChip(
                            label: AppLanguageService.tr(
                              lv: 'Visas',
                              en: 'All',
                            ),
                            selected: true,
                          ),
                          const SizedBox(width: 8),

                          _buildCategoryChip(
                            label: AppLanguageService.tr(
                              lv: 'Daba',
                              en: 'Nature',
                            ),
                          ),
                          const SizedBox(width: 8),

                          _buildCategoryChip(
                            label: AppLanguageService.tr(
                              lv: 'Pilis',
                              en: 'Castles',
                            ),
                          ),
                          const SizedBox(width: 8),

                          _buildCategoryChip(
                            label: AppLanguageService.tr(
                              lv: 'Skatu vietas',
                              en: 'Viewpoints',
                            ),
                            showSwipeHint: true,
                          ),
                          const SizedBox(width: 8),

                          _buildCategoryChip(
                            label: AppLanguageService.tr(
                              lv: 'Vēsture',
                              en: 'History',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

// POI saraksts
                    Expanded(
                      child: _buildPoiList(
                        controller: scrollController,
                      ),
                    ),

                    // Create route tagad dzīvo pašā draggable panelī
                    if (_selectedRoutePois.isNotEmpty && _sheetController.size > 0.50)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            10,
                            16,
                            10,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final updatedPois =
                                await Navigator.push<List<Poi>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AlongRoutePreviewScreen(
                                      routePoints: widget.routePoints,
                                      startName: widget.startName,
                                      destinationName: widget.destinationName,
                                      distanceKm: widget.distanceKm,
                                      durationMinutes: widget.durationMinutes,
                                      pois: _selectedRoutePois.toList(),
                                    ),
                                  ),
                                );

                                if (!mounted) return;

                                if (updatedPois != null) {
                                  setState(() {
                                    _selectedRoutePois
                                      ..clear()
                                      ..addAll(updatedPois);
                                  });
                                }

// Pēc atgriešanās ļaujam DraggableScrollableSheet
// pilnībā pieslēgties atpakaļ ekrānam.
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted || !_sheetController.isAttached) return;

                                  _sheetController.jumpTo(0.32);
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10D9D1),
                                foregroundColor: const Color(0xFF062326),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(
                                Icons.route_rounded,
                                size: 25,
                              ),
                              label: Text(
                                AppLanguageService.tr(
                                  lv:
                                  'Izveidot maršrutu (${_selectedRoutePois.length})',
                                  en:
                                  'Create route (${_selectedRoutePois.length})',
                                ),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

        ],
      ),
    );
  }

  Widget _buildSearchStatus() {
    if (_searchFailed) {
      return Text(
        AppLanguageService.tr(
          lv: 'Meklēšanu neizdevās pabeigt.',
          en: 'The search could not be completed.',
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.redAccent,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    if (!_isSearching) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          if (_pois.length < 6 &&
              !_hasSearchedFarther &&
              MediaQuery.orientationOf(context) != Orientation.landscape) ...[
            const SizedBox(height: 0),

            Text(
              AppLanguageService.tr(
                lv: 'Pa ceļam atrasts maz vietu. Vai meklēt mazliet tālāk?',
                en: 'Only a few places were found along the route. Search a little farther?',
              ),
              style: const TextStyle(
                fontSize: 12,
                height: 1.1,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF10D9D1),
                      Color(0xFF17BEBB),
                      Color(0xFF0A8FA3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10D9D1).withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSearchingFarther
                      ? null
                      : _searchFarther,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  icon: _isSearchingFarther
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons.travel_explore,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isSearchingFarther
                        ? AppLanguageService.tr(
                      lv: 'Meklējam tālāk...',
                      en: 'Searching farther...',
                    )
                        : AppLanguageService.tr(
                      lv: 'Meklēt vēl',
                      en: 'Search farther',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }
    if (_isSearching) {
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF6B52E5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLanguageService.tr(
                lv: 'Meklējam... ${_pois.length} vietas atrastas',
                en: 'Searching... ${_pois.length} places found',
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6B52E5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF6B52E5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLanguageService.tr(
                  lv: 'Meklējam interesantas vietas...',
                  en: 'Finding interesting places...',
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B52E5),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Text(
          AppLanguageService.tr(
            lv: 'Atrastas ${_pois.length} vietas',
            en: '${_pois.length} places found',
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),

        if (_totalCenters > 0) ...[
          const SizedBox(height: 9),

          LinearProgressIndicator(
            value: _processedCenters / _totalCenters,
            minHeight: 6,
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF6B52E5),
            backgroundColor: const Color(0xFFEDE8FF),
          ),

          const SizedBox(height: 6),

          Text(
            AppLanguageService.tr(
              lv: 'Pārmeklēts: ${((_processedCenters / _totalCenters) * 100).round()}%',
              en: 'Searched: ${((_processedCenters / _totalCenters) * 100).round()}%',
            ),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
  Widget _buildCategoryChip({
    required String label,
    bool selected = false,
    bool showSwipeHint = false,
  }) {
    if (showSwipeHint) {
      return _SwipeLightChip(
        label: label,
        selected: selected,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF10D9D1)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? const Color(0xFF10D9D1)
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected
              ? Colors.black
              : Colors.white.withValues(alpha: 0.82),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
        
  String _poiCategoryLabel(Poi poi) {
    if (poi.categories.contains(PoiCategory.castle)) {
      return AppLanguageService.tr(lv: 'Pils', en: 'Castle');
    }

    if (poi.categories.contains(PoiCategory.museum)) {
      return AppLanguageService.tr(lv: 'Muzejs', en: 'Museum');
    }

    if (poi.categories.contains(PoiCategory.viewpoint)) {
      return AppLanguageService.tr(lv: 'Skatu vieta', en: 'Viewpoint');
    }

    if (poi.categories.contains(PoiCategory.nature)) {
      return AppLanguageService.tr(lv: 'Daba', en: 'Nature');
    }

    if (poi.categories.contains(PoiCategory.church)) {
      return AppLanguageService.tr(lv: 'Baznīca', en: 'Church');
    }

    if (poi.categories.contains(PoiCategory.monument)) {
      return AppLanguageService.tr(lv: 'Vēsture', en: 'History');
    }

    if (poi.categories.contains(PoiCategory.beach)) {
      return AppLanguageService.tr(lv: 'Pludmale', en: 'Beach');
    }

    if (poi.categories.contains(PoiCategory.food)) {
      return AppLanguageService.tr(lv: 'Ēdiens', en: 'Food');
    }

    if (poi.categories.contains(PoiCategory.city)) {
      return AppLanguageService.tr(lv: 'Pilsēta', en: 'City');
    }

    if (poi.categories.contains(PoiCategory.indoor)) {
      return AppLanguageService.tr(lv: 'Iekštelpās', en: 'Indoor');
    }

    return AppLanguageService.tr(
      lv: 'Interesanta vieta',
      en: 'Point of interest',
    );
  }
  Widget _buildPoiList({
    ScrollController? controller,
  }) {
    if (_pois.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLanguageService.tr(
              lv: 'Pagaidām nav atrastu vietu.',
              en: 'No places found yet.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      itemCount: _pois.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final poi = _pois[index];
        final isSelected = _selectedRoutePois.contains(poi);

        return InkWell(
          onTap: () => _togglePoiSelection(poi),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF103C3B)
                  : const Color(0xFF092A31),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF10D9D1)
                    : Colors.white.withValues(alpha: 0.12),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // POI numurs
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF10D9D1)
                        : const Color(0xFF6B52E5),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF062326)
                          : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // POI informācija
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Row(
                        children: [
                          Icon(
                            poi.isIndoor
                                ? Icons.museum_outlined
                                : Icons.landscape_outlined,
                            color: const Color(0xFF10D9D1),
                            size: 15,
                          ),

                          const SizedBox(width: 5),

                          Flexible(
                            child: Text(
                              _poiCategoryLabel(poi),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.58),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Icon(
                            Icons.schedule_rounded,
                            color: Colors.white.withValues(alpha: 0.45),
                            size: 14,
                          ),

                          const SizedBox(width: 4),

                          Text(
                            '${poi.visitMinutes} min',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      if (poi.shortDescription != null &&
                          poi.shortDescription!.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          poi.shortDescription!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // izvēle
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected
                      ? const Color(0xFF10D9D1)
                      : Colors.white.withValues(alpha: 0.35),
                  size: 28,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRouteMarker({
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
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.28,
            ),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _showPoiSheet(
      BuildContext context,
      Poi poi,
      int number,
      ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetContext) {
        final isSelected = _selectedRoutePois.contains(poi);
        return _buildPoiDetailContent(
          context: sheetContext,
          poi: poi,
          index: number,
          isSelected: isSelected,
          onAddToRoute: () {
            setState(() {
              if (_selectedRoutePois.contains(poi)) {
                _selectedRoutePois.remove(poi);
              } else {
                _selectedRoutePois.add(poi);
              }
            });

            Navigator.of(sheetContext).pop();
          },
          onMoreInfo: () async {
            final url = poi.infoUrl;

            if (url == null || url.isEmpty) return;

            final uri = Uri.tryParse(url);

            if (uri != null) {
              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            }
          },
        );
      },
    );
  }
}
Widget _buildPoiDetailContent({
  required BuildContext context,
  required Poi poi,
  required int index,
  required bool isSelected,
  required VoidCallback onAddToRoute,
  required VoidCallback onMoreInfo,
}) {
  // ============================================================
  // ALONG ROUTE 2.0 — VARIANTS 6
  // ============================================================

  const darkBg = Color(0xFF06261F);
  const neonGreen = Color(0xFF10D9D1);

  const greenDark = Color(0xFF10D9D1);
  const greenLight = Color(0xFF32F1E8);

  const cardBg = Color(0x1AFFFFFF);

  const white = Colors.white;
  const white70 = Color(0xB3FFFFFF);

  const cyan = Color(0xFF10D9D1);

  return Container(
    decoration: BoxDecoration(
      color: darkBg,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      border: Border.all(
        color: neonGreen.withValues(alpha: 0.40),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: neonGreen.withValues(alpha: 0.15),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ====================================================
            // 1. DRAG HANDLE
            // ====================================================

            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: neonGreen.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: neonGreen.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ====================================================
            // 2. NUMBER + TITLE
            // ====================================================

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // NUMBER CIRCLE
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: neonGreen,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: neonGreen.withValues(alpha: 0.40),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // TITLE
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      poi.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // ==================================================
                // IMAGE AREA
                //
                // Pagaidām apzināti bez poi.imageUrl,
                // jo pašreizējā Poi klasē tāda lauka nav.
                // ==================================================

                Container(
                  width: 92,
                  height: 68,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: neonGreen.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    color: Colors.white24,
                    size: 30,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ====================================================
            // 3. BADGES
            // ====================================================

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                      _buildPoiInfoChip(
                      icon: Icons.castle_outlined,
                      text: _poiCategoryLabel(poi),
                        color: neonGreen,
                    ),

                const SizedBox(width: 8),

                _buildPoiInfoChip(
                  icon: Icons.schedule_outlined,
                  text: '${poi.visitMinutes} min',
                  color: cyan,
                ),

                const SizedBox(width: 8),


                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ====================================================
            // 4. CATEGORY / DESCRIPTION
            // ====================================================


            if (poi.shortDescription != null &&
                poi.shortDescription!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),

              Text(
                poi.shortDescription!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],

            const SizedBox(height: 20),


            // ====================================================
            // 6. ADD TO ROUTE
            // ====================================================

            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),

                gradient: const LinearGradient(
                  colors: [
                    greenDark,
                    greenLight,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),

                boxShadow: [
                  BoxShadow(
                    color: neonGreen.withValues(alpha: 0.40),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onAddToRoute,

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),

                icon: Icon(
                  isSelected ? Icons.remove_road : Icons.add_road,
                  color: Colors.black,
                  size: 25,
                ),

                label: Text(
                  AppLanguageService.tr(
                    lv: isSelected
                        ? 'Noņemt no maršruta'
                        : 'Pievienot maršrutam',
                    en: isSelected
                        ? 'Remove from route'
                        : 'Add to route',
                  ),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ====================================================
            // 7. BOTTOM ACTIONS
            // ====================================================

            Container(
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0x1200FF66),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: neonGreen.withValues(alpha: 0.75),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [



                  // MORE INFO
                  Expanded(
                    flex: 2,
                    child: TextButton.icon(
                      onPressed: onMoreInfo,

                      icon: const Icon(
                        Icons.info_outline,
                        color: neonGreen,
                        size: 28,
                      ),

                      label: Text(
                        AppLanguageService.tr(
                          lv: 'Vairāk informācijas',
                          en: 'More info',
                        ),
                        style: const TextStyle(
                          color: white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                                 ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
Widget _buildPoiInfoChip({
  required IconData icon,
  required String text,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 13,
      vertical: 8,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: color.withValues(alpha: 0.55),
        width: 1.2,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

String _poiCategoryLabel(Poi poi) {
  if (poi.categories.contains(PoiCategory.castle)) {
    return AppLanguageService.tr(
      lv: 'Pils',
      en: 'Castle',
    );
  }

  if (poi.categories.contains(PoiCategory.nature)) {
    return AppLanguageService.tr(
      lv: 'Daba',
      en: 'Nature',
    );
  }

  if (poi.categories.contains(PoiCategory.viewpoint)) {
    return AppLanguageService.tr(
      lv: 'Skatu vieta',
      en: 'Viewpoint',
    );
  }

  if (poi.categories.contains(PoiCategory.museum)) {
    return AppLanguageService.tr(
      lv: 'Muzejs',
      en: 'Museum',
    );
  }

  return AppLanguageService.tr(
    lv: 'Interesanta vieta',
    en: 'Interesting place',
  );
}
class _SwipeLightChip extends StatefulWidget {
  final String label;
  final bool selected;

  const _SwipeLightChip({
    required this.label,
    this.selected = false,
  });

  @override
  State<_SwipeLightChip> createState() => _SwipeLightChipState();
}

class _SwipeLightChipState extends State<_SwipeLightChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _position = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _position,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFF10D9D1)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFF10D9D1)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor: 0.42,
                    alignment: Alignment(
                      -1.0 + (_position.value * 2.0),
                      0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFF10D9D1)
                                .withValues(alpha: 0.0),
                            const Color(0xFF10D9D1)
                                .withValues(alpha: 0.55),
                            const Color(0xFF10D9D1)
                                .withValues(alpha: 0.0),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.selected
                        ? Colors.black
                        : Colors.white.withValues(alpha: 0.88),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}