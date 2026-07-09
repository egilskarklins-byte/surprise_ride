import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'found_poi_map_screen.dart';
import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../services/app_language_service.dart';
import '../../services/poi_history_service.dart';
import '../../services/route_history_service.dart';
import '../../services/simple_route_builder.dart';
import 'surprise_route_screen.dart';

class SurprisePoiResultsScreen extends StatefulWidget {
  final List<Poi> pois;
  final LatLon start;

  const SurprisePoiResultsScreen({
    super.key,
    required this.pois,
    required this.start,
  });

  @override
  State<SurprisePoiResultsScreen> createState() =>
      _SurprisePoiResultsScreenState();
}

class _SurprisePoiResultsScreenState extends State<SurprisePoiResultsScreen> {
  final Map<String, double> _selectedDurations = {};
  final PoiHistoryService _historyService = PoiHistoryService();
  final RouteHistoryService _routeHistoryService = RouteHistoryService();

  Map<String, PoiHistoryEntry> _history = {};
  bool _hideVisited = false;

  @override
  void initState() {
    super.initState();
    _initHistory();
  }

  Future<void> _initHistory() async {
    await _historyService.markGenerated(widget.pois);
    final history = await _historyService.loadHistory();

    if (!mounted) return;

    setState(() {
      _history = history;
    });
  }

  double get totalHours {
    return _selectedDurations.values.fold(0.0, (a, b) => a + b);
  }

  List<Poi> get filteredPois {
    if (!_hideVisited) return widget.pois;

    return widget.pois.where((poi) {
      return !_isVisited(poi);
    }).toList();
  }

  List<Poi> get selectedPois {
    return widget.pois
        .where((poi) => _selectedDurations.containsKey(poi.id))
        .map((poi) {
      final durationH = _selectedDurations[poi.id] ?? poi.durationH;
      final visitMinutes = (durationH * 60).round();

      return Poi(
        id: poi.id,
        name: poi.name,
        location: poi.location,
        durationH: durationH,
        visitMinutes: visitMinutes,
        shortDescription: poi.shortDescription,
        infoUrl: poi.infoUrl,
        categories: poi.categories,
        isIndoor: poi.isIndoor,
      );
    }).toList();
  }

  List<Poi> get orderedSelectedRoute {
    return SimpleRouteBuilder.buildRoute(
      start: widget.start,
      pois: selectedPois,
      returnToStart: true,
    );
  }

  Future<void> _selectDuration(Poi poi) async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(poi.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _optionButton(
                AppLanguageService.tr(
                  lv: 'Uzmest aci (~15 min)',
                  en: 'Quick look (~15 min)',
                ),
                0.25,
              ),
              _optionButton(
                AppLanguageService.tr(
                  lv: 'Ātri izskriet (~45 min)',
                  en: 'Short visit (~45 min)',
                ),
                0.75,
              ),
              _optionButton(
                AppLanguageService.tr(
                  lv: 'Iepazīt nopietni (~90 min)',
                  en: 'Explore properly (~90 min)',
                ),
                1.5,
              ),
              if (_isLargePoi(poi)) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppLanguageService.tr(
                            lv: 'Šī objekta pilnvērtīga apskate var aizņemt vairāk nekā 90 min.',
                            en: 'A full visit to this place may take more than 90 minutes.',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );

    if (result != null) {
      final historyEntry = await _historyService.markSelected(poi);
      final history = await _historyService.loadHistory();

      if (!mounted) return;

      setState(() {
        _selectedDurations[poi.id] = result;
        _history = history;
      });

      await _showPoiHistoryWarningIfNeeded(historyEntry);
    }
  }

  Future<void> _showPoiHistoryWarningIfNeeded(
      PoiHistoryEntry historyEntry,
      ) async {
    final alreadySelectedBefore = historyEntry.selectedCount > 1;
    final alreadyVisitedBefore = historyEntry.visited;

    if (!alreadySelectedBefore && !alreadyVisitedBefore) return;

    final messages = <String>[];

    if (alreadySelectedBefore) {
      messages.add(
        AppLanguageService.tr(
          lv: 'Šis objekts jau ir izvēlēts ${historyEntry.selectedCount} reizes.',
          en: 'This place has already been selected ${historyEntry.selectedCount} times.',
        ),
      );
    }

    if (alreadyVisitedBefore) {
      messages.add(
        AppLanguageService.tr(
          lv: 'Jūs šeit jau esat bijis.',
          en: 'You have already visited this place.',
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            AppLanguageService.tr(
              lv: 'Iepriekš izmantots objekts',
              en: 'Previously used place',
            ),
          ),
          content: Text(messages.join('\n\n')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                AppLanguageService.tr(
                  lv: 'Saprotu',
                  en: 'Got it',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _optionButton(String text, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context, value);
        },
        child: Text(text),
      ),
    );
  }

  Future<void> _generateRoute() async {
    if (selectedPois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageService.tr(
              lv: 'Vispirms izvēlies vismaz vienu vietu',
              en: 'Please select at least one olace first',
            ),
          ),
        ),
      );
      return;
    }

    final url = _buildGoogleMapsDirectionsUrl(
      start: widget.start,
      route: orderedSelectedRoute,
    );

    final uri = Uri.parse(url);


   
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageService.tr(
              lv: 'Neizdevās atvērt Google Maps',
              en: 'Could not open Google Maps',
            ),
          ),
        ),
      );
    }
  }

  String _buildGoogleMapsDirectionsUrl({
    required LatLon start,
    required List<Poi> route,
  }) {
    final waypoints = <String>[];

    for (final poi in route) {


      final isReturnToStart =
          poi.location.lat == start.lat && poi.location.lon == start.lon;

      if (isReturnToStart) continue;

      waypoints.add('${poi.location.lat},${poi.location.lon}');
    }

    final queryParameters = <String, String>{
      'api': '1',
      'origin': '${start.lat},${start.lon}',
      'destination': '${start.lat},${start.lon}',
      'travelmode': 'driving',
    };

    if (waypoints.isNotEmpty) {
      queryParameters['waypoints'] = waypoints.join('|');
    }

    final url = Uri.https(
      'www.google.com',
      '/maps/dir/',
      queryParameters,
    ).toString();



    return url;
  }

  Future<void> _openRoutePreview() async {
    if (selectedPois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageService.tr(
              lv: 'Vispirms izvēlies vismaz vienu vietu',
              en: 'Please select at least one place first',
            ),
          ),
        ),
      );
      return;
    }

    await _routeHistoryService.saveRoute(
      start: widget.start,
      pois: orderedSelectedRoute,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurpriseRouteScreen(
          route: orderedSelectedRoute,
          start: widget.start,
          apiKey: '',
        ),
      ),
    );
  }

  bool _isVisited(Poi poi) {
    final entry = _history[_poiKey(poi)];
    return entry?.visited ?? false;
  }

  String _poiKey(Poi poi) {
    final name = poi.name.trim().toLowerCase();
    final lat = poi.location.lat.toStringAsFixed(5);
    final lon = poi.location.lon.toStringAsFixed(5);

    return '$name|$lat|$lon';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,

        title: Text(
          AppLanguageService.tr(
            lv: 'Izvēlies vietas',
            en: 'Choose places',
          ),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.black87,
          ),
        ),

        actions: [
          IconButton(
            tooltip: AppLanguageService.tr(
              lv: 'Skatīt kartē',
              en: 'View on map',
            ),
            icon: const Icon(Icons.map_outlined),
            onPressed: () async {
              final selectedPoiId = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => FoundPoiMapScreen(
                    pois: filteredPois,
                    start: widget.start,
                    selectedCount: _selectedDurations.length,
                    totalHours: totalHours,
                    selectedPoiIds: _selectedDurations.keys.toSet(),
                  ),
                ),
              );

              if (selectedPoiId == null) return;
              if (!mounted) return;

              final poi = filteredPois.firstWhere(
                    (p) => p.id == selectedPoiId,
              );

              await _selectDuration(poi);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLanguageService.tr(
                        lv: 'Kopējais laiks',
                        en: 'Total time',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  formatDurationHours(totalHours),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                selected: _hideVisited,
                avatar: Icon(
                  _hideVisited ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                label: Text(
                  AppLanguageService.tr(
                    lv: 'Slēpt apmeklētos',
                    en: 'Hide visited',
                  ),
                ),
                onSelected: (value) {
                  setState(() {
                    _hideVisited = value;
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: filteredPois.length,
              itemBuilder: (context, index) {
                final poi = filteredPois[index];
                final mapNumber = index + 1;
                final isSelected = _selectedDurations.containsKey(poi.id);
                final isVisited = _isVisited(poi);

                final tileColor = isSelected
                    ? Colors.green.withValues(alpha: 0.10)
                    : isVisited
                    ? Colors.redAccent.withValues(alpha: 0.08)
                    : Colors.white;

                final subtitleParts = <String>[
                  formatCategory(poi),
                ];

                if (isSelected) {
                  subtitleParts.add(
                    AppLanguageService.tr(
                      lv: '✓ Izvēlēts',
                      en: '✓ Selected',
                    ),
                  );
                }

                if (isVisited) {
                  subtitleParts.add(
                    AppLanguageService.tr(
                      lv: '✓ Apmeklēts',
                      en: '✓ Visited',
                    ),
                  );
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected
                          ? Colors.green.withValues(alpha: 0.28)
                          : isVisited
                          ? Colors.redAccent.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.045),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isSelected
                              ? Colors.green.withValues(alpha: 0.12)
                              : isVisited
                              ? Colors.redAccent.withValues(alpha: 0.10)
                              : Colors.deepPurple.withValues(alpha: 0.08),
                        ),
                        child: Center(
                          child: Text(
                            '$mapNumber',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.green
                                  : isVisited
                                  ? Colors.redAccent
                                  : Colors.deepPurple,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              poi.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.15,
                                fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w700,
                                color: isVisited && !isSelected
                                    ? Colors.redAccent.shade700
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              subtitleParts.join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected
                                    ? Colors.green.shade700
                                    : isVisited
                                    ? Colors.redAccent.shade700
                                    : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          if (isSelected) {
                            setState(() {
                              _selectedDurations.remove(poi.id);
                            });
                          } else {
                            await _selectDuration(poi);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: isSelected
                                ? Colors.green.withValues(alpha: 0.12)
                                : const Color(0xFF6C63FF)
                                .withValues(alpha: 0.10),
                          ),
                          child: Text(
                            isSelected
                                ? '✓'
                                : AppLanguageService.tr(
                              lv: 'Izvēlēties',
                              en: 'Select',
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? Colors.green.shade700
                                  : const Color(0xFF6C63FF),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 10, 14, 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: selectedPois.isEmpty
                      ? null
                      : const LinearGradient(
                    colors: [
                      Color(0xFF6C63FF),
                      Color(0xFF8E7BFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  color: selectedPois.isEmpty ? Colors.grey.shade300 : null,
                  boxShadow: selectedPois.isEmpty
                      ? []
                      : [
                    BoxShadow(
                      color: const Color(0xFF6C63FF)
                          .withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: selectedPois.isEmpty ? null : _openRoutePreview,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.route,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            selectedPois.isEmpty
                                ? AppLanguageService.tr(
                              lv: 'Izvēlies vietas',
                              en: 'Choose places',
                            )
                                : AppLanguageService.tr(
                              lv: 'Parādīt maršrutu (${selectedPois.length})',
                              en: 'Show route (${selectedPois.length})',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: selectedPois.isEmpty ? null : _generateRoute,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    AppLanguageService.tr(
                      lv: 'Atvērt Google Maps',
                      en: 'Open Google Maps',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatCategory(Poi poi) {
  if (poi.categories.contains(PoiCategory.castle)) {
    return AppLanguageService.tr(
      lv: '🏰 Pils / Muiža',
      en: '🏰 Castle / Manor',
    );
  }

  if (poi.categories.contains(PoiCategory.museum)) {
    return AppLanguageService.tr(
      lv: '🏛 Muzejs',
      en: '🏛 Museum',
    );
  }

  if (poi.categories.contains(PoiCategory.nature)) {
    return AppLanguageService.tr(
      lv: '🌲 Daba',
      en: '🌲 Nature',
    );
  }

  if (poi.categories.contains(PoiCategory.church)) {
    return AppLanguageService.tr(
      lv: '⛪ Baznīca',
      en: '⛪ Church',
    );
  }

  if (poi.categories.contains(PoiCategory.monument)) {
    return AppLanguageService.tr(
      lv: '🗿 Piemineklis',
      en: '🗿 Monument',
    );
  }

  if (poi.categories.contains(PoiCategory.viewpoint)) {
    return AppLanguageService.tr(
      lv: '🌄 Skatu vieta',
      en: '🌄 Viewpoint',
    );
  }

  return AppLanguageService.tr(
    lv: '📍 Apskates objekts',
    en: '📍 Point of interest',
  );
}

bool _isLargePoi(Poi poi) {
  final name = poi.name.toLowerCase();

  if (poi.categories.contains(PoiCategory.museum)) return true;
  if (poi.categories.contains(PoiCategory.castle)) return true;

  if (name.contains('museum')) return true;
  if (name.contains('muzej')) return true;
  if (name.contains('castle')) return true;
  if (name.contains('pils')) return true;
  if (name.contains('muiža')) return true;
  if (name.contains('manor')) return true;
  if (name.contains('palace')) return true;
  if (name.contains('zoo')) return true;
  if (name.contains('national park')) return true;
  if (name.contains('trail')) return true;

  return false;
}

String formatDurationHours(double hours) {
  final totalMinutes = (hours * 60).round();

  if (totalMinutes < 60) {
    return '$totalMinutes min';
  }

  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;

  if (m == 0) {
    return '$h h';
  }

  return '$h h $m min';
}

