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
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:latlong2/latlong.dart' as latlng;
import 'dart:math' as math;

class SurpriseInputScreen extends StatefulWidget {
  const SurpriseInputScreen({super.key});

  @override
  State<SurpriseInputScreen> createState() => _SurpriseInputScreenState();
}

class _SurpriseInputScreenState extends State<SurpriseInputScreen>
    with SingleTickerProviderStateMixin {
  final geo_search.GeocodingService _geocoding =
  geo_search.GeocodingService();
  final SurprisePoiService _poiService = SurprisePoiService();
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
  Future<void>? _poiPrefetchFuture;
  LatLon? _poiPrefetchCenter;
  int _poiPrefetchRequestId = 0;
  bool _poiPrefetchRunning = false;
  bool _poiPrefetchReady = false;
  bool _poiPrefetchFailed = false;
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
          _startSuggestions = results.take(3).toList();
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
    _startPoiPrefetch(suggestion.location);

    await _showWeatherPopup(
      location: suggestion.location,
      label: suggestion.name,
    );
  }

  Future<void> _startPoiPrefetch(LatLon location) async {
    final sameCenter =
        _poiPrefetchCenter != null &&
            _poiPrefetchCenter!.lat == location.lat &&
            _poiPrefetchCenter!.lon == location.lon;

    // Ja šim centram meklēšana jau notiek vai ir pabeigta,
    // otru identisku Overpass pieprasījumu nesākam.
    if (sameCenter && _poiPrefetchFuture != null) {
      return _poiPrefetchFuture!;
    }

    final int requestId = ++_poiPrefetchRequestId;

    _poiPrefetchCenter = location;

    if (mounted) {
      setState(() {
        _poiPrefetchRunning = true;
        _poiPrefetchReady = false;
        _poiPrefetchFailed = false;
      });
    }

    final future = _poiService
        .prefetchPois(
      center: location,
      radiusKm: 50,
    )
        .then<void>((_) {
      if (!mounted || requestId != _poiPrefetchRequestId) return;

      setState(() {
        _poiPrefetchRunning = false;
        _poiPrefetchReady = true;
        _poiPrefetchFailed = false;
      });
    })
        .catchError((Object error) {
      debugPrint('POI prefetch error: $error');

      if (!mounted || requestId != _poiPrefetchRequestId) return;

      setState(() {
        _poiPrefetchRunning = false;
        _poiPrefetchReady = false;
        _poiPrefetchFailed = true;
      });
    });

    _poiPrefetchFuture = future;

    return future;
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
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 18,
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              AppLanguageService.tr(
                lv: 'Laikapstākļi šodien',
                en: 'Today\'s weather',
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weatherIcon,
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weather.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      Text(
                        '🌡️ ${weather.tempC.toStringAsFixed(0)} °C',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        '🌧️ ${weather.rainMm.toStringAsFixed(1)} mm',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        '💨 ${weather.windMs.toStringAsFixed(1)} m/s',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLanguageService.tr(
                            lv: 'Gatavojam tavu pārsteiguma braucienu',
                            en: 'Preparing your surprise ride',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          AppLanguageService.tr(
                            lv: 'Meklējam interesantas vietas līdz 50 km attālumā. Pēc tam varēsi izvēlēties sev piemērotāko rādiusu.',
                            en: 'We are searching for interesting places within 50 km. You can then choose the radius that suits you.',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),

                        FutureBuilder<void>(
                          future: _poiPrefetchFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppLanguageService.tr(
                                        lv: 'Meklējam vietas fonā…',
                                        en: 'Searching for places…',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            if (snapshot.hasError || _poiPrefetchFailed) {
                              return Text(
                                AppLanguageService.tr(
                                  lv: '⚠️ Meklēšanu turpināsim pēc pogas nospiešanas.',
                                  en: '⚠️ The search will continue after you press the button.',
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            return Text(
                              AppLanguageService.tr(
                                lv: '✅ Interesantas vietas ir atrastas!',
                                en: '✅ Interesting places have been found!',
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
      _startPoiPrefetch(picked);
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
    _startPoiPrefetch(result);
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
  void _cancelPoiSearch() {
    _searchRequestId++;
    _poiPrefetchRequestId++;

    _poiPrefetchFuture = null;
    _poiPrefetchCenter = null;

    if (!mounted) return;

    setState(() {
      _loading = false;
      _poiPrefetchRunning = false;
      _poiPrefetchReady = false;
      _poiPrefetchFailed = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLanguageService.tr(
            lv: 'Meklēšana atcelta. Vari sākt jaunu meklēšanu.',
            en: 'Search cancelled. You can start a new search.',
          ),
        ),
      ),
    );
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
    final int requestId = ++_searchRequestId;
    setState(() => _loading = true);

    try {
      // Ja 50 km prefetch vēl notiek tam pašam sākumpunktam,
      // sagaidām tā pabeigšanu, lai nesāktu otru Overpass pieprasījumu.
      final samePrefetchCenter =
          _poiPrefetchCenter != null &&
              _poiPrefetchCenter!.lat == start.lat &&
              _poiPrefetchCenter!.lon == start.lon;

      if (samePrefetchCenter && _poiPrefetchFuture != null) {
        await _poiPrefetchFuture;
      }
      if (!mounted || requestId != _searchRequestId) return;
      final pois = await _poiService.fetchPoisInRadius(
        center: start,
        radiusKm: radiusKm.clamp(10, 50).toDouble(),
      );

      if (!mounted || requestId != _searchRequestId) return;

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
      if (mounted && requestId == _searchRequestId) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildQuickRadiusChip(double value) {
    final selected = radiusKm.round() == value.round();

    return ChoiceChip(
      color: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFFB348FF);
        }
        return const Color(0xFF24143B);
      }),
      showCheckmark: false,
      label: Text('${value.toInt()}'),
      selected: selected,
      onSelected: (_) => _setRadius(value),
      selectedColor: const Color(0xFFB348FF),
      backgroundColor: Colors.white.withValues(alpha: 0.07),
      disabledColor: const Color(0xFF24143B),
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : Colors.white70,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? const Color(0xFFE08AFF).withValues(alpha: 0.75)
              : Colors.white.withValues(alpha: 0.16),
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
        color: const Color(0xFF171126).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFB348FF).withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB348FF).withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 8),
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

    if (_editingStart &&
        _searchCtrl.text.trim().length >= 2 &&
        _startSuggestions.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAF8FD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
        ),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(
            Icons.search_off,
            color: Color(0xFF6B52E5),
            size: 20,
          ),
          title: Text(
            AppLanguageService.tr(
              lv: 'Nav atrasts. Pamēģini citu nosaukumu.',
              en: 'Not found. Try another name.',
            ),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
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
        color: const Color(0xFFFAF8FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: _startSuggestions.map((suggestion) {
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(
              Icons.place_outlined,
              color: Color(0xFF6B52E5),
              size: 20,
            ),
            title: Text(
              suggestion.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _selectStartSuggestion(suggestion),
          );
        }).toList(),
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
  double _previewZoomForRadius(double radiusKm) {
    const referenceRadius = 20.0;
    const referenceZoom = 10.0;

    return referenceZoom -
        (math.log(radiusKm / referenceRadius) / math.ln2);
  }
  Widget _buildMiniMapPreview() {
    final center = latlng.LatLng(
      start!.lat,
      start!.lon,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                key: ValueKey('preview_${center.latitude}_${center.longitude}_$radiusKm'),
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _previewZoomForRadius(radiusKm),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  // Karte
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'lv.surpriseride.app',
                  ),



                  // Īstais meklēšanas rādiuss
                  // Vizuālais meklēšanas rādiuss.
// Aplis ekrānā paliek vienāda izmēra,
// bet karte zem tā maina mērogu pēc radiusKm.
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: center,
                        radius: 105,
                        useRadiusInMeter: false,
                        color: const Color(0xFFB348FF).withValues(alpha: 0.19),
                        borderColor: const Color(0xFFE054FF),
                        borderStrokeWidth: 2.5,
                      ),
                    ],
                  ),

                  // Centra punkts
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 52,
                        height: 52,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFF4DDF),
                                Color(0xFF8C45FF),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFCE49FF)
                                    .withValues(alpha: 0.70),
                                blurRadius: 18,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Edge vignette
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF08050F)
                            .withValues(alpha: 0.34),
                      ],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 50 km badge
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFD94FFF),
                      Color(0xFF8248FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB348FF)
                          .withValues(alpha: 0.38),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  '${radiusKm.toInt()} km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            // Bottom description

          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canLoadPois = !_loading && !_editingStart && !_locatingStart;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF08050F),
      body: Stack(
        fit: StackFit.expand,
        children: [
        // PILNA EKRĀNA FONA BILDE
        Image.asset(
        'lib/assets/home/surprise_input_bg.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),

      // Tumšais violetais slānis, lai UI labi salasāms
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF12051F).withValues(alpha: 0.30),
              const Color(0xFF08050F).withValues(alpha: 0.52),
              const Color(0xFF05030A).withValues(alpha: 0.78),
            ],
            stops: const [0.0, 0.48, 1.0],
          ),
        ),
      ),

      SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // ─────────────────────────────────────────────
                // BACKGROUND GLOW
                // ─────────────────────────────────────────────
                Positioned(
                  top: -150,
                  left: -100,
                  child: Container(
                    width: 330,
                    height: 330,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7A3CFF)
                          .withValues(alpha: 0.13),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB348FF)
                              .withValues(alpha: 0.12),
                          blurRadius: 100,
                          spreadRadius: 35,
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  top: 300,
                  right: -150,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFB348FF)
                          .withValues(alpha: 0.06),
                    ),
                  ),
                ),

                // ─────────────────────────────────────────────
                // MAIN ONE-SCREEN LAYOUT
                // ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                  child: Column(
                    children: [
                      // ───────────────────────────────────────
                      // TOP BAR
                      // ───────────────────────────────────────
                      SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            _roundTopButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.maybePop(context),
                            ),
                            const Spacer(),
                            _roundTopButton(
                              icon: Icons.history_rounded,
                              onTap: _openHistoryStats,
                            ),
                            const SizedBox(width: 7),
                            _roundTopButton(
                              icon: Icons.route_rounded,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                    const SavedRoutesScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 7),
                            _roundTopButton(
                              icon: Icons.help_outline_rounded,
                              onTap: () {
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
                      ),

                      const SizedBox(height: 5),

                      // ───────────────────────────────────────
                      // HERO
                      // ───────────────────────────────────────
                      // ───────────────────────────────────────
// HERO
// ───────────────────────────────────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                          height: 132,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [

                              // Dark cinematic overlay
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.10),
                                      const Color(0xFF13071F).withValues(alpha: 0.28),
                                      const Color(0xFF08050F).withValues(alpha: 0.88),
                                    ],
                                    stops: const [0.0, 0.48, 1.0],
                                  ),
                                ),
                              ),

                              // Purple glow
                              Positioned(
                                top: -35,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    width: 145,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFB348FF)
                                              .withValues(alpha: 0.42),
                                          blurRadius: 55,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Center content
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(17),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFF55E6),
                                          Color(0xFFC33FFF),
                                          Color(0xFF694CFF),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFF2B4FF),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFCF4FFF)
                                              .withValues(alpha: 0.72),
                                          blurRadius: 22,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.explore_rounded,
                                      color: Colors.white,
                                      size: 27,
                                    ),
                                  ),

                                  const SizedBox(height: 7),

                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: const TextSpan(
                                      style: TextStyle(
                                        fontSize: 25,
                                        height: 1,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.8,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Surprise ',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        TextSpan(
                                          text: 'Ride',
                                          style: TextStyle(
                                            color: Color(0xFFE34FFF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 5),

                                  Text(
                                    AppLanguageService.tr(
                                      lv: 'Atrodi negaidītu vietu netālu no tevis',
                                      en: 'Find an unexpected place near you',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.82),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ───────────────────────────────────────
// STARTING POINT
// ───────────────────────────────────────
                      _referenceGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [


                            // Vecais autocomplete princips jaunajā dizainā
                            TextField(
                              controller: _searchCtrl,
                              enabled: !_loading && !_locatingStart,
                              onChanged: _onStartSearchChanged,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFFB348FF),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: AppLanguageService.tr(
                                  lv: 'Ievadi pilsētu, lai sāktu',
                                  en: 'Enter a city to start',
                                ),
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFFDFA5FF),
                                  size: 20,
                                ),
                                suffixIcon: _buildSearchSuffixIcon(),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.055),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFB348FF),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 5),

                            // Vecie autocomplete rezultāti
                            _buildSuggestionBox(),

                            const SizedBox(height: 8),

                            // Tikai 2 pogas kā vecajā variantā
                            Row(
                              children: [
                                Expanded(
                                  child: _locationActionButton(
                                    icon: Icons.my_location_rounded,
                                    label: _locatingStart
                                        ? AppLanguageService.tr(
                                      lv: 'Nosaka...',
                                      en: 'Locating...',
                                    )
                                        : AppLanguageService.tr(
                                      lv: 'Mana vieta',
                                      en: 'My location',
                                    ),
                                    highlighted: true,
                                    onTap: (_loading || _locatingStart)
                                        ? null
                                        : _useCurrentLocation,
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Expanded(
                                  child: _locationActionButton(
                                    icon: Icons.map_outlined,
                                    label: AppLanguageService.tr(
                                      lv: 'Kartē',
                                      en: 'On map',
                                    ),
                                    onTap: (_loading || _locatingStart)
                                        ? null
                                        : _pickStartOnMap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                      // ───────────────────────────────────────
                      // RADIUS
                      // ───────────────────────────────────────
                      _referenceGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.radar_rounded,
                                  color: Color(0xFFDFA5FF),
                                  size: 17,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    AppLanguageService.tr(
                                      lv: 'Cik tālu meklēt?',
                                      en: 'How far should we search?',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white54,
                                  size: 17,
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                _referenceRadiusButton(10),
                                _referenceRadiusButton(20),
                                _referenceRadiusButton(30),
                                _referenceRadiusButton(40),
                                _referenceRadiusButton(50),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
// MAP PREVIEW
// Autocomplete laikā karti paslēpjam,
// lai tastatūra nerada overflow.
// ───────────────────────────────────────
                      if (!_editingStart) ...[
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 105,
                              maxHeight: 145,
                            ),
                            child: _buildMiniMapPreview(),
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
            // ─────────────────────────────────────
                        // ─────────────────────────────────────
// BOTTOM ACTION ROW
// ─────────────────────────────────────
                        Row(
                          children: [
                            // ─────────────────────────────────
                            // SURPRISE ME / CANCEL
                            // ─────────────────────────────────
                            Expanded(
                              flex: 2,
                              child: AnimatedBuilder(
                                animation: _glowAnimation,
                                builder: (context, _) {
                                  return Container(
                                    height: 58,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(19),
                                      gradient: canLoadPois
                                          ? const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFFF14BEF),
                                          Color(0xFFB742FF),
                                          Color(0xFF654CFF),
                                        ],
                                      )
                                          : null,
                                      color: canLoadPois
                                          ? null
                                          : Colors.white.withValues(alpha: 0.08),
                                      border: Border.all(
                                        color: canLoadPois
                                            ? const Color(0xFFE895FF)
                                            .withValues(alpha: 0.40)
                                            : Colors.white.withValues(alpha: 0.08),
                                      ),
                                      boxShadow: canLoadPois
                                          ? [
                                        BoxShadow(
                                          color: const Color(0xFFB348FF).withValues(
                                            alpha: _glowAnimation.value,
                                          ),
                                          blurRadius: 25,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                          : [],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(19),
                                        onTap: (_loading || _poiPrefetchRunning)
                                            ? _cancelPoiSearch
                                            : canLoadPois
                                            ? _loadPois
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (_loading || _poiPrefetchRunning)
                                                const Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.white,
                                                  size: 19,
                                                )
                                              else
                                                const Text(
                                                  '✨',
                                                  style: TextStyle(fontSize: 17),
                                                ),

                                              const SizedBox(width: 7),

                                              Flexible(
                                                child: Text(
                                                  (_loading || _poiPrefetchRunning)
                                                      ? AppLanguageService.tr(
                                                    lv: 'Atcelt',
                                                    en: 'Cancel',
                                                  )
                                                      : AppLanguageService.tr(
                                                    lv: 'Pārsteidz mani!',
                                                    en: 'Surprise me!',
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),

                                              if (!_loading && !_poiPrefetchRunning) ...[
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  color: Colors.white,
                                                  size: 19,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(width: 9),

                            // ─────────────────────────────────
                            // SEARCH STATUS
                            // ─────────────────────────────────
                            Expanded(
                              flex: 1,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                height: 58,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.055),
                                  borderRadius: BorderRadius.circular(19),
                                  border: Border.all(
                                    color: _poiPrefetchReady
                                        ? const Color(0xFFB348FF)
                                        .withValues(alpha: 0.45)
                                        : Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Center(
                                  child: _poiPrefetchRunning
                                      ? const SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFFDCA4FF),
                                    ),
                                  )
                                      : _poiPrefetchReady
                                      ? Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.check_rounded,
                                        color: Color(0xFFDCA4FF),
                                        size: 22,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        AppLanguageService.tr(
                                          lv: 'Atrasts',
                                          en: 'Found',
                                        ),
                                        maxLines: 1,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  )
                                      : const Icon(
                                    Icons.travel_explore_rounded,
                                    color: Colors.white38,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ), // Row
                      ], // Column children
                      ), // Column
                ), // Padding
              ], // Stack children
            ); // Stack
          }, // LayoutBuilder builder
        ), // LayoutBuilder
      ), // SafeArea

          // beidzas pilna ekrāna Stack children
        ],
      ), // Stack
    ); // Scaffold
  }

// ============================================================================
// NEW SURPRISE RIDE UI HELPERS
// ============================================================================

  Widget _referenceGlassCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171020).withValues(alpha: 0.91),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFB97AFF).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }


  Widget _roundTopButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1324)
                .withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFE0B8F6),
            size: 19,
          ),
        ),
      ),
    );
  }


  Widget _locationActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool highlighted = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 39,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: highlighted
                ? const Color(0xFF8F35E8)
                .withValues(alpha: 0.23)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFD25AFF)
                  .withValues(alpha: 0.80)
                  : Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: highlighted
                ? [
              BoxShadow(
                color: const Color(0xFFB348FF)
                    .withValues(alpha: 0.22),
                blurRadius: 11,
                spreadRadius: 1,
              ),
            ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: highlighted
                    ? const Color(0xFFF0CAFF)
                    : const Color(0xFFD3C8DA),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: highlighted
                          ? const Color(0xFFF0CAFF)
                          : const Color(0xFFD8CEDD),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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


  Widget _referenceRadiusButton(double value) {
    final selected = radiusKm.round() == value.round();

    return GestureDetector(
      onTap: (_loading || _locatingStart)
          ? null
          : () => _setRadius(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected
              ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE14EFF),
              Color(0xFF9347FF),
            ],
          )
              : null,
          color: selected
              ? null
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? const Color(0xFFF0A8FF)
                : Colors.white.withValues(alpha: 0.13),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: const Color(0xFFB348FF)
                  .withValues(alpha: 0.38),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${value.toInt()}',
              style: TextStyle(
                color:
                selected ? Colors.white : Colors.white70,
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'km',
              style: TextStyle(
                color:
                selected ? Colors.white : Colors.white54,
                fontSize: 8,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}