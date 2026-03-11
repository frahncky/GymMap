import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/app_metrics_service.dart';
import '../data/collaborative_crowd_service.dart';
import '../data/contextual_push_notification_service.dart';
import '../data/crowd_report_remote_service.dart';
import '../data/plan_subscription_service.dart';
import '../domain/gym_models.dart';
import '../domain/plan_insight_models.dart';
import 'gym_map_colors.dart';
import 'gym_map_helpers.dart';
import 'gym_map_logic.dart';
import 'gym_map_poi_controller.dart';
import 'gym_map_poi_reload_controller.dart';
import 'gym_map_search_state_controller.dart';
import 'widgets/gym_marker_bubble.dart';
import 'widgets/gym_page_sections.dart';
import 'widgets/map_controls.dart';
import 'widgets/selected_gym_panel.dart';

part 'gym_map_page_models.dart';

class GymMapPage extends StatefulWidget {
  const GymMapPage({
    super.key,
    required this.showMap,
    required this.isActive,
    this.onActivePlanChanged,
    this.focusGymId,
    this.focusRequestToken = 0,
  });

  final bool showMap;
  final bool isActive;
  final ValueChanged<AppPlanTier>? onActivePlanChanged;
  final String? focusGymId;
  final int focusRequestToken;

  @override
  State<GymMapPage> createState() => _GymMapPageState();
}


class _GymMapPageState extends State<GymMapPage> with WidgetsBindingObserver {
  static const LatLng _fallbackMapCenter = LatLng(-23.5615, -46.6560);
  static const String _localReporterId = 'local-device-user';
  static const String _mapTutorialSeenPrefKey = 'gymmap_map_tutorial_seen_v1';
  static const String _initialLocationPromptDonePrefKey =
      'gymmap_initial_location_prompt_done_v1';
  static const String _favoriteGymIdsPrefKey = 'gymmap_favorite_gym_ids_v1';
  static const String _favoriteGymNamesPrefKey = 'gymmap_favorite_gym_names_v1';
  static const String _communityPointsPrefKey = 'gymmap_community_points_v1';
  static const String _dataSaverPrefKey = 'gymmap_pref_data_saver_v1';
  static const String _quickFiltersPrefKey = 'gymmap_quick_filters_v1';
  static const bool _autoShowMapTutorialOnStartup = false;
  static const double _defaultCoverageRadiusMeters = 50000;
  static const double _eliteCoverageRadiusMeters = 6000000;
  static const double _mapPoiReloadMinDistanceMeters = 1800;
  static const double _mapBrowseAnchorUpdateMinDistanceMeters = 220;
  static const Duration _mapPoiReloadDebounceDelay = Duration(
    milliseconds: 450,
  );
  static const Duration _mapBrowseCenterUiDebounceDelay = Duration(
    milliseconds: 180,
  );
  static const Duration _dataSaverPoiReloadCooldown = Duration(seconds: 16);
  static const Duration _dataSaverCrowdSyncCooldown = Duration(minutes: 3);
  static const Duration _backgroundLocationInterval = Duration(seconds: 25);
  static const double _backgroundLocationDistanceFilterMeters = 35;
  static const double _backgroundLocationUiRefreshMinDistanceMeters = 25;
  static const double _dataSaverPoiReloadMinDistanceMeters = 3200;
  static const double _mapMarkerBodyAnchorOffset = -6;
  static const int _maxMapPoiMarkers = 90;
  static const int _maxMapPoiMarkersZoomedOut = 48;
  static const int _layoutTotalFlex = 100;
  static const int _panelMinFlex = 42;
  static const int _panelMaxFlex = 66;
  static const double _panelFlexDragSensitivity = 0.28;
  static const double _panelDragPixelThreshold = 3;
  static const String _smartPlayProductId = String.fromEnvironment(
    'PLAN_PLAY_PRODUCT_ID_SMART',
    defaultValue: 'smart_mensal',
  );
  static const String _proPlayProductId = String.fromEnvironment(
    'PLAN_PLAY_PRODUCT_ID_PRO',
    defaultValue: 'pro_mensal',
  );
  static const String _elitePlayProductId = String.fromEnvironment(
    'PLAN_PLAY_PRODUCT_ID_ELITE',
    defaultValue: 'elite_mensal',
  );
  static const String _paywallPromoMessage = String.fromEnvironment(
    'PAYWALL_PROMO_MESSAGE',
    defaultValue: '',
  );
  static const String _paywallPromoDeadline = String.fromEnvironment(
    'PAYWALL_PROMO_DEADLINE',
    defaultValue: '',
  );
  static const Map<AppPlanTier, String> _planProductIds = {
    AppPlanTier.smart: _smartPlayProductId,
    AppPlanTier.pro: _proPlayProductId,
    AppPlanTier.elite: _elitePlayProductId,
  };

  final TextEditingController _searchController = TextEditingController();
  final Set<MapQuickFilter> _activeQuickFilters = <MapQuickFilter>{};

  // Controlador do mapa raster (flutter_map).
  final MapController _mapController = MapController();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Serviço que agrega relatos colaborativos de lotação.
  final CollaborativeCrowdService _crowdService =
      CollaborativeCrowdService.withSeedData();
  final GymMapPoiController _mapPoiController = GymMapPoiController();
  CrowdReportRemoteService? _crowdReportRemoteService;
  bool _isSyncingCrowdReports = false;
  bool _isSubmittingCrowdReport = false;
  int _communityPoints = 0;
  final Set<String> _favoriteGymIds = <String>{};
  final Map<String, String> _favoriteGymNamesById = <String, String>{};
  final Set<String> _pendingCrowdSyncGymIds = <String>{};
  final GymMapSearchStateController _mapSearchState =
      GymMapSearchStateController();
  final GymMapPoiReloadController _mapPoiReloadController =
      GymMapPoiReloadController(
        reloadDebounceDelay: _mapPoiReloadDebounceDelay,
        reloadMinDistanceMeters: _mapPoiReloadMinDistanceMeters,
        pendingCenterMinDistanceMeters: _mapBrowseAnchorUpdateMinDistanceMeters,
      );

  // Lista base de academias exibidas no app.
  final List<Gym> _gyms = DemoGyms.all;

  // Academia selecionada no mapa para abrir a aba inferior.
  Gym? _selectedGym;

  // Valor de lotação usado no slider de envio de relato.
  double _reportPercent = 50;

  // Coordenada atual do usuário (quando permitida).
  LatLng? _userLocation;

  // Estado de carregamento da geolocalização para bloquear clique repetido.
  bool _isLocating = false;
  bool _isMapReady = false;
  bool _hasCompletedInitialLocationAttempt = false;
  bool _hasRunOpeningSearchIntro = false;
  bool _showMarkerDetails = true;
  bool _skipNextMapTapClear = false;
  bool _isPanelDragging = false;
  int _panelFlex = _panelMinFlex;
  double _panelDragOffset = 0;
  List<MapGymPoi> _mapPois = const [];
  bool _isLoadingMapPois = false;
  int _mapPoiLoadingRequests = 0;
  bool _hasTriggeredInitialMapBootstrap = false;
  final Map<String, Gym> _generatedGymsByPoiId = <String, Gym>{};
  bool _isResolvingSearchLocation = false;
  bool _hasLoadedMapTutorialState = false;
  bool _hasSeenMapTutorial = false;
  bool _showMapTutorialOverlay = false;
  bool _hasInteractedWithQuickFilters = false;
  bool _isDataSaverEnabled = false;
  bool _showContributionCelebration = false;
  int _contributionCelebrationTick = 0;
  LatLng? _lastDataSaverPoiReloadCenter;
  DateTime? _lastDataSaverPoiReloadAt;
  DateTime? _lastDataSaverCrowdSyncAt;
  Timer? _mapBrowseCenterUiDebounce;
  Timer? _contributionCelebrationTimer;
  Timer? _planSyncTimer;
  bool _isUiRefreshQueued = false;
  StreamSubscription<List<PurchaseDetails>>? _purchaseStreamSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isStartingBackgroundLocationStream = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  final ContextualPushNotificationService _contextualPushService =
      ContextualPushNotificationService();

  // Plano atual do usuário para liberar informações e propaganda.
  AppPlanTier _activePlan = AppPlanTier.free;
  DateTime? _activePlanExpiresAtUtc;
  PlanSubscriptionService? _planSubscriptionService;
  bool _isLoadingPlanSubscription = true;
  bool _isStartingStoreCheckout = false;
  bool _isPlayStoreAvailable = false;
  bool _isLoadingPlayProducts = false;
  List<ProductDetails> _playProducts = const <ProductDetails>[];
  final Set<String> _processingPlayPurchases = <String>{};
  final Set<String> _purchaseSuccessNotificationKeys = <String>{};
  bool _isPlanAuthBusy = false;
  String? _lastPlanExpiryWarningKey;
  int _mapVisualReloadTick = 0;
  bool _hasTrackedMapReadyMetric = false;
  String? _pendingFocusGymId;
  final AppMetricsService _metrics = AppMetricsService.instance;

  String get _searchTerm => _mapSearchState.searchTerm;
  set _searchTerm(String value) => _mapSearchState.searchTerm = value;

  LatLng? get _searchLocationCenter => _mapSearchState.searchLocationCenter;

  String? get _searchLocationQuery => _mapSearchState.searchLocationQuery;

  LatLng? get _manualBrowseCenter => _mapSearchState.manualBrowseCenter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadMapTutorialState());
    unawaited(_loadFavoriteGymIds());
    unawaited(_loadCommunityPoints());
    unawaited(_loadDataSaverPreference());
    unawaited(_loadQuickFiltersState());
    unawaited(_initializeGymLocationCache());
    unawaited(_initializeCrowdRemoteService());
    unawaited(_initializePlanSubscription());
    unawaited(_initializePlayStoreBilling());
    unawaited(_contextualPushService.initialize());
    if ((widget.focusGymId?.trim().isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _tryFocusGymById(widget.focusGymId);
      });
    }
    if (widget.showMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasTriggeredInitialMapBootstrap) {
          return;
        }
        _hasTriggeredInitialMapBootstrap = true;
        unawaited(_runInitialMapBootstrap());
      });
    }
  }

  Future<void> _runInitialMapBootstrap() async {
    final bootstrapUserLocation = await _resolveBootstrapUserLocation();
    final initialCenter = bootstrapUserLocation ?? _fallbackMapCenter;
    final initialZoom = bootstrapUserLocation != null ? 14.8 : 13.4;

    if (mounted) {
      setState(() {
        _hasCompletedInitialLocationAttempt = true;
        if (bootstrapUserLocation != null) {
          _userLocation = bootstrapUserLocation;
        }
      });
    } else {
      _hasCompletedInitialLocationAttempt = true;
      if (bootstrapUserLocation != null) {
        _userLocation = bootstrapUserLocation;
      }
    }
    _moveMapTo(initialCenter, initialZoom);
    unawaited(_restoreCachedMapPoisNear(initialCenter, force: true));
    unawaited(_loadMapPoisAround(initialCenter));
    unawaited(_startBackgroundLocationStream());

    await _resolveInitialLocationFlow();

    _maybeStartOpeningSearchIntro();
    _maybeShowMapTutorialOverlay();
  }

  Future<LatLng?> _resolveBootstrapUserLocation() async {
    final cached = _userLocation;
    if (cached != null) {
      return cached;
    }

    try {
      final permission = await Geolocator.checkPermission();
      if (!_hasLocationPermission(permission)) {
        return null;
      }
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown == null) {
        return null;
      }
      return LatLng(lastKnown.latitude, lastKnown.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _resolveInitialLocationFlow() async {
    final shouldPrompt = await _shouldPromptInitialLocationPermission();
    if (!mounted) {
      return;
    }

    if (shouldPrompt) {
      await _markInitialLocationPromptDone();
      await _centerMapOnDeviceLocation(
        requestPermissionIfDenied: true,
        showDeniedSnack: true,
      );
      return;
    }

    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
    } catch (_) {
      return;
    }
    if (!_hasLocationPermission(permission)) {
      return;
    }

    await _centerMapOnDeviceLocation(
      requestPermissionIfDenied: false,
      showDeniedSnack: false,
    );
  }

  Future<bool> _shouldPromptInitialLocationPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_initialLocationPromptDonePrefKey) ?? false);
    } catch (_) {
      return true;
    }
  }

  Future<void> _markInitialLocationPromptDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_initialLocationPromptDonePrefKey, true);
    } catch (_) {
      // Falha local não deve bloquear o fluxo.
    }
  }

  @override
  void didUpdateWidget(covariant GymMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showMap && widget.showMap) {
      unawaited(_startBackgroundLocationStream());
    } else if (oldWidget.showMap && !widget.showMap) {
      unawaited(_stopBackgroundLocationStream());
    }
    if (!oldWidget.isActive && widget.isActive) {
      unawaited(_loadCommunityPoints());
      unawaited(_startBackgroundLocationStream());
      _tryResolvePendingFocusGymId();
    }
    if (oldWidget.focusRequestToken != widget.focusRequestToken) {
      _tryFocusGymById(widget.focusGymId);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadDataSaverPreference());
      unawaited(_syncPlanFromStorage(showExpiryNotice: false));
      unawaited(_reloadMapImages());
      unawaited(_refreshGymLocationCacheFromRemote());
      unawaited(_syncCrowdReportsForCurrentContext());
      unawaited(_startBackgroundLocationStream());
    } else if (state == AppLifecycleState.detached) {
      unawaited(_stopBackgroundLocationStream());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapBrowseCenterUiDebounce?.cancel();
    _contributionCelebrationTimer?.cancel();
    _planSyncTimer?.cancel();
    _purchaseStreamSubscription?.cancel();
    _positionStreamSubscription?.cancel();
    _mapPoiReloadController.dispose();
    _mapPoiController.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setStateIfMapVisible(VoidCallback updateState) {
    if (!mounted || !widget.isActive) {
      updateState();
      return;
    }
    setState(updateState);
  }

  void _queueUiRefreshIfMapVisible() {
    if (!mounted || !widget.isActive || _isUiRefreshQueued) {
      return;
    }
    _isUiRefreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUiRefreshQueued = false;
      if (!mounted || !widget.isActive) {
        return;
      }
      setState(() {});
    });
  }

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
          ? _eliteCoverageRadiusMeters
          : _defaultCoverageRadiusMeters;

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
    mapCenter: _isMapReady ? _mapController.camera.center : _fallbackMapCenter,
    zoom: _isMapReady ? _mapController.camera.zoom : 13.4,
    maxMapPoiMarkers: _maxMapPoiMarkers,
    maxMapPoiMarkersZoomedOut: _maxMapPoiMarkersZoomedOut,
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

  Future<void> _loadDataSaverPreference() async {
    var enabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_dataSaverPrefKey) ?? false;
    } catch (_) {
      // Falha local não deve bloquear o mapa.
    }
    if (!mounted || _isDataSaverEnabled == enabled) {
      return;
    }
    setState(() {
      _isDataSaverEnabled = enabled;
      if (!enabled) {
        _lastDataSaverPoiReloadCenter = null;
        _lastDataSaverPoiReloadAt = null;
        _lastDataSaverCrowdSyncAt = null;
      }
    });
  }

  Future<void> _syncCrowdReportsForCurrentContext() async {
    if (_isDataSaverEnabled) {
      final now = DateTime.now();
      final lastSync = _lastDataSaverCrowdSyncAt;
      if (lastSync != null &&
          now.difference(lastSync) < _dataSaverCrowdSyncCooldown) {
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
        _fallbackMapCenter;
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
      limit: _maxMapPoiMarkers,
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
          now.difference(lastReloadAt) < _dataSaverPoiReloadCooldown) {
        return;
      }
      if (lastCenter != null &&
          _isWithinDistanceMeters(
            center,
            lastCenter,
            _dataSaverPoiReloadMinDistanceMeters,
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
      minDistanceMeters: _mapBrowseAnchorUpdateMinDistanceMeters,
    );

    if (shouldUpdate) {
      _mapBrowseCenterUiDebounce?.cancel();
      _mapBrowseCenterUiDebounce = Timer(_mapBrowseCenterUiDebounceDelay, () {
        if (!mounted) {
          return;
        }
        _queueUiRefreshIfMapVisible();
      });
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

  Future<void> _loadQuickFiltersState() async {
    List<String> ids = const <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      ids = prefs.getStringList(_quickFiltersPrefKey) ?? const <String>[];
    } catch (_) {
      // Falha local não impede o uso dos filtros na sessão atual.
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
    setState(() {
      _activeQuickFilters
        ..clear()
        ..addAll(restoredFilters);
    });
  }

  Future<void> _persistQuickFiltersState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _activeQuickFilters
        .map(_quickFilterId)
        .toList(growable: false)..sort();
      await prefs.setStringList(_quickFiltersPrefKey, ids);
    } catch (_) {
      // Falha local de persistência não deve interromper fluxo.
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
    setState(() {
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
    setState(() {
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

  bool _samePoiList(List<MapGymPoi> left, List<MapGymPoi> right) {
    return GymMapLogic.samePoiList(left, right);
  }

  void _setMapPoisIfChanged(List<MapGymPoi> nextPois) {
    if (!mounted || _samePoiList(_mapPois, nextPois)) {
      return;
    }
    var hasHydratedFavoriteNames = false;
    _setStateIfMapVisible(() {
      _mapPois = List<MapGymPoi>.unmodifiable(nextPois);
      hasHydratedFavoriteNames = _hydrateFavoriteGymNamesFromPois(nextPois);
    });
    _tryResolvePendingFocusGymId();
    if (hasHydratedFavoriteNames) {
      unawaited(_persistFavoriteGymIds());
    }
    final userPoint = _userLocation;
    if (userPoint != null) {
      unawaited(_maybeNotifyNearbyLowCrowd(userPoint));
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

    setState(() {
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

    setState(() {
      _isResolvingSearchLocation = true;
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
        'accept-language': 'pt-BR',
      });
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
        _showMapSnack('Não foi possível buscar esta localização agora.');
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
        _showMapSnack(
          'Local não encontrado. Tente bairro, cidade ou endereço.',
        );
        return;
      }

      final firstResult = decoded.first as Map;
      final latitude = double.tryParse('${firstResult['lat'] ?? ''}');
      final longitude = double.tryParse('${firstResult['lon'] ?? ''}');
      if (latitude == null || longitude == null) {
        _showMapSnack('Não foi possível interpretar essa localização.');
        return;
      }

      if (!mounted || _normalizeSearchTerm(_searchTerm) != normalized) {
        return;
      }

      final center = LatLng(latitude, longitude);
      setState(() {
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
      unawaited(_loadMapPoisAround(center));
    } on TimeoutException {
      _showMapSnack('Tempo esgotado ao buscar essa localização.');
    } catch (_) {
      _showMapSnack('Não foi possível buscar essa localização.');
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingSearchLocation = false;
        });
      }
    }
  }

  void _moveMapTo(LatLng point, double zoom) {
    if (!widget.showMap) {
      return;
    }
    try {
      _mapController.move(point, zoom);
    } catch (_) {
      // Ignora quando o controlador ainda não está conectado ao widget do mapa.
    }
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
    setState(() {
      _selectedGym = gym;
      _showMarkerDetails = true;
      _isPanelDragging = false;
      _panelFlex = _panelMinFlex;
      _panelDragOffset = 0;
      _reportPercent =
          _crowdService.snapshotFor(gym).occupancyPercent.toDouble();
    });

    if (moveMap) {
      _moveMapTo(gym.position, 15);
    }
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
        address: 'Academia encontrada no mapa',
        position: poi.position,
        capacity: capacity,
        baseOccupancyPercent: base,
        amenities: const ['Musculação', 'Cardio', 'Aulas coletivas'],
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
    setState(() {
      _selectedGym = null;
      _isPanelDragging = false;
      _panelFlex = _panelMinFlex;
      _panelDragOffset = 0;
    });
  }

  void _onPanelDismissDragStart(DragStartDetails details) {
    setState(() {
      _isPanelDragging = true;
    });
  }

  int _panelFlexStepForDrag(double deltaY) {
    if (deltaY.abs() < 2) {
      return 0;
    }
    return math.max(1, (deltaY.abs() * _panelFlexDragSensitivity).round());
  }

  void _onPanelDismissDragUpdate(DragUpdateDetails details) {
    final deltaY = details.delta.dy;

    if (deltaY < 0) {
      final step = _panelFlexStepForDrag(deltaY);
      if (step == 0 || _panelFlex >= _panelMaxFlex) {
        return;
      }
      setState(() {
        _panelFlex = (_panelFlex + step).clamp(_panelMinFlex, _panelMaxFlex);
        _panelDragOffset = 0;
      });
      return;
    }

    if (_panelFlex > _panelMinFlex) {
      final step = _panelFlexStepForDrag(deltaY);
      if (step == 0) {
        return;
      }
      setState(() {
        _panelFlex = (_panelFlex - step).clamp(_panelMinFlex, _panelMaxFlex);
      });
      return;
    }

    final next = (_panelDragOffset + deltaY).clamp(0, 280).toDouble();
    if ((next - _panelDragOffset).abs() < _panelDragPixelThreshold) {
      return;
    }
    setState(() {
      _panelDragOffset = next;
    });
  }

  void _onPanelDismissDragEnd(DragEndDetails details) {
    if (_panelFlex > _panelMinFlex) {
      setState(() {
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
    setState(() {
      _isPanelDragging = false;
      _panelDragOffset = 0;
    });
  }

  void _onPanelDismissDragCancel() {
    setState(() {
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
        'assets/logo/pinGym.png',
      ).evict(configuration: config);
    } catch (_) {
      // Ignora falhas de cache; o rebuild abaixo ainda forca novo carregamento.
    }

    if (!mounted) {
      return;
    }
    setState(() {
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

  Future<void> _loadMapTutorialState() async {
    bool hasSeen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      hasSeen = prefs.getBool(_mapTutorialSeenPrefKey) ?? false;
    } catch (_) {
      // Falha de leitura local não impede o app.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _hasSeenMapTutorial = hasSeen;
      _hasLoadedMapTutorialState = true;
    });
    _maybeShowMapTutorialOverlay();
  }

  Future<void> _loadFavoriteGymIds() async {
    List<String> ids = const <String>[];
    final namesById = <String, String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      ids = prefs.getStringList(_favoriteGymIdsPrefKey) ?? const <String>[];
      final rawNamesJson = prefs.getString(_favoriteGymNamesPrefKey);
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
      // Falha local não impede uso dos favoritos na sessão atual.
    }
    if (!mounted) {
      return;
    }
    var hasHydratedFavoriteNames = false;
    setState(() {
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
      final prefs = await SharedPreferences.getInstance();
      final ids = _favoriteGymIds.toList(growable: false)..sort();
      await prefs.setStringList(_favoriteGymIdsPrefKey, ids);
      final namesById = <String, String>{};
      for (final id in ids) {
        final name = _favoriteGymNamesById[id]?.trim();
        if (name == null || name.isEmpty) {
          continue;
        }
        namesById[id] = name;
      }
      if (namesById.isEmpty) {
        await prefs.remove(_favoriteGymNamesPrefKey);
      } else {
        await prefs.setString(_favoriteGymNamesPrefKey, jsonEncode(namesById));
      }
    } catch (_) {
      // Falha local de persistência não deve interromper fluxo.
    }
  }

  Future<void> _loadCommunityPoints() async {
    var points = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      points = prefs.getInt(_communityPointsPrefKey) ?? 0;
    } catch (_) {
      // Falha local não bloqueia uso.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _communityPoints = points.clamp(0, 1000000);
    });
  }

  Future<void> _persistCommunityPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_communityPointsPrefKey, _communityPoints);
    } catch (_) {
      // Falha local não bloqueia uso.
    }
  }

  bool _isFavoriteGymId(String gymId) => _favoriteGymIds.contains(gymId.trim());

  void _toggleFavoriteGym(Gym gym) {
    final id = gym.id.trim();
    if (id.isEmpty) {
      return;
    }
    late final bool added;
    setState(() {
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
      added
          ? '${gym.name} adicionada aos favoritos.'
          : '${gym.name} removida dos favoritos.',
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
    if (!_autoShowMapTutorialOnStartup) {
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
    setState(() {
      _showMapTutorialOverlay = true;
    });
  }

  Future<void> _dismissMapTutorialOverlay({bool persist = true}) async {
    if (mounted && _showMapTutorialOverlay) {
      setState(() {
        _showMapTutorialOverlay = false;
      });
    }
    if (!persist || _hasSeenMapTutorial) {
      return;
    }
    _hasSeenMapTutorial = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mapTutorialSeenPrefKey, true);
    } catch (_) {
      // Falha de escrita local não interrompe o fluxo.
    }
  }

  void _highlightNearestGymFromTutorial() {
    final gyms = _filteredGyms;
    final origin = _userLocation ?? _fallbackMapCenter;
    final nearest = _nearestGymTo(origin, gyms);
    if (nearest == null) {
      _showMapSnack('Nenhuma academia disponível para destacar agora.');
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
        setState(() {
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
        setState(() {
          _showMarkerDetails = true;
        });
      }
      return;
    }

    final origin = _userLocation ?? _fallbackMapCenter;
    final targetGym = _nearestGymTo(origin, gyms);
    if (targetGym == null) {
      if (mounted) {
        setState(() {
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
      setState(() {
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
    setState(() {
      _showMarkerDetails = true;
    });
    _maybeShowMapTutorialOverlay();
  }

  String _resolveCrowdReporterId() {
    final remoteService = _crowdReportRemoteService;
    if (remoteService != null) {
      remoteService.refreshAuthFromStorage();
      final remoteUserId = remoteService.userId.trim();
      if (remoteUserId.isNotEmpty) {
        return 'user:$remoteUserId';
      }
    }
    return _localReporterId;
  }

  void _submitCrowdReport() {
    unawaited(_submitCrowdReportAsync());
  }

  /// Registra relato colaborativo (0-100) e recalcula snapshot da academia.
  Future<void> _submitCrowdReportAsync() async {
    if (_isSubmittingCrowdReport) {
      return;
    }
    final selectedGym = _selectedGym;
    if (selectedGym == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isSubmittingCrowdReport = true;
      });
    } else {
      _isSubmittingCrowdReport = true;
    }
    final int report = _reportPercent.round().clamp(0, 100).toInt();
    final reporterId = _resolveCrowdReporterId();
    final regionKey = _leaderboardRegionKey(preferredGym: selectedGym);
    final regionLabel = _leaderboardRegionLabel(preferredGym: selectedGym);
    final remoteService = _crowdReportRemoteService;
    try {
      if (remoteService != null && remoteService.hasRemoteBackend) {
        try {
          final remoteResult = await remoteService.submitReport(
            gymId: selectedGym.id,
            occupancyPercent: report,
            reporterId: reporterId,
            regionKey: regionKey,
            regionLabel: regionLabel,
          );
          if (!remoteResult.accepted) {
            final retryAfter =
                remoteResult.retryAfter ?? const Duration(minutes: 1);
            final waitMinutes =
                retryAfter.inMinutes >= 1 ? retryAfter.inMinutes : 1;
            unawaited(
              _metrics.trackEvent(
                'crowd_report_submit',
                params: <String, Object?>{
                  'gymId': selectedGym.id,
                  'occupancyPercent': report,
                  'source': 'remote',
                  'result': 'blocked',
                  'waitMinutes': waitMinutes,
                },
              ),
            );
            _showMapSnack(
              'Envio bloqueado temporariamente. Aguarde $waitMinutes min para novo relato.',
            );
            return;
          }

          final remoteReport = remoteResult.report;
          if (remoteReport != null) {
            _crowdService.mergeReports(<CrowdReport>[remoteReport]);
          } else {
            _crowdService.mergeReports(<CrowdReport>[
              CrowdReport(
                gymId: selectedGym.id,
                occupancyPercent: report,
                createdAt: DateTime.now().toUtc(),
                reporterId: reporterId,
                reliabilityWeight: 1,
              ),
            ]);
          }

          final snapshot = _crowdService.snapshotFor(selectedGym);
          if (mounted) {
            setState(() {
              _reportPercent = snapshot.occupancyPercent.toDouble();
              _communityPoints += 5;
            });
          }
          unawaited(_persistCommunityPoints());

          final trust =
              ((remoteReport?.reliabilityWeight ?? 1) * 100)
                  .round()
                  .clamp(20, 160)
                  .toInt();
          _showContributionSnack(
            gymName: selectedGym.name,
            report: report,
            trust: trust,
          );
          unawaited(
            _metrics.trackEvent(
              'crowd_report_submit',
              params: <String, Object?>{
                'gymId': selectedGym.id,
                'occupancyPercent': report,
                'source': 'remote',
                'result': 'accepted',
              },
            ),
          );
          unawaited(
            _syncCrowdReportsForGyms(
              _crowdSyncGymIds(extraGymIds: [selectedGym.id]),
            ),
          );
          return;
        } catch (_) {
          // Sem rede/backend: segue fluxo local para não perder envio do usuário.
        }
      }

      final localResult = _crowdService.submitReport(
        gym: selectedGym,
        reporterId: reporterId,
        occupancyPercent: report,
      );
      if (!localResult.accepted) {
        final retryAfter = localResult.retryAfter ?? const Duration(minutes: 1);
        final waitMinutes =
            retryAfter.inMinutes >= 1 ? retryAfter.inMinutes : 1;
        unawaited(
          _metrics.trackEvent(
            'crowd_report_submit',
            params: <String, Object?>{
              'gymId': selectedGym.id,
              'occupancyPercent': report,
              'source': 'local',
              'result': 'blocked',
              'waitMinutes': waitMinutes,
            },
          ),
        );
        _showMapSnack(
          'Envio bloqueado temporariamente. Aguarde $waitMinutes min para novo relato.',
        );
        return;
      }

      final snapshot = _crowdService.snapshotFor(selectedGym);
      if (mounted) {
        setState(() {
          _reportPercent = snapshot.occupancyPercent.toDouble();
          _communityPoints += 5;
        });
      }
      unawaited(_persistCommunityPoints());

      final trust = ((localResult.appliedWeight ?? 1) * 100).round();
      _showContributionSnack(
        gymName: selectedGym.name,
        report: report,
        trust: trust,
      );
      unawaited(
        _metrics.trackEvent(
          'crowd_report_submit',
          params: <String, Object?>{
            'gymId': selectedGym.id,
            'occupancyPercent': report,
            'source': 'local',
            'result': 'accepted',
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingCrowdReport = false;
        });
      } else {
        _isSubmittingCrowdReport = false;
      }
    }
  }

  /// Fluxo de geolocalização:
  /// 1) valida serviço de GPS;
  /// 2) valida/solicita permissão;
  /// 3) centraliza usando cache/última posição conhecida quando disponível;
  /// 4) obtém posição atual para refino.
  void _applyResolvedUserLocation(LatLng userPoint, {required bool moveMap}) {
    if (!mounted) {
      return;
    }

    setState(() {
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
        distanceFilter: _backgroundLocationDistanceFilterMeters.round(),
        intervalDuration: _backgroundLocationInterval,
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
        distanceFilter: _backgroundLocationDistanceFilterMeters.round(),
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.fitness,
      );
    }

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _backgroundLocationDistanceFilterMeters.round(),
    );
  }

  void _onBackgroundLocationUpdate(Position position) {
    final userPoint = LatLng(position.latitude, position.longitude);
    final previousLocation = _userLocation;
    if (previousLocation != null &&
        _isWithinDistanceMeters(
          previousLocation,
          userPoint,
          _backgroundLocationUiRefreshMinDistanceMeters,
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

    setState(() {
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
        setState(() {
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

  void _showMapSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  bool _markPurchaseSuccessNotified(String key) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return false;
    }
    final added = _purchaseSuccessNotificationKeys.add(normalizedKey);
    if (added && _purchaseSuccessNotificationKeys.length > 24) {
      _purchaseSuccessNotificationKeys.remove(
        _purchaseSuccessNotificationKeys.first,
      );
    }
    return added;
  }

  Future<void> _showPlanActivationSuccessDialog(AppPlanTier tier) async {
    if (!mounted) {
      return;
    }
    final plan = kPlanCatalog[tier]!;
    final highlights = plan.insights.take(2).toList(growable: false);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final primary = _planAccentColor(tier);
        final onPrimary = _planOnAccentColor(tier);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.88, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: withUiOpacity(primary, 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Assinatura ativada!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: GymMapColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Plano ${plan.label} liberado com sucesso.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GymMapColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final highlight in highlights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: withUiOpacity(primary, 0.90),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              highlight,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: GymMapColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: onPrimary,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: const Text('Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showContributionSnack({
    required String gymName,
    required int report,
    required int trust,
  }) {
    if (!mounted) {
      return;
    }
    HapticFeedback.lightImpact();
    _triggerContributionCelebration();
    final totalPoints = _communityPoints;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: GymMapColors.occupancyLow,
        content: Row(
          children: [
            const Icon(
              Icons.celebration_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Obrigado por contribuir! +5 pontos\n$gymName atualizado para $report% (conf. $trust%).',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: withUiOpacity(Colors.white, 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$totalPoints pts',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerContributionCelebration() {
    if (!mounted) {
      return;
    }
    _contributionCelebrationTimer?.cancel();
    setState(() {
      _showContributionCelebration = true;
      _contributionCelebrationTick++;
    });
    _contributionCelebrationTimer = Timer(
      const Duration(milliseconds: 1100),
      () {
        if (!mounted) {
          return;
        }
        setState(() {
          _showContributionCelebration = false;
        });
      },
    );
  }

  Color _leaderboardMedalColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFE0A800);
      case 1:
        return const Color(0xFF8E9AA8);
      case 2:
        return const Color(0xFFB97745);
      default:
        return GymMapColors.textSecondary;
    }
  }

  LatLng _leaderboardRegionPoint({Gym? preferredGym}) {
    if (preferredGym != null) {
      return preferredGym.position;
    }
    final userPoint = _userLocation;
    if (userPoint != null) {
      return userPoint;
    }
    final selected = _selectedGym;
    if (selected != null) {
      return selected.position;
    }
    if (_isMapReady) {
      try {
        return _mapController.camera.center;
      } catch (_) {
        // Ignora quando a câmera ainda não está pronta.
      }
    }
    return _fallbackMapCenter;
  }

  String _leaderboardRegionKey({Gym? preferredGym}) {
    final point = _leaderboardRegionPoint(preferredGym: preferredGym);
    return _leaderboardRegionKeyFromPoint(point);
  }

  String _leaderboardRegionKeyFromPoint(LatLng point) {
    final latBucket = (point.latitude * 10).round() / 10;
    final lngBucket = (point.longitude * 10).round() / 10;
    return '${latBucket.toStringAsFixed(1)},${lngBucket.toStringAsFixed(1)}';
  }

  String _leaderboardRegionLabel({Gym? preferredGym}) {
    final gym = preferredGym;
    if (gym != null) {
      final address = gym.address.trim();
      if (address.isNotEmpty && address != 'Academia encontrada no mapa') {
        return address;
      }
    }
    if (_userLocation != null) {
      return 'Sua localização atual';
    }
    final selected = _selectedGym;
    if (selected != null) {
      final selectedAddress = selected.address.trim();
      if (selectedAddress.isNotEmpty &&
          selectedAddress != 'Academia encontrada no mapa') {
        return selectedAddress;
      }
    }
    final searchLocation = (_searchLocationQuery ?? '').trim();
    if (searchLocation.isNotEmpty) {
      return searchLocation;
    }
    return 'Região atual';
  }

  _CommunityLeaderboardSheetData _buildLocalLeaderboardSheetData({
    required String regionLabel,
  }) {
    return _CommunityLeaderboardSheetData(
      entries: const <_CommunityLeaderboardEntry>[],
      userRank: 0,
      userPoints: _communityPoints.clamp(0, 1000000).toInt(),
      regionLabel: regionLabel,
      isRegional: false,
    );
  }

  Future<_CommunityLeaderboardSheetData> _loadRegionalLeaderboardSheetData({
    required String regionKey,
    required String regionLabel,
  }) async {
    final fallback = _buildLocalLeaderboardSheetData(regionLabel: regionLabel);
    final localUserPoints = _communityPoints.clamp(0, 1000000).toInt();
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null || !remoteService.hasRemoteBackend) {
      return fallback;
    }
    try {
      final result = await remoteService.loadRegionalLeaderboard(
        regionKey: regionKey,
        regionLabel: regionLabel,
        limit: 10,
        windowDays: 7,
      );
      if (result == null || result.entries.isEmpty) {
        return fallback;
      }
      final entries = result.entries
          .map(
            (entry) => _CommunityLeaderboardEntry(
              name: entry.displayName,
              points: entry.isCurrentUser ? localUserPoints : entry.points,
              isCurrentUser: entry.isCurrentUser,
            ),
          )
          .toList(growable: false);
      final userRankFromEntries =
          entries.indexWhere((entry) => entry.isCurrentUser) + 1;
      final userRank =
          userRankFromEntries > 0
              ? userRankFromEntries
              : (result.userRank > 0 ? result.userRank : 0);
      final normalizedRegionLabel =
          result.regionLabel.trim().isEmpty
              ? regionLabel
              : result.regionLabel.trim();
      return _CommunityLeaderboardSheetData(
        entries: entries,
        userRank: userRank,
        userPoints: localUserPoints,
        regionLabel: normalizedRegionLabel,
        isRegional: true,
      );
    } catch (_) {
      return fallback;
    }
  }

  void _openCommunityLeaderboard() {
    if (!mounted) {
      return;
    }
    HapticFeedback.selectionClick();
    final userPoint = _userLocation;
    final regionKey =
        userPoint == null ? '' : _leaderboardRegionKeyFromPoint(userPoint);
    final regionLabel =
        userPoint == null ? 'Região indisponível' : 'Sua região';
    final fallbackData = _buildLocalLeaderboardSheetData(
      regionLabel: regionLabel,
    );
    final leaderboardFuture = _loadRegionalLeaderboardSheetData(
      regionKey: regionKey,
      regionLabel: regionLabel,
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final primary = Theme.of(sheetContext).colorScheme.primary;
        return FutureBuilder<_CommunityLeaderboardSheetData>(
          future: leaderboardFuture,
          initialData: fallbackData,
          builder: (context, snapshot) {
            final data = snapshot.data ?? fallbackData;
            final entries = data.entries;
            final userRank = data.userRank;
            final userPoints = data.userPoints;
            final rankLabel = userRank > 0 ? '#$userRank' : 'sem ranking';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top 10 contribuidores da semana',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sua posição atual: $rankLabel  .  $userPoints pts',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GymMapColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Região: ${data.regionLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GymMapColors.textSecondary,
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !data.isRegional) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Atualizando ranking regional...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: withUiOpacity(primary, 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: withUiOpacity(primary, 0.08),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data.isRegional
                                    ? 'Pontuação regional real dos últimos 7 dias. Cada envio válido soma +5 pontos.'
                                    : 'Cada envio válido soma +5 pontos. Continue contribuindo para subir no ranking.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: GymMapColors.textStrong,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < entries.length; i++) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color:
                                entries[i].isCurrentUser
                                    ? withUiOpacity(primary, 0.10)
                                    : Colors.white,
                            border: Border.all(
                              color:
                                  entries[i].isCurrentUser
                                      ? withUiOpacity(primary, 0.34)
                                      : withUiOpacity(
                                        primary,
                                        0.10,
                                      ),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child:
                                    i < 3
                                        ? Icon(
                                          Icons.emoji_events_rounded,
                                          size: 19,
                                          color: _leaderboardMedalColor(i),
                                        )
                                        : Text(
                                          '#${i + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: GymMapColors.textSecondary,
                                          ),
                                        ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entries[i].name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color:
                                        entries[i].isCurrentUser
                                            ? GymMapColors.textPrimary
                                            : GymMapColors.textStrong,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: withUiOpacity(primary, 0.09),
                                ),
                                child: Text(
                                  '${entries[i].points} pts',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: GymMapColors.textStrong,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Ainda não há pontuação suficiente nesta região.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: GymMapColors.textSecondary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Fechar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _tierToPlanKey(AppPlanTier tier) => tier.name;

  AppPlanTier _tierFromPlanKey(String planKey) {
    for (final tier in AppPlanTier.values) {
      if (tier.name == planKey) {
        return tier;
      }
    }
    return AppPlanTier.free;
  }

  String _formatDateTimeLabel(DateTime dateUtc) {
    final local = dateUtc.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _activePlanStatusLabel() {
    if (_activePlan == AppPlanTier.free || _activePlanExpiresAtUtc == null) {
      return 'Plano gratuito ativo';
    }
    return 'Válido até ${_formatDateTimeLabel(_activePlanExpiresAtUtc!)}';
  }

  void _maybeWarnPlanNearExpiry(AppPlanTier plan, DateTime? expiresAtUtc) {
    if (plan == AppPlanTier.free || expiresAtUtc == null) {
      _lastPlanExpiryWarningKey = null;
      return;
    }
    final now = DateTime.now().toUtc();
    final remaining = expiresAtUtc.difference(now);
    if (remaining <= Duration.zero || remaining > const Duration(days: 3)) {
      return;
    }
    final warningKey = '${plan.name}:${expiresAtUtc.millisecondsSinceEpoch}';
    if (_lastPlanExpiryWarningKey == warningKey) {
      return;
    }
    _lastPlanExpiryWarningKey = warningKey;
    final days = remaining.inDays;
    final hours = remaining.inHours;
    final planLabel = kPlanCatalog[plan]!.label;
    final windowLabel =
        days >= 1
            ? '$days dia${days == 1 ? '' : 's'}'
            : hours >= 1
            ? '$hours hora${hours == 1 ? '' : 's'}'
            : 'menos de 1 hora';
    _showMapSnack(
      'Seu plano $planLabel expira em $windowLabel. Renovação somente manual, quando você decidir.',
    );
  }

  String _planAuthStatusLabel() {
    final service = _planSubscriptionService;
    if (service == null) {
      return 'Autenticação ainda inicializando';
    }
    if (service.isProductionMode && !service.hasRemoteBackend) {
      return 'Modo produção ativo sem backend remoto configurado';
    }
    if (!service.hasRemoteBackend) {
      return 'Backend remoto não configurado no app';
    }
    if (service.isProductionMode && !service.hasAuthSession) {
      return 'Modo produção exige sessão autenticada';
    }
    if (service.hasAuthSession) {
      return 'Sessão ativa para ${service.userId}';
    }
    return 'Sessão não autenticada';
  }

  String _playBillingStatusLabel() {
    if (_isLoadingPlayProducts) {
      return 'Google Play: carregando produtos...';
    }
    if (!_isPlayStoreAvailable) {
      return 'Google Play indisponível neste aparelho.';
    }
    if (_playProducts.length < _planProductIds.length) {
      return 'Google Play: um ou mais produtos ainda não encontrados.';
    }
    return 'Google Play pronto para checkout.';
  }

  Future<void> _initializePlayStoreBilling() async {
    try {
      final isAvailable = await _inAppPurchase.isAvailable();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlayStoreAvailable = isAvailable;
      });
      if (!isAvailable) {
        return;
      }
      _purchaseStreamSubscription?.cancel();
      _purchaseStreamSubscription = _inAppPurchase.purchaseStream.listen(
        (purchases) {
          unawaited(_handlePlayPurchaseUpdates(purchases));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) {
            return;
          }
          _showMapSnack('Falha ao escutar compras do Google Play.');
        },
      );
      await _loadPlayProducts(forceRefresh: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlayStoreAvailable = false;
      });
    }
  }

  Future<void> _loadPlayProducts({bool forceRefresh = false}) async {
    if (!_isPlayStoreAvailable) {
      return;
    }
    if (_isLoadingPlayProducts && !forceRefresh) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingPlayProducts = true;
      });
    }
    try {
      final response = await _inAppPurchase.queryProductDetails(
        _planProductIds.values.toSet(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _playProducts = response.productDetails;
      });
      if (response.error != null) {
        _showMapSnack('Não foi possível carregar produtos do Google Play.');
      } else if (response.notFoundIDs.isNotEmpty) {
        _showMapSnack(
          'Produtos não encontrados no Google Play: ${response.notFoundIDs.join(', ')}',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMapSnack('Falha ao carregar produtos do Google Play.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlayProducts = false;
        });
      }
    }
  }

  String _formatAuthFailure(Object error) {
    final raw = '$error'.trim();
    final normalized =
        raw.startsWith('Bad state: ')
            ? raw.substring('Bad state: '.length).trim()
            : raw;
    if (normalized.startsWith('rate_limited')) {
      final retryAfter = _retryAfterSecondsFromRateLimitError(normalized);
      if (retryAfter != null) {
        return 'Muitas tentativas de login. Aguarde ${_formatRetryAfterLabel(retryAfter)}.';
      }
      return 'Muitas tentativas de login. Aguarde um pouco e tente novamente.';
    }
    switch (normalized) {
      case 'invalid_credentials':
        return 'Usuário ou senha inválidos.';
      case 'missing_credentials':
        return 'Informe usuário e senha.';
      case 'unauthorized':
        return 'Sessão não autorizada.';
      case '':
        return 'Falha de autenticação';
      default:
        return normalized;
    }
  }

  String _metricErrorCode(Object error) {
    final raw = '$error'.trim();
    final normalized =
        raw.startsWith('Bad state: ')
            ? raw.substring('Bad state: '.length).trim()
            : raw;
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  int? _retryAfterSecondsFromRateLimitError(String normalized) {
    final separator = normalized.indexOf(':');
    if (separator < 0 || separator + 1 >= normalized.length) {
      return null;
    }
    final parsed = int.tryParse(normalized.substring(separator + 1).trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  String _formatRetryAfterLabel(int seconds) {
    if (seconds >= 60) {
      final minutes = (seconds / 60).ceil();
      return '$minutes min';
    }
    return '$seconds s';
  }

  String _formatBillingFailure(Object error) {
    final raw = '$error'.trim();
    final normalized =
        raw.startsWith('Bad state: ')
            ? raw.substring('Bad state: '.length).trim()
            : raw;
    if (normalized.startsWith('rate_limited')) {
      final retryAfter = _retryAfterSecondsFromRateLimitError(normalized);
      if (retryAfter != null) {
        return 'Limite de tentativas atingido. Aguarde ${_formatRetryAfterLabel(retryAfter)}.';
      }
      return 'Limite de tentativas atingido. Aguarde um pouco e tente novamente.';
    }
    switch (normalized) {
      case 'backend_required_in_production':
        return 'Modo produção exige backend remoto configurado.';
      case 'backend_required_for_play_billing':
        return 'Checkout no Google Play exige backend remoto configurado.';
      case 'user_identity_required_in_production':
        return 'Modo produção exige usuário autenticado.';
      case 'play_store_unavailable':
        return 'Google Play indisponível neste aparelho.';
      case 'play_product_not_found':
        return 'Produto de assinatura não encontrado no Google Play.';
      case 'play_checkout_not_started':
        return 'Não foi possível iniciar checkout no Google Play.';
      case 'play_product_id_missing':
        return 'Produto da assinatura não informado.';
      case 'play_purchase_token_missing':
        return 'Token de compra ausente. Tente novamente.';
      case 'play_purchase_not_active':
        return 'Compra ainda não está ativa no Google Play.';
      case 'play_purchase_not_found':
        return 'Compra não encontrada no Google Play.';
      case 'play_product_mismatch':
        return 'Produto da compra não corresponde ao plano selecionado.';
      case 'play_package_mismatch':
        return 'Compra vinculada a outro aplicativo.';
      case 'play_api_unauthorized':
        return 'Backend sem permissão para validar Google Play. Verifique credenciais.';
      case 'play_validation_unavailable':
      case 'play_api_unavailable':
        return 'Não foi possível validar a compra no Google Play agora.';
      case 'payment_pending_webhook':
        return 'Pagamento ainda não confirmado pelo webhook. Aguarde alguns segundos e tente novamente.';
      case 'pix_provider_unavailable':
        return 'Gateway Pix indisponível no momento. Tente novamente em instantes.';
      case 'invalid_webhook_signature':
        return 'Webhook do pagamento inválido. Contate o suporte.';
      case 'unauthorized':
      case 'forbidden':
        return 'Sessão expirada ou sem permissão. Faça login novamente.';
      default:
        if (normalized == 'Backend HTTP 401') {
          return 'Sessão expirada. Faça login novamente.';
        }
        if (normalized == 'Backend HTTP 429') {
          return 'Limite de tentativas atingido. Aguarde um pouco e tente novamente.';
        }
        if (normalized.isEmpty) {
          return 'Não foi possível processar a assinatura agora.';
        }
        return normalized;
    }
  }

  Future<void> _initializePlanSubscription() async {
    try {
      final service = await PlanSubscriptionService.create();
      final snapshot = await service.loadActiveSubscription();
      final nextPlan = _tierFromPlanKey(snapshot.activePlanKey);
      if (!mounted) {
        return;
      }
      setState(() {
        _planSubscriptionService = service;
        _activePlan = nextPlan;
        _activePlanExpiresAtUtc = snapshot.expiresAt;
        _isLoadingPlanSubscription = false;
      });
      widget.onActivePlanChanged?.call(nextPlan);
      _maybeWarnPlanNearExpiry(_activePlan, _activePlanExpiresAtUtc);
      _startPlanSyncTimer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingPlanSubscription = false;
      });
    }
  }

  void _startPlanSyncTimer() {
    _planSyncTimer?.cancel();
    _planSyncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_syncPlanFromStorage(showExpiryNotice: false));
    });
  }

  Future<void> _syncPlanFromStorage({required bool showExpiryNotice}) async {
    final service = _planSubscriptionService;
    if (service == null) {
      return;
    }

    final previousPlan = _activePlan;
    final snapshot = await service.loadActiveSubscription();
    if (!mounted) {
      return;
    }

    final nextPlan = _tierFromPlanKey(snapshot.activePlanKey);
    final nextExpiresAt = snapshot.expiresAt;
    final hasExpiryChanged =
        (nextExpiresAt?.millisecondsSinceEpoch ?? 0) !=
        (_activePlanExpiresAtUtc?.millisecondsSinceEpoch ?? 0);
    final hasPlanChanged = nextPlan != _activePlan;
    if (!hasPlanChanged && !hasExpiryChanged) {
      return;
    }

    setState(() {
      _activePlan = nextPlan;
      _activePlanExpiresAtUtc = nextExpiresAt;
    });
    if (hasPlanChanged) {
      widget.onActivePlanChanged?.call(nextPlan);
    }
    _maybeWarnPlanNearExpiry(nextPlan, nextExpiresAt);

    if (showExpiryNotice &&
        previousPlan != AppPlanTier.free &&
        nextPlan == AppPlanTier.free) {
      _showMapSnack('Assinatura expirada. O app voltou para o plano gratuito.');
    }
  }

  Future<void> _activateFreePlan() async {
    final service = _planSubscriptionService;
    if (service == null) {
      _showMapSnack('Assinatura ainda esta inicializando. Tente novamente.');
      return;
    }
    await service.downgradeToFree();
    await _syncPlanFromStorage(showExpiryNotice: false);
    _showMapSnack('Plano gratuito ativado.');
  }

  Future<void> _startPlanLoginFlow(BuildContext sheetContext) async {
    final service = _planSubscriptionService;
    if (service == null) {
      _showMapSnack('Assinatura ainda esta inicializando. Tente novamente.');
      return;
    }
    if (!service.hasRemoteBackend) {
      _showMapSnack('Backend remoto não configurado para login.');
      return;
    }

    final userController = TextEditingController(text: service.userId);
    final passwordController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var isSubmitting = false;
          var hidePassword = true;
          String? errorMessage;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submitLogin() async {
                final userId = userController.text.trim();
                final password = passwordController.text;
                if (userId.isEmpty || password.isEmpty) {
                  setDialogState(() {
                    errorMessage = 'Informe usuário e senha';
                  });
                  return;
                }

                setDialogState(() {
                  errorMessage = null;
                  isSubmitting = true;
                });
                if (mounted) {
                  setState(() {
                    _isPlanAuthBusy = true;
                  });
                }
                try {
                  final session = await service.signIn(
                    userId: userId,
                    password: password,
                  );
                  await _syncPlanFromStorage(showExpiryNotice: false);
                  _crowdReportRemoteService?.refreshAuthFromStorage();
                  unawaited(_syncCrowdReportsForCurrentContext());
                  if (!mounted) {
                    return;
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  _showMapSnack('Login concluido para ${session.userId}.');
                } catch (error) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      errorMessage = _formatAuthFailure(error);
                    });
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isPlanAuthBusy = false;
                    });
                  }
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      isSubmitting = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: const Text('Entrar no plano mensal'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: userController,
                      enabled: !isSubmitting,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Usuário',
                        hintText: 'user-001',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      enabled: !isSubmitting,
                      obscureText: hidePassword,
                      onSubmitted: (_) {
                        unawaited(submitLogin());
                      },
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        suffixIcon: IconButton(
                          onPressed:
                              isSubmitting
                                  ? null
                                  : () {
                                    setDialogState(() {
                                      hidePassword = !hidePassword;
                                    });
                                  },
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isSubmitting
                            ? null
                            : () {
                              Navigator.of(dialogContext).pop();
                            },
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        isSubmitting
                            ? null
                            : () {
                              unawaited(submitLogin());
                            },
                    icon:
                        isSubmitting
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.login),
                    label: Text(isSubmitting ? 'Entrando...' : 'Entrar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      userController.dispose();
      passwordController.dispose();
    }
  }

  Future<void> _logoutPlanSession(BuildContext sheetContext) async {
    final service = _planSubscriptionService;
    if (service == null) {
      _showMapSnack('Assinatura ainda esta inicializando. Tente novamente.');
      return;
    }
    if (!service.hasAuthSession) {
      _showMapSnack('Não existe sessão autenticada.');
      return;
    }
    if (_isPlanAuthBusy) {
      return;
    }

    setState(() {
      _isPlanAuthBusy = true;
    });
    try {
      await service.signOut();
      await _syncPlanFromStorage(showExpiryNotice: false);
      _crowdReportRemoteService?.refreshAuthFromStorage();
      unawaited(_syncCrowdReportsForCurrentContext());
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      _showMapSnack('Sessão encerrada.');
    } catch (_) {
      _showMapSnack('Não foi possível encerrar sessão agora.');
    } finally {
      if (mounted) {
        setState(() {
          _isPlanAuthBusy = false;
        });
      }
    }
  }

  void _onPlanPicked(AppPlanTier selectedTier, BuildContext sheetContext) {
    unawaited(
      _metrics.trackEvent(
        'plan_select',
        params: <String, Object?>{
          'source': 'paywall',
          'currentPlan': _tierToPlanKey(_activePlan),
          'selectedPlan': _tierToPlanKey(selectedTier),
        },
      ),
    );
    Navigator.of(sheetContext).pop();
    if (selectedTier == AppPlanTier.free) {
      unawaited(_activateFreePlan());
      return;
    }
    unawaited(_startStoreCheckout(selectedTier));
  }

  Future<void> _startStoreCheckout(AppPlanTier tier) async {
    final planKey = _tierToPlanKey(tier);
    final service = _planSubscriptionService;
    if (service == null) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'result': 'failed',
            'reason': 'service_unavailable',
          },
        ),
      );
      _showMapSnack('Assinatura ainda esta inicializando. Tente novamente.');
      return;
    }
    if (_isStartingStoreCheckout) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'result': 'failed',
            'reason': 'checkout_in_progress',
          },
        ),
      );
      return;
    }
    if (!_isPlayStoreAvailable) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'result': 'failed',
            'reason': 'play_store_unavailable',
          },
        ),
      );
      _showMapSnack(
        _formatBillingFailure(StateError('play_store_unavailable')),
      );
      return;
    }
    final productId = _planProductIds[tier];
    if (productId == null || productId.trim().isEmpty) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'result': 'failed',
            'reason': 'play_product_id_missing',
          },
        ),
      );
      _showMapSnack(
        _formatBillingFailure(StateError('play_product_id_missing')),
      );
      return;
    }

    ProductDetails? product;
    for (final item in _playProducts) {
      if (item.id == productId) {
        product = item;
        break;
      }
    }
    if (product == null) {
      await _loadPlayProducts(forceRefresh: true);
      for (final item in _playProducts) {
        if (item.id == productId) {
          product = item;
          break;
        }
      }
    }
    if (product == null) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'result': 'failed',
            'reason': 'play_product_not_found',
          },
        ),
      );
      _showMapSnack(
        _formatBillingFailure(StateError('play_product_not_found')),
      );
      return;
    }

    setState(() {
      _isStartingStoreCheckout = true;
    });

    try {
      if (service.isProductionMode && !service.hasRemoteBackend) {
        throw StateError('backend_required_in_production');
      }
      if (service.isProductionMode && !service.hasAuthSession) {
        throw StateError('user_identity_required_in_production');
      }
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        throw StateError('play_checkout_not_started');
      }
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'productId': product.id,
            'result': 'started',
          },
        ),
      );
      if (!mounted) {
        return;
      }
      _showMapSnack('Finalize o pagamento no Google Play para ativar o plano.');
    } catch (error) {
      unawaited(
        _metrics.trackEvent(
          'checkout_start',
          params: <String, Object?>{
            'plan': planKey,
            'productId': product.id,
            'result': 'failed',
            'reason': _metricErrorCode(error),
          },
        ),
      );
      _showMapSnack(_formatBillingFailure(error));
    } finally {
      if (mounted) {
        setState(() {
          _isStartingStoreCheckout = false;
        });
      }
    }
  }

  Future<void> _handlePlayPurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (!mounted) {
        return;
      }
      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _processPlayPurchase(purchase);
          continue;
        case PurchaseStatus.error:
          final errorMessage = purchase.error?.message.trim();
          unawaited(
            _metrics.trackEvent(
              'purchase_fail',
              params: <String, Object?>{
                'status': 'error',
                'productId': purchase.productID.trim(),
                'reason': _metricErrorCode(errorMessage ?? 'purchase_error'),
              },
            ),
          );
          if (errorMessage != null && errorMessage.isNotEmpty) {
            _showMapSnack(errorMessage);
          } else {
            _showMapSnack('Falha ao processar compra no Google Play.');
          }
          continue;
        case PurchaseStatus.canceled:
          unawaited(
            _metrics.trackEvent(
              'purchase_cancel',
              params: <String, Object?>{
                'productId': purchase.productID.trim(),
              },
            ),
          );
          _showMapSnack('Pagamento cancelado no Google Play.');
          continue;
      }
    }
  }

  Future<void> _processPlayPurchase(PurchaseDetails purchase) async {
    final service = _planSubscriptionService;
    if (service == null) {
      unawaited(
        _metrics.trackEvent(
          'purchase_fail',
          params: <String, Object?>{
            'productId': purchase.productID.trim(),
            'reason': 'service_unavailable',
          },
        ),
      );
      _showMapSnack('Assinatura ainda esta inicializando. Tente novamente.');
      return;
    }
    final token = purchase.verificationData.serverVerificationData.trim();
    final productId = purchase.productID.trim();
    if (token.isEmpty) {
      unawaited(
        _metrics.trackEvent(
          'purchase_fail',
          params: <String, Object?>{
            'productId': productId,
            'reason': 'play_purchase_token_missing',
          },
        ),
      );
      _showMapSnack(_formatBillingFailure(StateError('play_purchase_token_missing')));
      return;
    }
    final tier = _tierFromProductId(productId);
    if (tier == null) {
      unawaited(
        _metrics.trackEvent(
          'purchase_fail',
          params: <String, Object?>{
            'productId': productId,
            'reason': 'play_product_not_found',
          },
        ),
      );
      _showMapSnack('Produto desconhecido no Google Play: $productId');
      return;
    }
    final processingKey = '${purchase.purchaseID ?? 'no-id'}|$productId|$token';
    if (_processingPlayPurchases.contains(processingKey)) {
      return;
    }
    _processingPlayPurchases.add(processingKey);
    try {
      final snapshot = await service.confirmPlayStorePurchase(
        planKey: _tierToPlanKey(tier),
        productId: productId,
        purchaseToken: token,
        purchaseId: purchase.purchaseID,
      );
      await _syncActivePlanFromSnapshot(snapshot);
      if (!mounted) {
        return;
      }
      await _completePlayPurchaseIfNeeded(purchase);
      unawaited(
        _metrics.trackEvent(
          'purchase_success',
          params: <String, Object?>{
            'plan': _tierToPlanKey(tier),
            'productId': productId,
            'status': purchase.status.name,
          },
        ),
      );
      final notificationKey = '$productId|$token';
      if (_markPurchaseSuccessNotified(notificationKey)) {
        unawaited(_showPlanActivationSuccessDialog(tier));
      } else {
        _showMapSnack(
          'Assinatura ${kPlanCatalog[tier]!.label} ativada com sucesso.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      unawaited(
        _metrics.trackEvent(
          'purchase_fail',
          params: <String, Object?>{
            'plan': _tierToPlanKey(tier),
            'productId': productId,
            'reason': _metricErrorCode(error),
          },
        ),
      );
      _showMapSnack(_formatBillingFailure(error));
    } finally {
      _processingPlayPurchases.remove(processingKey);
    }
  }

  Future<void> _completePlayPurchaseIfNeeded(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) {
      return;
    }
    try {
      await _inAppPurchase.completePurchase(purchase);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMapSnack(
        'Compra validada, mas não foi possível finalizar no Google Play.',
      );
    }
  }

  AppPlanTier? _tierFromProductId(String productId) {
    for (final entry in _planProductIds.entries) {
      if (entry.value == productId) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _syncActivePlanFromSnapshot(SubscriptionState snapshot) async {
    if (!mounted) {
      return;
    }
    final nextPlan = _tierFromPlanKey(snapshot.activePlanKey);
    setState(() {
      _activePlan = nextPlan;
      _activePlanExpiresAtUtc = snapshot.expiresAt;
    });
    widget.onActivePlanChanged?.call(nextPlan);
  }

  PlanInfo get _activePlanInfo => kPlanCatalog[_activePlan]!;

  bool get _isFreePlan => _activePlan == AppPlanTier.free;
  bool get _hasHistoryInsights =>
      _activePlan == AppPlanTier.smart ||
      _activePlan == AppPlanTier.pro ||
      _activePlan == AppPlanTier.elite;
  bool get _hasProInsights =>
      _activePlan == AppPlanTier.pro || _activePlan == AppPlanTier.elite;
  bool get _hasEliteInsights => _activePlan == AppPlanTier.elite;
  bool get _hasNationwideCoverage => _activePlan == AppPlanTier.elite;

  int _planTierWeight(AppPlanTier tier) {
    switch (tier) {
      case AppPlanTier.free:
        return 0;
      case AppPlanTier.smart:
        return 1;
      case AppPlanTier.pro:
        return 2;
      case AppPlanTier.elite:
        return 3;
    }
  }

  ProductDetails? _playProductForTier(AppPlanTier tier) {
    final productId = _planProductIds[tier];
    if (productId == null || productId.trim().isEmpty) {
      return null;
    }
    for (final product in _playProducts) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  String _planPriceLabel(AppPlanTier tier) {
    if (tier == AppPlanTier.free) {
      return 'R\$ 0/mês';
    }
    final playProduct = _playProductForTier(tier);
    if (playProduct != null) {
      final price = playProduct.price.trim();
      if (price.isNotEmpty) {
        return '$price/mês';
      }
    }
    return kPlanCatalog[tier]!.monthlyPrice;
  }

  String _planActionLabel(AppPlanTier tier, AppPlanTier current) {
    if (tier == current) {
      return 'Plano atual';
    }
    if (tier == AppPlanTier.free) {
      return current == AppPlanTier.free
          ? 'Continuar grátis'
          : 'Voltar ao gratuito';
    }
    if (_planTierWeight(tier) > _planTierWeight(current)) {
      return current == AppPlanTier.free ? 'Assinar' : 'Fazer upgrade';
    }
    return 'Trocar plano';
  }

  Color _planAccentColor(AppPlanTier tier) {
    return PlanThemePalette.colorFor(tier);
  }

  Color _planOnAccentColor(AppPlanTier tier) {
    return PlanThemePalette.onColorFor(tier);
  }

  IconData _planIcon(AppPlanTier tier) {
    switch (tier) {
      case AppPlanTier.free:
        return Icons.lock_open_rounded;
      case AppPlanTier.smart:
        return Icons.bolt_rounded;
      case AppPlanTier.pro:
        return Icons.rocket_launch_rounded;
      case AppPlanTier.elite:
        return Icons.workspace_premium_rounded;
    }
  }

  String? _paywallPromoLabel() {
    final message = _paywallPromoMessage.trim();
    if (message.isEmpty) {
      return null;
    }
    final deadline = _paywallPromoDeadline.trim();
    if (deadline.isEmpty) {
      return message;
    }
    return '$message • até $deadline';
  }

  List<String> _planCardHighlights(AppPlanTier tier) {
    final currentInsights = kPlanCatalog[tier]!.insights;
    switch (tier) {
      case AppPlanTier.free:
        return currentInsights.take(2).toList(growable: false);
      case AppPlanTier.smart:
        final freeInsights = kPlanCatalog[AppPlanTier.free]!.insights.toSet();
        final unique = currentInsights
            .where((feature) => !freeInsights.contains(feature))
            .toList(growable: false);
        final source = unique.isEmpty ? currentInsights : unique;
        return source.take(3).toList(growable: false);
      case AppPlanTier.pro:
        return currentInsights.take(4).toList(growable: false);
      case AppPlanTier.elite:
        final proInsights = kPlanCatalog[AppPlanTier.pro]!.insights.toSet();
        final eliteOnly = currentInsights
            .where((feature) => !proInsights.contains(feature))
            .toList(growable: true);
        if (eliteOnly.length < 4) {
          eliteOnly.add('Inclui tudo do Pro');
        }
        return eliteOnly.take(4).toList(growable: false);
    }
  }

  Widget _buildPlanOfferCard({
    required BuildContext sheetContext,
    required AppPlanTier tier,
    required AppPlanTier current,
    required bool isRecommended,
  }) {
    final plan = kPlanCatalog[tier]!;
    final cardHighlights = _planCardHighlights(tier);
    final accentColor = _planAccentColor(tier);
    final onAccentColor = _planOnAccentColor(tier);
    final isCurrent = tier == current;
    final isActionEnabled =
        !_isLoadingPlanSubscription && !_isStartingStoreCheckout && !isCurrent;
    final isPrimaryTrialCta =
        current == AppPlanTier.free && tier == AppPlanTier.pro;
    final actionLabel =
        isPrimaryTrialCta
            ? 'Começar teste grátis'
            : _planActionLabel(tier, current);
    final fullPriceLabel = _planPriceLabel(tier);
    final periodSeparatorIndex = fullPriceLabel.indexOf('/');
    final priceMain =
        periodSeparatorIndex > 0
            ? fullPriceLabel.substring(0, periodSeparatorIndex)
            : fullPriceLabel;
    final pricePeriod =
        periodSeparatorIndex > 0
            ? fullPriceLabel.substring(periodSeparatorIndex)
            : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: withUiOpacity(accentColor, isRecommended ? 0.48 : 0.26),
          width: isRecommended ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: withUiOpacity(accentColor, 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _planIcon(tier),
                  size: 16,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: accentColor,
                  ),
                ),
              ),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: withUiOpacity(accentColor, 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'MAIS POPULAR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: priceMain,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: GymMapColors.textStrong,
              ),
              children: [
                if (pricePeriod.isNotEmpty)
                  TextSpan(
                    text: ' $pricePeriod',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GymMapColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...cardHighlights
              .map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            color: GymMapColors.textStrong,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child:
                isCurrent
                    ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: accentColor,
                        side: BorderSide(color: withUiOpacity(accentColor, 0.42)),
                      ),
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(actionLabel),
                    )
                    : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: accentColor,
                        foregroundColor: onAccentColor,
                      ),
                      onPressed:
                          isActionEnabled
                              ? () {
                                _onPlanPicked(tier, sheetContext);
                              }
                              : null,
                      icon:
                          _isStartingStoreCheckout && tier != AppPlanTier.free
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                tier == AppPlanTier.free
                                    ? Icons.arrow_back
                                    : Icons.rocket_launch,
                              ),
                      label: Text(actionLabel),
                    ),
          ),
          if (isPrimaryTrialCta) ...[
            const SizedBox(height: 4),
            const Text(
              'Acesso imediato e cancelamento quando quiser.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: GymMapColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanComparisonMatrix() {
    const unavailableColor = Color(0xFFD64B4B);
    const rows = <({String feature, Set<AppPlanTier> available})>[
      (
        feature: 'Lotação em tempo real',
        available: {
          AppPlanTier.free,
          AppPlanTier.smart,
          AppPlanTier.pro,
          AppPlanTier.elite,
        },
      ),
      (
        feature: 'Histórico 24h',
        available: {AppPlanTier.smart, AppPlanTier.pro, AppPlanTier.elite},
      ),
      (
        feature: 'Pico e comparativo',
        available: {AppPlanTier.pro, AppPlanTier.elite},
      ),
      (feature: 'Previsão e alertas', available: {AppPlanTier.elite}),
      (feature: 'Cobertura nacional', available: {AppPlanTier.elite}),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: withUiOpacity(_planAccentColor(_activePlan), 0.12),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 340.0;
          final tierCount = AppPlanTier.values.length;
          const minTierWidth = 44.0;
          const maxTierWidth = 58.0;
          const minFeatureWidth = 108.0;
          const maxFeatureWidth = 136.0;

          var tierWidth = ((totalWidth - minFeatureWidth) / tierCount)
              .clamp(minTierWidth, maxTierWidth)
              .toDouble();
          var featureWidth = totalWidth - (tierWidth * tierCount);
          featureWidth = featureWidth.clamp(minFeatureWidth, maxFeatureWidth);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comparativo rápido',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: GymMapColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(width: featureWidth),
                  for (final tier in AppPlanTier.values)
                    SizedBox(
                      width: tierWidth,
                      child: Builder(
                        builder: (_) {
                          final accentColor = _planAccentColor(tier);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: withUiOpacity(accentColor, 0.10),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  kPlanCatalog[tier]!.label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ...rows.map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: featureWidth,
                        child: Text(
                          row.feature,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: GymMapColors.textStrong,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final tier in AppPlanTier.values)
                        SizedBox(
                          width: tierWidth,
                          child: Center(
                            child: Semantics(
                              label:
                                  row.available.contains(tier)
                                      ? 'Disponível no plano ${kPlanCatalog[tier]!.label}'
                                      : 'Indisponível no plano ${kPlanCatalog[tier]!.label}',
                              child: Icon(
                                row.available.contains(tier)
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                size: 17,
                                color:
                                    row.available.contains(tier)
                                        ? GymMapColors.occupancyLow
                                        : unavailableColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              const Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: GymMapColors.occupancyLow,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Disponível',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: GymMapColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cancel_rounded,
                        size: 14,
                        color: unavailableColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Indisponível',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: GymMapColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _openPlanSettings() {
    unawaited(_syncPlanFromStorage(showExpiryNotice: true));
    unawaited(
      _metrics.trackEvent(
        'paywall_open',
        params: <String, Object?>{
          'source': 'map_header',
          'currentPlan': _tierToPlanKey(_activePlan),
        },
      ),
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final current = _activePlan;
        final service = _planSubscriptionService;
        final hasRemoteBackend = service?.hasRemoteBackend ?? false;
        final hasAuthSession = service?.hasAuthSession ?? false;
        final promoLabel = _paywallPromoLabel();
        const recommendedTier = AppPlanTier.pro;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Desbloqueie o máximo do GymMap',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Escolha o plano ideal para lotação, previsão e comparativos.',
                    style: TextStyle(
                      fontSize: 13,
                      color: GymMapColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: withUiOpacity(
                        Theme.of(context).colorScheme.primary,
                        0.08,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 16),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '+10.000 usuários premium ativos',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: GymMapColors.textStrong,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            Icon(
                              Icons.star_half_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Nota média 4.8/5 em avaliações verificadas.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: GymMapColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (promoLabel != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: withUiOpacity(const Color(0xFFFFA500), 0.16),
                        border: Border.all(
                          color: withUiOpacity(const Color(0xFFFFA500), 0.46),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_outlined,
                            size: 16,
                            color: Color(0xFF8B5A00),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              promoLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6A4300),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    _isLoadingPlanSubscription
                        ? 'Carregando assinatura...'
                        : _activePlanStatusLabel(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GymMapColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _planAuthStatusLabel(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GymMapColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _playBillingStatusLabel(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GymMapColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              (!hasRemoteBackend ||
                                      _isLoadingPlanSubscription ||
                                      _isPlanAuthBusy)
                                  ? null
                                  : () {
                                    unawaited(_startPlanLoginFlow(context));
                                  },
                          icon:
                              _isPlanAuthBusy
                                  ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.login),
                          label: const Text('Entrar'),
                        ),
                      ),
                      if (hasAuthSession) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            onPressed:
                                _isPlanAuthBusy
                                    ? null
                                    : () {
                                      unawaited(_logoutPlanSession(context));
                                    },
                            icon: const Icon(Icons.logout),
                            label: const Text('Sair'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...AppPlanTier.values.map((tier) {
                    return _buildPlanOfferCard(
                      sheetContext: context,
                      tier: tier,
                      current: current,
                      isRecommended: tier == recommendedTier,
                    );
                  }),
                  const SizedBox(height: 4),
                  _buildPlanComparisonMatrix(),
                  const SizedBox(height: 10),
                  if (current == AppPlanTier.free) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed:
                            _isLoadingPlanSubscription ||
                                    _isStartingStoreCheckout
                                ? null
                                : () {
                                  _onPlanPicked(recommendedTier, context);
                                },
                        icon:
                            _isStartingStoreCheckout
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.rocket_launch),
                        label: const Text('Começar teste grátis'),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        current == AppPlanTier.free
                            ? 'Continuar com plano gratuito'
                            : 'Fechar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshotsByGymId = <String, GymCrowdSnapshot>{
      for (final gym in _gyms) gym.id: _crowdService.snapshotFor(gym),
    };
    final rawFilteredGyms = _filteredGyms;
    final rawFilteredMapPois = _filteredMapPois();
    final filteredGyms = _applyQuickFiltersToGyms(
      rawFilteredGyms,
      snapshotsByGymId,
    );
    final filteredMapPois = _applyQuickFiltersToPois(rawFilteredMapPois);
    final markerGyms = filteredGyms;
    final quickFilterChips = _buildQuickFilterChips();
    final hasVisiblePins =
        filteredGyms.isNotEmpty || filteredMapPois.isNotEmpty;
    final hasNoSearchResults =
        (_searchTerm.trim().isNotEmpty || _activeQuickFilters.isNotEmpty) &&
        !hasVisiblePins;
    final hasNoNearbyGyms =
        _searchTerm.trim().isEmpty && _userLocation != null && !hasVisiblePins;
    final selectedGym = _selectedGym;
    final snapshot =
        selectedGym == null
            ? null
            : snapshotsByGymId[selectedGym.id] ??
                _crowdService.snapshotFor(selectedGym);
    final activePlan = _activePlanInfo;
    final activePlanColor = _planAccentColor(_activePlan);
    final headerGradientColors = <Color>[
      Color.alphaBlend(Colors.black.withValues(alpha: 0.78), activePlanColor),
      Color.alphaBlend(Colors.black.withValues(alpha: 0.46), activePlanColor),
      Color.alphaBlend(Colors.white.withValues(alpha: 0.10), activePlanColor),
    ];
    final pageBackgroundColor = Color.alphaBlend(
      activePlanColor.withValues(alpha: 0.10),
      Colors.white,
    );

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: headerGradientColors,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  GymPageHeader(
                    planLabel: activePlan.label,
                    planBadgeColor: _planAccentColor(_activePlan),
                    planBadgeTextColor: _planOnAccentColor(_activePlan),
                    communityPoints: _communityPoints,
                    onOpenPlanSettings: _openPlanSettings,
                    onOpenCommunityRanking: _openCommunityLeaderboard,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: pageBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableHeight = constraints.maxHeight;
                          final minPanelHeight =
                              (availableHeight * 0.38).clamp(150.0, 220.0)
                                  .toDouble();
                          final maxPanelHeight =
                              (availableHeight - 132).clamp(
                                    minPanelHeight,
                                    availableHeight,
                                  )
                                  .toDouble();
                          final panelHeight =
                              (availableHeight * (_panelFlex / _layoutTotalFlex))
                                  .clamp(minPanelHeight, maxPanelHeight)
                                  .toDouble();

                          return Stack(
                            children: [
                              Positioned.fill(
                                child: _buildMap(
                                  markerGyms,
                                  snapshotsByGymId,
                                  filteredMapPois,
                                ),
                              ),
                              Positioned(
                                left: 14,
                                top: 12,
                                right: 14,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    GymSearchField(
                                      controller: _searchController,
                                      searchTerm: _searchTerm,
                                      isResolvingSearchLocation:
                                          _isResolvingSearchLocation,
                                      onChanged: _updateSearchTerm,
                                      onSubmitted: _submitSearch,
                                      onClear: _clearSearch,
                                      onSearchTap:
                                          () => _submitSearch(
                                            _searchController.text,
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      child: MapQuickFiltersBar(
                                        key: ValueKey<int>(
                                          _activeQuickFilters.length,
                                        ),
                                        filters: quickFilterChips,
                                        onToggle: _toggleQuickFilterById,
                                      ),
                                    ),
                                    if (_isFreePlan) ...[
                                      const SizedBox(height: 8),
                                      const AdBannerCard(),
                                    ],
                                  ],
                                ),
                              ),
                              if (selectedGym == null)
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 10,
                                  child: SelectionHintCard(
                                    hasNoResults: hasNoSearchResults,
                                    hasNoNearbyGyms: hasNoNearbyGyms,
                                    hasActiveFilters:
                                        _activeQuickFilters.isNotEmpty,
                                    onClearFilters: _clearAllQuickFilters,
                                  ),
                                )
                              else
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 10,
                                  child: AnimatedContainer(
                                    height: panelHeight,
                                    duration:
                                        _isPanelDragging
                                            ? Duration.zero
                                            : const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    transform: Matrix4.translationValues(
                                      0,
                                      _panelDragOffset,
                                      0,
                                    ),
                                    transformAlignment: Alignment.topCenter,
                                    child: _buildSelectedGymPanel(
                                      selectedGym,
                                      snapshot!,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child:
                    _showContributionCelebration
                        ? _ContributionCelebrationOverlay(
                          key: ValueKey<int>(_contributionCelebrationTick),
                        )
                        : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                  isFavorite: _isFavoriteGymId(gym.id),
                  selected: gym.id == _selectedGym?.id,
                  revealDetails: _showMarkerDetails,
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
                _selectedGym?.position ?? _userLocation ?? _fallbackMapCenter,
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
              key: ValueKey<String>('tile-layer-$_mapVisualReloadTick'),
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
    return _mapMarkerBodyAnchorOffset * markerScale;
  }

  double _mapControlsTopOffset(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final normalizedScale = textScale.clamp(1.0, 1.25).toDouble();
    final searchAndFilterHeight = (56 * normalizedScale) + 10 + (52 * normalizedScale);
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

  Marker _buildPoiMarker(
    MapGymPoi poi, {
    required double markerBaseWidth,
    required double markerBaseHeight,
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
            isFavorite: _isFavoriteGymId(poiGym.id),
            selected: poiGym.id == _selectedGym?.id,
            revealDetails: _showMarkerDetails,
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

  void _openRouteForGym(Gym gym) {
    _moveMapTo(gym.position, 15.6);
    final userPoint = _userLocation;
    if (userPoint == null) {
      _showMapSnack(
        'Rota exibida no mapa. Ative sua localização para ver distância estimada.',
      );
      return;
    }
    final distanceKm =
        math.sqrt(_distanceSquaredMeters(userPoint, gym.position)) / 1000;
    final distanceLabel =
        distanceKm < 1
            ? '${(distanceKm * 1000).round()} m'
            : '${distanceKm.toStringAsFixed(1)} km';
    _showMapSnack('Rota para ${gym.name}: aproximadamente $distanceLabel.');
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
        setState(() {
          _reportPercent = value;
        });
      },
      isSubmittingCrowdReport: _isSubmittingCrowdReport,
      onSubmitCrowdReport: _submitCrowdReport,
      onOpenRoute: () => _openRouteForGym(gym),
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

class _ContributionCelebrationOverlay extends StatelessWidget {
  const _ContributionCelebrationOverlay({super.key});

  static const List<_CelebrationParticleData> _particles =
      <_CelebrationParticleData>[
        _CelebrationParticleData(
          end: Offset(-72, -94),
          icon: Icons.auto_awesome_rounded,
          color: Color(0xFFFFC94A),
          size: 18,
        ),
        _CelebrationParticleData(
          end: Offset(-44, -112),
          icon: Icons.circle,
          color: Color(0xFF93B4D9),
          size: 8,
        ),
        _CelebrationParticleData(
          end: Offset(-16, -126),
          icon: Icons.bolt_rounded,
          color: Color(0xFF4A7DBA),
          size: 16,
        ),
        _CelebrationParticleData(
          end: Offset(12, -128),
          icon: Icons.star_rounded,
          color: Color(0xFFFFB74D),
          size: 15,
        ),
        _CelebrationParticleData(
          end: Offset(40, -116),
          icon: Icons.circle,
          color: Color(0xFF6A9ACF),
          size: 9,
        ),
        _CelebrationParticleData(
          end: Offset(68, -96),
          icon: Icons.emoji_events_rounded,
          color: Color(0xFFE09F3E),
          size: 18,
        ),
        _CelebrationParticleData(
          end: Offset(-84, -64),
          icon: Icons.favorite_rounded,
          color: Color(0xFFCC4A37),
          size: 14,
        ),
        _CelebrationParticleData(
          end: Offset(82, -66),
          icon: Icons.favorite_rounded,
          color: Color(0xFFCC4A37),
          size: 14,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final fadeOut = (1 - t).clamp(0.0, 1.0).toDouble();
        final pulse = (1 - (t - 0.35).abs().clamp(0.0, 1.0)).toDouble();
        return Opacity(
          opacity: fadeOut,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 86),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54 + (t * 14),
                    height: 54 + (t * 14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: withUiOpacity(GymMapColors.occupancyLow, 0.15),
                    ),
                  ),
                  for (var i = 0; i < _particles.length; i++)
                    _CelebrationParticle(
                      data: _particles[i],
                      progress: t,
                      spinDirection: i.isEven ? 1 : -1,
                    ),
                  Transform.scale(
                    scale: 0.9 + (0.2 * pulse),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: withUiOpacity(Colors.white, 0.96),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 10,
                            offset: Offset(0, 3),
                            color: GymMapColors.cardShadow,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        color: GymMapColors.occupancyLow,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CelebrationParticleData {
  const _CelebrationParticleData({
    required this.end,
    required this.icon,
    required this.color,
    required this.size,
  });

  final Offset end;
  final IconData icon;
  final Color color;
  final double size;
}

class _CelebrationParticle extends StatelessWidget {
  const _CelebrationParticle({
    required this.data,
    required this.progress,
    required this.spinDirection,
  });

  final _CelebrationParticleData data;
  final double progress;
  final int spinDirection;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOut.transform(progress);
    final drift = Offset(data.end.dx * eased, data.end.dy * eased);
    final scale = 0.7 + (0.5 * (1 - progress));
    final angle = progress * spinDirection * 1.3;

    return Transform.translate(
      offset: drift,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: Icon(
            data.icon,
            size: data.size,
            color: withUiOpacity(data.color, 0.92),
          ),
        ),
      ),
    );
  }
}
