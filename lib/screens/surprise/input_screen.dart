import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/geo.dart';
import '../../services/geocoding_service.dart' as geo_search;
import '../../services/surprise_poi_service.dart';
import 'pick_start_on_map_screen.dart';
import 'surprise_poi_results_screen.dart';
import 'history_stats_screen.dart';

class SurpriseInputScreen extends StatefulWidget {
  const SurpriseInputScreen({super.key});

  @override
  State<SurpriseInputScreen> createState() => _SurpriseInputScreenState();
}

class _SurpriseInputScreenState extends State<SurpriseInputScreen> {
  final geo_search.GeocodingService _geocoding =
  geo_search.GeocodingService();

  final TextEditingController _searchCtrl = TextEditingController();

  Timer? _searchDebounce;
  int _searchRequestId = 0;

  static const LatLon _defaultStart = LatLon(56.9496, 24.1052);
  static const String _defaultStartLabel = 'Rīga';

  LatLon start = _defaultStart;
  String startLabel = _defaultStartLabel;
  double radiusKm = 50;

  bool _loading = false;
  bool _locatingStart = false;
  bool _searchingStart = false;
  bool _editingStart = false;

  List<geo_search.PlaceSuggestion> _startSuggestions = [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }
  void _openHistoryStats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HistoryStatsScreen(),
      ),
    );
  }
  void _clearStartSearch() {
    _searchDebounce?.cancel();
    _searchRequestId++;

    setState(() {
      _searchCtrl.clear();
      _editingStart = false;
      _startSuggestions = [];
      _searchingStart = false;
    });
  }

  void _cancelStartEdit() {
    _searchDebounce?.cancel();
    _searchRequestId++;

    setState(() {
      _searchCtrl.text = startLabel;
      _editingStart = false;
      _startSuggestions = [];
      _searchingStart = false;
    });
  }

  void _onStartSearchChanged(String value) {
    final query = value.trim();

    _searchDebounce?.cancel();
    _searchRequestId++;

    if (query.isEmpty) {
      setState(() {
        _editingStart = false;
        _startSuggestions = [];
        _searchingStart = false;
      });
      return;
    }

    setState(() {
      _editingStart = true;
      _startSuggestions = [];
      _searchingStart = query.length >= 2;
    });

    if (query.length < 2) {
      setState(() {
        _searchingStart = false;
      });
      return;
    }

    final requestId = _searchRequestId;

    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final results = await _geocoding.search(
          query,
          biasCenter: start,
        );

        if (!mounted || requestId != _searchRequestId) return;

        setState(() {
          _startSuggestions = results;
          _searchingStart = false;
        });
      } catch (_) {
        if (!mounted || requestId != _searchRequestId) return;

        setState(() {
          _startSuggestions = [];
          _searchingStart = false;
        });
      }
    });
  }

  void _selectStartSuggestion(geo_search.PlaceSuggestion suggestion) {
    _searchDebounce?.cancel();
    _searchRequestId++;

    setState(() {
      start = suggestion.location;
      startLabel = suggestion.name;
      _searchCtrl.text = suggestion.name;
      _editingStart = false;
      _startSuggestions = [];
      _searchingStart = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_loading || _locatingStart) return;

    setState(() {
      _locatingStart = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ieslēdz atrašanās vietas noteikšanu ierīcē.'),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atrašanās vietas atļauja netika piešķirta.'),
          ),
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Atrašanās vieta ir bloķēta. Atļauju var mainīt pārlūka vai ierīces iestatījumos.',
            ),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final picked = LatLon(position.latitude, position.longitude);

      final label =
          'Mana atrašanās vieta (${picked.lat.toStringAsFixed(4)}, ${picked.lon.toStringAsFixed(4)})';

      _searchDebounce?.cancel();
      _searchRequestId++;

      if (!mounted) return;

      setState(() {
        start = picked;
        startLabel = label;
        _searchCtrl.text = label;
        _editingStart = false;
        _startSuggestions = [];
        _searchingStart = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neizdevās noteikt atrašanās vietu: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _locatingStart = false;
        });
      }
    }
  }

  Future<void> _pickStartOnMap() async {
    final result = await Navigator.push<LatLon>(
      context,
      MaterialPageRoute(
        builder: (_) => PickStartOnMapScreen(initial: start),
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    final label =
        'Kartes punkts (${result.lat.toStringAsFixed(4)}, ${result.lon.toStringAsFixed(4)})';

    _searchDebounce?.cancel();
    _searchRequestId++;

    setState(() {
      start = result;
      startLabel = label;
      _searchCtrl.text = label;
      _editingStart = false;
      _startSuggestions = [];
      _searchingStart = false;
    });
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

  Widget _buildStartStatus(ThemeData theme) {
    if (_editingStart) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meklē jaunu sākumpunktu…',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aktīvais sākumpunkts: $startLabel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cancelStartEdit,
            icon: const Icon(Icons.undo),
            label: const Text('Atcelt maiņu'),
          ),
        ],
      );
    }

    return Text(
      'Aktīvais sākumpunkts: $startLabel',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildSuggestionBox() {
    if (!_editingStart && _startSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_searchingStart) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).cardColor,
        ),
        child: const ListTile(
          dense: true,
          leading: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Meklē vietas…'),
        ),
      );
    }

    if (_editingStart &&
        _searchCtrl.text.trim().length >= 2 &&
        _startSuggestions.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).cardColor,
        ),
        child: const ListTile(
          dense: true,
          title: Text('Nav atrasts. Pamēģini citu nosaukumu.'),
        ),
      );
    }

    if (_startSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
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
          final distanceKm = haversineKm(start, suggestion.location);

          return ListTile(
            dense: true,
            title: Text(suggestion.name),
            subtitle: Text(
              '${distanceKm.toStringAsFixed(0)} km no pašreizējā sākumpunkta',
            ),
            onTap: () => _selectStartSuggestion(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildSearchSuffixIcon() {
    if (_searchingStart) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_searchCtrl.text.isNotEmpty || _editingStart) {
      return IconButton(
        icon: const Icon(Icons.close),
        onPressed: _clearStartSearch,
      );
    }

    return const Icon(Icons.search);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final canLoadPois = !_loading && !_editingStart && !_locatingStart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surprise Ride'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Mana vēsture',
            onPressed: _openHistoryStats,
          ),
        ],
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
                    enabled: !_loading && !_locatingStart,
                    onChanged: _onStartSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Ieraksti pilsētu vai vietu',
                      border: const OutlineInputBorder(),
                      suffixIcon: _buildSearchSuffixIcon(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSuggestionBox(),
                  const SizedBox(height: 12),
                  _buildStartStatus(theme),
                  const SizedBox(height: 6),
                  Text(
                    'Lat: ${start.lat.toStringAsFixed(5)}, Lon: ${start.lon.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                        (_loading || _locatingStart) ? null : _useCurrentLocation,
                        icon: _locatingStart
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.my_location),
                        label: Text(
                          _locatingStart
                              ? 'Nosaka atrašanās vietu...'
                              : 'Mana atrašanās vieta',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: (_loading || _locatingStart)
                            ? null
                            : _pickStartOnMap,
                        icon: const Icon(Icons.map),
                        label: const Text('Izvēlēties kartē'),
                      ),
                    ],
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
                    onChanged: (_loading || _locatingStart) ? null : _setRadius,
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
              onPressed: canLoadPois ? _loadPois : null,
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
                  _loading
                      ? 'Meklē POI...'
                      : _locatingStart
                      ? 'Nosaka atrašanās vietu...'
                      : _editingStart
                      ? 'Vispirms izvēlies sākumpunktu'
                      : 'Atrast POI',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),


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