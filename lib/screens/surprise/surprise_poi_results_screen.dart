import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../services/poi_history_service.dart';
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
    if (!_hideVisited) {
      return widget.pois;
    }

    return widget.pois.where((poi) {
      return !_isVisited(poi);
    }).toList();
  }

  List<Poi> get selectedPois {
    return widget.pois
        .where((poi) => _selectedDurations.containsKey(poi.id))
        .toList();
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
              _optionButton('Uzmest aci (~15 min)', 0.25),
              _optionButton('Ātri izskriet (~45 min)', 0.75),
              _optionButton('Iepazīt nopietni (~90 min)', 1.5),
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

    if (!alreadySelectedBefore && !alreadyVisitedBefore) {
      return;
    }

    final messages = <String>[];

    if (alreadySelectedBefore) {
      messages.add(
        'Šis objekts jau ir izvēlēts '
            '${historyEntry.selectedCount} reizes.',
      );
    }

    if (alreadyVisitedBefore) {
      messages.add('Jūs šeit jau esat bijis.');
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Iepriekš izmantots objekts'),
          content: Text(messages.join('\n\n')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Saprotu'),
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
        const SnackBar(
          content: Text('Vispirms izvēlies vismaz vienu POI'),
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
        const SnackBar(
          content: Text('Neizdevās atvērt Google Maps'),
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

      if (isReturnToStart) {
        continue;
      }

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

    return Uri.https(
      'www.google.com',
      '/maps/dir/',
      queryParameters,
    ).toString();
  }

  void _openRoutePreview() {
    if (selectedPois.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vispirms izvēlies vismaz vienu POI'),
        ),
      );
      return;
    }

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
        title: const Text(
          'Izvēlies POI',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.black87,
          ),
        ),
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
                    const Text(
                      'Kopējais laiks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${totalHours.toStringAsFixed(1)} h',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Nerādīt apmeklētos'),
            subtitle: const Text(
              'Paslēpt POI, kuri jau atzīmēti kā apmeklēti',
            ),
            value: _hideVisited,
            onChanged: (value) {
              setState(() {
                _hideVisited = value;
              });
            },
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: filteredPois.length,
              itemBuilder: (context, index) {
                final poi = filteredPois[index];
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
                  subtitleParts.add('✓ Izvēlēts');
                }

                if (isVisited) {
                  subtitleParts.add('✓ Apmeklēts');
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isSelected
                              ? Colors.green.withValues(alpha: 0.12)
                              : isVisited
                              ? Colors.redAccent.withValues(alpha: 0.10)
                              : Colors.deepPurple.withValues(alpha: 0.08),
                        ),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle_outline
                              : isVisited
                              ? Icons.history
                              : _iconForPoi(poi),
                          color: isSelected
                              ? Colors.green
                              : isVisited
                              ? Colors.redAccent
                              : Colors.deepPurple,
                          size: 27,
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
                                fontSize: 17,
                                height: 1.15,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
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
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: isSelected
                                ? Colors.green.withValues(alpha: 0.12)
                                : const Color(0xFF6C63FF).withValues(alpha: 0.10),
                          ),
                          child: Text(
                            isSelected ? '✓' : 'Izvēlēties',
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? Colors.green.shade700 : const Color(0xFF6C63FF),
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
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
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
                  color: selectedPois.isEmpty
                      ? Colors.grey.shade300
                      : null,
                  boxShadow: selectedPois.isEmpty
                      ? []
                      : [
                    BoxShadow(
                      color: const Color(
                        0xFF6C63FF,
                      ).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: selectedPois.isEmpty
                        ? null
                        : _openRoutePreview,
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
                                ? 'Izvēlies POI'
                                : 'Parādīt maršrutu (${selectedPois.length})',
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: selectedPois.isEmpty
                      ? null
                      : _generateRoute,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Atvērt Google Maps'),
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
  if (poi.categories.contains(PoiCategory.nature)) return 'Daba';
  if (poi.categories.contains(PoiCategory.museum)) return 'Muzejs';
  if (poi.categories.contains(PoiCategory.mustSee)) return 'Must see';
  return 'Cits';
}

IconData _iconForPoi(Poi poi) {
  if (poi.categories.contains(PoiCategory.nature)) {
    return Icons.forest;
  }

  if (poi.categories.contains(PoiCategory.museum)) {
    return Icons.museum;
  }

  if (poi.categories.contains(PoiCategory.mustSee)) {
    return Icons.castle;
  }

  return Icons.place;
}