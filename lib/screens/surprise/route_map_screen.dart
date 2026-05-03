import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

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

    final result = await _routeService.fetchDrivingRoute(points);

    if (!mounted) return;

    setState(() {
      _routePolyline = result
          .map((p) => ll.LatLng(p.lat, p.lon))
          .toList();
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

  IconData _iconForPoi(Poi poi) {
    if (poi.categories.contains(PoiCategory.nature)) return Icons.park;
    if (poi.categories.contains(PoiCategory.museum)) return Icons.museum;
    if (poi.categories.contains(PoiCategory.viewpoint)) return Icons.landscape;
    if (poi.categories.contains(PoiCategory.beach)) return Icons.beach_access;
    if (poi.categories.contains(PoiCategory.mustSee)) return Icons.castle;
    return Icons.place;
  }

  void _showPoiInfo(Poi poi) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  child: Icon(_iconForPoi(poi), size: 34),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    poi.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
        children: const [
          Icon(Icons.home, size: 34),
          Text(
            'Starts',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
        title: Text('Maršruta preview (${_route.length})'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _startLatLng,
                initialZoom: 9,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.surprise_ride',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePolyline.isNotEmpty
                          ? _routePolyline
                          : _polylinePoints,
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: ReorderableListView.builder(
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

                return ListTile(
                  key: ValueKey(poi.id),
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(poi.name),
                  subtitle: const Text('Velc, lai mainītu secību'),
                  trailing: Wrap(
                    children: [
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
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _route.isEmpty ? null : _openGoogleMaps,
            child: const Text('Sākt navigāciju Google Maps'),
          ),
        ),
      ),
    );
  }
}