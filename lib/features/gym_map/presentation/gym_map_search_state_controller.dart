import 'package:latlong2/latlong.dart';

import 'gym_map_logic.dart';

class GymMapSearchStateController {
  String searchTerm = '';
  LatLng? searchLocationCenter;
  String? searchLocationQuery;
  LatLng? manualBrowseCenter;

  String normalizeSearchTerm(String value) =>
      GymMapLogic.normalizeSearchTerm(value);

  bool isSearchLocationQuery(String normalizedTerm) {
    return GymMapLogic.isSearchLocationQuery(
      normalizedTerm: normalizedTerm,
      searchLocationCenter: searchLocationCenter,
      searchLocationQuery: searchLocationQuery,
    );
  }

  bool shouldClearSearchLocation(String normalizedTerm) {
    return normalizedTerm.isEmpty ||
        (searchLocationQuery != null && searchLocationQuery != normalizedTerm);
  }

  void clearSearchLocation() {
    searchLocationCenter = null;
    searchLocationQuery = null;
  }

  void clearAnchors() {
    clearSearchLocation();
    manualBrowseCenter = null;
  }

  void applyResolvedSearchLocation({
    required String normalizedQuery,
    required LatLng center,
  }) {
    searchLocationCenter = center;
    searchLocationQuery = normalizedQuery;
    manualBrowseCenter = null;
  }

  bool updateCenterFromMapGesture({
    required LatLng center,
    required String normalizedSearchTerm,
    required double minDistanceMeters,
  }) {
    final followsSearchQuery = isSearchLocationQuery(normalizedSearchTerm);
    final previousCenter =
        followsSearchQuery ? searchLocationCenter : manualBrowseCenter;
    if (previousCenter != null &&
        GymMapLogic.isWithinDistanceMeters(
          center,
          previousCenter,
          minDistanceMeters,
        )) {
      return false;
    }

    if (followsSearchQuery) {
      searchLocationCenter = center;
    } else {
      manualBrowseCenter = center;
    }
    return true;
  }
}
