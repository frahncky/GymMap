import 'dart:async';

import 'package:latlong2/latlong.dart';

import 'gym_map_logic.dart';

class GymMapPoiReloadController {
  GymMapPoiReloadController({
    required Duration reloadDebounceDelay,
    required double reloadMinDistanceMeters,
    required double pendingCenterMinDistanceMeters,
  }) : _reloadDebounceDelay = reloadDebounceDelay,
       _reloadMinDistanceMeters = reloadMinDistanceMeters,
       _pendingCenterMinDistanceMeters = pendingCenterMinDistanceMeters;

  final Duration _reloadDebounceDelay;
  final double _reloadMinDistanceMeters;
  final double _pendingCenterMinDistanceMeters;

  bool _isLoading = false;
  LatLng? _lastLoadCenter;
  LatLng? _pendingLoadCenter;
  Timer? _reloadDebounce;

  void dispose() {
    _reloadDebounce?.cancel();
  }

  void scheduleReload({
    required LatLng center,
    bool force = false,
    required Future<void> Function(LatLng center) onDebouncedReload,
  }) {
    final last = _lastLoadCenter;
    if (!force &&
        last != null &&
        GymMapLogic.isWithinDistanceMeters(
          center,
          last,
          _reloadMinDistanceMeters,
        )) {
      return;
    }
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(_reloadDebounceDelay, () {
      unawaited(onDebouncedReload(center));
    });
  }

  Future<void> loadWithQueue({
    required LatLng center,
    required Future<bool> Function(LatLng center) onLoad,
  }) async {
    _pendingLoadCenter = center;
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    LatLng? lastProcessedCenter = _lastLoadCenter;
    try {
      while (true) {
        final nextCenter = _pendingLoadCenter;
        _pendingLoadCenter = null;
        if (nextCenter == null) {
          break;
        }
        if (lastProcessedCenter != null &&
            GymMapLogic.isWithinDistanceMeters(
              nextCenter,
              lastProcessedCenter,
              _pendingCenterMinDistanceMeters,
            )) {
          continue;
        }
        final loaded = await onLoad(nextCenter);
        if (loaded) {
          _lastLoadCenter = nextCenter;
        }
        lastProcessedCenter = nextCenter;
      }
    } finally {
      _isLoading = false;
    }
  }
}
