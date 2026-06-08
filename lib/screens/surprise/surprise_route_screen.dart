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
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
        itemCount: visibleRoute.length,
        itemBuilder: (context, index) {
          final poi = visibleRoute[index];
          final isVisited = _visitedPoiIds.contains(poi.id);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isVisited
                  ? const Color(0xFFEFFAF3)
                  : Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isVisited
                    ? Colors.green.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: isVisited
                      ? Colors.green.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.045),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isVisited
                          ? [
                        const Color(0xFF57D38C),
                        const Color(0xFF2FBF71),
                      ]
                          : [
                        const Color(0xFF7B6DFF),
                        const Color(0xFF9A8CFF),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isVisited
                            ? '${_formatCategory(poi)} • Apmeklēts'
                            : _formatCategory(poi),
                        style: TextStyle(
                          fontSize: 14,
                          color: isVisited
                              ? Colors.green.shade700
                              : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: isVisited ? null : () => _markVisited(poi),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: isVisited
                            ? Colors.green.withValues(alpha: 0.12)
                            : const Color(0xFF6C63FF).withValues(alpha: 0.10),
                      ),
                      child: Text(
                        isVisited ? '✓' : 'Atzīmēt',
                        style: TextStyle(
                          fontSize: 14,
                          color: isVisited
                              ? Colors.green.shade700
                              : const Color(0xFF6C63FF),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
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
              height: 52,
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