part of 'gym_map_page.dart';

extension _GymMapPageFilters on _GymMapPageState {
  /// Algoritmo de busca local:
  /// - normaliza para minusculas;
  /// - se vazio, retorna todas as academias;
  /// - senão, filtra por nome ou endereço.
  List<Gym> _filterGyms(String term) => GymMapLogic.filterGyms(
    gyms: _gyms,
    term: term,
    searchLocationCenter: _searchLocationCenter,
    searchLocationQuery: _searchLocationQuery,
  );

  double _distanceSquaredMeters(LatLng from, LatLng to) =>
      GymMapLogic.distanceSquaredMeters(from, to);

  bool _isWithinDistanceMeters(LatLng from, LatLng to, double maxMeters) =>
      GymMapLogic.isWithinDistanceMeters(from, to, maxMeters);

  bool _isWithinLocalRadius(Gym gym, LatLng userPoint) =>
      GymMapLogic.isWithinLocalRadius(gym, userPoint, _coverageRadiusMeters);

  double get _coverageRadiusMeters =>
      _hasNationwideCoverage
          ? _GymMapPageState._eliteCoverageRadiusMeters
          : _GymMapPageState._defaultCoverageRadiusMeters;

  String _normalizeSearchTerm(String value) =>
      _mapSearchState.normalizeSearchTerm(value);

  List<Gym> _applyLocationFilter(List<Gym> gyms, {String? term}) =>
      GymMapLogic.applyLocationFilter(
        gyms: gyms,
        effectiveTerm: term ?? _searchTerm,
        searchLocationCenter: _searchLocationCenter,
        searchLocationQuery: _searchLocationQuery,
        manualBrowseCenter: _manualBrowseCenter,
        userLocation: _userLocation,
        localGymRadiusMeters: _coverageRadiusMeters,
      );

  List<MapGymPoi> _filteredMapPois() => GymMapLogic.filterMapPois(
    mapPois: _mapPois,
    searchTerm: _searchTerm,
    searchLocationCenter: _searchLocationCenter,
    searchLocationQuery: _searchLocationQuery,
    manualBrowseCenter: _manualBrowseCenter,
    userLocation: _userLocation,
    localGymRadiusMeters: _coverageRadiusMeters,
    mapCenter:
        _isMapReady
            ? _mapController.camera.center
            : _GymMapPageState._fallbackMapCenter,
    zoom: _isMapReady ? _mapController.camera.zoom : 13.4,
    maxMapPoiMarkers: _GymMapPageState._maxMapPoiMarkers,
    maxMapPoiMarkersZoomedOut: _GymMapPageState._maxMapPoiMarkersZoomedOut,
  );

  List<String> _crowdSyncGymIds({Iterable<String>? extraGymIds}) {
    final ids = <String>{};
    for (final gym in _gyms) {
      final id = gym.id.trim();
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    final selected = _selectedGym;
    if (selected != null && selected.id.trim().isNotEmpty) {
      ids.add(selected.id.trim());
    }
    for (final poi in _mapPois.take(80)) {
      final id = poi.id.trim();
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    if (extraGymIds != null) {
      for (final idRaw in extraGymIds) {
        final id = idRaw.trim();
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }
    return ids.toList(growable: false);
  }

  Future<void> _initializeCrowdRemoteService() async {
    try {
      final remoteService = await CrowdReportRemoteService.create();
      if (!mounted) {
        return;
      }
      _crowdReportRemoteService = remoteService;
      unawaited(_syncCrowdReportsForCurrentContext());
    } catch (_) {
      // Falha de inicialização remota não bloqueia experiência local.
    }
  }

  Future<void> _syncCrowdReportsForCurrentContext() async {
    if (_isDataSaverEnabled) {
      final now = DateTime.now();
      final lastSync = _lastDataSaverCrowdSyncAt;
      if (lastSync != null &&
          now.difference(lastSync) <
              _GymMapPageState._dataSaverCrowdSyncCooldown) {
        return;
      }
      _lastDataSaverCrowdSyncAt = now;
    }
    await _syncCrowdReportsForGyms(_crowdSyncGymIds());
  }

  Future<void> _syncCrowdReportsForGyms(Iterable<String> gymIds) async {
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null || !remoteService.hasRemoteBackend) {
      return;
    }

    final requested =
        gymIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (requested.isEmpty) {
      return;
    }
    _pendingCrowdSyncGymIds.addAll(requested);
    if (_isSyncingCrowdReports) {
      return;
    }

    _isSyncingCrowdReports = true;
    try {
      while (_pendingCrowdSyncGymIds.isNotEmpty) {
        final batch = _pendingCrowdSyncGymIds.take(80).toList(growable: false);
        _pendingCrowdSyncGymIds.removeAll(batch);
        remoteService.refreshAuthFromStorage();
        final reports = await remoteService.loadReportsForGyms(gymIds: batch);
        if (!mounted || reports.isEmpty) {
          continue;
        }
        final merged = _crowdService.mergeReports(reports);
        if (merged > 0) {
          _markCrowdDataChanged();
          _queueUiRefreshIfMapVisible();
        }
      }
    } catch (_) {
      // Falha de rede remota não deve interromper fluxo local.
    } finally {
      _isSyncingCrowdReports = false;
    }
  }

  Future<void> _initializeGymLocationCache() async {
    try {
      final cachedPois = await _mapPoiController.loadCachedPois();
      if (!mounted) {
        return;
      }
      unawaited(_refreshGymLocationCacheFromRemote());
      if (_mapPois.isNotEmpty || cachedPois.isEmpty) {
        return;
      }
      _setMapPoisIfChanged(cachedPois);
    } catch (_) {
      // Falha de cache local não deve bloquear o mapa.
    }
  }

  Future<void> _refreshGymLocationCacheFromRemote() async {
    final pulledCount = await _mapPoiController.pullRemoteToLocal();
    if (pulledCount <= 0 || !mounted) {
      return;
    }
    final center =
        _manualBrowseCenter ??
        _searchLocationCenter ??
        _userLocation ??
        _GymMapPageState._fallbackMapCenter;
    await _restoreCachedMapPoisNear(center, force: true);
  }

  Future<void> _persistMapPoisToCache(List<MapGymPoi> pois) async {
    try {
      await _mapPoiController.persistPois(pois);
    } catch (_) {
      // Falha de cache local não deve bloquear o mapa.
    }
  }

  Future<void> _restoreCachedMapPoisNear(
    LatLng center, {
    bool force = false,
  }) async {
    final hasNearbyInMemory = _mapPois.any(
      (poi) =>
          _isWithinDistanceMeters(center, poi.position, _coverageRadiusMeters),
    );
    if (!force && hasNearbyInMemory) {
      return;
    }

    final nearby = await _mapPoiController.loadCachedPoisNear(
      center: center,
      radiusMeters: _coverageRadiusMeters,
      limit: _GymMapPageState._maxMapPoiMarkers,
    );
    if (nearby.isEmpty || !mounted) {
      return;
    }
    _setMapPoisIfChanged(nearby);
  }

  Future<void> _loadMapPoisAround(LatLng center) async {
    _beginMapPoiLoading();
    try {
      await _mapPoiReloadController.loadWithQueue(
        center: center,
        onLoad: (targetCenter) async {
          try {
            final poiList = await _mapPoiController.fetchOverpassPoisAround(
              center: targetCenter,
              knownGyms: _gyms,
            );
            if (poiList == null) {
              return false;
            }
            if (!mounted) {
              return false;
            }
            _setMapPoisIfChanged(poiList);
            unawaited(_persistMapPoisToCache(poiList));
            if (poiList.isNotEmpty) {
              unawaited(
                _syncCrowdReportsForGyms(
                  _crowdSyncGymIds(extraGymIds: poiList.map((poi) => poi.id)),
                ),
              );
            }
            return true;
          } catch (_) {
            // Falha de rede/API não deve travar o fluxo local do mapa.
            return false;
          }
        },
      );
    } finally {
      _endMapPoiLoading();
    }
  }

  void _scheduleMapPoiReload(LatLng center, {bool force = false}) {
    if (!widget.showMap) {
      return;
    }
    if (_isDataSaverEnabled && !force) {
      final now = DateTime.now();
      final lastReloadAt = _lastDataSaverPoiReloadAt;
      final lastCenter = _lastDataSaverPoiReloadCenter;
      if (lastReloadAt != null &&
          now.difference(lastReloadAt) <
              _GymMapPageState._dataSaverPoiReloadCooldown) {
        return;
      }
      if (lastCenter != null &&
          _isWithinDistanceMeters(
            center,
            lastCenter,
            _GymMapPageState._dataSaverPoiReloadMinDistanceMeters,
          )) {
        return;
      }
      _lastDataSaverPoiReloadAt = now;
      _lastDataSaverPoiReloadCenter = center;
    }
    _mapPoiReloadController.scheduleReload(
      center: center,
      force: force,
      onDebouncedReload: (targetCenter) async {
        if (!mounted) {
          return;
        }
        await _loadMapPoisAround(targetCenter);
      },
    );
  }

  void _beginMapPoiLoading() {
    _mapPoiLoadingRequests++;
    if (_isLoadingMapPois || !mounted) {
      return;
    }
    _setStateIfMapVisible(() {
      _isLoadingMapPois = true;
    });
  }

  void _endMapPoiLoading() {
    if (_mapPoiLoadingRequests <= 0) {
      return;
    }
    _mapPoiLoadingRequests--;
    if (_mapPoiLoadingRequests > 0 || !_isLoadingMapPois || !mounted) {
      return;
    }
    _setStateIfMapVisible(() {
      _isLoadingMapPois = false;
    });
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) {
      return;
    }
    final center = camera.center;
    final normalizedSearchTerm = _normalizeSearchTerm(_searchTerm);
    final shouldUpdate = _mapSearchState.updateCenterFromMapGesture(
      center: center,
      normalizedSearchTerm: normalizedSearchTerm,
      minDistanceMeters:
          _GymMapPageState._mapBrowseAnchorUpdateMinDistanceMeters,
    );

    if (shouldUpdate) {
      _mapBrowseCenterUiDebounce?.cancel();
      _mapBrowseCenterUiDebounce = Timer(
        _GymMapPageState._mapBrowseCenterUiDebounceDelay,
        () {
        if (!mounted) {
          return;
        }
        _queueUiRefreshIfMapVisible();
      },
      );
    }

    _scheduleMapPoiReload(center);
  }

  List<Gym> get _filteredGyms =>
      _applyLocationFilter(_filterGyms(_searchTerm), term: _searchTerm);

  bool _gymHasAmenity(Gym gym, String amenityTerm) {
    final normalizedTerm = _normalizeSearchTerm(amenityTerm);
    for (final amenity in gym.amenities) {
      if (_normalizeSearchTerm(amenity).contains(normalizedTerm)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesQuickFilters({
    required Gym gym,
    required GymCrowdSnapshot snapshot,
  }) {
    if (_activeQuickFilters.contains(MapQuickFilter.openNow) &&
        !_isGymOpenNow(gym)) {
      return false;
    }
    if (_activeQuickFilters.contains(MapQuickFilter.lowCrowd) &&
        snapshot.occupancyPercent > 45) {
      return false;
    }
    if (_activeQuickFilters.contains(MapQuickFilter.withClasses) &&
        !_gymHasAmenity(gym, 'aula')) {
      return false;
    }
    if (_activeQuickFilters.contains(MapQuickFilter.withCardio) &&
        !_gymHasAmenity(gym, 'cardio')) {
      return false;
    }
    if (_activeQuickFilters.contains(MapQuickFilter.withPool) &&
        !_gymHasAmenity(gym, 'piscina')) {
      return false;
    }
    if (_activeQuickFilters.contains(MapQuickFilter.favorites) &&
        !_isFavoriteGymId(gym.id)) {
      return false;
    }
    return true;
  }

  List<Gym> _applyQuickFiltersToGyms(
    List<Gym> gyms,
    Map<String, GymCrowdSnapshot> snapshotsByGymId,
  ) {
    if (_activeQuickFilters.isEmpty) {
      return gyms;
    }
    return gyms
        .where((gym) {
          final snapshot =
              snapshotsByGymId[gym.id] ?? _crowdService.snapshotFor(gym);
          return _matchesQuickFilters(gym: gym, snapshot: snapshot);
        })
        .toList(growable: false);
  }

  List<MapGymPoi> _applyQuickFiltersToPois(List<MapGymPoi> pois) {
    if (_activeQuickFilters.isEmpty) {
      return pois;
    }
    return pois
        .where((poi) {
          final gym = _gymFromPoi(poi);
          final snapshot = _crowdService.snapshotFor(gym);
          return _matchesQuickFilters(gym: gym, snapshot: snapshot);
        })
        .toList(growable: false);
  }

  String _quickFilterId(MapQuickFilter filter) {
    switch (filter) {
      case MapQuickFilter.openNow:
        return 'open';
      case MapQuickFilter.lowCrowd:
        return 'low';
      case MapQuickFilter.withClasses:
        return 'classes';
      case MapQuickFilter.withCardio:
        return 'cardio';
      case MapQuickFilter.withPool:
        return 'pool';
      case MapQuickFilter.favorites:
        return 'favorites';
    }
  }

  MapQuickFilter? _quickFilterFromId(String id) {
    switch (id) {
      case 'open':
        return MapQuickFilter.openNow;
      case 'low':
        return MapQuickFilter.lowCrowd;
      case 'classes':
        return MapQuickFilter.withClasses;
      case 'cardio':
        return MapQuickFilter.withCardio;
      case 'pool':
        return MapQuickFilter.withPool;
      case 'favorites':
        return MapQuickFilter.favorites;
      default:
        return null;
    }
  }

  void _toggleQuickFilterById(String id) {
    final filter = _quickFilterFromId(id);
    if (filter == null) {
      return;
    }
    _toggleQuickFilter(filter);
  }

  void _toggleQuickFilter(MapQuickFilter filter) {
    var isSelected = false;
    _hasInteractedWithQuickFilters = true;
    _setStateIfMapVisible(() {
      if (_activeQuickFilters.contains(filter)) {
        _activeQuickFilters.remove(filter);
        isSelected = false;
      } else {
        _activeQuickFilters.add(filter);
        isSelected = true;
      }

      final selectedGym = _selectedGym;
      if (selectedGym == null) {
        return;
      }
      final selectedSnapshot = _crowdService.snapshotFor(selectedGym);
      if (!_matchesQuickFilters(gym: selectedGym, snapshot: selectedSnapshot)) {
        _selectedGym = null;
      }
    });
    unawaited(
      _metrics.trackEvent(
        'filter_toggle',
        params: <String, Object?>{
          'filterId': _quickFilterId(filter),
          'selected': isSelected,
        },
      ),
    );
    unawaited(_persistQuickFiltersState());
  }

  void _clearAllQuickFilters() {
    if (_activeQuickFilters.isEmpty) {
      return;
    }
    _hasInteractedWithQuickFilters = true;
    _setStateIfMapVisible(() {
      _activeQuickFilters.clear();
    });
    unawaited(_metrics.trackEvent('filter_clear_all'));
    unawaited(_persistQuickFiltersState());
  }

  List<QuickFilterChipData> _buildQuickFilterChips() {
    return <QuickFilterChipData>[
      QuickFilterChipData(
        id: 'open',
        label: 'Abertas agora',
        icon: Icons.schedule_rounded,
        selected: _activeQuickFilters.contains(MapQuickFilter.openNow),
      ),
      QuickFilterChipData(
        id: 'low',
        label: 'Lotação baixa',
        icon: Icons.trending_down_rounded,
        selected: _activeQuickFilters.contains(MapQuickFilter.lowCrowd),
      ),
      QuickFilterChipData(
        id: 'classes',
        label: 'Aulas',
        icon: Icons.groups_2_outlined,
        selected: _activeQuickFilters.contains(MapQuickFilter.withClasses),
      ),
      QuickFilterChipData(
        id: 'cardio',
        label: 'Cardio',
        icon: Icons.directions_run_outlined,
        selected: _activeQuickFilters.contains(MapQuickFilter.withCardio),
      ),
      QuickFilterChipData(
        id: 'pool',
        label: 'Com piscina',
        icon: Icons.pool_outlined,
        selected: _activeQuickFilters.contains(MapQuickFilter.withPool),
      ),
      QuickFilterChipData(
        id: 'favorites',
        label: 'Favoritas',
        icon: Icons.favorite_outline_rounded,
        selected: _activeQuickFilters.contains(MapQuickFilter.favorites),
      ),
    ];
  }

  (int openHour, int closeHour) _heuristicOpenWindowForWeekday(int weekday) {
    // Janela local heurística enquanto não existe cadastro oficial de horários.
    return switch (weekday) {
      DateTime.saturday => (8, 20),
      DateTime.sunday => (8, 14),
      _ => (6, 23),
    };
  }

  String _hourTag24(int hour) => '${hour.toString().padLeft(2, '0')}h';

  bool _isGymOpenNow(Gym gym) {
    final now = DateTime.now();
    final (openHour, closeHour) = _heuristicOpenWindowForWeekday(now.weekday);
    return now.hour >= openHour && now.hour < closeHour;
  }

  String _gymOpenStatusLabel(Gym gym) {
    final now = DateTime.now();
    final (openHour, closeHour) = _heuristicOpenWindowForWeekday(now.weekday);
    final isOpen = _isGymOpenNow(gym);
    if (isOpen) {
      return 'Aberta até ${_hourTag24(closeHour)}';
    }
    if (now.hour < openHour) {
      return 'Abre as ${_hourTag24(openHour)}';
    }
    final nextWeekday =
        now.weekday == DateTime.sunday ? DateTime.monday : now.weekday + 1;
    final (nextOpenHour, _) = _heuristicOpenWindowForWeekday(nextWeekday);
    return 'Abre amanhã as ${_hourTag24(nextOpenHour)}';
  }

  String _gymOpenHoursLabel(Gym gym) {
    final now = DateTime.now();
    final (openHour, closeHour) = _heuristicOpenWindowForWeekday(now.weekday);
    return 'Hoje: ${_hourTag24(openHour)} - ${_hourTag24(closeHour)}';
  }
}
