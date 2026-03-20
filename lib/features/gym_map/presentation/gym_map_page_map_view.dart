part of 'gym_map_page.dart';

extension _GymMapPageMapView on _GymMapPageState {
  Widget _buildMap(
    List<Gym> gyms,
    Map<String, GymCrowdSnapshot> snapshotsByGymId,
    List<MapGymPoi> mapPois,
  ) {
    const controlsRight = 14.0;
    final controlsTop = _mapControlsTopOffset(context);
    const controlsGap = 58.0;
    final markerBaseWidth = _markerBaseWidth(context);
    final markerBaseHeight = _markerBaseHeight(context);
    final totalMapMarkers = gyms.length + mapPois.length;
    final enableMarkerPulse = _shouldAnimateMarkerPulse(
      totalMarkers: totalMapMarkers,
    );

    if (!widget.showMap) {
      return const MapStatusCard(message: 'Mapa desativado no modo de teste');
    }

    if (!_hasCompletedInitialLocationAttempt) {
      return const MapStatusCard(message: 'Localizando você...', loading: true);
    }

    final markers = <Marker>[
      for (final gym in gyms)
        () {
          final markerScale = _markerScaleForPosition(gym.position);
          return Marker(
            point: gym.position,
            width: markerBaseWidth * markerScale,
            height: markerBaseHeight * markerScale,
            child: Transform.translate(
              offset: Offset(0, _markerBodyAnchorOffset(markerScale)),
              child: Transform.scale(
                scale: markerScale,
                alignment: Alignment.bottomCenter,
                child: GymMarkerBubble(
                  label: gym.name,
                  percent:
                      snapshotsByGymId[gym.id]?.occupancyPercent ??
                      gym.baseOccupancyPercent,
                  isOpenNow: _isGymOpenNow(gym),
                  isFavorite: _isFavoriteGymId(gym.id),
                  selected: gym.id == _selectedGym?.id,
                  revealDetails: _showMarkerDetails,
                  enablePulse: enableMarkerPulse,
                  onTap:
                      () => _handleMarkerTap(
                        () => _selectGym(gym, moveMap: false),
                      ),
                ),
              ),
            ),
          );
        }(),
      for (final poi in mapPois)
        _buildPoiMarker(
          poi,
          markerBaseWidth: markerBaseWidth,
          markerBaseHeight: markerBaseHeight,
          enablePulse: enableMarkerPulse,
        ),
    ];
    final userPoint = _userLocation;
    if (userPoint != null) {
      markers.add(
        Marker(
          point: userPoint,
          width: 34,
          height: 34,
          child: const UserLocationMarkerDot(),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                _selectedGym?.position ??
                _userLocation ??
                _GymMapPageState._fallbackMapCenter,
            initialZoom: 13.4,
            minZoom: 3,
            maxZoom: 18,
            initialRotation: 0,
            onMapReady: _onMapReady,
            onPositionChanged: _onMapPositionChanged,
            onTap: (_, __) {
              if (_skipNextMapTapClear) {
                _skipNextMapTapClear = false;
                return;
              }
              _clearSelectedGym();
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.gymmap',
            ),
            MarkerLayer(
              key: ValueKey<String>('marker-layer-$_mapVisualReloadTick'),
              markers: markers,
            ),
          ],
        ),

        Positioned(
          right: controlsRight,
          top: controlsTop,
          child: NorthResetButton(onTap: _resetNorthOrientation),
        ),
        Positioned(
          right: controlsRight,
          top: controlsTop + controlsGap,
          child: MyLocationButton(onTap: _centerMapOnDeviceLocation),
        ),
        Positioned(
          left: 12,
          top: controlsTop,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child:
                _isLoadingMapPois
                    ? const MapPoiLoadingBadge(
                      key: ValueKey<String>('map-poi-loading'),
                    )
                    : const SizedBox.shrink(
                      key: ValueKey<String>('map-poi-idle'),
                    ),
          ),
        ),
        if (_showMapTutorialOverlay)
          Positioned.fill(
            child: MapTutorialOverlay(
              onDismiss: () {
                unawaited(_dismissMapTutorialOverlay());
              },
              onFocusNearestGym: _highlightNearestGymFromTutorial,
            ),
          ),
      ],
    );
  }

  double _markerScaleForPosition(LatLng position) {
    final userPoint = _userLocation;
    if (userPoint == null) {
      return 1.0;
    }
    final distanceMeters = math.sqrt(
      _distanceSquaredMeters(userPoint, position),
    );
    const nearScale = 1.14;
    const farScale = 0.90;
    const maxDistanceKm = 12.0;
    final normalizedDistance = (distanceMeters / 1000).clamp(0, maxDistanceKm);
    final t = normalizedDistance / maxDistanceKm;
    return (nearScale + ((farScale - nearScale) * t)).clamp(
      farScale,
      nearScale,
    );
  }

  double _markerBodyAnchorOffset(double markerScale) {
    return _GymMapPageState._mapMarkerBodyAnchorOffset * markerScale;
  }

  double _mapControlsTopOffset(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final normalizedScale = textScale.clamp(1.0, 1.25).toDouble();
    final searchAndFilterHeight =
        (56 * normalizedScale) + 10 + (52 * normalizedScale);
    final adHeight = _isFreePlan ? (52 * normalizedScale) + 8 : 0.0;
    final computedOffset = 12 + searchAndFilterHeight + adHeight + 8;
    return computedOffset.clamp(132.0, 230.0).toDouble();
  }

  double _markerBaseWidth(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    if (shortestSide <= 360) {
      return 208;
    }
    if (shortestSide <= 420) {
      return 232;
    }
    if (shortestSide >= 720) {
      return 280;
    }
    return 250;
  }

  double _markerBaseHeight(BuildContext context) {
    return (_markerBaseWidth(context) * 0.72).clamp(154.0, 220.0).toDouble();
  }

  bool _shouldAnimateMarkerPulse({required int totalMarkers}) {
    if (!widget.isActive || !_showMarkerDetails) {
      return false;
    }
    if (totalMarkers > _GymMapPageState._maxMarkersForPulseAnimation) {
      return false;
    }
    final zoom = _isMapReady ? _mapController.camera.zoom : 13.4;
    return zoom >= 12.8;
  }

  Marker _buildPoiMarker(
    MapGymPoi poi, {
    required double markerBaseWidth,
    required double markerBaseHeight,
    required bool enablePulse,
  }) {
    final poiGym = _gymFromPoi(poi);
    final poiPercent = _crowdService.snapshotFor(poiGym).occupancyPercent;
    final markerScale = _markerScaleForPosition(poi.position);
    return Marker(
      key: ValueKey<String>('poi-marker-${poi.id}-$_mapVisualReloadTick'),
      point: poi.position,
      width: markerBaseWidth * markerScale,
      height: markerBaseHeight * markerScale,
      child: Transform.translate(
        offset: Offset(0, _markerBodyAnchorOffset(markerScale)),
        child: Transform.scale(
          scale: markerScale,
          alignment: Alignment.bottomCenter,
          child: GymMarkerBubble(
            label: poi.name,
            percent: poiPercent,
            isOpenNow: _isGymOpenNow(poiGym),
            isFavorite: _isFavoriteGymId(poiGym.id),
            selected: poiGym.id == _selectedGym?.id,
            revealDetails: _showMarkerDetails,
            enablePulse: enablePulse,
            onTap:
                () =>
                    _handleMarkerTap(() => _selectGym(poiGym, moveMap: false)),
          ),
        ),
      ),
    );
  }

  String? _distanceLabelFromUser(Gym gym) {
    final userPoint = _userLocation;
    if (userPoint == null) {
      return null;
    }
    final distanceMeters = math.sqrt(
      _distanceSquaredMeters(userPoint, gym.position),
    );
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m de você';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km de você';
  }

  Future<void> _openRouteForGym(Gym gym) async {
    _moveMapTo(gym.position, 15.6);
    final latitude = gym.position.latitude.toStringAsFixed(6);
    final longitude = gym.position.longitude.toStringAsFixed(6);
    final destination = '$latitude,$longitude';

    final androidUri = Uri.parse('google.navigation:q=$destination');
    final iosUri = Uri.parse(
      'comgooglemaps://?daddr=$destination&directionsmode=driving',
    );
    final webFallbackUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    });

    try {
      var launched = false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        launched = await launchUrl(
          androidUri,
          mode: LaunchMode.externalApplication,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        launched = await launchUrl(
          iosUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          launched = await launchUrl(
            webFallbackUri,
            mode: LaunchMode.externalApplication,
          );
        }
      } else {
        launched = await launchUrl(
          webFallbackUri,
          mode: LaunchMode.externalApplication,
        );
      }
      if (!launched) {
        _showMapSnack('Nao foi possivel abrir o Google Maps agora.');
      }
    } catch (_) {
      _showMapSnack('Nao foi possivel abrir o Google Maps agora.');
    }
  }

  Widget _buildSelectedGymPanel(Gym gym, GymCrowdSnapshot snapshot) {
    final historySampled =
        _hasHistoryInsights
            ? _sampledHistoryPoints(_crowdService.history24hFor(gym))
            : const <HourlyOccupancyPoint>[];
    final peakWindow =
        _hasProInsights ? _crowdService.peakWindowForToday(gym) : null;
    final comparison =
        _hasProInsights
            ? _crowdService
                .compareGymsByOccupancy(_comparisonGymsFor(gym), gym)
                .where((item) => item.gymName != gym.name)
                .take(4)
                .toList(growable: false)
            : const <GymComparisonInsight>[];
    final forecast =
        _hasEliteInsights
            ? _crowdService.forecastNextHoursFor(gym, hours: 6)
            : const <ForecastInsightPoint>[];
    final alerts =
        _hasEliteInsights
            ? _crowdService.personalizedAlertsFor(
              selectedGym: gym,
              gyms: _comparisonGymsFor(gym),
            )
            : const <String>[];

    return SelectedGymPanel(
      gym: gym,
      snapshot: snapshot,
      distanceFromUserLabel: _distanceLabelFromUser(gym),
      isOpenNow: _isGymOpenNow(gym),
      openStatusLabel: _gymOpenStatusLabel(gym),
      openHoursLabel: _gymOpenHoursLabel(gym),
      isFavorite: _isFavoriteGymId(gym.id),
      onToggleFavorite: () => _toggleFavoriteGym(gym),
      reportPercent: _reportPercent,
      onReportPercentChanged: (value) {
        _setStateIfMapVisible(() {
          _reportPercent = value;
        });
      },
      isSubmittingCrowdReport: _isSubmittingCrowdReport,
      onSubmitCrowdReport: _submitCrowdReport,
      onOpenRoute: () {
        unawaited(_openRouteForGym(gym));
      },
      onVerticalDragStart: _onPanelDismissDragStart,
      onVerticalDragUpdate: _onPanelDismissDragUpdate,
      onVerticalDragEnd: _onPanelDismissDragEnd,
      onVerticalDragCancel: _onPanelDismissDragCancel,
      hasHistoryInsights: _hasHistoryInsights,
      hasProInsights: _hasProInsights,
      hasEliteInsights: _hasEliteInsights,
      historySampled: historySampled,
      peakWindow: peakWindow,
      comparison: comparison,
      forecast: forecast,
      alerts: alerts,
    );
  }

  List<HourlyOccupancyPoint> _sampledHistoryPoints(
    List<HourlyOccupancyPoint> history,
  ) {
    if (history.isEmpty) {
      return const <HourlyOccupancyPoint>[];
    }
    final sampled = <HourlyOccupancyPoint>[];
    for (var i = 0; i < history.length; i += 3) {
      sampled.add(history[i]);
    }
    if (sampled.last.time != history.last.time) {
      sampled.add(history.last);
    }
    return List<HourlyOccupancyPoint>.unmodifiable(sampled);
  }
}
