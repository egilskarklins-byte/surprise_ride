import 'dart:async';
import 'help_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/app_language_service.dart';
import '../../models/geo.dart';
import '../../services/geocoding_service.dart' as geo_search;
import '../../services/surprise_poi_service.dart';
import 'history_stats_screen.dart';
import 'pick_start_on_map_screen.dart';
import 'surprise_poi_results_screen.dart';
import 'saved_routes_screen.dart';
import '../../services/surprise_weather_service.dart';

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
  double radiusKm = 20;

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

  Future<void> _selectStartSuggestion(
      geo_search.PlaceSuggestion suggestion,
      ) async {
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

    await _showWeatherPopup(
      location: suggestion.location,
      label: suggestion.name,
    );
  }
  Future<void> _showWeatherPopup({
    required LatLon location,
    required String label,
  }) async {
    try {
      final weather = await const SurpriseWeatherService().getTodayWeather(
        lat: location.lat,
        lon: location.lon,
        languageCode: Localizations.localeOf(context).languageCode,
      );

      if (!mounted) return;

      final weatherIcon = weather.isStormy
          ? '🌪️'
          : weather.isRainy
          ? '🌧️'
          : weather.isCold
          ? '🥶'
          : '🌤️';

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              AppLanguageService.tr(
                lv: 'Laikapstākļi šodien',
                en: 'Today\'s weather',
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weatherIcon,
                  style: const TextStyle(fontSize: 52),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  weather.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17),
                ),
                const SizedBox(height: 16),
                Text(
                  '🌡️ ${weather.tempC.toStringAsFixed(0)} °C',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  '🌧️ ${weather.rainMm.toStringAsFixed(1)} mm',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  '💨 ${weather.windMs.toStringAsFixed(1)} m/s',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  AppLanguageService.tr(
                    lv: 'Turpināt',
                    en: 'Continue',
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (error) {
      debugPrint('Weather popup error: $error');
    }
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
          SnackBar(
            content: Text(
              AppLanguageService.tr(
                lv: 'Ieslēdz atrašanās vietas noteikšanu ierīcē.',
                en: 'Enable location services on your device.',
              ),
            ),
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
          SnackBar(
            content: Text(
              AppLanguageService.tr(
                lv: 'Atrašanās vietas atļauja netika piešķirta.',
                en: 'Location permission was not granted.',
              ),
            ),
          ),
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLanguageService.tr(
                lv: 'Atrašanās vietas atļauja ir bloķēta ierīces iestatījumos.',
                en: 'Location permission is blocked in device settings.',
              ),
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
          '${AppLanguageService.tr(
        lv: 'Mana atrašanās vieta',
        en: 'My location',
      )} (${picked.lat.toStringAsFixed(4)}, ${picked.lon.toStringAsFixed(4)})';

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
      await _showWeatherPopup(
        location: picked,
        label: label,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageService.tr(
              lv: 'Neizdevās noteikt atrašanās vietu: $e',
              en: 'Could not detect location: $e',
            ),
          ),
        ),
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
        '${AppLanguageService.tr(
      lv: 'Kartes punkts',
      en: 'Map point',
    )} (${result.lat.toStringAsFixed(4)}, ${result.lon.toStringAsFixed(4)})';

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
    await _showWeatherPopup(
      location: result,
      label: label,
    );
  }

  void _setRadius(double value) {
    setState(() {
      radiusKm = value;
    });
  }

  Future<void> _loadPois() async {
    if (radiusKm > 50) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageService.tr(
              lv: 'Meklēšana radiusos virs 50 km pašlaik tiek uzlabota. Pagaidām stabilākai darbībai izmantojiet līdz 50 km.',
              en: 'Searches above a 50 km radius are currently being improved. For the best experience, please use up to 50 km for now.',
            ),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      return;
    }

    setState(() => _loading = true);

    try {
      final pois = await SurprisePoiService().fetchPoisInRadius(
        center: start,
        radiusKm: radiusKm.clamp(10, 100).toDouble(),
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
        SnackBar(
          content: Text(
            AppLanguageService.tr(
              lv: 'Kļūda: $e',
              en: 'Error: $e',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildQuickRadiusChip(double value) {
    final selected = radiusKm.round() == value.round();

    return ChoiceChip(
      showCheckmark: false,
      label: Text('${value.toInt()}'),
      selected: selected,
      onSelected: (_) => _setRadius(value),
      selectedColor: const Color(0xFF6C63FF),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : Colors.black87,
        fontWeight: FontWeight.w700,
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
           Text(
            AppLanguageService.tr(
              lv: 'Meklē jaunu sākumpunktu...',
              en: 'Searching for a new starting point...',
            ),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLanguageService.tr(
              lv: 'Aktīvais sākumpunkts:',
              en: 'Current starting point:',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cancelStartEdit,
            icon: const Icon(Icons.undo),
            label: Text(AppLanguageService.tr(
              lv: 'Atcelt maiņu',
              en: 'Cancel change',
            )),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
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
        child: ListTile(
          dense: true,
          leading: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
            title: Text(
              AppLanguageService.tr(
                lv: 'Meklē vietas...',
                en: 'Searching places...',
              ),
            ),
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
        child: ListTile(
          dense: true,
          title: Text(
            AppLanguageService.tr(
              lv: 'Nav atrasts. Pamēģini citu nosaukumu.',
              en: 'Not found. Try another name.',
            ),
          ),
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
              AppLanguageService.tr(
                lv: '${distanceKm.toStringAsFixed(0)} km no pašreizējā sākumpunkta',
                en: '${distanceKm.toStringAsFixed(0)} km from current starting point',
              ),
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
        title: const SizedBox.shrink(),
        actions: [
          ValueListenableBuilder<String>(
            valueListenable: AppLanguageService.language,
            builder: (context, lang, _) {
              return TextButton(
                onPressed: () async {
                  await AppLanguageService.setLanguage(
                    lang == 'lv' ? 'en' : 'lv',
                  );

                  if (mounted) {
                    setState(() {});
                  }
                },
                child: Text(
                  lang.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: AppLanguageService.tr(
              lv: 'Mana vēsture',
              en: 'My history',
            ),
            onPressed: _openHistoryStats,
          ),
          IconButton(
            icon: const Icon(Icons.route),
            tooltip: AppLanguageService.tr(
              lv: 'Mani maršruti',
              en: 'My routes',
            ),
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
            tooltip: AppLanguageService.tr(
              lv: 'Palīdzība',
              en: 'Help',
            ),
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
                      Expanded(
                        child: Text(
                          AppLanguageService.tr(
                            lv: 'Atrodi negaidītu maršrutu',
                            en: 'Find a surprise route',
                          ),
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

                ],
              ),
            ),
            _buildPremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLanguageService.tr(
                      lv: 'Sākumpunkts',
                      en: 'Starting point',
                    ),
                    style: const TextStyle(
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
                      hintText: AppLanguageService.tr(
                        lv: 'Ieraksti pilsētu vai vietu',
                        en: 'Enter a city or place',
                      ),
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

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_loading || _locatingStart)
                              ? null
                              : _useCurrentLocation,
                          icon: _locatingStart
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(
                              _locatingStart
                                  ? AppLanguageService.tr(
                                lv: 'Nosaka...',
                                en: 'Locating...',
                              )
                                  : AppLanguageService.tr(
                                lv: 'Mana vieta',
                                en: 'My location',
                              )
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_loading || _locatingStart)
                              ? null
                              : _pickStartOnMap,
                          icon: const Icon(Icons.map, size: 18),
                          label: Text(AppLanguageService.tr(
                            lv: 'Kartē',
                            en: 'On map',
                          ),
                        ),
                      ),
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
                   Text(
                    AppLanguageService.tr(
                      lv: 'Meklēšanas rādiuss',
                      en: 'Search radius',
                    ),
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
                    max: 50,
                    divisions: 4,
                    label: '${radiusKm.toInt()} km',
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (_loading || _locatingStart) ? null : _setRadius,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildQuickRadiusChip(10),
                      _buildQuickRadiusChip(20),
                      _buildQuickRadiusChip(30),
                      _buildQuickRadiusChip(40),
                      _buildQuickRadiusChip(50),
                    ],
                  ),

                                 ],
              ),
            ),
            const SizedBox(height: 20),

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
                              ? AppLanguageService.tr(
                            lv: 'Meklē vietas...',
                            en: 'Searching for places...',
                          )
                              : _locatingStart
                              ? AppLanguageService.tr(
                            lv: 'Nosaka atrašanās vietu...',
                            en: 'Determining location...',
                          )
                              : _editingStart
                              ? AppLanguageService.tr(
                            lv: 'Vispirms izvēlies sākumpunktu',
                            en: 'Please select a starting point first',
                          )
                              : AppLanguageService.tr(
                            lv: 'Atrast vietas',
                            en: 'Find places',
                          ),
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
               Center(
                child: Text(
                  AppLanguageService.tr(
                    lv: 'Notiek vietu meklēšana. Tas var aizņemt dažas sekundes.',
                    en: 'Searching for places. This may take a few seconds.',
                  ),
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