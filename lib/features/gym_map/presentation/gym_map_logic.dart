import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../domain/gym_models.dart';

class MapGymPoi {
  const MapGymPoi({
    required this.id,
    required this.position,
    required this.name,
  });

  final String id;
  final LatLng position;
  final String name;
}

class GymMapLogic {
  static String normalizeSearchTerm(String value) => value.trim().toLowerCase();

  static bool isSearchLocationQuery({
    required String normalizedTerm,
    required LatLng? searchLocationCenter,
    required String? searchLocationQuery,
  }) {
    return searchLocationCenter != null &&
        searchLocationQuery != null &&
        searchLocationQuery == normalizedTerm;
  }

  static double distanceSquaredMeters(LatLng from, LatLng to) {
    const metersPerDegree = 111320.0;
    final avgLatRad = ((from.latitude + to.latitude) * 0.5) * math.pi / 180.0;
    final deltaLatMeters = (from.latitude - to.latitude) * metersPerDegree;
    final deltaLonMeters =
        (from.longitude - to.longitude) * metersPerDegree * math.cos(avgLatRad);
    return deltaLatMeters * deltaLatMeters + deltaLonMeters * deltaLonMeters;
  }

  static bool isWithinDistanceMeters(LatLng from, LatLng to, double maxMeters) {
    final maxSquared = maxMeters * maxMeters;
    return distanceSquaredMeters(from, to) <= maxSquared;
  }

  static bool isWithinLocalRadius(
    Gym gym,
    LatLng userPoint,
    double localGymRadiusMeters,
  ) {
    return isWithinDistanceMeters(
      gym.position,
      userPoint,
      localGymRadiusMeters,
    );
  }

  static List<Gym> filterGyms({
    required List<Gym> gyms,
    required String term,
    required LatLng? searchLocationCenter,
    required String? searchLocationQuery,
  }) {
    final normalized = normalizeSearchTerm(term);
    if (normalized.isEmpty) {
      return gyms;
    }
    if (isSearchLocationQuery(
      normalizedTerm: normalized,
      searchLocationCenter: searchLocationCenter,
      searchLocationQuery: searchLocationQuery,
    )) {
      return gyms;
    }
    return gyms
        .where(
          (gym) =>
              gym.name.toLowerCase().contains(normalized) ||
              gym.address.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  static List<Gym> applyLocationFilter({
    required List<Gym> gyms,
    required String effectiveTerm,
    required LatLng? searchLocationCenter,
    required String? searchLocationQuery,
    required LatLng? manualBrowseCenter,
    required LatLng? userLocation,
    required double localGymRadiusMeters,
  }) {
    final normalized = normalizeSearchTerm(effectiveTerm);
    final center =
        isSearchLocationQuery(
              normalizedTerm: normalized,
              searchLocationCenter: searchLocationCenter,
              searchLocationQuery: searchLocationQuery,
            )
            ? searchLocationCenter
            : (manualBrowseCenter ?? userLocation);
    if (center == null) {
      return gyms;
    }
    return gyms
        .where((gym) => isWithinLocalRadius(gym, center, localGymRadiusMeters))
        .toList(growable: false);
  }

  static bool isNearAnyKnownGym({
    required LatLng point,
    required List<Gym> gyms,
    double maxMeters = 120,
  }) {
    for (final gym in gyms) {
      if (isWithinDistanceMeters(point, gym.position, maxMeters)) {
        return true;
      }
    }
    return false;
  }

  static int poiMarkerLimitForZoom({
    required double zoom,
    required int maxMapPoiMarkers,
    required int maxMapPoiMarkersZoomedOut,
  }) {
    return zoom < 12.9 ? maxMapPoiMarkersZoomedOut : maxMapPoiMarkers;
  }

  static List<MapGymPoi> filterMapPois({
    required List<MapGymPoi> mapPois,
    required String searchTerm,
    required LatLng? searchLocationCenter,
    required String? searchLocationQuery,
    required LatLng? manualBrowseCenter,
    required LatLng? userLocation,
    required double localGymRadiusMeters,
    required LatLng mapCenter,
    required double zoom,
    required int maxMapPoiMarkers,
    required int maxMapPoiMarkersZoomedOut,
  }) {
    final normalized = normalizeSearchTerm(searchTerm);
    final useSearchLocation = isSearchLocationQuery(
      normalizedTerm: normalized,
      searchLocationCenter: searchLocationCenter,
      searchLocationQuery: searchLocationQuery,
    );
    final anchorPoint =
        useSearchLocation
            ? searchLocationCenter
            : (manualBrowseCenter ?? userLocation);

    final filtered = <MapGymPoi>[];
    for (final poi in mapPois) {
      if (anchorPoint != null &&
          !isWithinDistanceMeters(
            anchorPoint,
            poi.position,
            localGymRadiusMeters,
          )) {
        continue;
      }
      if (normalized.isEmpty || useSearchLocation) {
        filtered.add(poi);
        continue;
      }
      if (poi.name.toLowerCase().contains(normalized)) {
        filtered.add(poi);
      }
    }

    final markerLimit = poiMarkerLimitForZoom(
      zoom: zoom,
      maxMapPoiMarkers: maxMapPoiMarkers,
      maxMapPoiMarkersZoomedOut: maxMapPoiMarkersZoomedOut,
    );
    if (filtered.length <= markerLimit) {
      return filtered;
    }

    final rankingCenter = anchorPoint ?? mapCenter;
    filtered.sort(
      (a, b) => distanceSquaredMeters(
        rankingCenter,
        a.position,
      ).compareTo(distanceSquaredMeters(rankingCenter, b.position)),
    );
    return filtered.take(markerLimit).toList(growable: false);
  }

  static bool samePoiList(List<MapGymPoi> left, List<MapGymPoi> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      final a = left[i];
      final b = right[i];
      if (a.id != b.id ||
          a.name != b.name ||
          a.position.latitude != b.position.latitude ||
          a.position.longitude != b.position.longitude) {
        return false;
      }
    }
    return true;
  }
}
