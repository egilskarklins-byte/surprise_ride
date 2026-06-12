import 'dart:async';
import 'help_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/geo.dart';
import '../../services/geocoding_service.dart' as geo_search;
import '../../services/surprise_poi_service.dart';
import 'history_stats_screen.dart';
import 'pick_start_on_map_screen.dart';
import 'surprise_poi_results_screen.dart';
import 'saved_routes_screen.dart';

class SurpriseInputScreen extends StatefulWidget {
  const SurpriseInputScreen({super.key});

  @override
  State<SurpriseInputScreen> createState() => _SurpriseInputScreenState();
}

class _SurpriseInputScreenState extends State<SurpriseInputScreen>
    with SingleTickerProviderStateMixin {
  final geo_search.GeocodingService _geocoding =
  geo_search.GeocodingService();

  final TextEditingController _searchCtrl = TextEditingController();

  Timer? _searchDebounce;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
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
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.18,
      end: 0.38,
    ).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
  }
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
      selectedColor: const Color(0xFFE6DDFF),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF5B3FD6) : Colors.black87,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  Widget _buildPremiumCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
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
              fontWeight: FontWeight.w600,
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
        fontSize: 17,
        fontWeight: FontWeight.w600,
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
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
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
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
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
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
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
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Surprise Ride',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Mana vēsture',
            onPressed: _openHistoryStats,
          ),
          IconButton(
            icon: const Icon(Icons.route),
            tooltip: 'Mani maršruti',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SavedRoutesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Palīdzība',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF2EAFB),
              Color(0xFFF9F5FC),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [

            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6C63FF),
                              Color(0xFF8E7BFF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF)
                                  .withValues(alpha: 0.30),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.explore,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Atrodi negaidītu maršrutu',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Izvēlies sākumpunktu un radiusu — app atradīs interesantus objektus tavā apkārtnē.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            _buildPremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sākumpunkts',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    enabled: !_loading && !_locatingStart,
                    onChanged: _onStartSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Ieraksti pilsētu vai vietu',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF6C63FF),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFDFDFF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Colors.black.withValues(alpha: 0.10),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Color(0xFF6C63FF),
                          width: 1.4,
                        ),
                      ),
                      suffixIcon: _buildSearchSuffixIcon(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSuggestionBox(),
                  const SizedBox(height: 14),
                  _buildStartStatus(theme),
                  const SizedBox(height: 6),
                  Text(
                    'Lat: ${start.lat.toStringAsFixed(5)}, Lon: ${start.lon.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: (_loading || _locatingStart)
                            ? null
                            : _useCurrentLocation,
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
            const SizedBox(height: 20),
            _buildPremiumCard(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meklēšanas rādiuss',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      '${radiusKm.toInt()} km',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF5B3FD6),
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  Slider(
                    value: radiusKm,
                    min: 10,
                    max: 150,
                    divisions: 14,
                    label: '${radiusKm.toInt()} km',
                    activeColor: const Color(0xFF6C63FF),
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
                  const SizedBox(height: 12),
                  const Text(
                    'Lielākam rādiusam tiek izmantoti vairāki meklēšanas centri, lai rezultāti tiešām mainītos.',
                    style: TextStyle(
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildPremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kas tiks meklēts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'App meklēs interesantus POI ap "$startLabel" aptuveni ${radiusKm.toInt()} km rādiusā.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pēc tam varēsi izvēlēties POI un uzģenerēt maršrutu ar atgriešanos sākumpunktā.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: double.infinity,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: canLoadPois
                    ? const LinearGradient(
                  colors: [
                    Color(0xFF6C63FF),
                    Color(0xFF8E7BFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: canLoadPois ? null : Colors.grey.shade300,
                boxShadow: canLoadPois
                    ? [
                  BoxShadow(
                    color: const Color(0xFF6C63FF)
                        .withValues(alpha: _glowAnimation.value),
                    blurRadius: 34,
                    spreadRadius: 3,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: const Color(0xFF8E7BFF)
                        .withValues(alpha: _glowAnimation.value * 0.45),
                    blurRadius: 52,
                    spreadRadius: 8,
                    offset: const Offset(0, 18),
                  ),
                ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: canLoadPois ? _loadPois : null,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_loading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            Icons.travel_explore,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 10),
                        Text(
                          _loading
                              ? 'Meklē POI...'
                              : _locatingStart
                              ? 'Nosaka atrašanās vietu...'
                              : _editingStart
                              ? 'Vispirms izvēlies sākumpunktu'
                              : 'Atrast POI',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
                );
              },
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
      ),
    );
  }
}