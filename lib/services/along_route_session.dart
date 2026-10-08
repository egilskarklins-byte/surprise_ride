import '../models/geo.dart';
import '../models/poi.dart';

class AlongRouteSession {
  AlongRouteSession._();

  static final AlongRouteSession instance = AlongRouteSession._();

  List<LatLon>? routePoints;
  String? startName;
  String? destinationName;
  double? distanceKm;
  double? durationMinutes;
  double? corridorKm;

  List<Poi> pois = [];
  Set<Poi> selectedPois = {};

  bool get hasCompletedRoute =>
      routePoints != null &&
          routePoints!.isNotEmpty &&
          startName != null &&
          destinationName != null &&
          pois.isNotEmpty;

  void clear() {
    routePoints = null;
    startName = null;
    destinationName = null;
    distanceKm = null;
    durationMinutes = null;
    corridorKm = null;
    pois = [];
    selectedPois = {};
  }
}