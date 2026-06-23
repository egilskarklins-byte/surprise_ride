import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_language_service.dart';
import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../services/route_service.dart';

class RouteMapScreen extends StatefulWidget {
  final List<Poi> route;
  final LatLon start;
  final String apiKey;

  const RouteMapScreen({
    super.key,
    required this.route,
    required this.start,
    required this.apiKey,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  late List<Poi> _route;

  List<ll.LatLng> _routePolyline = [];
  int _driveMinutes = 0;
  double _driveKm = 0;
  bool _loadingRouteStats = false;
  final _routeService = RouteService();

  @override
  void initState() {
    super.initState();
    _route = List<Poi>.from(widget.route);
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final points = [
      widget.start,
      ..._route.map((p) => p.location),
      widget.start,
    ];

    setState(() {
      _loadingRouteStats = true;
    });

    final result = await _routeService.fetchDrivingRouteWithStats(points);

    if (!mounted) return;

    setState(() {
      _routePolyline = result.points
          .map((p) => ll.LatLng(p.lat, p.lon))
          .toList();

      _driveMinutes = (result.durationSeconds / 60).round();
      _driveKm = result.distanceMeters / 1000;
      _loadingRouteStats = false;
    });
  }

  Future<void> _openGoogleMaps() async {
    if (_route.isEmpty) return;

    final waypoints = _route
        .map((p) => '${p.location.lat},${p.location.lon}')
        .join('|');

    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'origin': '${widget.start.lat},${widget.start.lon}',
        'destination': '${widget.start.lat},${widget.start.lon}',
        'travelmode': 'driving',
        'waypoints': waypoints,
      },
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _removePoi(Poi poi) {
    setState(() {
      _route.removeWhere((p) => p.id == poi.id);
      _routePolyline = [];
    });

    _loadRoute();
  }

  void _moveUp(int index) {
    if (index <= 0) return;

    setState(() {
      final item = _route.removeAt(index);
      _route.insert(index - 1, item);
      _routePolyline = [];
    });

    _loadRoute();
  }

  void _moveDown(int index) {
    if (index >= _route.length - 1) return;

    setState(() {
      final item = _route.removeAt(index);
      _route.insert(index + 1, item);
      _routePolyline = [];
    });

    _loadRoute();
  }

  ll.LatLng get _startLatLng => ll.LatLng(widget.start.lat, widget.start.lon);

  List<ll.LatLng> get _polylinePoints {
    return [
      _startLatLng,
      ..._route.map((p) => ll.LatLng(p.location.lat, p.location.lon)),
      _startLatLng,
    ];
  }
  int get _visitMinutes {
    return _route.fold<int>(
      0,
          (sum, poi) => sum + poi.visitMinutes,
    );
  }

  int get _totalMinutes {
    return _driveMinutes + _visitMinutes;
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '—';

    final h = minutes ~/ 60;
    final m = minutes % 60;

    if (h == 0) return '$m min';
    if (m == 0) return '$h h';

    return '$h h $m min';
  }

  Widget _buildTimeSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguageService.tr(
              lv: 'Aptuvenais maršruta laiks',
              en: 'Estimated route time',
            ),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              Text(
                _loadingRouteStats
                    ? AppLanguageService.tr(
                  lv: '🚗 Braukšana: rēķina...',
                  en: '🚗 Driving: calculating...',
                )
                    : AppLanguageService.tr(
                  lv: '🚗 Braukšana: ~${_formatMinutes(_driveMinutes)}',
                  en: '🚗 Driving: ~${_formatMinutes(_driveMinutes)}',
                ),
              ),
              Text(
                AppLanguageService.tr(
                  lv: '📍 Objekti: ~${_formatMinutes(_visitMinutes)}',
                  en: '📍 Places: ~${_formatMinutes(_visitMinutes)}',
                ),
              ),
              Text(
                _loadingRouteStats
                    ? AppLanguageService.tr(
                  lv: '🕒 Kopā: rēķina...',
                  en: '🕒 Total: calculating...',
                )
                    : AppLanguageService.tr(
                  lv: '🕒 Kopā: ~${_formatMinutes(_totalMinutes)}',
                  en: '🕒 Total: ~${_formatMinutes(_totalMinutes)}',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_driveKm > 0)
                Text('🛣 ${_driveKm.toStringAsFixed(0)} km'),
            ],
          ),
          _buildRouteLoadIndicator(),
        ],
      ),
    );
  }
  Widget _buildRouteLoadIndicator() {
    final totalMinutes = _totalMinutes;

    String text;
    Color color;
    IconData icon;

    if (totalMinutes < 180) {
      text = AppLanguageService.tr(
        lv: 'Relax izbrauciens',
        en: 'Relaxed trip',
      );
      color = Colors.green;
      icon = Icons.sentiment_very_satisfied;
    } else if (totalMinutes < 300) {
      text = AppLanguageService.tr(
        lv: 'Vidēji intensīvs maršruts',
        en: 'Moderately intensive route',
      );
      color = Colors.orange;
      icon = Icons.directions_car;
    } else if (totalMinutes < 480) {
      text = AppLanguageService.tr(
        lv: 'Gara diena',
        en: 'Long day',
      );
      color = Colors.deepOrange;
      icon = Icons.warning_amber_rounded;
    } else {
      text = AppLanguageService.tr(
        lv: 'Ļoti gara diena',
        en: 'Very long day',
      );
      color = Colors.red;
      icon = Icons.dangerous;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  IconData _iconForPoi(Poi poi) {
    if (poi.categories.contains(PoiCategory.nature)) return Icons.park;
    if (poi.categories.contains(PoiCategory.museum)) return Icons.museum;
    if (poi.categories.contains(PoiCategory.viewpoint)) return Icons.landscape;
    if (poi.categories.contains(PoiCategory.beach)) return Icons.beach_access;
    if (poi.categories.contains(PoiCategory.mustSee)) return Icons.castle;
    return Icons.place;
  }

  void _showPoiInfo(Poi poi) {
    final infoText = poi.shortDescription?.trim().isNotEmpty == true
        ? poi.shortDescription!.trim()
        : AppLanguageService.tr(
      lv: 'Apraksts nav pieejams.',
      en: 'Description not available.',
    );

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Icon(
                    _iconForPoi(poi),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        infoText,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            AppLanguageService.tr(
                              lv: 'Apmeklējums: ~${poi.visitMinutes} min',
                              en: 'Visit: ~${poi.visitMinutes} min',
                            ),
                          ),
                        ],
                      ),
                      if (poi.isIndoor) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.home, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              AppLanguageService.tr(
                                lv: 'Iekštelpu objekts',
                                en: 'Indoor attraction',
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (poi.infoUrl != null && poi.infoUrl!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await launchUrl(
                              Uri.parse(poi.infoUrl!),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            AppLanguageService.tr(
                              lv: 'Vairāk informācijas',
                              en: 'More information',
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLanguageService.tr(
                                  lv: 'Papildu informācija nav pieejama',
                                  en: 'Additional information is not available',
                                ),
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Marker _startMarker() {
    return Marker(
      point: _startLatLng,
      width: 120,
      height: 70,
      child: Column(
        children: [
          const Icon(Icons.home, size: 34),
          Text(
            AppLanguageService.tr(
              lv: 'Starts',
              en: 'Start',
            ),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Marker _poiMarker(Poi poi, int index) {
    return Marker(
      point: ll.LatLng(poi.location.lat, poi.location.lon),
      width: 150,
      height: 86,
      child: GestureDetector(
        onTap: () => _showPoiInfo(poi),
        child: Column(
          children: [
            CircleAvatar(
              radius: 16,
              child: Text('${index + 1}'),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                poi.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = [
      _startMarker(),
      for (int i = 0; i < _route.length; i++) _poiMarker(_route[i], i),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLanguageService.tr(
            lv: 'Maršruta priekšskats (${_route.length})',
            en: 'Route preview (${_route.length})',
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _startLatLng,
                initialZoom: 9,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.surprise_ride',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePolyline.isNotEmpty
                          ? _routePolyline
                          : _polylinePoints,
                      strokeWidth: 5,
                      color: const Color(0xFF6C63FF),
                    ),
                  ],
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.24,
            maxChildSize: 0.88,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 90),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      Container(
                        width: 56,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),

                      const SizedBox(height: 8),

                      _buildTimeSummary(),

                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _route.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _route.removeAt(oldIndex);
                            _route.insert(newIndex, item);
                            _routePolyline = [];
                          });

                          _loadRoute();
                        },
                        itemBuilder: (context, index) {
                          final poi = _route[index];

                          return Container(
                            key: ValueKey(poi.id),
                            margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF6C63FF),
                                        Color(0xFF8E7BFF),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                Expanded(
                                  child: Text(
                                    poi.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),

                                IconButton(
                                  icon: const Icon(Icons.arrow_upward),
                                  onPressed: () => _moveUp(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward),
                                  onPressed: () => _moveDown(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => _removePoi(poi),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _route.isEmpty ? null : _openGoogleMaps,
              child: Ink(
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6C63FF),
                      Color(0xFF8E7BFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF)
                          .withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.navigation,
                      color: Colors.white,
                    ),
                    SizedBox(width: 10),
                    Text(
                      AppLanguageService.tr(
                        lv: 'Sākt navigāciju Google Maps',
                        en: 'Start navigation in Google Maps',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}