import 'package:flutter/material.dart';

import '../../models/geo.dart';
import '../../models/poi.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../services/route_service.dart';
import '../../services/drivable_access_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AlongRoutePreviewScreen extends StatefulWidget {
  final List<LatLon> routePoints;
  final String startName;
  final String destinationName;
  final double distanceKm;
  final double durationMinutes;
  final List<Poi> pois;

  const AlongRoutePreviewScreen({
    super.key,
    required this.routePoints,
    required this.startName,
    required this.destinationName,
    required this.distanceKm,
    required this.durationMinutes,
    required this.pois,
  });

  @override
  State<AlongRoutePreviewScreen> createState() =>
      _AlongRoutePreviewScreenState();
}

class _AlongRoutePreviewScreenState
    extends State<AlongRoutePreviewScreen> {

  late List<Poi> _selectedPois;
  final RouteService _routeService = RouteService();
  final DrivableAccessService _drivableAccessService =
  DrivableAccessService();

  List<LatLon> _previewRoutePoints = [];
  double _previewDistanceMeters = 0;
  double _previewDurationSeconds = 0;
  bool _isBuildingPreviewRoute = false;
  final Map<Poi, DrivableAccessResult> _poiAccessResults = {};
  List<LatLon> _navigationWaypoints = [];

  @override
  void initState() {
    super.initState();

    _selectedPois = List<Poi>.from(widget.pois);

    // Preview vienmēr sakārtojam A → B virzienā,
    // nevis pēc tā, kādā secībā lietotājs POI atzīmēja.
    _selectedPois.sort(
          (a, b) => _nearestRouteIndex(a).compareTo(
        _nearestRouteIndex(b),
      ),
    );

    _previewRoutePoints = List<LatLon>.from(widget.routePoints);

// Kamēr jaunais A → POI → B preview vēl būvējas,
// rādām sākotnējā A → B maršruta statistiku.
    _previewDistanceMeters = widget.distanceKm * 1000;
    _previewDurationSeconds = widget.durationMinutes * 60;

    _buildPreviewRoute();
  }
  int _nearestRouteIndex(Poi poi) {
    var bestIndex = 0;
    var bestDistance = double.infinity;

    for (var i = 0; i < widget.routePoints.length; i++) {
      final routePoint = widget.routePoints[i];

      final dLat = poi.location.lat - routePoint.lat;
      final dLon = poi.location.lon - routePoint.lon;

      final distance = dLat * dLat + dLon * dLon;

      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  Future<void> _buildPreviewRoute() async {
    if (widget.routePoints.length < 2) return;

    setState(() {
      _isBuildingPreviewRoute = true;
    });

    try {
      final waypoints = <LatLon>[
        widget.routePoints.first,
      ];
      final accessSw = Stopwatch()..start();

      for (var i = 0; i < _selectedPois.length; i++) {
        final poi = _selectedPois[i];

        if (!poi.needsDrivableAccess) {
          debugPrint(
            '⚡ PREVIEW POI ${i + 1}: ${poi.name} '
                '→ direct waypoint',
          );

          waypoints.add(poi.location);
          continue;
        }

        debugPrint(
          '🥾 PREVIEW POI ${i + 1}: ${poi.name} '
              '→ checking drivable access',
        );

        final lookup =
        await _drivableAccessService.findNearestDrivablePointDetailed(
          poi.location,
        );

        if (!mounted) return;

        if (lookup.status == DrivableAccessLookupStatus.found &&
            lookup.access != null) {
          final access = lookup.access!;

          debugPrint(
            '🚗 PREVIEW POI ${i + 1}: ${poi.name} '
                '→ access ${access.distanceMeters.round()} m',
          );

          _poiAccessResults[poi] = access;

          debugPrint(
            '🥾 ACCESS SAVED ${poi.name}: '
                '${access.distanceMeters.round()} m',
          );

          waypoints.add(access.point);
        } else {
          debugPrint(
            '⚠️ PREVIEW POI ${i + 1}: ${poi.name} '
                '→ using original POI',
          );

          waypoints.add(poi.location);
        }
      }
      accessSw.stop();

      debugPrint(
        '⏱ PREVIEW ACCESS TOTAL: '
            '${accessSw.elapsedMilliseconds} ms, '
            '${_selectedPois.length} POIs',
      );
      debugPrint(
        '🛣️ PREVIEW OSRM: ${waypoints.length + 1} waypoints '
            '(A + ${_selectedPois.length} POI + B)',
      );

      waypoints.add(widget.routePoints.last);
      _navigationWaypoints = List<LatLon>.from(waypoints);
      final routeBuildSw = Stopwatch()..start();
      final result =
      await _routeService.fetchDrivingRouteWithStats(
        waypoints,
      );
      routeBuildSw.stop();

      debugPrint(
        '⏱ PREVIEW ROUTE BUILD: '
            '${routeBuildSw.elapsedMilliseconds} ms, '
            '${waypoints.length} waypoints',
      );

      if (!mounted) return;

      setState(() {
        _previewRoutePoints =
        List<LatLon>.from(result.points);

        if (result.distanceMeters > 0 &&
            result.durationSeconds > 0) {
          _previewDistanceMeters = result.distanceMeters;
          _previewDurationSeconds = result.durationSeconds;
        }

        _isBuildingPreviewRoute = false;
      });
    } catch (error) {
      debugPrint(
        'Along Route preview route error: $error',
      );

      if (!mounted) return;

      setState(() {
        // Ja jaunā A → POI → B maršruta izveide neizdodas,
        // atstājam sākotnējo A → B maršrutu un tā statistiku.
        _previewRoutePoints =
        List<LatLon>.from(widget.routePoints);

        _previewDistanceMeters =
            widget.distanceKm * 1000;

        _previewDurationSeconds =
            widget.durationMinutes * 60;

        _isBuildingPreviewRoute = false;
      });
    }
  }
  Future<void> _openGoogleMapsNavigation() async {
    if (_navigationWaypoints.length < 2) return;

    final origin = _navigationWaypoints.first;
    final destination = _navigationWaypoints.last;

    final middlePoints = _navigationWaypoints
        .skip(1)
        .take(_navigationWaypoints.length - 2)
        .map((p) => '${p.lat},${p.lon}')
        .join('|');

    final params = <String, String>{
      'api': '1',
      'origin': '${origin.lat},${origin.lon}',
      'destination': '${destination.lat},${destination.lon}',
      'travelmode': 'driving',
    };

    if (middlePoints.isNotEmpty) {
      params['waypoints'] = middlePoints;
    }

    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      params,
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps'),
        ),
      );
    }
  }
  String _formatDurationFromSeconds(double seconds) {
    final totalMinutes = (seconds / 60).round();

    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '$hours h';
    }

    return '$hours h $minutes min';
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061516),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(
              context,
              List<Poi>.from(_selectedPois),
            );
          },
        ),
        backgroundColor: const Color(0xFF061516),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          'Route preview (${_selectedPois.length})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: ll.LatLng(
                  widget.routePoints.first.lat,
                  widget.routePoints.first.lon,
                ),
                initialZoom: 9,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                  'com.example.surprise_ride',
                ),

                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _previewRoutePoints
                          .map(
                            (p) => ll.LatLng(
                          p.lat,
                          p.lon,
                        ),
                      )
                          .toList(),
                      strokeWidth: 5,
                      color: const Color(0xFF10D9D1),
                    ),
                  ],
                ),

                MarkerLayer(
                  markers: [
                    // A
                    Marker(
                      point: ll.LatLng(
                        widget.routePoints.first.lat,
                        widget.routePoints.first.lon,
                      ),
                      width: 54,
                      height: 54,
                      child: _buildMarker(
                        text: 'A',
                        color: const Color(0xFF17BEBB),
                      ),
                    ),

                    // izvēlētie POI
                    ..._selectedPois.asMap().entries.map(
                          (entry) {
                        final index = entry.key + 1;
                        final poi = entry.value;

                        return Marker(
                          point: ll.LatLng(
                            poi.location.lat,
                            poi.location.lon,
                          ),
                          width: 46,
                          height: 46,
                          child: _buildMarker(
                            text: '$index',
                            color: const Color(0xFF10D9D1),
                          ),
                        );
                      },
                    ),

                    // B
                    Marker(
                      point: ll.LatLng(
                        widget.routePoints.last.lat,
                        widget.routePoints.last.lon,
                      ),
                      width: 54,
                      height: 54,
                      child: _buildMarker(
                        text: 'B',
                        color: const Color(0xFFFF8A4C),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.48,
            minChildSize: 0.28,
            maxChildSize: 0.88,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 120),
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      '${widget.startName} → ${widget.destinationName}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '${(_previewDistanceMeters / 1000).toStringAsFixed(1)} km  •  '
                          '${_formatDurationFromSeconds(_previewDurationSeconds)}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Selected places (${_selectedPois.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 14),

                    ..._selectedPois.asMap().entries.map((entry) {
                      final index = entry.key;
                      final poi = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFF10D9D1)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10D9D1)
                                    .withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFF10D9D1),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Text(
                                poi.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedPois.remove(poi);
                                });
                              },
                              icon: const Icon(
                                Icons.close,
                                color: Colors.black54,
                              ),
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isBuildingPreviewRoute ||
                            _navigationWaypoints.length < 2
                            ? null
                            : _openGoogleMapsNavigation,
                        icon: _isBuildingPreviewRoute
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                            : const Icon(Icons.navigation),
                        label: Text(
                          _isBuildingPreviewRoute
                              ? 'Building route...'
                              : 'Start navigation in Google Maps',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10D9D1),
                          foregroundColor: const Color(0xFF061516),
                          disabledBackgroundColor:
                          const Color(0xFF10D9D1).withValues(alpha: 0.35),
                          disabledForegroundColor: Colors.black54,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  Widget _buildMarker({
    required String text,
    required Color color,
  }) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}