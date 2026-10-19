part of 'gym_map_page.dart';

extension _GymMapPageStateCache on _GymMapPageState {
  String _locationCacheKey(LatLng? point) {
    if (point == null) {
      return 'none';
    }
    return '${point.latitude.toStringAsFixed(5)},'
        '${point.longitude.toStringAsFixed(5)}';
  }

  void _markCrowdDataChanged() {
    _crowdDataRevision++;
  }

  String _mapDerivedDataKeyForCurrentContext() {
    final camera = _isMapReady ? _mapController.camera : null;
    final mapCenter = camera?.center;
    final mapZoom = camera?.zoom ?? 13.4;
    final normalizedSearchTerm = _normalizeSearchTerm(_searchTerm);
    final normalizedSearchLocationQuery = _normalizeSearchTerm(
      _searchLocationQuery ?? '',
    );
    final quickFilterHash = Object.hashAllUnordered(_activeQuickFilters);
    final favoritesHash = Object.hashAllUnordered(_favoriteGymIds);
    return [
      normalizedSearchTerm,
      normalizedSearchLocationQuery,
      _locationCacheKey(_searchLocationCenter),
      _locationCacheKey(_manualBrowseCenter),
      _locationCacheKey(_userLocation),
      _locationCacheKey(mapCenter),
      mapZoom.toStringAsFixed(2),
      _coverageRadiusMeters.toStringAsFixed(0),
      quickFilterHash.toString(),
      favoritesHash.toString(),
      _mapPoisRevision.toString(),
      _crowdDataRevision.toString(),
      _isMapReady ? '1' : '0',
    ].join('|');
  }

  _MapDerivedData _resolveMapDerivedData() {
    final nextKey = _mapDerivedDataKeyForCurrentContext();
    final cached = _mapDerivedDataCache;
    if (cached != null && _mapDerivedDataCacheKey == nextKey) {
      return cached;
    }
    final snapshotsByGymId = <String, GymCrowdSnapshot>{
      for (final gym in _gyms) gym.id: _crowdService.snapshotFor(gym),
    };
    final filteredGyms = _applyQuickFiltersToGyms(
      _filteredGyms,
      snapshotsByGymId,
    );
    final filteredMapPois = _applyQuickFiltersToPois(_filteredMapPois());
    final resolved = _MapDerivedData(
      snapshotsByGymId: snapshotsByGymId,
      filteredGyms: filteredGyms,
      filteredMapPois: filteredMapPois,
    );
    _mapDerivedDataCacheKey = nextKey;
    _mapDerivedDataCache = resolved;
    return resolved;
  }

  bool _samePoiList(List<MapGymPoi> left, List<MapGymPoi> right) {
    return GymMapLogic.samePoiList(left, right);
  }

  /// Soma [incoming] às academias já carregadas em vez de substituí-las, para
  /// os pinos não sumirem e voltarem a cada busca. Descarta só as que ficaram
  /// longe de [center] e limita o total, mantendo as mais próximas.
  void _mergeMapPois(List<MapGymPoi> incoming, LatLng center) {
    final byId = <String, MapGymPoi>{
      for (final poi in _mapPois) poi.id: poi,
      for (final poi in incoming) poi.id: poi,
    };
    final retained =
        byId.values
            .where(
              (poi) => _isWithinDistanceMeters(
                center,
                poi.position,
                _GymMapPageState._mapPoiRetentionRadiusMeters,
              ),
            )
            .toList();
    if (retained.length > _GymMapPageState._maxRetainedMapPois) {
      retained.sort(
        (a, b) => _distanceSquaredMeters(
          center,
          a.position,
        ).compareTo(_distanceSquaredMeters(center, b.position)),
      );
      retained.removeRange(
        _GymMapPageState._maxRetainedMapPois,
        retained.length,
      );
    }
    _setMapPoisIfChanged(retained);
  }

  void _setMapPoisIfChanged(List<MapGymPoi> nextPois) {
    if (!mounted || _samePoiList(_mapPois, nextPois)) {
      return;
    }
    var hasHydratedFavoriteNames = false;
    _setStateIfMapVisible(() {
      _mapPois = List<MapGymPoi>.unmodifiable(nextPois);
      _mapPoisRevision++;
      hasHydratedFavoriteNames = _hydrateFavoriteGymNamesFromPois(nextPois);
    });
    _tryResolvePendingFocusGymId();
    // A lista muda quando a localização chega ou o mapa se move: hora de
    // ver as sugestões de academia por perto.
    unawaited(_loadGymSuggestions());
    if (hasHydratedFavoriteNames) {
      unawaited(_persistFavoriteGymIds());
    }
  }

  bool _hydrateFavoriteGymNamesFromGyms(Iterable<Gym> gyms) {
    var changed = false;
    for (final gym in gyms) {
      final id = gym.id.trim();
      final name = gym.name.trim();
      if (id.isEmpty ||
          name.isEmpty ||
          !_favoriteGymIds.contains(id) ||
          _favoriteGymNamesById.containsKey(id)) {
        continue;
      }
      _favoriteGymNamesById[id] = name;
      changed = true;
    }
    return changed;
  }

  bool _hydrateFavoriteGymNamesFromPois(Iterable<MapGymPoi> pois) {
    var changed = false;
    for (final poi in pois) {
      final id = poi.id.trim();
      final name = poi.name.trim();
      if (id.isEmpty ||
          name.isEmpty ||
          !_favoriteGymIds.contains(id) ||
          _favoriteGymNamesById.containsKey(id)) {
        continue;
      }
      _favoriteGymNamesById[id] = name;
      changed = true;
    }
    return changed;
  }
}
