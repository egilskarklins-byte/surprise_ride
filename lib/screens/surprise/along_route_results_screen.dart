import 'package:flutter/material.dart';

import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../services/app_language_service.dart';


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


  late List<Poi> _pois;
  late Set<Poi> _selectedPois;

  bool _isSearching = false;
  bool _searchFailed = false;

  int _processedCenters = 0;
  int _totalCenters = 0;


  @override
  void initState() {
    super.initState();
    _pois = List<Poi>.from(widget.pois);
    _selectedPois = Set<Poi>.from(widget.selectedPois);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061516),
      appBar: AppBar(
        backgroundColor: const Color(0xFF061516),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context, _selectedPois);
          },
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          AppLanguageService.tr(
            lv: 'Vietas pa ceļam',
            en: 'Places along route',
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
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
                  color: const Color(0xFF0B2A2B).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF10D9D1).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10D9D1).withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
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
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      '${widget.distanceKm.toStringAsFixed(1)} km  •  '
                          '${widget.durationMinutes.toStringAsFixed(0)} min',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFFB9D8D6),
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
                              color: Color(0xFF10D9D1),
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
                                color: Color(0xFF10D9D1),
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
                              ? const Color(0xFF103C3B)
                              : const Color(0xFF0B2627),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF10D9D1)
                                : const Color(0xFF10D9D1).withValues(alpha: 0.22),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10D9D1).withValues(
                                alpha: isSelected ? 0.16 : 0.06,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10D9D1).withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF10D9D1).withValues(alpha: 0.55),
                            ),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF10D9D1),
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
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? const Color(0xFF10D9D1)
                              : Colors.white38,
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