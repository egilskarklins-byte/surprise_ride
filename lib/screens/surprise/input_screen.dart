import 'package:flutter/material.dart';

import '../../models/geo.dart';
import '../../services/geocoding_service.dart' as geo_search;
import '../../services/places_service.dart';
import '../../services/surprise_poi_service.dart';
import 'pick_start_on_map_screen.dart';
import 'surprise_poi_results_screen.dart';

class SurpriseInputScreen extends StatefulWidget {
  const SurpriseInputScreen({super.key});

  @override
  State<SurpriseInputScreen> createState() => _SurpriseInputScreenState();
}

class _SurpriseInputScreenState extends State<SurpriseInputScreen> {
  final PlacesService _places = PlacesService();
  final geo_search.GeocodingService _geocoding =
  geo_search.GeocodingService();

  final TextEditingController _searchCtrl = TextEditingController();

  static const LatLon _defaultStart = LatLon(56.9496, 24.1052);
  static const String _defaultStartLabel = 'Rīga';

  LatLon start = _defaultStart;
  String startLabel = _defaultStartLabel;
  double radiusKm = 50;
  bool _loading = false;
  bool _searchingStart = false;

  List<geo_search.PlaceSuggestion> _startSuggestions = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onStartSearchChanged(String value) async {
    final query = value.trim();

    if (query.length < 2) {
      setState(() {
        _startSuggestions = [];
        _searchingStart = false;
      });
      return;
    }

    setState(() => _searchingStart = true);

    try {
      final results = await _geocoding.search(query);

      if (!mounted) return;

      setState(() {
        _startSuggestions = results;
        _searchingStart = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _startSuggestions = [];
        _searchingStart = false;
      });
    }
  }

  void _selectStartSuggestion(geo_search.PlaceSuggestion suggestion) {
    setState(() {
      start = suggestion.location;
      startLabel = suggestion.name;
      _searchCtrl.text = suggestion.name;
      _startSuggestions = [];
    });
  }

  Future<void> _pickStartOnMap() async {
    final result = await Navigator.push<LatLon>(
      context,
      MaterialPageRoute(
        builder: (_) => PickStartOnMapScreen(initial: start),
      ),
    );

    if (result == null) return;

    try {
      final name = await _places.reverseGeocode(
        location: result,
        languageCode: 'lv',
      );

      if (!mounted) return;

      setState(() {
        start = result;
        startLabel = name ??
            'Kartes punkts (${result.lat.toStringAsFixed(4)}, ${result.lon.toStringAsFixed(4)})';
        _searchCtrl.text = startLabel;
        _startSuggestions = [];
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        start = result;
        startLabel =
        'Kartes punkts (${result.lat.toStringAsFixed(4)}, ${result.lon.toStringAsFixed(4)})';
        _searchCtrl.text = startLabel;
        _startSuggestions = [];
      });
    }
  }

  void _setRadius(double value) {
    setState(() {
      radiusKm = value;
    });
  }

  Future<void> _loadPois() async {
    setState(() => _loading = true);

    try {
      final pois = await SurprisePoiService().fetchPoisInRadius(
        center: start,
        radiusKm: radiusKm,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SurprisePoiResultsScreen(
            pois: pois,
            start: start,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kļūda: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildQuickRadiusChip(double value) {
    final selected = radiusKm.round() == value.round();

    return ChoiceChip(
      label: Text('${value.toInt()} km'),
      selected: selected,
      onSelected: (_) => _setRadius(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surprise Ride'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sākumpunkts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchCtrl,
                    enabled: !_loading,
                    onChanged: _onStartSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Ieraksti pilsētu vai vietu',
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchingStart
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : const Icon(Icons.search),
                    ),
                  ),
                  if (_startSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context).cardColor,
                      ),
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _startSuggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final suggestion = _startSuggestions[index];

                          return ListTile(
                            dense: true,
                            title: Text(suggestion.name),
                            onTap: () => _selectStartSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Izvēlēts: $startLabel',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lat: ${start.lat.toStringAsFixed(5)}, Lon: ${start.lon.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickStartOnMap,
                    icon: const Icon(Icons.map),
                    label: const Text('Izvēlēties kartē'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meklēšanas rādiuss',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${radiusKm.toInt()} km',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Slider(
                    value: radiusKm,
                    min: 10,
                    max: 150,
                    divisions: 14,
                    label: '${radiusKm.toInt()} km',
                    onChanged: _loading ? null : _setRadius,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickRadiusChip(20),
                      _buildQuickRadiusChip(50),
                      _buildQuickRadiusChip(100),
                      _buildQuickRadiusChip(150),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Lielākam rādiusam tiek izmantoti vairāki meklēšanas centri, lai rezultāti tiešām mainītos.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 1,
            color: Colors.blueGrey.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kas tiks meklēts',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'App meklēs interesantus POI ap "$startLabel" aptuveni ${radiusKm.toInt()} km rādiusā.',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pēc tam varēsi izvēlēties POI un uzģenerēt maršrutu ar atgriešanos sākumpunktā.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _loadPois,
              icon: _loading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.travel_explore),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  _loading ? 'Meklē POI...' : 'Atrast POI',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Text(
                'Notiek POI meklēšana. Tas var aizņemt dažas sekundes.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}