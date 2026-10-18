import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;

import '../../../core/analytics/app_metrics_service.dart';
import '../../../core/l10n/l10n.dart';
import '../data/collaborative_crowd_service.dart';
import '../data/contextual_push_notification_service.dart';
import '../data/crowd_report_remote_service.dart';
import '../data/map/basemap_style_filter.dart';
import '../data/map/map_vector_style_service.dart';
import '../data/map/vector_map_style_loader.dart';
import '../data/gym_route_service.dart';
import '../data/map_services_config.dart';
import '../data/plan_subscription_service.dart';
import '../domain/gym_models.dart';
import '../domain/opening_hours.dart';
import '../domain/plan_insight_models.dart';
import 'gym_map_colors.dart';
import 'gym_map_helpers.dart';
import 'gym_map_logic.dart';
import 'gym_map_poi_controller.dart';
import 'gym_map_poi_reload_controller.dart';
import 'gym_map_search_state_controller.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/amenity_vote_sheet.dart';
import 'widgets/gym_marker_bubble.dart';
import 'widgets/gym_page_sections.dart';
import 'widgets/map_controls.dart';
import 'widgets/selected_gym_panel.dart';
import 'widgets/suggested_gym_marker.dart';

part 'gym_map_page_models.dart';
part 'gym_map_page_preferences.dart';
part 'gym_map_page_location.dart';
part 'gym_map_page_map_view.dart';
part 'gym_map_page_celebration.dart';
part 'gym_map_page_search.dart';
part 'gym_map_page_filters.dart';
part 'gym_map_page_interactions.dart';
part 'gym_map_page_state_cache.dart';
part 'gym_map_page_community.dart';
part 'gym_map_page_plan.dart';
part 'gym_map_page_amenities.dart';
part 'gym_map_page_suggestions.dart';

/// Traduções do idioma em uso (válido também depois de `await`).
AppLocalizations get _t => AppL10n.current;

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
  static const LatLng _fallbackMapCenter = LatLng(-14.2350, -51.9253);
  static const double _fallbackMapZoom = 4.2;
  static const double _minZoomForAreaPoiSearch = 12.0;
  static const String _localReporterId = 'local-device-user';
  static const String _mapTutorialSeenPrefKey = 'gymmap_map_tutorial_seen_v1';
  static const String _initialLocationPromptDonePrefKey =
      'gymmap_initial_location_prompt_done_v1';
  static const String _favoriteGymIdsPrefKey = 'gymmap_favorite_gym_ids_v1';
  static const String _favoriteGymNamesPrefKey = 'gymmap_favorite_gym_names_v1';
  static const String _communityPointsPrefKey = 'gymmap_community_points_v1';
  static const String _dataSaverPrefKey = 'gymmap_pref_data_saver_v1';
  static const String _quickFiltersPrefKey = 'gymmap_quick_filters_v1';
  static const String _hiddenBasemapPoiCategoriesPrefKey =
      'gymmap_hidden_basemap_poi_categories_v1';
  static const bool _autoShowMapTutorialOnStartup = false;
  static const double _defaultCoverageRadiusMeters = 50000;
  static const double _eliteCoverageRadiusMeters = 6000000;
  // Cada busca cobre 25 km em volta do centro; só busca de novo depois de
  // andar boa parte disso.
  static const double _mapPoiReloadMinDistanceMeters = 8000;
  // Academias já carregadas ficam na memória até este raio do centro, para
  // não sumirem quando uma nova busca chega.
  static const double _mapPoiRetentionRadiusMeters = 40000;
  static const int _maxRetainedMapPois = 400;
  // Com pelo menos isto de academias na lista compartilhada, a área já está
  // mapeada e o Overpass público não é consultado.
  static const int _minSharedGymsToSkipOverpass = 5;
  // Trajeto em andamento: a localização é acompanhada de perto e, se a
  // pessoa se afastar da linha, uma nova rota é calculada.
  static const double _routeTrackingDistanceFilterMeters = 10;
  static const Duration _routeTrackingInterval = Duration(seconds: 3);
  static const double _offRouteWalkingMeters = 40;
  static const double _offRouteDrivingMeters = 70;
  static const Duration _rerouteCooldown = Duration(seconds: 12);
  static const double _routeArrivalMeters = 30;
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
  static const Duration _coverageLockSnackCooldown = Duration(seconds: 8);
  static const double _backgroundLocationDistanceFilterMeters = 35;
  static const double _backgroundLocationUiRefreshMinDistanceMeters = 25;
  static const double _dataSaverPoiReloadMinDistanceMeters = 3200;
  // Distância entre a ponta do `assets/brand/pin.png` e a base do `GymMarkerBubble`:
  // 3 de padding + 17 entre a base da imagem (32 px) e a base da área de 66 px.
  static const double _mapMarkerPinTipInset = 20;
  static const int _maxMapPoiMarkers = 90;
  static const int _maxMapPoiMarkersZoomedOut = 48;
  static const int _layoutTotalFlex = 100;
  static const int _panelMinFlex = 42;

  /// Pessoas que precisam marcar "tem" para a comodidade valer para todos
  /// (o servidor usa o mesmo número).
  static const int _amenityConfirmThreshold = 3;
  static const int _panelMaxFlex = 66;
  static const double _panelFlexDragSensitivity = 0.28;
  static const double _panelDragPixelThreshold = 3;
  static const int _maxMarkersForPulseAnimation = 34;
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

  // Controlador do mapa vetorial (flutter_map + vector_map_tiles).
  final MapController _mapController = MapController();
  final VectorMapStyleLoader _vectorMapStyleLoader = VectorMapStyleLoader();

  // O que fica por cima do mapa; medido para centralizar na área livre.
  final GlobalKey _mapTopOverlayKey = GlobalKey();
  final GlobalKey _mapHintCardKey = GlobalKey();
  final GlobalKey _routeOverlayKey = GlobalKey();
  double _mapAreaHeight = 0;

  // Trajeto até a academia, desenhado no próprio mapa.
  final GymRouteService _routeService = GymRouteService();
  GymRoute? _activeRoute;
  Gym? _routeGym;
  bool _isRouteCardOpen = false;
  DateTime? _lastRerouteAt;
  GymRouteMode _routeMode = GymRouteMode.walking;
  bool _isLoadingRoute = false;
  int _routeRequestId = 0;
  vmt.Style? _vectorMapStyle;
  bool _vectorMapFailed = false;
  // Categorias de pontos de interesse do mapa base (paradas de ônibus,
  // lojas...) escondidas; por padrão o mapa mostra só as academias do app.
  Set<BasemapPoiCategory> _hiddenBasemapPoiCategories =
      BasemapPoiCategory.values.toSet();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Serviço que agrega relatos colaborativos de lotação.
  final CollaborativeCrowdService _crowdService =
      CollaborativeCrowdService.withSeedData();
  final GymMapPoiController _mapPoiController = GymMapPoiController();
  CrowdReportRemoteService? _crowdReportRemoteService;

  // Votos da comunidade nas comodidades, por academia, e o saldo de pontos
  // no servidor (null sem servidor; aí vale _communityPoints).
  final Map<String, List<GymAmenityVotes>> _amenityVotesByGymId =
      <String, List<GymAmenityVotes>>{};
  RemoteRewards? _rewards;

  // Academias sugeridas por perto e o modo de posicionar uma nova.
  List<GymSuggestion> _gymSuggestions = const <GymSuggestion>[];
  bool _isPlacingSuggestion = false;
  LatLng? _suggestionsLoadedAround;
  DateTime? _suggestionsLoadedAt;
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
  // Último gesto da pessoa no mapa; movimentos automáticos (GPS) que
  // chegarem depois dele não puxam a câmera de volta.
  DateTime? _lastMapGestureAt;
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

  // Horários já lidos, pela etiqueta opening_hours (null = não entendido).
  final Map<String, OpeningHours?> _parsedOpeningHours =
      <String, OpeningHours?>{};
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
  DateTime? _lastCoverageLockSnackAt;
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
  int _mapPoisRevision = 0;
  int _crowdDataRevision = 0;
  String? _mapDerivedDataCacheKey;
  _MapDerivedData? _mapDerivedDataCache;
  SharedPreferences? _prefsCache;
  Future<SharedPreferences>? _prefsFuture;
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
    unawaited(_initializeVectorMap());
    unawaited(_loadBasemapPoiPreference());
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
    final initialZoom = bootstrapUserLocation != null ? 14.8 : _fallbackMapZoom;

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
    _routeService.dispose();
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

  @override
  Widget build(BuildContext context) {
    final derivedMapData = _resolveMapDerivedData();
    final snapshotsByGymId = derivedMapData.snapshotsByGymId;
    final filteredGyms = derivedMapData.filteredGyms;
    final filteredMapPois = derivedMapData.filteredMapPois;
    // Com trajeto, só o destino fica no mapa.
    final routeGym = _routeGym;
    var markerGyms = filteredGyms;
    var markerPois = filteredMapPois;
    if (routeGym != null) {
      markerGyms = [
        for (final gym in filteredGyms)
          if (gym.id == routeGym.id) gym,
      ];
      markerPois = [
        for (final poi in filteredMapPois)
          if (poi.id == routeGym.id) poi,
      ];
      if (markerGyms.isEmpty && markerPois.isEmpty) {
        markerGyms = [routeGym];
      }
    }
    final quickFilterChips = _buildQuickFilterChips();
    final hasVisiblePins =
        filteredGyms.isNotEmpty || filteredMapPois.isNotEmpty;
    final hasNoSearchResults =
        (_searchTerm.trim().isNotEmpty || _activeQuickFilters.isNotEmpty) &&
        !hasVisiblePins;
    final hasNoNearbyGyms =
        _searchTerm.trim().isEmpty && _userLocation != null && !hasVisiblePins;
    final needsLocationForNearbyGyms =
        _searchTerm.trim().isEmpty &&
        !_hasNationwideCoverage &&
        _userLocation == null &&
        !hasVisiblePins &&
        _hasCompletedInitialLocationAttempt;
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
                    communityPoints: _displayedCommunityPoints,
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
                          _mapAreaHeight = constraints.maxHeight;
                          final panelHeight = _selectedPanelHeight();

                          return Stack(
                            children: [
                              Positioned.fill(
                                child: _buildMap(
                                  markerGyms,
                                  snapshotsByGymId,
                                  markerPois,
                                ),
                              ),
                              Positioned(
                                left: 14,
                                top: 12,
                                right: 14,
                                child: Column(
                                  key: _mapTopOverlayKey,
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
                              // Com trajeto, o cartão da rota ocupa a parte
                              // de baixo; a dica não aparece.
                              if (selectedGym == null && routeGym == null)
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 10,
                                  child: SelectionHintCard(
                                    key: _mapHintCardKey,
                                    hasNoResults: hasNoSearchResults,
                                    hasNoNearbyGyms: hasNoNearbyGyms,
                                    needsLocationForNearbyGyms:
                                        needsLocationForNearbyGyms,
                                    hasActiveFilters:
                                        _activeQuickFilters.isNotEmpty,
                                    onClearFilters: _clearAllQuickFilters,
                                  ),
                                )
                              else if (selectedGym != null)
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
}
