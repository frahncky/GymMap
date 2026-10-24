part of 'gym_map_page.dart';

extension _GymMapPageSearch on _GymMapPageState {
  /// Atualiza apenas o texto da busca, sem recenter automatico do mapa.
  void _updateSearchTerm(String value) {
    final normalized = _normalizeSearchTerm(value);
    final shouldClearSearchLocation = _mapSearchState.shouldClearSearchLocation(
      normalized,
    );
    if (!shouldClearSearchLocation && value == _searchTerm) {
      return;
    }
    final filtered = _applyLocationFilter(_filterGyms(value), term: value);

    _setStateIfMapVisible(() {
      _searchTerm = value;
      if (shouldClearSearchLocation) {
        _mapSearchState.clearSearchLocation();
      }
      final selectedGym = _selectedGym;
      if (selectedGym != null &&
          filtered.every((gym) => gym.id != selectedGym.id)) {
        _selectedGym = null;
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _updateSearchTerm('');
  }

  bool _hasLocalTextMatch(String normalizedTerm) {
    if (normalizedTerm.isEmpty) {
      return false;
    }
    final hasGymMatch = _gyms.any(
      (gym) =>
          gym.name.toLowerCase().contains(normalizedTerm) ||
          gym.address.toLowerCase().contains(normalizedTerm),
    );
    if (hasGymMatch) {
      return true;
    }
    return _mapPois.any(
      (poi) => poi.name.toLowerCase().contains(normalizedTerm),
    );
  }

  void _submitSearch(String rawValue) {
    final query = rawValue.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    FocusScope.of(context).unfocus();
    unawaited(_resolveSearchLocation(query));
  }

  Future<void> _resolveSearchLocation(String rawQuery) async {
    if (!widget.showMap || _isResolvingSearchLocation) {
      return;
    }
    final query = rawQuery.trim();
    final normalized = _normalizeSearchTerm(query);
    if (normalized.isEmpty || _hasLocalTextMatch(normalized)) {
      return;
    }
    _setStateIfMapVisible(() {
      _isResolvingSearchLocation = true;
    });

    // Referência para preferir o lugar mais próximo: onde a pessoa está ou,
    // sem localização, o centro do mapa.
    LatLng? near = _userLocation;
    if (near == null) {
      try {
        near = _mapController.camera.center;
      } catch (_) {
        // Mapa ainda sem câmera: busca sem preferência de região.
      }
    }

    try {
      final uri = MapServicesConfig.nominatimSearchUri(
        PlaceSearch.queryParameters(
          query,
          near: near,
          language: _t.localeName == 'en' ? 'en' : 'pt-BR',
        ),
      );
      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'gymmap/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _showMapSnack(_t.searchFailed);
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        _showMapSnack(_t.searchNotFound);
        return;
      }

      final center = PlaceSearch.pickPosition(decoded, near: near);
      if (center == null) {
        _showMapSnack(_t.searchParseFailed);
        return;
      }

      if (!mounted || _normalizeSearchTerm(_searchTerm) != normalized) {
        return;
      }

      if (!_ensurePlanCoverageForCenter(center, notifyIfBlocked: true)) {
        return;
      }
      _setStateIfMapVisible(() {
        _mapSearchState.applyResolvedSearchLocation(
          normalizedQuery: normalized,
          center: center,
        );
        final selectedGym = _selectedGym;
        if (selectedGym != null && !_isWithinLocalRadius(selectedGym, center)) {
          _selectedGym = null;
        }
      });

      _moveMapTo(center, 13.8);
      unawaited(_restoreCachedMapPoisNear(center, force: true));
      unawaited(_loadMapPoisAround(center));
    } on TimeoutException {
      _showMapSnack(_t.searchTimeout);
    } catch (_) {
      _showMapSnack(_t.searchError);
    } finally {
      if (mounted) {
        _setStateIfMapVisible(() {
          _isResolvingSearchLocation = false;
        });
      }
    }
  }
}
