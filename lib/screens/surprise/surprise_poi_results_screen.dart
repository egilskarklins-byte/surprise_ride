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
      appBar: AppBar(
        title: const Text('Izvēlies POI'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.green.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kopējais laiks:'),
                Text('${totalHours.toStringAsFixed(1)} h'),
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
                    ? Colors.grey.withValues(alpha: 0.15)
                    : Colors.transparent;

                final subtitleParts = <String>[
                  formatCategory(poi),
                ];

                if (isSelected) {
                  subtitleParts.add('✓ Izvēlēts');
                }

                if (isVisited) {
                  subtitleParts.add('✓ Apmeklēts');
                }

                return Container(
                  color: tileColor,
                  child: ListTile(
                    leading: isSelected
                        ? const Icon(Icons.check_circle_outline)
                        : isVisited
                        ? const Icon(Icons.history)
                        : const Icon(Icons.place_outlined),
                    title: Text(
                      poi.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : null,
                        color: isVisited && !isSelected ? Colors.grey.shade700 : null,
                      ),
                    ),
                    subtitle: Text(subtitleParts.join(' • ')),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (val) async {
                        if (val == true) {
                          await _selectDuration(poi);
                        } else {
                          setState(() {
                            _selectedDurations.remove(poi.id);
                          });
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedPois.isEmpty ? null : _openRoutePreview,
                child: Text(
                  selectedPois.isEmpty
                      ? 'Izvēlies POI'
                      : 'Parādīt maršrutu (${selectedPois.length})',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: selectedPois.isEmpty ? null : _generateRoute,
                child: const Text('Atvērt Google Maps'),
              ),
            ),
          ],
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