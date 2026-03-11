part of 'gym_map_page.dart';

extension _GymMapPageLocation on _GymMapPageState {
  void _applyResolvedUserLocation(LatLng userPoint, {required bool moveMap}) {
    if (!mounted) {
      return;
    }

    _setStateIfMapVisible(() {
      _userLocation = userPoint;
      _mapSearchState.clearAnchors();
      final selectedGym = _selectedGym;
      if (selectedGym != null &&
          !_isWithinLocalRadius(selectedGym, userPoint)) {
        _selectedGym = null;
      }
    });

    if (moveMap) {
      _moveMapTo(userPoint, 14.8);
    }
    unawaited(_restoreCachedMapPoisNear(userPoint, force: true));
    unawaited(_loadMapPoisAround(userPoint));
  }

  bool _hasLocationPermission(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  LocationSettings _backgroundLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _GymMapPageState._backgroundLocationDistanceFilterMeters.round(),
        intervalDuration: _GymMapPageState._backgroundLocationInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'GymMap localização ativa',
          notificationText:
              'GymMap está atualizando sua localização em segundo plano.',
          enableWakeLock: true,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: _GymMapPageState._backgroundLocationDistanceFilterMeters.round(),
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.fitness,
      );
    }

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _GymMapPageState._backgroundLocationDistanceFilterMeters.round(),
    );
  }

  void _onBackgroundLocationUpdate(Position position) {
    final userPoint = LatLng(position.latitude, position.longitude);
    final previousLocation = _userLocation;
    if (previousLocation != null &&
        _isWithinDistanceMeters(
          previousLocation,
          userPoint,
          _GymMapPageState._backgroundLocationUiRefreshMinDistanceMeters,
        )) {
      return;
    }

    if (!mounted) {
      _userLocation = userPoint;
      return;
    }

    _setStateIfMapVisible(() {
      _userLocation = userPoint;
      final selectedGym = _selectedGym;
      if (selectedGym != null &&
          !_isWithinLocalRadius(selectedGym, userPoint)) {
        _selectedGym = null;
      }
    });

    unawaited(_restoreCachedMapPoisNear(userPoint));
    _scheduleMapPoiReload(userPoint);
    unawaited(_maybeNotifyNearbyLowCrowd(userPoint));
  }

  Future<void> _startBackgroundLocationStream() async {
    if (!widget.showMap ||
        _positionStreamSubscription != null ||
        _isStartingBackgroundLocationStream) {
      return;
    }

    _isStartingBackgroundLocationStream = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (!_hasLocationPermission(permission)) {
        return;
      }

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: _backgroundLocationSettings(),
      ).listen(
        _onBackgroundLocationUpdate,
        onError: (_) {},
        onDone: () {
          _positionStreamSubscription = null;
        },
      );
    } catch (_) {
      // Falha de stream nao deve interromper o restante da tela.
    } finally {
      _isStartingBackgroundLocationStream = false;
    }
  }

  Future<void> _stopBackgroundLocationStream() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  Future<void> _centerMapOnDeviceLocation({
    bool requestPermissionIfDenied = true,
    bool showDeniedSnack = true,
  }) async {
    if (!widget.showMap) {
      return;
    }

    final cachedPoint = _userLocation;
    var hasImmediateCenter = cachedPoint != null;
    if (cachedPoint != null) {
      _moveMapTo(cachedPoint, 14.8);
      unawaited(_restoreCachedMapPoisNear(cachedPoint, force: true));
    }

    if (_isLocating) {
      return;
    }

    _setStateIfMapVisible(() {
      _isLocating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!hasImmediateCenter && showDeniedSnack) {
          _showMapSnack('Ative o GPS para centralizar sua localização.');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!requestPermissionIfDenied) {
          return;
        }
        final shouldRequest = await _confirmLocationPermissionRequest();
        if (!shouldRequest) {
          if (!hasImmediateCenter && showDeniedSnack) {
            _showMapSnack(
              'Sem permissão de localização. Você pode ativar isso depois nas configurações.',
            );
          }
          return;
        }
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!hasImmediateCenter && showDeniedSnack) {
          if (permission == LocationPermission.deniedForever) {
            _showMapSnack(
              'Permissão de localização negada permanentemente. Ajuste nas configurações do aparelho.',
            );
          } else {
            _showMapSnack('Permissão de localização negada.');
          }
        }
        return;
      }

      unawaited(_startBackgroundLocationStream());

      if (!hasImmediateCenter) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          hasImmediateCenter = true;
          final lastKnownPoint = LatLng(
            lastKnown.latitude,
            lastKnown.longitude,
          );
          _applyResolvedUserLocation(lastKnownPoint, moveMap: true);
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 8));

      if (!mounted) {
        return;
      }

      final userPoint = LatLng(position.latitude, position.longitude);
      _applyResolvedUserLocation(userPoint, moveMap: true);
    } on TimeoutException {
      if (!hasImmediateCenter && showDeniedSnack) {
        _showMapSnack(
          'Tempo esgotado ao obter localização. Tente novamente em instantes.',
        );
      }
    } catch (_) {
      if (!hasImmediateCenter && showDeniedSnack) {
        _showMapSnack('Não foi possível obter sua localização no momento.');
      }
    } finally {
      if (mounted) {
        _setStateIfMapVisible(() {
          _isLocating = false;
        });
      }
      _hasCompletedInitialLocationAttempt = true;
      _maybeStartOpeningSearchIntro();
      _maybeShowMapTutorialOverlay();
    }
  }

  Future<bool> _confirmLocationPermissionRequest() async {
    if (!mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.location_on_outlined),
          title: const Text('Permitir localização?'),
          content: const Text(
            'Com a localização ativa, o GymMap encontra academias próximas automaticamente e calcula distância em tempo real.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Permitir'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
