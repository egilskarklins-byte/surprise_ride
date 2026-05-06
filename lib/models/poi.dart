import 'geo.dart';

enum PoiCategory {
  mustSee,
  nature,
  beach,
  viewpoint,
  museum,
  indoor,
  food,
  city,
}

class Poi {
  final String id;
  final String name;
  final LatLon location;

  // veco atstājam, lai nekas nesalūzt
  final double durationH;

  // JAUNAIS
  final int visitMinutes;

  // JAUNAIS
  final String? shortDescription;

  final Set<PoiCategory> categories;
  final bool isIndoor;

  const Poi({
    required this.id,
    required this.name,
    required this.location,

    this.durationH = 1.5,

    this.visitMinutes = 30,

    this.shortDescription,

    this.categories = const {PoiCategory.mustSee},
    this.isIndoor = false,
  });
}