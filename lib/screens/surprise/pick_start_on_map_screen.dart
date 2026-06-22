import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lm;

import '../../models/geo.dart';
import '../../services/app_language_service.dart';

class PickStartOnMapScreen extends StatefulWidget {
  const PickStartOnMapScreen({
    super.key,
    required this.initial,
  });

  final LatLon initial;

  @override
  State<PickStartOnMapScreen> createState() => _PickStartOnMapScreenState();
}

class _PickStartOnMapScreenState extends State<PickStartOnMapScreen> {
  late final MapController _mapController;
  late lm.LatLng _mapCenter;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapCenter = lm.LatLng(widget.initial.lat, widget.initial.lon);
  }

  void _confirmSelection() {
    Navigator.pop(
      context,
      LatLon(_mapCenter.latitude, _mapCenter.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLanguageService.tr(
            lv: 'Izvēlies sākumpunktu kartē',
            en: 'Choose start point on map',
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 12,
              onPositionChanged: (position, hasGesture) {
                _mapCenter = position.center;
              },
              onMapEvent: (event) {
                if (event is MapEventMoveStart) {
                  if (!_moving) {
                    setState(() {
                      _moving = true;
                    });
                  }
                }

                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd) {
                  if (_moving) {
                    setState(() {
                      _moving = false;
                    });
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fun_weather_ride',
              ),
            ],
          ),
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_pin,
                    size: 52,
                    color: _moving ? Colors.redAccent : Colors.red,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLanguageService.tr(
                        lv: 'Pārbīdi karti, lai sarkanais pin būtu virs vēlamā sākumpunkta.',
                        en: 'Move the map so the red pin is above the desired start point.',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${AppLanguageService.tr(
                        lv: 'Centrs',
                        en: 'Center',
                      )}: ${_mapCenter.latitude.toStringAsFixed(5)}, ${_mapCenter.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 46,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: _confirmSelection,
                icon: const Icon(Icons.check_circle_outline),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    AppLanguageService.tr(
                      lv: 'Izvēlēties šo punktu',
                      en: 'Choose this point',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}