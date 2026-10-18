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

  bool _isOutsideCurrentPlanCoverage(
    LatLng center, {
    bool allowWithoutUserLocation = false,
  }) {
    if (_hasNationwideCoverage) {
      return false;
    }
    final userPoint = _userLocation;
    if (userPoint == null) {
      return !allowWithoutUserLocation;
    }
    return !_isWithinDistanceMeters(
      userPoint,
      center,
      _GymMapPageState._defaultCoverageRadiusMeters,
    );
  }

  bool _ensurePlanCoverageForCenter(
    LatLng center, {
    bool notifyIfBlocked = false,
    bool offerEliteUpgrade = false,
    bool allowWithoutUserLocation = false,
  }) {
    if (!_isOutsideCurrentPlanCoverage(
      center,
      allowWithoutUserLocation: allowWithoutUserLocation,
    )) {
      return true;
    }
    if (notifyIfBlocked) {
      _notifyCoverageAccessBlocked(offerEliteUpgrade: offerEliteUpgrade);
    }
    return false;
  }

  void _notifyCoverageAccessBlocked({required bool offerEliteUpgrade}) {
    final now = DateTime.now().toUtc();
    final lastNoticeAt = _lastCoverageLockSnackAt;
    if (lastNoticeAt != null &&
        now.difference(lastNoticeAt) <
            _GymMapPageState._coverageLockSnackCooldown) {
      return;
    }
    _lastCoverageLockSnackAt = now;

    if (_userLocation == null && !_hasNationwideCoverage) {
      _showMapSnack(_t.coverageEnableLocation);
      return;
    }

    _showMapSnack(_t.coverageEliteOnly);
    if (offerEliteUpgrade) {
      _openPlanSettings();
    }
  }

  List<MapGymPoi> _filterPoisByCurrentPlan(Iterable<MapGymPoi> pois) {
    if (_hasNationwideCoverage) {
      return pois.toList(growable: false);
    }
    final coverageCenter =
        _userLocation ?? _searchLocationCenter ?? _manualBrowseCenter;
    if (coverageCenter == null) {
      return const <MapGymPoi>[];
    }
    return pois
        .where(
          (poi) => _isWithinDistanceMeters(
            coverageCenter,
            poi.position,
            _GymMapPageState._defaultCoverageRadiusMeters,
          ),
        )
        .toList(growable: false);
  }

  void _enforcePlanCoverageAfterTierChange() {
    if (_hasNationwideCoverage) {
      return;
    }

    final userPoint = _userLocation;
    if (userPoint == null) {
      _setMapPoisIfChanged(const <MapGymPoi>[]);
      _clearSelectedGym();
      _setStateIfMapVisible(() {
        _mapSearchState.clearAnchors();
      });
      return;
    }

    final searchCenter = _searchLocationCenter;
    final manualCenter = _manualBrowseCenter;
    final hasOutOfRangeAnchor =
        (searchCenter != null &&
            !_isWithinDistanceMeters(
              userPoint,
              searchCenter,
              _GymMapPageState._defaultCoverageRadiusMeters,
            )) ||
        (manualCenter != null &&
            !_isWithinDistanceMeters(
              userPoint,
              manualCenter,
              _GymMapPageState._defaultCoverageRadiusMeters,
            ));
    if (hasOutOfRangeAnchor) {
      _setStateIfMapVisible(() {
        _mapSearchState.clearAnchors();
      });
      _moveMapTo(userPoint, 14.8);
    }

    final selectedGym = _selectedGym;
    if (selectedGym != null &&
        !_isWithinDistanceMeters(
          userPoint,
          selectedGym.position,
          _GymMapPageState._defaultCoverageRadiusMeters,
        )) {
      _clearSelectedGym();
    }
    _setMapPoisIfChanged(_filterPoisByCurrentPlan(_mapPois));
  }

  String _normalizeSearchTerm(String value) =>
      _mapSearchState.normalizeSearchTerm(value);

  List<Gym> _applyLocationFilter(List<Gym> gyms, {String? term}) {
    final hasAreaAnchor =
        _searchLocationCenter != null || _manualBrowseCenter != null;
    if (!_hasNationwideCoverage && _userLocation == null && !hasAreaAnchor) {
      return const <Gym>[];
    }
    return GymMapLogic.applyLocationFilter(
      gyms: gyms,
      effectiveTerm: term ?? _searchTerm,
      searchLocationCenter: _searchLocationCenter,
      searchLocationQuery: _searchLocationQuery,
      manualBrowseCenter: _manualBrowseCenter,
      userLocation: _userLocation,
      localGymRadiusMeters: _coverageRadiusMeters,
    );
  }

  List<MapGymPoi> _filteredMapPois() {
    final hasAreaAnchor =
        _searchLocationCenter != null || _manualBrowseCenter != null;
    if (!_hasNationwideCoverage && _userLocation == null && !hasAreaAnchor) {
      return const <MapGymPoi>[];
    }
    return GymMapLogic.filterMapPois(
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
  }

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
      unawaited(_refreshRewards());
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
        unawaited(_loadAmenityVotes(batch));
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
      final visibleCachedPois = _filterPoisByCurrentPlan(cachedPois);
      if (_mapPois.isNotEmpty || visibleCachedPois.isEmpty) {
        return;
      }
      _setMapPoisIfChanged(visibleCachedPois);
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
    bool allowWithoutUserLocation = false,
  }) async {
    if (!_ensurePlanCoverageForCenter(
      center,
      allowWithoutUserLocation: allowWithoutUserLocation,
    )) {
      return;
    }
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
    final visibleNearby = _filterPoisByCurrentPlan(nearby);
    if (visibleNearby.isEmpty || !mounted) {
      return;
    }
    _mergeMapPois(visibleNearby, center);
  }

  Future<void> _loadMapPoisAround(
    LatLng center, {
    bool allowWithoutUserLocation = false,
  }) async {
    if (!_ensurePlanCoverageForCenter(
      center,
      allowWithoutUserLocation: allowWithoutUserLocation,
    )) {
      return;
    }
    _beginMapPoiLoading();
    try {
      await _mapPoiReloadController.loadWithQueue(
        center: center,
        onLoad: (targetCenter) async {
          if (!_ensurePlanCoverageForCenter(
            targetCenter,
            allowWithoutUserLocation: allowWithoutUserLocation,
          )) {
            return false;
          }
          try {
            // 1) Lista compartilhada do backend: rápida e já com o que outros
            // usuários encontraram. Com academias suficientes na área, não
            // precisa consultar o Overpass público.
            final shared = await _mapPoiController.fetchSharedPoisAround(
              center: targetCenter,
              knownGyms: _gyms,
            );
            if (!mounted) {
              return false;
            }
            if (shared != null && shared.isNotEmpty) {
              final visibleShared = _filterPoisByCurrentPlan(shared);
              _mergeMapPois(visibleShared, targetCenter);
              unawaited(
                _syncCrowdReportsForGyms(
                  _crowdSyncGymIds(
                    extraGymIds: visibleShared.map((poi) => poi.id),
                  ),
                ),
              );
            }
            if (shared != null &&
                shared.length >=
                    _GymMapPageState._minSharedGymsToSkipOverpass) {
              return true;
            }

            // 2) Área pouco mapeada: busca no Overpass/Nominatim; o resultado
            // vai para o backend e passa a valer para todos.
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
            final visiblePois = _filterPoisByCurrentPlan(poiList);
            _mergeMapPois(visiblePois, targetCenter);
            unawaited(_persistMapPoisToCache(poiList));
            if (visiblePois.isNotEmpty) {
              unawaited(
                _syncCrowdReportsForGyms(
                  _crowdSyncGymIds(
                    extraGymIds: visiblePois.map((poi) => poi.id),
                  ),
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

  void _scheduleMapPoiReload(
    LatLng center, {
    bool force = false,
    bool allowWithoutUserLocation = false,
  }) {
    if (!widget.showMap) {
      return;
    }
    if (!_ensurePlanCoverageForCenter(
      center,
      allowWithoutUserLocation: allowWithoutUserLocation,
    )) {
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
        await _loadMapPoisAround(
          targetCenter,
          allowWithoutUserLocation: allowWithoutUserLocation,
        );
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
    _lastMapGestureAt = DateTime.now();
    final center = camera.center;
    final allowWithoutUserLocation =
        !_hasNationwideCoverage &&
        _userLocation == null &&
        camera.zoom >= _GymMapPageState._minZoomForAreaPoiSearch;
    if (!_ensurePlanCoverageForCenter(
      center,
      notifyIfBlocked: _userLocation != null,
      allowWithoutUserLocation: allowWithoutUserLocation,
    )) {
      return;
    }
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
      unawaited(
        _restoreCachedMapPoisNear(
          center,
          allowWithoutUserLocation: allowWithoutUserLocation,
        ),
      );
    }

    _scheduleMapPoiReload(
      center,
      allowWithoutUserLocation: allowWithoutUserLocation,
    );
  }

  List<Gym> get _filteredGyms =>
      _applyLocationFilter(_filterGyms(_searchTerm), term: _searchTerm);

  bool _matchesQuickFilters({
    required Gym gym,
    required GymCrowdSnapshot snapshot,
  }) {
    if (_activeQuickFilters.contains(MapQuickFilter.openNow) &&
        !_isGymOpenNow(gym)) {
      return false;
    }
    // Sem lotação conhecida, a academia não entra em "Lotação baixa".
    final occupancy = snapshot.occupancyPercent;
    if (_activeQuickFilters.contains(MapQuickFilter.lowCrowd) &&
        (occupancy == null || occupancy > 45)) {
      return false;
    }
    if (_activeQuickFilters.contains(MapQuickFilter.withClasses) &&
        !_gymOffers(gym, GymAmenity.groupClasses)) {
      return false;
    }
    if (_activeQuickFilters.contains(MapQuickFilter.withCardio) &&
        !_gymOffers(gym, GymAmenity.cardio)) {
      return false;
    }
    if (_activeQuickFilters.contains(MapQuickFilter.withPool) &&
        !_gymOffers(gym, GymAmenity.pool)) {
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
        label: _t.filterOpenNow,
        icon: Icons.schedule_rounded,
        selected: _activeQuickFilters.contains(MapQuickFilter.openNow),
      ),
      QuickFilterChipData(
        id: 'low',
        label: _t.filterLowCrowd,
        icon: Icons.trending_down_rounded,
        selected: _activeQuickFilters.contains(MapQuickFilter.lowCrowd),
      ),
      QuickFilterChipData(
        id: 'classes',
        label: _t.filterClasses,
        icon: Icons.groups_2_outlined,
        selected: _activeQuickFilters.contains(MapQuickFilter.withClasses),
      ),
      QuickFilterChipData(
        id: 'cardio',
        label: _t.filterCardio,
        icon: Icons.directions_run_outlined,
        selected: _activeQuickFilters.contains(MapQuickFilter.withCardio),
      ),
      QuickFilterChipData(
        id: 'pool',
        label: _t.filterPool,
        icon: Icons.pool_outlined,
        selected: _activeQuickFilters.contains(MapQuickFilter.withPool),
      ),
      QuickFilterChipData(
        id: 'favorites',
        label: _t.filterFavorites,
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
      return _t.hoursOpenUntil(_hourTag24(closeHour));
    }
    if (now.hour < openHour) {
      return _t.hoursOpensAt(_hourTag24(openHour));
    }
    final nextWeekday =
        now.weekday == DateTime.sunday ? DateTime.monday : now.weekday + 1;
    final (nextOpenHour, _) = _heuristicOpenWindowForWeekday(nextWeekday);
    return _t.hoursOpensTomorrow(_hourTag24(nextOpenHour));
  }

  String _gymOpenHoursLabel(Gym gym) {
    final now = DateTime.now();
    final (openHour, closeHour) = _heuristicOpenWindowForWeekday(now.weekday);
    return _t.hoursToday(_hourTag24(openHour), _hourTag24(closeHour));
  }
}
