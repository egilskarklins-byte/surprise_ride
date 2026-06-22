import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../services/app_language_service.dart';

class FoundPoiMapScreen extends StatelessWidget {
  final List<Poi> pois;
  final LatLon start;

  const FoundPoiMapScreen({
    super.key,
    required this.pois,
    required this.start,
  });

  @override
  Widget build(BuildContext context) {
    final points = [
      ll.LatLng(start.lat, start.lon),
      ...pois.map((poi) => ll.LatLng(poi.location.lat, poi.location.lon)),
    ];

    final bounds = LatLngBounds.fromPoints(points);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FB),
      appBar: AppBar(
        title: Text(
          AppLanguageService.tr(
            lv: 'Atrastie POI kartē',
            en: 'Found POIs on map',
          ),
        ),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(48),
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.surprise_ride',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: ll.LatLng(start.lat, start.lon),
                width: 52,
                height: 52,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
              ...pois.asMap().entries.map((entry) {
                final number = entry.key + 1;
                final poi = entry.value;
                final color = _markerColor(poi);

                return Marker(
                  point: ll.LatLng(poi.location.lat, poi.location.lon),
                  width: 42,
                  height: 42,
                  child: Container(
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
                    alignment: Alignment.center,
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Color _markerColor(Poi poi) {
    if (poi.categories.contains(PoiCategory.castle)) {
      return Colors.brown;
    }

    if (poi.categories.contains(PoiCategory.museum)) {
      return Colors.blue;
    }

    if (poi.categories.contains(PoiCategory.nature)) {
      return Colors.green;
    }

    if (poi.categories.contains(PoiCategory.church)) {
      return Colors.amber.shade700;
    }

    if (poi.categories.contains(PoiCategory.monument)) {
      return Colors.orange;
    }

    if (poi.categories.contains(PoiCategory.viewpoint)) {
      return Colors.teal;
    }

    return Colors.deepPurple;
  }
}