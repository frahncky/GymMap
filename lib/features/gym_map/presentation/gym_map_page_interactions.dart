part of 'gym_map_page.dart';

extension _GymMapPageInteractions on _GymMapPageState {
  /// Leva o ponto ao centro da área livre do mapa (fora da busca, dos
  /// filtros, do anúncio e do painel de baixo), não ao centro do widget.
  void _moveMapTo(LatLng point, double zoom) {
    if (!widget.showMap) {
      return;
    }
    final covered = _mapCoveredInsets();
    final shift =
        ((covered.top - covered.bottom) / 2)
            .clamp(-_mapAreaHeight / 4, _mapAreaHeight / 4)
            .toDouble();
    try {
      _mapController.move(point, zoom, offset: Offset(0, shift));
    } catch (_) {
      // Ignora quando o controlador ainda não está conectado ao widget do mapa.
    }
  }

  /// Altura do painel da academia selecionada, conforme o arrasto.
  double _selectedPanelHeight() {
    final availableHeight = _mapAreaHeight;
    final minPanelHeight = (availableHeight * 0.38).clamp(150.0, 220.0);
    final maxPanelHeight = (availableHeight - 132).clamp(
      minPanelHeight,
      math.max(minPanelHeight, availableHeight),
    );
    return (availableHeight * (_panelFlex / _GymMapPageState._layoutTotalFlex))
        .clamp(minPanelHeight, maxPanelHeight)
        .toDouble();
  }

  /// Quanto do mapa fica coberto em cima e embaixo.
  EdgeInsets _mapCoveredInsets() {
    double heightOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject();
      return box is RenderBox && box.hasSize ? box.size.height : 0;
    }

    final topOverlay = heightOf(_mapTopOverlayKey);
    final panel =
        _selectedGym != null
            ? _selectedPanelHeight()
            : heightOf(_mapHintCardKey);
    final routeOverlay = _routeGym != null ? heightOf(_routeOverlayKey) : 0.0;
    return EdgeInsets.only(
      top: topOverlay > 0 ? topOverlay + 12 : 0,
      bottom: math.max(
        panel > 0 ? panel + 10 : 0,
        routeOverlay > 0 ? routeOverlay + 28 : 0,
      ),
    );
  }

  /// Corrige somente orientação para norte (0 graus), sem alterar centro/zoom.
  void _resetNorthOrientation() {
    if (!widget.showMap) {
      return;
    }
    try {
      _mapController.rotate(0);
    } catch (_) {
      // Ignora quando o controlador ainda não está conectado ao widget do mapa.
    }
  }

  void _selectGym(Gym gym, {bool moveMap = true}) {
    _setStateIfMapVisible(() {
      _selectedGym = gym;
      _showMarkerDetails = true;
      _isPanelDragging = false;
      _panelFlex = _GymMapPageState._panelMinFlex;
      _panelDragOffset = 0;
      _reportPercent =
          _crowdService.snapshotFor(gym).occupancyPercent.toDouble();
    });

    if (moveMap) {
      _moveMapTo(gym.position, 15);
    }
    unawaited(_loadAmenityVotes(<String>[gym.id]));
    unawaited(
      _syncCrowdReportsForGyms(_crowdSyncGymIds(extraGymIds: [gym.id])),
    );
  }

  Gym? _findGymById(String gymId) {
    final normalizedGymId = gymId.trim();
    if (normalizedGymId.isEmpty) {
      return null;
    }
    for (final gym in _gyms) {
      if (gym.id.trim() == normalizedGymId) {
        return gym;
      }
    }
    final selectedGym = _selectedGym;
    if (selectedGym != null && selectedGym.id.trim() == normalizedGymId) {
      return selectedGym;
    }
    for (final poi in _mapPois) {
      if (poi.id.trim() == normalizedGymId) {
        return _gymFromPoi(poi);
      }
    }
    return null;
  }

  void _tryFocusGymById(String? gymId) {
    final normalizedGymId = gymId?.trim() ?? '';
    if (normalizedGymId.isEmpty) {
      return;
    }
    final gym = _findGymById(normalizedGymId);
    if (gym == null) {
      _pendingFocusGymId = normalizedGymId;
      return;
    }
    _pendingFocusGymId = null;
    _selectGym(gym);
  }

  void _tryResolvePendingFocusGymId() {
    final pendingGymId = _pendingFocusGymId;
    if (pendingGymId == null || pendingGymId.isEmpty) {
      return;
    }
    final gym = _findGymById(pendingGymId);
    if (gym == null) {
      return;
    }
    _pendingFocusGymId = null;
    _selectGym(gym);
  }

  void _handleMarkerTap(VoidCallback onTap) {
    _skipNextMapTapClear = true;
    onTap();
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      _skipNextMapTapClear = false;
    });
  }

  Gym _gymFromPoi(MapGymPoi poi) {
    return _generatedGymsByPoiId.putIfAbsent(poi.id, () {
      final seed = poi.id.codeUnits.fold<int>(0, (sum, code) => sum + code);
      final base = (35 + (seed % 35)).clamp(12, 88).toInt();
      final capacity = 70 + (seed % 140);
      return Gym(
        id: poi.id,
        name: poi.name,
        address: kMapGymAddress,
        position: poi.position,
        capacity: capacity,
        baseOccupancyPercent: base,
        amenities: const [
          kAmenityWeights,
          kAmenityCardio,
          kAmenityGroupClasses,
        ],
      );
    });
  }

  Gym? _nearestLowCrowdCandidate(LatLng userPoint) {
    Gym? bestGym;
    double? bestDistanceSquared;
    final seenGymIds = <String>{};

    void consider(Gym gym) {
      final gymId = gym.id.trim();
      if (gymId.isEmpty || !seenGymIds.add(gymId)) {
        return;
      }
      final snapshot = _crowdService.snapshotFor(gym);
      if (snapshot.occupancyPercent > 35 || !_isGymOpenNow(gym)) {
        return;
      }
      final distanceSquared = _distanceSquaredMeters(userPoint, gym.position);
      const maxDistanceMeters = 1800.0;
      if (distanceSquared > (maxDistanceMeters * maxDistanceMeters)) {
        return;
      }
      if (bestGym == null || distanceSquared < bestDistanceSquared!) {
        bestGym = gym;
        bestDistanceSquared = distanceSquared;
      }
    }

    for (final gym in _gyms) {
      consider(gym);
    }
    for (final poi in _mapPois) {
      consider(_gymFromPoi(poi));
    }
    return bestGym;
  }

  Future<void> _maybeNotifyNearbyLowCrowd(LatLng userPoint) async {
    if (_appLifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final candidate = _nearestLowCrowdCandidate(userPoint);
    if (candidate == null) {
      return;
    }
    final snapshot = _crowdService.snapshotFor(candidate);
    final distanceMeters = math.sqrt(
      _distanceSquaredMeters(userPoint, candidate.position),
    );
    await _contextualPushService.maybeNotifyLowCrowdNearby(
      gymId: candidate.id,
      gymName: candidate.name,
      occupancyPercent: snapshot.occupancyPercent,
      distanceMeters: distanceMeters,
    );
  }

  List<Gym> _comparisonGymsFor(Gym selectedGym) {
    final byId = <String, Gym>{
      for (final gym in _gyms) gym.id: gym,
      for (final poi in _mapPois) poi.id: _gymFromPoi(poi),
    };
    byId[selectedGym.id] = selectedGym;
    return byId.values.toList();
  }

  void _clearSelectedGym() {
    if (_selectedGym == null) {
      return;
    }
    _setStateIfMapVisible(() {
      _selectedGym = null;
      _isPanelDragging = false;
      _panelFlex = _GymMapPageState._panelMinFlex;
      _panelDragOffset = 0;
    });
  }

  void _onPanelDismissDragStart(DragStartDetails details) {
    _setStateIfMapVisible(() {
      _isPanelDragging = true;
    });
  }

  int _panelFlexStepForDrag(double deltaY) {
    if (deltaY.abs() < 2) {
      return 0;
    }
    return math.max(
      1,
      (deltaY.abs() * _GymMapPageState._panelFlexDragSensitivity).round(),
    );
  }

  void _onPanelDismissDragUpdate(DragUpdateDetails details) {
    final deltaY = details.delta.dy;

    if (deltaY < 0) {
      final step = _panelFlexStepForDrag(deltaY);
      if (step == 0 || _panelFlex >= _GymMapPageState._panelMaxFlex) {
        return;
      }
      _setStateIfMapVisible(() {
        _panelFlex = (_panelFlex + step).clamp(
          _GymMapPageState._panelMinFlex,
          _GymMapPageState._panelMaxFlex,
        );
        _panelDragOffset = 0;
      });
      return;
    }

    if (_panelFlex > _GymMapPageState._panelMinFlex) {
      final step = _panelFlexStepForDrag(deltaY);
      if (step == 0) {
        return;
      }
      _setStateIfMapVisible(() {
        _panelFlex = (_panelFlex - step).clamp(
          _GymMapPageState._panelMinFlex,
          _GymMapPageState._panelMaxFlex,
        );
      });
      return;
    }

    final next = (_panelDragOffset + deltaY).clamp(0, 280).toDouble();
    if ((next - _panelDragOffset).abs() <
        _GymMapPageState._panelDragPixelThreshold) {
      return;
    }
    _setStateIfMapVisible(() {
      _panelDragOffset = next;
    });
  }

  void _onPanelDismissDragEnd(DragEndDetails details) {
    if (_panelFlex > _GymMapPageState._panelMinFlex) {
      _setStateIfMapVisible(() {
        _isPanelDragging = false;
        _panelDragOffset = 0;
      });
      return;
    }

    final velocityY = details.velocity.pixelsPerSecond.dy;
    final shouldDismiss = _panelDragOffset >= 56 || velocityY > 350;
    if (shouldDismiss) {
      _clearSelectedGym();
      return;
    }
    _setStateIfMapVisible(() {
      _isPanelDragging = false;
      _panelDragOffset = 0;
    });
  }

  void _onPanelDismissDragCancel() {
    _setStateIfMapVisible(() {
      _isPanelDragging = false;
      _panelDragOffset = 0;
    });
  }

  Gym? _nearestGymTo(LatLng origin, List<Gym> gyms) {
    Gym? nearest;
    double? nearestDistanceSquared;
    for (final gym in gyms) {
      final distanceSquared = _distanceSquaredMeters(origin, gym.position);
      if (nearest == null || distanceSquared < nearestDistanceSquared!) {
        nearest = gym;
        nearestDistanceSquared = distanceSquared;
      }
    }
    return nearest;
  }

  Future<void> _reloadMapImages() async {
    if (!mounted || !widget.showMap) {
      return;
    }

    try {
      final config = createLocalImageConfiguration(context);
      await const AssetImage(
        'assets/brand/pin.png',
      ).evict(configuration: config);
    } catch (_) {
      // Ignora falhas de cache; o rebuild abaixo ainda forca novo carregamento.
    }

    if (!mounted) {
      return;
    }
    _setStateIfMapVisible(() {
      _mapVisualReloadTick++;
    });
  }

  void _onMapReady() {
    _isMapReady = true;
    if (!_hasTrackedMapReadyMetric) {
      _hasTrackedMapReadyMetric = true;
      unawaited(
        _metrics.trackEvent(
          'map_open',
          params: <String, Object?>{'origin': 'map_ready'},
        ),
      );
      unawaited(_metrics.trackScreen('mapa'));
    }
    final userPoint = _userLocation;
    if (userPoint != null) {
      _moveMapTo(userPoint, 14.8);
    }
    unawaited(_reloadMapImages());
    _scheduleMapPoiReload(_mapController.camera.center, force: true);
    _maybeStartOpeningSearchIntro();
    _maybeShowMapTutorialOverlay();
  }

  bool _isFavoriteGymId(String gymId) => _favoriteGymIds.contains(gymId.trim());

  void _toggleFavoriteGym(Gym gym) {
    final id = gym.id.trim();
    if (id.isEmpty) {
      return;
    }
    late final bool added;
    _setStateIfMapVisible(() {
      if (_favoriteGymIds.contains(id)) {
        _favoriteGymIds.remove(id);
        _favoriteGymNamesById.remove(id);
        added = false;
      } else {
        _favoriteGymIds.add(id);
        final name = gym.name.trim();
        if (name.isNotEmpty) {
          _favoriteGymNamesById[id] = name;
        }
        added = true;
      }
      final selectedGym = _selectedGym;
      if (!added &&
          _activeQuickFilters.contains(MapQuickFilter.favorites) &&
          selectedGym != null &&
          selectedGym.id == id) {
        _selectedGym = null;
      }
    });
    HapticFeedback.lightImpact();
    _showMapSnack(
      added ? _t.favoriteAdded(gym.name) : _t.favoriteRemoved(gym.name),
    );
    unawaited(
      _metrics.trackEvent(
        'favorite_toggle',
        params: <String, Object?>{'gymId': id, 'selected': added},
      ),
    );
    unawaited(_persistFavoriteGymIds());
  }

  void _maybeShowMapTutorialOverlay() {
    if (!_GymMapPageState._autoShowMapTutorialOnStartup) {
      return;
    }
    if (!_hasLoadedMapTutorialState ||
        _hasSeenMapTutorial ||
        _showMapTutorialOverlay ||
        !widget.showMap ||
        !_isMapReady ||
        !_hasCompletedInitialLocationAttempt ||
        _selectedGym != null) {
      return;
    }
    _setStateIfMapVisible(() {
      _showMapTutorialOverlay = true;
    });
  }

  void _highlightNearestGymFromTutorial() {
    final gyms = _filteredGyms;
    final origin = _userLocation ?? _GymMapPageState._fallbackMapCenter;
    final nearest = _nearestGymTo(origin, gyms);
    if (nearest == null) {
      _showMapSnack(_t.tutorialNoGymToHighlight);
      return;
    }
    unawaited(_dismissMapTutorialOverlay());
    _selectGym(nearest);
  }

  void _maybeStartOpeningSearchIntro() {
    if (!widget.showMap ||
        !_isMapReady ||
        !_hasCompletedInitialLocationAttempt ||
        _hasRunOpeningSearchIntro) {
      return;
    }
    if (_userLocation != null) {
      if (!_showMarkerDetails && mounted) {
        _setStateIfMapVisible(() {
          _showMarkerDetails = true;
        });
      }
      return;
    }
    _hasRunOpeningSearchIntro = true;
    unawaited(_runOpeningSearchIntro());
  }

  Future<void> _runOpeningSearchIntro() async {
    final gyms = _filteredGyms;
    if (gyms.isEmpty) {
      if (mounted) {
        _setStateIfMapVisible(() {
          _showMarkerDetails = true;
        });
      }
      return;
    }

    final origin = _userLocation ?? _GymMapPageState._fallbackMapCenter;
    final targetGym = _nearestGymTo(origin, gyms);
    if (targetGym == null) {
      if (mounted) {
        _setStateIfMapVisible(() {
          _showMarkerDetails = true;
        });
      }
      return;
    }

    final target = targetGym.position;
    final scanSteps = <({LatLng point, double zoom, int waitMs})>[
      (
        point: LatLng(target.latitude + 0.012, target.longitude - 0.016),
        zoom: 12.3,
        waitMs: 420,
      ),
      (
        point: LatLng(target.latitude - 0.010, target.longitude + 0.012),
        zoom: 13.1,
        waitMs: 400,
      ),
      (
        point: LatLng(target.latitude + 0.004, target.longitude + 0.005),
        zoom: 14.2,
        waitMs: 360,
      ),
      (point: target, zoom: 15.2, waitMs: 280),
    ];

    if (mounted) {
      _setStateIfMapVisible(() {
        _showMarkerDetails = false;
      });
    }

    for (final step in scanSteps) {
      if (!mounted) {
        return;
      }
      _moveMapTo(step.point, step.zoom);
      await Future<void>.delayed(Duration(milliseconds: step.waitMs));
    }

    if (!mounted) {
      return;
    }
    _setStateIfMapVisible(() {
      _showMarkerDetails = true;
    });
    _maybeShowMapTutorialOverlay();
  }
}
