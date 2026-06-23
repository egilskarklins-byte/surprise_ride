import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../services/app_language_service.dart';

class FoundPoiMapScreen extends StatelessWidget {
  final List<Poi> pois;
  final LatLon start;
  final int selectedCount;
  final double totalHours;
  final Set<String> selectedPoiIds;

  const FoundPoiMapScreen({
    super.key,
    required this.pois,
    required this.start,
    required this.selectedCount,
    required this.totalHours,
    required this.selectedPoiIds,
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
      body: Stack(
        children: [
          FlutterMap(
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
                    final isSelected = selectedPoiIds.contains(poi.id);

                    return Marker(
                      point: ll.LatLng(poi.location.lat, poi.location.lon),
                      width: isSelected ? 48 : 42,
                      height: isSelected ? 48 : 42,
                      child: GestureDetector(
                        onTap: () {
                          _showPoiSheet(context, poi, number);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 5 : 3,
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
                          child: isSelected
                              ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 22,
                          )
                              : Text(
                            '$number',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  AppLanguageService.tr(
                    lv:
                    'Atrasti: ${pois.length}   Izvēlēti: $selectedCount   Laiks: ${_formatDurationHours(totalHours)}',
                    en:
                    'Found: ${pois.length}   Selected: $selectedCount   Time: ${_formatDurationHours(totalHours)}',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPoiSheet(
      BuildContext context,
      Poi poi,
      int number,
      ) async {
    final isSelected = selectedPoiIds.contains(poi.id);
    final selectedPoiId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. ${poi.name}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _categoryText(poi),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (poi.shortDescription != null &&
                    poi.shortDescription!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(poi.shortDescription!),
                ],
                const SizedBox(height: 20),
                isSelected
                    ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      AppLanguageService.tr(
                        lv: '✓ Jau izvēlēts',
                        en: '✓ Already selected',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
                    : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext, poi.id);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      AppLanguageService.tr(
                        lv: 'Izvēlēties',
                        en: 'Select',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (selectedPoiId == null) return;
    if (!context.mounted) return;

    Navigator.pop(context, selectedPoiId);
  }

  String _categoryText(Poi poi) {
    if (poi.categories.contains(PoiCategory.castle)) {
      return '🏰 Pils / Muiža';
    }

    if (poi.categories.contains(PoiCategory.museum)) {
      return '🏛 Muzejs';
    }

    if (poi.categories.contains(PoiCategory.nature)) {
      return '🌲 Daba';
    }

    if (poi.categories.contains(PoiCategory.church)) {
      return '⛪ Baznīca';
    }

    if (poi.categories.contains(PoiCategory.monument)) {
      return '🗿 Piemineklis';
    }

    if (poi.categories.contains(PoiCategory.viewpoint)) {
      return '🌄 Skatu vieta';
    }

    return '📍 Apskates objekts';
  }

  String _formatDurationHours(double hours) {
    final totalMinutes = (hours * 60).round();

    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }

    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    if (m == 0) {
      return '$h h';
    }

    return '$h h $m min';
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