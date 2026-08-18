import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../services/geocoding_service.dart';
import '../../services/route_service.dart';
import '../../services/surprise_poi_service.dart';
import '../../services/app_language_service.dart';
import 'along_route_map_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/geo.dart';
import 'pick_start_on_map_screen.dart';
import '../../services/surprise_weather_service.dart';
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
  final MapController _mapController = MapController();

  ll.LatLng _mapCenter = const ll.LatLng(
    56.9496,
    24.1052,
  );

  bool _pickingPointOnMap = false;
  bool _pickingDestinationOnMap = false;
  bool _mapMoving = false;

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
      await _showWeatherPopup(
        location: suggestion.location,
        label: suggestion.name,
      );
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

    final target = ll.LatLng(
      initial.lat,
      initial.lon,
    );

    setState(() {
      _pickingPointOnMap = true;
      _pickingDestinationOnMap = false;
      _mapCenter = target;

      _startSuggestions = [];
      _destinationSuggestions = [];
    });

    _mapController.move(
      target,
      12,
    );
  }

  Future<void> _pickDestinationOnMap() async {
    final initial = _selectedDestination?.location ??
        _selectedStart?.location ??
        const LatLon(56.9496, 24.1052);

    final target = ll.LatLng(
      initial.lat,
      initial.lon,
    );

    setState(() {
      _pickingPointOnMap = true;
      _pickingDestinationOnMap = true;
      _mapCenter = target;

      _startSuggestions = [];
      _destinationSuggestions = [];
    });

    _mapController.move(
      target,
      12,
    );
  }
  void _confirmMapPointSelection() {
    final wasDestination = _pickingDestinationOnMap;

    final selectedPoint = LatLon(
      _mapCenter.latitude,
      _mapCenter.longitude,
    );

    final suggestion = PlaceSuggestion(
      name: AppLanguageService.tr(
        lv: 'Kartes punkts',
        en: 'Map point',
      ),
      location: selectedPoint,
    );

    setState(() {
      if (wasDestination) {
        _selectedDestination = suggestion;
        _destinationController.text =
        '${suggestion.name} '
            '(${selectedPoint.lat.toStringAsFixed(4)}, '
            '${selectedPoint.lon.toStringAsFixed(4)})';
        _destinationSuggestions = [];
      } else {
        _selectedStart = suggestion;
        _startController.text =
        '${suggestion.name} '
            '(${selectedPoint.lat.toStringAsFixed(4)}, '
            '${selectedPoint.lon.toStringAsFixed(4)})';
        _startSuggestions = [];
      }

      _pickingPointOnMap = false;
      _pickingDestinationOnMap = false;
      _mapMoving = false;
    });

    if (!wasDestination) {
      _showWeatherPopup(
        location: selectedPoint,
        label: _startController.text,
      );
    }
  }
  Future<void> _showWeatherPopup({
    required LatLon location,
    required String label,
  }) async {
    try {
      final weather =
      await const SurpriseWeatherService().getTodayWeather(
        lat: location.lat,
        lon: location.lon,
        languageCode:
        Localizations.localeOf(context).languageCode,
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
            contentPadding:
            const EdgeInsets.fromLTRB(20, 10, 20, 6),
            actionsPadding:
            const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
                    style: const TextStyle(
                      fontSize: 40,
                    ),
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
                    style: const TextStyle(
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      Text(
                        '🌡️ ${weather.tempC.toStringAsFixed(0)} °C',
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '🌧️ ${weather.rainMm.toStringAsFixed(1)} mm',
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '💨 ${weather.windMs.toStringAsFixed(1)} m/s',
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.45),
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    child: Text(
                      AppLanguageService.tr(
                        lv: 'Izvēlies galamērķi, un mēs atradīsim interesantas vietas pa ceļam.',
                        en: 'Choose your destination and we will find interesting places along the way.',
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
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
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
      debugPrint(
        'Along Route weather popup error: $error',
      );
    }
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
          builder: (_) =>
              AlongRouteMapScreen(
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
            '(${resolvedDestination.location.lat}, ${resolvedDestination
            .location.lon})',
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
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 7.2,

              onPositionChanged: (position, hasGesture) {
                _mapCenter = position.center;
              },

              onMapEvent: (event) {
                if (!_pickingPointOnMap) {
                  return;
                }

                if (event is MapEventMoveStart) {
                  if (!_mapMoving && mounted) {
                    setState(() {
                      _mapMoving = true;
                    });
                  }
                }

                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd) {
                  if (_mapMoving && mounted) {
                    setState(() {
                      _mapMoving = false;
                    });
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'lv.surpriseride.app',
              ),
            ],
          ),
          if (_pickingPointOnMap) ...[
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_pin,
                      size: 56,
                      color: _mapMoving
                          ? Colors.redAccent
                          : Colors.red,
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: FilledButton.icon(
                  onPressed: _confirmMapPointSelection,
                  icon: const Icon(
                    Icons.check_circle_outline,
                  ),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    child: Text(
                      AppLanguageService.tr(
                        lv: _pickingDestinationOnMap
                            ? 'Izvēlēties galamērķi'
                            : 'Izvēlēties sākumpunktu',
                        en: _pickingDestinationOnMap
                            ? 'Choose destination'
                            : 'Choose start point',
                      ),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                    const Color(0xFF6B52E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ],
          // Back poga
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  top: 12,
                ),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.94),
                  shape: const CircleBorder(),
                  elevation: 5,
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF6B52E5),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Paslidināmais A/B panelis
          if (!_pickingPointOnMap)
          DraggableScrollableSheet(
            initialChildSize: 0.53,
            minChildSize: 0.14,
            maxChildSize: 0.78,
            snap: true,
            snapSizes: const [
              0.14,
              0.53,
              0.78,
            ],
            snapAnimationDuration: const Duration(
              milliseconds: 220,
            ),
            builder: (context, scrollController) {
              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 52,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      _buildLocationCard(
                        title: AppLanguageService.tr(
                          lv: 'A  Sākumpunkts',
                          en: 'A  Starting point',
                        ),
                        hint: AppLanguageService.tr(
                          lv: 'Ievadi sākumpunktu',
                          en: 'Enter starting point',
                        ),
                        icon: Icons.trip_origin,
                        controller: _startController,
                        onChanged: _searchStartSuggestions,
                        suggestions: _startSuggestions,
                        isSearching:
                        _searchingStartSuggestions,
                        onSuggestionTap: (suggestion) async {
                          setState(() {
                            _selectedStart = suggestion;
                            _startController.text = suggestion.name;
                            _startSuggestions = [];
                          });

                          await _showWeatherPopup(
                            location: suggestion.location,
                            label: suggestion.name,
                          );
                        },
                        onMapTap: _pickStartOnMap,
                      ),

                      const SizedBox(height: 10),

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
                          style: TextButton.styleFrom(
                            foregroundColor:
                            const Color(0xFF6B52E5),
                            backgroundColor:
                            const Color(0xFFF7F3FD),
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Divider(
                        color: Colors.grey.shade300,
                        height: 1,
                      ),

                      const SizedBox(height: 18),

                      _buildLocationCard(
                        title: AppLanguageService.tr(
                          lv: 'B  Galamērķis',
                          en: 'B  Destination',
                        ),
                        hint: AppLanguageService.tr(
                          lv: 'Ievadi galamērķi',
                          en: 'Enter your destination',
                        ),
                        icon: Icons.flag_outlined,
                        controller: _destinationController,
                        onChanged:
                        _searchDestinationSuggestions,
                        suggestions:
                        _destinationSuggestions,
                        isSearching:
                        _searchingDestinationSuggestions,
                        onSuggestionTap: (suggestion) {
                          setState(() {
                            _selectedDestination =
                                suggestion;
                            _destinationController.text =
                                suggestion.name;
                            _destinationSuggestions = [];
                          });
                        },
                        onMapTap: _pickDestinationOnMap,
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: FilledButton.icon(
                          onPressed:
                          _findPlacesAlongRoute,
                          icon: const Icon(
                            Icons.alt_route,
                          ),
                          label: Text(
                            AppLanguageService.tr(
                              lv: 'Meklēt vietas pa maršrutu',
                              en: 'Find places along route',
                            ),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF6B52E5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 10),

        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF6B52E5),
              size: 23,
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
                size: 24,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFFFAF8FD),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF6B52E5),
                width: 2,
              ),
            ),
          ),
        ),

        if (isSearching) ...[
          const SizedBox(height: 8),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        ],

        if (!isSearching && suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8FD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: suggestions.map((suggestion) {
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
                  onTap: () {
                    onSuggestionTap(suggestion);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}


