part of 'gym_map_page.dart';

extension _GymMapPagePreferences on _GymMapPageState {
  Future<SharedPreferences> _prefsInstance() async {
    final cached = _prefsCache;
    if (cached != null) {
      return cached;
    }
    final inFlight = _prefsFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = SharedPreferences.getInstance();
    _prefsFuture = future;
    try {
      final prefs = await future;
      _prefsCache = prefs;
      return prefs;
    } catch (_) {
      _prefsFuture = null;
      rethrow;
    }
  }

  Future<bool> _shouldPromptInitialLocationPermission() async {
    try {
      final prefs = await _prefsInstance();
      return !(prefs.getBool(_GymMapPageState._initialLocationPromptDonePrefKey) ?? false);
    } catch (_) {
      return true;
    }
  }

  Future<void> _markInitialLocationPromptDone() async {
    try {
      final prefs = await _prefsInstance();
      await prefs.setBool(_GymMapPageState._initialLocationPromptDonePrefKey, true);
    } catch (_) {
      // Falha local nao deve bloquear o fluxo.
    }
  }

  Future<void> _loadDataSaverPreference() async {
    var enabled = false;
    try {
      final prefs = await _prefsInstance();
      enabled = prefs.getBool(_GymMapPageState._dataSaverPrefKey) ?? false;
    } catch (_) {
      // Falha local nao deve bloquear o mapa.
    }
    if (!mounted || _isDataSaverEnabled == enabled) {
      return;
    }
    _setStateIfMapVisible(() {
      _isDataSaverEnabled = enabled;
      if (!enabled) {
        _lastDataSaverPoiReloadCenter = null;
        _lastDataSaverPoiReloadAt = null;
        _lastDataSaverCrowdSyncAt = null;
      }
    });
  }

  Future<void> _loadQuickFiltersState() async {
    List<String> ids = const <String>[];
    try {
      final prefs = await _prefsInstance();
      ids = prefs.getStringList(_GymMapPageState._quickFiltersPrefKey) ?? const <String>[];
    } catch (_) {
      // Falha local nao impede uso dos filtros na sessao.
    }
    final restoredFilters = <MapQuickFilter>{};
    for (final idRaw in ids) {
      final id = idRaw.trim();
      if (id.isEmpty) {
        continue;
      }
      final filter = _quickFilterFromId(id);
      if (filter != null) {
        restoredFilters.add(filter);
      }
    }
    if (!mounted || _hasInteractedWithQuickFilters) {
      return;
    }
    _setStateIfMapVisible(() {
      _activeQuickFilters
        ..clear()
        ..addAll(restoredFilters);
    });
  }

  Future<void> _persistQuickFiltersState() async {
    try {
      final prefs = await _prefsInstance();
      final ids = _activeQuickFilters
        .map(_quickFilterId)
        .toList(growable: false)
        ..sort();
      await prefs.setStringList(_GymMapPageState._quickFiltersPrefKey, ids);
    } catch (_) {
      // Falha local de persistencia nao interrompe o fluxo.
    }
  }

  Future<void> _loadMapTutorialState() async {
    var hasSeen = false;
    try {
      final prefs = await _prefsInstance();
      hasSeen = prefs.getBool(_GymMapPageState._mapTutorialSeenPrefKey) ?? false;
    } catch (_) {
      // Falha de leitura local nao impede o app.
    }
    if (!mounted) {
      return;
    }
    _setStateIfMapVisible(() {
      _hasSeenMapTutorial = hasSeen;
      _hasLoadedMapTutorialState = true;
    });
    _maybeShowMapTutorialOverlay();
  }

  Future<void> _loadFavoriteGymIds() async {
    List<String> ids = const <String>[];
    final namesById = <String, String>{};
    try {
      final prefs = await _prefsInstance();
      ids = prefs.getStringList(_GymMapPageState._favoriteGymIdsPrefKey) ?? const <String>[];
      final rawNamesJson = prefs.getString(_GymMapPageState._favoriteGymNamesPrefKey);
      if (rawNamesJson != null && rawNamesJson.trim().isNotEmpty) {
        final decoded = jsonDecode(rawNamesJson);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final id = '${entry.key}'.trim();
            final name = '${entry.value}'.trim();
            if (id.isEmpty || name.isEmpty) {
              continue;
            }
            namesById[id] = name;
          }
        }
      }
    } catch (_) {
      // Falha local nao impede uso dos favoritos na sessao.
    }
    if (!mounted) {
      return;
    }
    var hasHydratedFavoriteNames = false;
    _setStateIfMapVisible(() {
      _favoriteGymIds
        ..clear()
        ..addAll(ids.map((id) => id.trim()).where((id) => id.isNotEmpty));
      _favoriteGymNamesById
        ..clear()
        ..addAll(namesById);
      hasHydratedFavoriteNames =
          _hydrateFavoriteGymNamesFromGyms(_gyms) ||
          _hydrateFavoriteGymNamesFromPois(_mapPois);
    });
    if (hasHydratedFavoriteNames) {
      unawaited(_persistFavoriteGymIds());
    }
  }

  Future<void> _persistFavoriteGymIds() async {
    try {
      final prefs = await _prefsInstance();
      final ids = _favoriteGymIds.toList(growable: false)..sort();
      await prefs.setStringList(_GymMapPageState._favoriteGymIdsPrefKey, ids);
      final namesById = <String, String>{};
      for (final id in ids) {
        final name = _favoriteGymNamesById[id]?.trim();
        if (name == null || name.isEmpty) {
          continue;
        }
        namesById[id] = name;
      }
      if (namesById.isEmpty) {
        await prefs.remove(_GymMapPageState._favoriteGymNamesPrefKey);
      } else {
        await prefs.setString(
          _GymMapPageState._favoriteGymNamesPrefKey,
          jsonEncode(namesById),
        );
      }
    } catch (_) {
      // Falha local de persistencia nao interrompe o fluxo.
    }
  }

  Future<void> _loadCommunityPoints() async {
    var points = 0;
    try {
      final prefs = await _prefsInstance();
      points = prefs.getInt(_GymMapPageState._communityPointsPrefKey) ?? 0;
    } catch (_) {
      // Falha local nao bloqueia uso.
    }
    if (!mounted) {
      return;
    }
    _setStateIfMapVisible(() {
      _communityPoints = points.clamp(0, 1000000);
    });
  }

  Future<void> _persistCommunityPoints() async {
    try {
      final prefs = await _prefsInstance();
      await prefs.setInt(_GymMapPageState._communityPointsPrefKey, _communityPoints);
    } catch (_) {
      // Falha local nao bloqueia uso.
    }
  }

  Future<void> _dismissMapTutorialOverlay({bool persist = true}) async {
    if (mounted && _showMapTutorialOverlay) {
      _setStateIfMapVisible(() {
        _showMapTutorialOverlay = false;
      });
    }
    if (!persist || _hasSeenMapTutorial) {
      return;
    }
    _hasSeenMapTutorial = true;
    try {
      final prefs = await _prefsInstance();
      await prefs.setBool(_GymMapPageState._mapTutorialSeenPrefKey, true);
    } catch (_) {
      // Falha de escrita local nao interrompe o fluxo.
    }
  }
}
