import 'package:flutter/material.dart';

import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../services/app_language_service.dart';
import '../../services/surprise_poi_service.dart';

class AlongRouteResultsScreen extends StatefulWidget {
  final List<LatLon> routePoints;
  final String startName;
  final String destinationName;
  final double distanceKm;
  final double durationMinutes;
  final double corridorKm;
  final List<Poi> pois;
  final Set<Poi> selectedPois;

  const AlongRouteResultsScreen({
    super.key,
    required this.routePoints,
    required this.startName,
    required this.destinationName,
    required this.distanceKm,
    required this.durationMinutes,
    required this.pois,
    required this.selectedPois,
    this.corridorKm = 5.0,
  });

  @override
  State<AlongRouteResultsScreen> createState() =>
      _AlongRouteResultsScreenState();
}

class _AlongRouteResultsScreenState
    extends State<AlongRouteResultsScreen> {
  final SurprisePoiService _poiService = SurprisePoiService();

  late List<Poi> _pois;
  late Set<Poi> _selectedPois;

  bool _isSearching = true;
  bool _searchFailed = false;

  int _processedCenters = 0;
  int _totalCenters = 0;
  int _visiblePoiCount = 0;

  @override
  void initState() {
    super.initState();
    _pois = List<Poi>.from(widget.pois);
    _selectedPois = Set<Poi>.from(widget.selectedPois);
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

            if (_visiblePoiCount == 0) {
              _visiblePoiCount = 4;
            } else {
              _visiblePoiCount += 5;
            }

            if (_visiblePoiCount > progressPois.length) {
              _visiblePoiCount = progressPois.length;
            }

            _pois = progressPois
                .take(_visiblePoiCount)
                .toList();
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _pois = finalPois;
        _isSearching = false;
        _searchFailed = false;

        if (_totalCenters > 0) {
          _processedCenters = _totalCenters;
        }
      });
    } catch (error) {
      debugPrint('Along Route POI search error: $error');

      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _searchFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLanguageService.tr(
            lv: 'Vietas pa ceļam',
            en: 'Places along route',
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.startName} → ${widget.destinationName}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      '${widget.distanceKm.toStringAsFixed(1)} km  •  '
                          '${widget.durationMinutes.toStringAsFixed(0)} min',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_isSearching) ...[
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
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
                                fontSize: 15,
                                color: Color(0xFF6B52E5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        AppLanguageService.tr(
                          lv: 'Atrastas ${_pois.length} vietas',
                          en: '${_pois.length} places found',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      if (_totalCenters > 0) ...[
                        const SizedBox(height: 8),

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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ] else if (_searchFailed) ...[
                      Text(
                        AppLanguageService.tr(
                          lv: 'Meklēšanu neizdevās pabeigt.',
                          en: 'The search could not be completed.',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else ...[
                      Text(
                        AppLanguageService.tr(
                          lv: 'Atrastas ${_pois.length} interesantas vietas',
                          en: '${_pois.length} interesting places found',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF6B52E5),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Expanded(
              child: _pois.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _isSearching
                        ? AppLanguageService.tr(
                      lv: 'Pirmās vietas parādīsies jau meklēšanas laikā.',
                      en: 'The first places will appear while searching.',
                    )
                        : AppLanguageService.tr(
                      lv: 'Šajā maršrutā interesantas vietas netika atrastas.',
                      en: 'No interesting places were found along this route.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black54,
                    ),
                  ),
                ),
              )
                  : ListView.separated(
                padding:
                const EdgeInsets.fromLTRB(20, 8, 20, 28),
                itemCount: _pois.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final poi = _pois[index];
                  final isSelected = _selectedPois.contains(poi);
                  return InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedPois.remove(poi);
                          } else {
                            _selectedPois.add(poi);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF2EEFF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEDE8FF),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF6B52E5),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            poi.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? const Color(0xFF6B52E5)
                              : Colors.black38,
                          size: 28,
                        ),
                      ],
                    ),
                      ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}