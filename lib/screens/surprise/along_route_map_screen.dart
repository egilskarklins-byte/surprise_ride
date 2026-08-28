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


class AlongRouteMapScreen extends StatefulWidget {
  
  final List<LatLon> routePoints;
  final String startName;
  final String destinationName;
  final double distanceKm;
  final double durationMinutes;
  final double corridorKm;


  const AlongRouteMapScreen({
    super.key,
    required this.routePoints,
    required this.startName,
    required this.destinationName,
    required this.distanceKm,
    required this.durationMinutes,
    this.corridorKm = 5.0,
  });

  @override
  State<AlongRouteMapScreen> createState() =>
      _AlongRouteMapScreenState();
}

class _AlongRouteMapScreenState extends State<AlongRouteMapScreen> {
  final Set<Poi> _selectedRoutePois = {};
  final SurprisePoiService _poiService = SurprisePoiService();


  List<Poi> _pois = [];

  bool _isSearching = true;
  bool _searchFailed = false;
  bool _isSearchingFarther = false;
  bool _hasSearchedFarther = false;

  int _processedCenters = 0;
  int _totalCenters = 0;


  List<Poi> _targetPois = [];
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _startPoiSearch();
  }
  void _updateVisiblePois(List<Poi> newPois) {
    _targetPois = List<Poi>.from(newPois);

    // Kamēr POI skaits aug, saglabājam pakāpenisko parādīšanos.
    if (_targetPois.length > _pois.length) {
      _startRevealTimer();
      return;
    }

    // Ja jau sasniegti, piemēram, 30 POI, bet nākamie
    // maršruta posmi devuši citu POI komplektu,
    // atjaunojam karti ar jaunāko sadalījumu.
    setState(() {
      _pois = List<Poi>.from(_targetPois);

    });
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
        (_pois.length + 2).clamp(0, _targetPois.length);

        setState(() {
          _pois = _targetPois.take(nextCount).toList();

        });
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

          _updateVisiblePois(progressPois);
        },
      );

      if (!mounted) return;

      if (!mounted) return;

      setState(() {
        _targetPois = List<Poi>.from(finalPois);
        _pois = List<Poi>.from(finalPois);

        if (_totalCenters > 0) {
          _processedCenters = _totalCenters;
        }

        _isSearching = false;
        _searchFailed = false;

      });
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
  @override
  void dispose() {
    _revealTimer?.cancel();
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
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'lv.surpriseride.app',
              ),

              // A → B maršruta līnija
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routeLatLngs,
                    strokeWidth: 5,
                    color: const Color(0xFF6B52E5),
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
                    child: _buildRouteMarker(
                      text: 'A',
                      color: const Color(0xFF17BEBB),
                    ),
                  ),

                  // ====================================================
                  // B
                  // ====================================================
                  Marker(
                    point: routeLatLngs.last,
                    width: 56,
                    height: 56,
                    child: _buildRouteMarker(
                      text: 'B',
                      color: const Color(0xFFFF8A4C),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Augšējā Home Screen stila informācijas kartīte
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  10,
                  14,
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    12,
                    16,
                    14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.94,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.14,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 4),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.startName} → '
                                  '${widget.destinationName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              '${widget.distanceKm.toStringAsFixed(1)} km'
                                  '  •  '
                                  '${_formatDuration(widget.durationMinutes)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Apakšējais progress
          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.95,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.15,
                      ),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedRoutePois.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final updatedPois = await Navigator.push<List<Poi>>(
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
                            if (updatedPois == null || !mounted) return;

                            setState(() {
                              _selectedRoutePois
                                ..clear()
                                ..addAll(updatedPois);
                            });
                          },
                          icon: const Icon(Icons.route),
                          label: Text(
                            AppLanguageService.tr(
                              lv: 'Izveidot maršrutu (${_selectedRoutePois.length})',
                              en: 'Create route (${_selectedRoutePois.length})',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    _buildSearchStatus(),
                  ],
                ),
              ),
            ),
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
          GestureDetector(
            onTap: _pois.isEmpty
                ? null
                : () async {
              final selectedPois = await Navigator.push<Set<Poi>>(
                context,
                MaterialPageRoute(
                  builder: (_) => AlongRouteResultsScreen(
                    routePoints: widget.routePoints,
                    startName: widget.startName,
                    destinationName: widget.destinationName,
                    distanceKm: widget.distanceKm,
                    durationMinutes: widget.durationMinutes,
                    corridorKm: widget.corridorKm,
                    pois: _pois,
                    selectedPois: _selectedRoutePois,
                  ),
                ),
              );

              if (selectedPois == null || !mounted) return;

              setState(() {
                _selectedRoutePois
                  ..clear()
                  ..addAll(selectedPois);
              });
            },
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10D9D1),
                  size: 28,
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLanguageService.tr(
                          lv: 'Atrastas ${_pois.length} interesantas vietas',
                          en: '${_pois.length} interesting places found',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        _selectedRoutePois.isEmpty
                            ? AppLanguageService.tr(
                          lv: 'Izvēlies vietas sarakstā vai kartē',
                          en: 'Choose places from the list or map',
                        )
                            : AppLanguageService.tr(
                          lv: 'Izvēlētas ${_selectedRoutePois.length} vietas · pieskaries, lai mainītu',
                          en: '${_selectedRoutePois.length} places selected · tap to change',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF10D9D1),
                  size: 30,
                ),
              ],
            ),
          ),
          if (_pois.length < 6 && !_hasSearchedFarther) ...[
            const SizedBox(height: 12),

            Text(
              AppLanguageService.tr(
                lv: 'Pa ceļam atrasts maz vietu. Vai meklēt mazliet tālāk?',
                en: 'Only a few places were found along the route. Search a little farther?',
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSearchingFarther
                    ? null
                    : _searchFarther,
                icon: _isSearchingFarther
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.travel_explore),
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
                ),
              ),
            ),
          ],
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
              lv: 'Meklēšana: $_processedCenters no $_totalCenters posmiem',
              en: 'Searching: $_processedCenters of $_totalCenters sections',
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
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. ${poi.name}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                if (poi.shortDescription != null &&
                    poi.shortDescription!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    poi.shortDescription!,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                Text(
                  AppLanguageService.tr(
                    lv: 'Vieta atrasta pa ceļam.',
                    en: 'Place found along your route.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF6B52E5),
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_selectedRoutePois.contains(poi)) {
                          _selectedRoutePois.remove(poi);
                        } else {
                          _selectedRoutePois.add(poi);
                        }
                      });

                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add_road),
                    label: Text(
                      AppLanguageService.tr(
                        lv: _selectedRoutePois.contains(poi)
                            ? 'Noņemt no maršruta'
                            : 'Pievienot maršrutam',
                        en: _selectedRoutePois.contains(poi)
                            ? 'Remove from route'
                            : 'Add to route',
                      ),
                    ),
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