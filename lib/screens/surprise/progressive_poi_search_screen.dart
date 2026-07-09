import 'package:flutter/material.dart';

import '../../models/geo.dart';

class ProgressivePoiSearchScreen extends StatelessWidget {
  const ProgressivePoiSearchScreen({
    super.key,
    required this.start,
    required this.radiusKm,
  });

  final LatLon start;
  final double radiusKm;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Searching places'),
      ),
      body: Center(
        child: Text('Searching in ${radiusKm.toInt()} km radius...'),
      ),
    );
  }
}