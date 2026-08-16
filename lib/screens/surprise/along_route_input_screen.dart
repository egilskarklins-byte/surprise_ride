import 'package:flutter/material.dart';
import '../../services/geocoding_service.dart';
import '../../services/route_service.dart';
import '../../services/surprise_poi_service.dart';
import '../../services/app_language_service.dart';
import 'along_route_map_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/geo.dart';
import 'pick_start_on_map_screen.dart';

class AlongRouteInputScreen extends StatefulWidget {
  const AlongRouteInputScreen({super.key});

  @override
  State<AlongRouteInputScreen> createState() => _AlongRouteInputScreenState();
}

class _AlongRouteInputScreenState extends State<AlongRouteInputScreen> {
  static const double _routeRadiusKm = 5.0;
  final _geocoding = GeocodingService();
  final _poiService = SurprisePoiService();
  final _routeService = RouteService();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  List<PlaceSuggestion> _startSuggestions = [];
  List<PlaceSuggestion> _destinationSuggestions = [];

  PlaceSuggestion? _selectedStart;
  PlaceSuggestion? _selectedDestination;

  bool _searchingStartSuggestions = false;
  bool _searchingDestinationSuggestions = false;
  Future<void> _searchStartSuggestions(String value) async {
    final query = value.trim();

    _selectedStart = null;

    if (query.length < 2) {
      if (!mounted) return;

      setState(() {
        _startSuggestions = [];
        _searchingStartSuggestions = false;
      });

      return;
    }

    setState(() {
      _searchingStartSuggestions = true;
    });

    try {
      final results = await _geocoding.search(query);

      if (!mounted) return;

      // Ja lietotājs pa šo laiku jau turpinājis rakstīt,
      // vecā pieprasījuma rezultātus nerādām.
      if (_startController.text.trim() != query) {
        return;
      }

      setState(() {
        _startSuggestions = results.take(6).toList();
        _searchingStartSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _startSuggestions = [];
        _searchingStartSuggestions = false;
      });
    }
  }

  Future<void> _searchDestinationSuggestions(String value) async {
    final query = value.trim();

    _selectedDestination = null;

    if (query.length < 2) {
      if (!mounted) return;

      setState(() {
        _destinationSuggestions = [];
        _searchingDestinationSuggestions = false;
      });

      return;
    }

    setState(() {
      _searchingDestinationSuggestions = true;
    });

    try {
      final results = await _geocoding.search(query);

      if (!mounted) return;

      if (_destinationController.text.trim() != query) {
        return;
      }

      setState(() {
        _destinationSuggestions = results.take(6).toList();
        _searchingDestinationSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _destinationSuggestions = [];
        _searchingDestinationSuggestions = false;
      });
    }
  }
  Future<void> _useCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();

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
                lv: 'Atrašanās vietas atļauja ir bloķēta. Atļauj to telefona iestatījumos.',
                en: 'Location permission is blocked. Enable it in your phone settings.',
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

      final suggestion = PlaceSuggestion(
        name: AppLanguageService.tr(
          lv: 'Mana atrašanās vieta',
          en: 'My location',
        ),
        location: LatLon(
          position.latitude,
          position.longitude,
        ),
      );

      if (!mounted) return;

      setState(() {
        _selectedStart = suggestion;
        _startController.text = suggestion.name;
        _startSuggestions = [];
        _searchingStartSuggestions = false;
      });
    } catch (error) {
      debugPrint('Along Route current location error: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageService.tr(
              lv: 'Neizdevās noteikt atrašanās vietu.',
              en: 'Could not determine your location.',
            ),
          ),
        ),
      );
    }
  }
  Future<void> _pickStartOnMap() async {
    final initial = _selectedStart?.location ??
        const LatLon(56.9496, 24.1052);

    final result = await Navigator.push<LatLon>(
      context,
      MaterialPageRoute(
        builder: (_) => PickStartOnMapScreen(
          initial: initial,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final suggestion = PlaceSuggestion(
      name: AppLanguageService.tr(
        lv: 'Kartes punkts',
        en: 'Map point',
      ),
      location: result,
    );

    setState(() {
      _selectedStart = suggestion;
      _startController.text =
      '${suggestion.name} (${result.lat.toStringAsFixed(4)}, ${result.lon.toStringAsFixed(4)})';
      _startSuggestions = [];
    });
  }

  Future<void> _pickDestinationOnMap() async {
    final initial = _selectedDestination?.location ??
        _selectedStart?.location ??
        const LatLon(56.9496, 24.1052);

    final result = await Navigator.push<LatLon>(
      context,
      MaterialPageRoute(
        builder: (_) => PickStartOnMapScreen(
          initial: initial,
          isDestination: true,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final suggestion = PlaceSuggestion(
      name: AppLanguageService.tr(
        lv: 'Kartes punkts',
        en: 'Map point',
      ),
      location: result,
    );

    setState(() {
      _selectedDestination = suggestion;
      _destinationController.text =
      '${suggestion.name} (${result.lat.toStringAsFixed(4)}, ${result.lon.toStringAsFixed(4)})';
      _destinationSuggestions = [];
    });
  }
  Future<void> _findPlacesAlongRoute() async {
    final startText = _startController.text.trim();
    final destinationText = _destinationController.text.trim();

    if (startText.isEmpty || destinationText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageService.tr(
              lv: 'Lūdzu, ievadi gan sākumpunktu, gan galamērķi.',
              en: 'Please enter both starting point and destination.',
            ),
          ),
        ),
      );
      return;
    }

    try {
      PlaceSuggestion? start = _selectedStart;
      PlaceSuggestion? destination = _selectedDestination;

      if (start == null) {
        final startResults = await _geocoding.search(startText);

        if (startResults.isNotEmpty) {
          start = startResults.first;
        }
      }

      if (destination == null) {
        final destinationResults = await _geocoding.search(destinationText);

        if (destinationResults.isNotEmpty) {
          destination = destinationResults.first;
        }
      }

      if (!mounted) return;

      if (start == null || destination == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLanguageService.tr(
                lv: 'Neizdevās atrast kādu no ievadītajām vietām.',
                en: 'Could not find one of the entered places.',
              ),
            ),
          ),
        );
        return;
      }
      final resolvedStart = start;
      final resolvedDestination = destination;

      final routeResult = await _routeService.fetchDrivingRouteWithStats([
        resolvedStart.location,
        resolvedDestination.location,
      ]);

      if (!mounted) return;

      if (routeResult.points.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLanguageService.tr(
                lv: 'Neizdevās izveidot braukšanas maršrutu.',
                en: 'Could not build a driving route.',
              ),
            ),
          ),
        );
        return;
      }

      final distanceKm = routeResult.distanceMeters / 1000;
      final durationMinutes = routeResult.durationSeconds / 60;



      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AlongRouteMapScreen(
            routePoints: routeResult.points,
            startName: resolvedStart.name,
            destinationName: resolvedDestination.name,
            distanceKm: distanceKm,
            durationMinutes: durationMinutes,
            corridorKm: _routeRadiusKm,
          ),
        ),
      );
      debugPrint('================ ROUTE =================');
      debugPrint('Points: ${routeResult.points.length}');
      debugPrint('Distance: ${distanceKm.toStringAsFixed(1)} km');
      debugPrint('Duration: ${durationMinutes.toStringAsFixed(0)} min');
      debugPrint('========== ALONG ROUTE ==========');
      debugPrint(
        'Start: ${resolvedStart.name} '
            '(${resolvedStart.location.lat}, ${resolvedStart.location.lon})',
      );

      debugPrint(
        'Destination: ${resolvedDestination.name} '
            '(${resolvedDestination.location.lat}, ${resolvedDestination.location.lon})',
      );
      debugPrint('Corridor: ${_routeRadiusKm.toInt()} km');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${resolvedStart.name} → ${resolvedDestination.name}\n'
                '${distanceKm.toStringAsFixed(1)} km • '
                '${durationMinutes.toStringAsFixed(0)} min • '
                '${routeResult.points.length} route points',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Along Route geocoding error: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageService.tr(
              lv: 'Neizdevās atrast maršruta punktus. Mēģini vēlreiz.',
              en: 'Could not find the route locations. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FC),
      appBar: AppBar(
        title: Text(
          AppLanguageService.tr(
            lv: 'Pa ceļam',
            en: 'Along Route',
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLanguageService.tr(
                  lv: 'Atrodi interesantas vietas pa ceļam',
                  en: 'Find interesting places along your journey',
                ),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 24),

              _buildLocationCard(
                title: AppLanguageService.tr(
                  lv: 'Sākumpunkts',
                  en: 'Starting point',
                ),
                hint: AppLanguageService.tr(
                  lv: 'Ievadi sākumpunktu',
                  en: 'Enter starting point',
                ),
                icon: Icons.my_location,
                controller: _startController,
                onChanged: _searchStartSuggestions,
                suggestions: _startSuggestions,
                isSearching: _searchingStartSuggestions,
                onSuggestionTap: (suggestion) {
                  setState(() {
                    _selectedStart = suggestion;
                    _startController.text = suggestion.name;
                    _startSuggestions = [];
                  });
                },
                onMapTap: _pickStartOnMap,
              ),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(
                    Icons.my_location,
                    size: 20,
                  ),
                  label: Text(
                    AppLanguageService.tr(
                      lv: 'Mana atrašanās vieta',
                      en: 'My location',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildLocationCard(
                title: AppLanguageService.tr(
                  lv: 'Galamērķis',
                  en: 'Destination',
                ),
                hint: AppLanguageService.tr(
                  lv: 'Ievadi galamērķi',
                  en: 'Enter your destination',
                ),
                icon: Icons.flag_outlined,
                controller: _destinationController,
                onChanged: _searchDestinationSuggestions,
                suggestions: _destinationSuggestions,
                isSearching: _searchingDestinationSuggestions,
                onSuggestionTap: (suggestion) {
                  setState(() {
                    _selectedDestination = suggestion;
                    _destinationController.text = suggestion.name;
                    _destinationSuggestions = [];
                  });
                },
                onMapTap: _pickDestinationOnMap,
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
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
                      AppLanguageService.tr(
                        lv: 'Interesantas vietas',
                        en: 'Interesting places',
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLanguageService.tr(
                        lv: 'Meklējam interesantas vietas līdz 5 km no tava maršruta.',
                        en: 'We search for interesting places up to 5 km from your route.',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 64,
                child: FilledButton.icon(
                  onPressed: _findPlacesAlongRoute,
                  icon: const Icon(Icons.alt_route),
                  label: Text(
                    AppLanguageService.tr(
                      lv: 'Meklēt vietas pa ceļam',
                      en: 'Find places along route',
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6B52E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
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
  Widget _buildLocationCard({
    required String title,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required List<PlaceSuggestion> suggestions,
    required bool isSearching,
    required ValueChanged<PlaceSuggestion> onSuggestionTap,
    required VoidCallback onMapTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF6B52E5),
              ),
              suffixIcon: IconButton(
                onPressed: onMapTap,
                tooltip: AppLanguageService.tr(
                  lv: 'Izvēlēties kartē',
                  en: 'Choose on map',
                ),
                icon: const Icon(
                  Icons.map_outlined,
                  color: Color(0xFF6B52E5),
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFFAF8FD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: Color(0xFF6B52E5),
                  width: 2,
                ),
              ),
            ),
          ),
          if (isSearching) ...[
            const SizedBox(height: 10),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          ],

          if (!isSearching && suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8FD),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: Column(
                children: suggestions.map((suggestion) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.place_outlined,
                      color: Color(0xFF6B52E5),
                    ),
                    title: Text(
                      suggestion.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      onSuggestionTap(suggestion);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}