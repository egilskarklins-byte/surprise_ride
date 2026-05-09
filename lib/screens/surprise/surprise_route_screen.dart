import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../services/poi_history_service.dart';
import 'route_map_screen.dart';

class SurpriseRouteScreen extends StatefulWidget {
  final List<Poi> route;
  final LatLon start;
  final String apiKey;

  const SurpriseRouteScreen({
    super.key,
    required this.route,
    required this.start,
    required this.apiKey,
  });

  @override
  State<SurpriseRouteScreen> createState() => _SurpriseRouteScreenState();
}

class _SurpriseRouteScreenState extends State<SurpriseRouteScreen> {
  final PoiHistoryService _historyService = PoiHistoryService();
  final Set<String> _visitedPoiIds = {};

  List<Poi> get _visibleRoute {
    return widget.route.where((poi) {
      final isStartPoint =
          poi.location.lat == widget.start.lat &&
              poi.location.lon == widget.start.lon;
      return !isStartPoint;
    }).toList();
  }

  Future<void> _markVisited(Poi poi) async {
    await _historyService.markVisited(poi);

    if (!mounted) return;

    setState(() {
      _visitedPoiIds.add(poi.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${poi.name} atzīmēts kā apmeklēts'),
      ),
    );
  }

  Future<void> _openInGoogleMaps(BuildContext context) async {
    final visibleRoute = _visibleRoute;

    if (visibleRoute.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nav izvēlētu POI maršrutam')),
      );
      return;
    }

    final queryParameters = <String, String>{
      'api': '1',
      'origin': '${widget.start.lat},${widget.start.lon}',
      'destination': '${widget.start.lat},${widget.start.lon}',
      'travelmode': 'driving',
      'waypoints': visibleRoute
          .map((p) => '${p.location.lat},${p.location.lon}')
          .join('|'),
    };

    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      queryParameters,
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Neizdevās atvērt Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRoute = _visibleRoute;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ģenerētais maršruts'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: visibleRoute.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final poi = visibleRoute[index];
          final isVisited = _visitedPoiIds.contains(poi.id);

          return ListTile(
            leading: CircleAvatar(
              child: Text('${index + 1}'),
            ),
            title: Text(poi.name),
            subtitle: Text(
              isVisited
                  ? '${_formatCategory(poi)} • Apmeklēts'
                  : _formatCategory(poi),
            ),
            trailing: TextButton(
              onPressed: isVisited ? null : () => _markVisited(poi),
              child: Text(isVisited ? 'Apmeklēts' : 'Atzīmēt'),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: visibleRoute.isEmpty
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RouteMapScreen(
                        route: visibleRoute,
                        start: widget.start,
                        apiKey: widget.apiKey,
                      ),
                    ),
                  );
                },
                child: const Text('Skatīt kartē'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: visibleRoute.isEmpty
                    ? null
                    : () => _openInGoogleMaps(context),
                child: const Text('Atvērt Google Maps'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCategory(Poi poi) {
  if (poi.categories.contains(PoiCategory.nature)) return 'Daba';
  if (poi.categories.contains(PoiCategory.museum)) return 'Muzejs';
  if (poi.categories.contains(PoiCategory.mustSee)) return 'Must see';
  return 'Cits';
}