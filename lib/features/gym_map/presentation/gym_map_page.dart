import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/collaborative_crowd_service.dart';
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

class GymMapPage extends StatefulWidget {
  const GymMapPage({super.key, required this.showMap});

  final bool showMap;

  @override
  State<GymMapPage> createState() => _GymMapPageState();
}

enum AppPlanTier { free, smart, pro, elite }

enum MapQuickFilter { lowCrowd, withClasses, withCardio, withPool }

class PlanInfo {
  const PlanInfo({
    required this.label,
    required this.monthlyPrice,
    required this.insights,
  });

  final String label;
  final String monthlyPrice;
  final List<String> insights;
}

const Map<AppPlanTier, PlanInfo> kPlanCatalog = {
  AppPlanTier.free: PlanInfo(
    label: 'Grátis',
    monthlyPrice: 'R\$ 0/mês',
    insights: ['Lotação atual'],
  ),
  AppPlanTier.smart: PlanInfo(
    label: 'Smart',
    monthlyPrice: 'R\$ 4,90/mês',
    insights: ['Lotação atual', 'Histórico das últimas 24h'],
  ),
  AppPlanTier.pro: PlanInfo(
    label: 'Pro',
    monthlyPrice: 'R\$ 9,90/mês',
    insights: [
      'Lotação atual',
      'Histórico das últimas 24h',
      'Horários de pico por dia',
      'Comparativo entre academias',
    ],
  ),
  AppPlanTier.elite: PlanInfo(
    label: 'Elite',
    monthlyPrice: 'R\$ 14,90/mês',
    insights: [
      'Lotação atual',
      'Histórico das últimas 24h',
      'Horários de pico por dia',
      'Comparativo entre academias',
      'Previsão de lotação para próximas horas',
      'Cobertura em qualquer lugar do pais',
      'Alertas personalizados',
    ],
  ),
};

class _GymMapPageState extends State<GymMapPage> with WidgetsBindingObserver {
  static const LatLng _fallbackMapCenter = LatLng(-23.5615, -46.6560);
  static const String _localReporterId = 'local-device-user';
  static const String _mapTutorialSeenPrefKey = 'gymmap_map_tutorial_seen_v1';
  static const String _favoriteGymIdsPrefKey = 'gymmap_favorite_gym_ids_v1';
  static const String _communityPointsPrefKey = 'gymmap_community_points_v1';
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

  // Servico que agrega relatos colaborativos de lotação.
  final CollaborativeCrowdService _crowdService =
      CollaborativeCrowdService.withSeedData();
  final GymMapPoiController _mapPoiController = GymMapPoiController();
  CrowdReportRemoteService? _crowdReportRemoteService;
  bool _isSyncingCrowdReports = false;
  bool _isSubmittingCrowdReport = false;
  int _communityPoints = 0;
  final Set<String> _favoriteGymIds = <String>{};
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

  // Coordenada atual do usuario (quando permitida).
  LatLng? _userLocation;

  // Estado de carregamento da geolocalização para bloquear clique repetido.
  bool _isLocating = false;
  bool _isMapReady = false;
  bool _hasCompletedInitialLocationAttempt = false;
  bool _hasRunOpeningSearchIntro = false;
  bool _showMarkerDetails = false;
  bool _skipNextMapTapClear = false;
  bool _isPanelDragging = false;
  int _panelFlex = _panelMinFlex;
  double _panelDragOffset = 0;
  List<MapGymPoi> _mapPois = const [];
  final Map<String, Gym> _generatedGymsByPoiId = <String, Gym>{};
  bool _isResolvingSearchLocation = false;
  bool _hasLoadedMapTutorialState = false;
  bool _hasSeenMapTutorial = false;
  bool _showMapTutorialOverlay = false;
  Timer? _mapBrowseCenterUiDebounce;
  Timer? _mapTutorialDismissTimer;
  Timer? _planSyncTimer;
  StreamSubscription<List<PurchaseDetails>>? _purchaseStreamSubscription;

  // Plano atual do usuario para liberar informacoes e propaganda.
  AppPlanTier _activePlan = AppPlanTier.free;
  DateTime? _activePlanExpiresAtUtc;
  PlanSubscriptionService? _planSubscriptionService;
  bool _isLoadingPlanSubscription = true;
  bool _isStartingStoreCheckout = false;
  bool _isPlayStoreAvailable = false;
  bool _isLoadingPlayProducts = false;
  List<ProductDetails> _playProducts = const <ProductDetails>[];
  final Set<String> _processingPlayPurchases = <String>{};
  bool _isPlanAuthBusy = false;
  String? _lastPlanExpiryWarningKey;
  int _mapVisualReloadTick = 0;

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
    unawaited(_initializeGymLocationCache());
    unawaited(_initializeCrowdRemoteService());
    unawaited(_initializePlanSubscription());
    unawaited(_initializePlayStoreBilling());
    if (widget.showMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerMapOnDeviceLocation();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncPlanFromStorage(showExpiryNotice: false));
      unawaited(_reloadMapImages());
      unawaited(_refreshGymLocationCacheFromRemote());
      unawaited(_syncCrowdReportsForCurrentContext());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapBrowseCenterUiDebounce?.cancel();
    _mapTutorialDismissTimer?.cancel();
    _planSyncTimer?.cancel();
    _purchaseStreamSubscription?.cancel();
    _mapPoiReloadController.dispose();
    _mapPoiController.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Algoritmo de busca local:
  /// - normaliza para minusculas;
  /// - se vazio, retorna todas as academias;
  /// - senao, filtra por nome ou endereco.
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
      // Falha de inicializacao remota nao bloqueia experiencia local.
    }
  }

  Future<void> _syncCrowdReportsForCurrentContext() async {
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
        if (merged > 0 && mounted) {
          setState(() {});
        }
      }
    } catch (_) {
      // Falha de rede remota nao deve interromper fluxo local.
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
      // Falha de cache local nao deve bloquear o mapa.
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
      // Falha de cache local nao deve bloquear o mapa.
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
          // Falha de rede/API nao deve travar o fluxo local do mapa.
          return false;
        }
      },
    );
  }

  void _scheduleMapPoiReload(LatLng center, {bool force = false}) {
    if (!widget.showMap) {
      return;
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
        setState(() {});
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

  MapQuickFilter? _quickFilterFromId(String id) {
    switch (id) {
      case 'low':
        return MapQuickFilter.lowCrowd;
      case 'classes':
        return MapQuickFilter.withClasses;
      case 'cardio':
        return MapQuickFilter.withCardio;
      case 'pool':
        return MapQuickFilter.withPool;
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
    setState(() {
      if (_activeQuickFilters.contains(filter)) {
        _activeQuickFilters.remove(filter);
      } else {
        _activeQuickFilters.add(filter);
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
  }

  List<QuickFilterChipData> _buildQuickFilterChips() {
    return <QuickFilterChipData>[
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
        label: 'Piscina',
        icon: Icons.pool_outlined,
        selected: _activeQuickFilters.contains(MapQuickFilter.withPool),
      ),
    ];
  }

  bool _samePoiList(List<MapGymPoi> left, List<MapGymPoi> right) {
    return GymMapLogic.samePoiList(left, right);
  }

  void _setMapPoisIfChanged(List<MapGymPoi> nextPois) {
    if (!mounted || _samePoiList(_mapPois, nextPois)) {
      return;
    }
    setState(() {
      _mapPois = List<MapGymPoi>.unmodifiable(nextPois);
    });
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
      // Ignora quando o controlador ainda nao está conectado ao widget do mapa.
    }
  }

  /// Corrige somente orientacao para norte (0 graus), sem alterar centro/zoom.
  void _resetNorthOrientation() {
    if (!widget.showMap) {
      return;
    }
    try {
      _mapController.rotate(0);
    } catch (_) {
      // Ignora quando o controlador ainda nao está conectado ao widget do mapa.
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
      // Falha de leitura local nao impede o app.
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
    try {
      final prefs = await SharedPreferences.getInstance();
      ids = prefs.getStringList(_favoriteGymIdsPrefKey) ?? const <String>[];
    } catch (_) {
      // Falha local nao impede uso dos favoritos na sessao atual.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _favoriteGymIds
        ..clear()
        ..addAll(ids.map((id) => id.trim()).where((id) => id.isNotEmpty));
    });
  }

  Future<void> _persistFavoriteGymIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _favoriteGymIds.toList(growable: false)..sort();
      await prefs.setStringList(_favoriteGymIdsPrefKey, ids);
    } catch (_) {
      // Falha local de persistencia nao deve interromper fluxo.
    }
  }

  Future<void> _loadCommunityPoints() async {
    var points = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      points = prefs.getInt(_communityPointsPrefKey) ?? 0;
    } catch (_) {
      // Falha local nao bloqueia uso.
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
      // Falha local nao bloqueia uso.
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
        added = false;
      } else {
        _favoriteGymIds.add(id);
        added = true;
      }
    });
    HapticFeedback.lightImpact();
    _showMapSnack(
      added
          ? '${gym.name} adicionada aos favoritos.'
          : '${gym.name} removida dos favoritos.',
    );
    unawaited(_persistFavoriteGymIds());
  }

  void _maybeShowMapTutorialOverlay() {
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
    _mapTutorialDismissTimer?.cancel();
    _mapTutorialDismissTimer = Timer(const Duration(seconds: 8), () {
      _dismissMapTutorialOverlay();
    });
  }

  Future<void> _dismissMapTutorialOverlay({bool persist = true}) async {
    _mapTutorialDismissTimer?.cancel();
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
      // Falha de escrita local nao interrompe o fluxo.
    }
  }

  void _highlightNearestGymFromTutorial() {
    final gyms = _filteredGyms;
    final origin = _userLocation ?? _fallbackMapCenter;
    final nearest = _nearestGymTo(origin, gyms);
    if (nearest == null) {
      _showMapSnack('Nenhuma academia disponivel para destacar agora.');
      return;
    }
    unawaited(_dismissMapTutorialOverlay());
    _selectGym(nearest);
  }

  void _maybeStartOpeningSearchIntro() {
    if (!widget.showMap ||
        !_isMapReady ||
        !_hasCompletedInitialLocationAttempt ||
        _hasRunOpeningSearchIntro ||
        _userLocation != null) {
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
    final remoteService = _crowdReportRemoteService;
    try {
      if (remoteService != null && remoteService.hasRemoteBackend) {
        try {
          final remoteResult = await remoteService.submitReport(
            gymId: selectedGym.id,
            occupancyPercent: report,
            reporterId: reporterId,
          );
          if (!remoteResult.accepted) {
            final retryAfter =
                remoteResult.retryAfter ?? const Duration(minutes: 1);
            final waitMinutes =
                retryAfter.inMinutes >= 1 ? retryAfter.inMinutes : 1;
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
            _syncCrowdReportsForGyms(
              _crowdSyncGymIds(extraGymIds: [selectedGym.id]),
            ),
          );
          return;
        } catch (_) {
          // Sem rede/backend: segue fluxo local para nao perder envio do usuario.
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
  /// 1) valida servico de GPS;
  /// 2) valida/solicita permissao;
  /// 3) centraliza usando cache/ultima posicao conhecida quando disponivel;
  /// 4) obtem posicao atual para refino.
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

  Future<void> _centerMapOnDeviceLocation() async {
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
        if (!hasImmediateCenter) {
          _showMapSnack('Ative o GPS para centralizar sua localização.');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!hasImmediateCenter) {
          if (permission == LocationPermission.deniedForever) {
            _showMapSnack(
              'Permissao de localização negada permanentemente. Ajuste nas configuracoes do aparelho.',
            );
          } else {
            _showMapSnack('Permissao de localização negada.');
          }
        }
        return;
      }

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
      if (!hasImmediateCenter) {
        _showMapSnack(
          'Tempo esgotado ao obter localização. Tente novamente em instantes.',
        );
      }
    } catch (_) {
      if (!hasImmediateCenter) {
        _showMapSnack('Nao foi possivel obter sua localização no momento.');
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

  void _showMapSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
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
    return 'Valido ate ${_formatDateTimeLabel(_activePlanExpiresAtUtc!)}';
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
      'Seu plano $planLabel expira em $windowLabel. Renovacao somente manual, quando você decidir.',
    );
  }

  String _planAuthStatusLabel() {
    final service = _planSubscriptionService;
    if (service == null) {
      return 'Autenticacao ainda inicializando';
    }
    if (service.isProductionMode && !service.hasRemoteBackend) {
      return 'Modo producao ativo sem backend remoto configurado';
    }
    if (!service.hasRemoteBackend) {
      return 'Backend remoto nao configurado no app';
    }
    if (service.isProductionMode && !service.hasAuthSession) {
      return 'Modo producao exige sessao autenticada';
    }
    if (service.hasAuthSession) {
      return 'Sessao ativa para ${service.userId}';
    }
    return 'Sessao nao autenticada';
  }

  String _playBillingStatusLabel() {
    if (_isLoadingPlayProducts) {
      return 'Google Play: carregando produtos...';
    }
    if (!_isPlayStoreAvailable) {
      return 'Google Play indisponivel neste aparelho.';
    }
    if (_playProducts.length < _planProductIds.length) {
      return 'Google Play: um ou mais produtos ainda nao encontrados.';
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
        _showMapSnack('Nao foi possivel carregar produtos do Google Play.');
      } else if (response.notFoundIDs.isNotEmpty) {
        _showMapSnack(
          'Produtos nao encontrados no Google Play: ${response.notFoundIDs.join(', ')}',
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
        return 'Usuario ou senha invalidos.';
      case 'missing_credentials':
        return 'Informe usuario e senha.';
      case 'unauthorized':
        return 'Sessao nao autorizada.';
      case '':
        return 'Falha de autenticacao';
      default:
        return normalized;
    }
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
        return 'Modo producao exige backend remoto configurado.';
      case 'backend_required_for_play_billing':
        return 'Checkout no Google Play exige backend remoto configurado.';
      case 'user_identity_required_in_production':
        return 'Modo producao exige usuario autenticado.';
      case 'play_store_unavailable':
        return 'Google Play indisponivel neste aparelho.';
      case 'play_product_not_found':
        return 'Produto de assinatura nao encontrado no Google Play.';
      case 'play_checkout_not_started':
        return 'Nao foi possivel iniciar checkout no Google Play.';
      case 'play_product_id_missing':
        return 'Produto da assinatura nao informado.';
      case 'play_purchase_token_missing':
        return 'Token de compra ausente. Tente novamente.';
      case 'play_purchase_not_active':
        return 'Compra ainda nao esta ativa no Google Play.';
      case 'play_purchase_not_found':
        return 'Compra nao encontrada no Google Play.';
      case 'play_product_mismatch':
        return 'Produto da compra nao corresponde ao plano selecionado.';
      case 'play_package_mismatch':
        return 'Compra vinculada a outro aplicativo.';
      case 'play_api_unauthorized':
        return 'Backend sem permissao para validar Google Play. Verifique credenciais.';
      case 'play_validation_unavailable':
      case 'play_api_unavailable':
        return 'Nao foi possivel validar a compra no Google Play agora.';
      case 'payment_pending_webhook':
        return 'Pagamento ainda nao confirmado pelo webhook. Aguarde alguns segundos e tente novamente.';
      case 'pix_provider_unavailable':
        return 'Gateway Pix indisponivel no momento. Tente novamente em instantes.';
      case 'invalid_webhook_signature':
        return 'Webhook do pagamento invalido. Contate o suporte.';
      case 'unauthorized':
      case 'forbidden':
        return 'Sessao expirada ou sem permissao. Faca login novamente.';
      default:
        if (normalized == 'Backend HTTP 401') {
          return 'Sessao expirada. Faca login novamente.';
        }
        if (normalized == 'Backend HTTP 429') {
          return 'Limite de tentativas atingido. Aguarde um pouco e tente novamente.';
        }
        if (normalized.isEmpty) {
          return 'Nao foi possivel processar a assinatura agora.';
        }
        return normalized;
    }
  }

  Future<void> _initializePlanSubscription() async {
    try {
      final service = await PlanSubscriptionService.create();
      final snapshot = await service.loadActiveSubscription();
      if (!mounted) {
        return;
      }
      setState(() {
        _planSubscriptionService = service;
        _activePlan = _tierFromPlanKey(snapshot.activePlanKey);
        _activePlanExpiresAtUtc = snapshot.expiresAt;
        _isLoadingPlanSubscription = false;
      });
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
      _showMapSnack('Backend remoto nao configurado para login.');
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
                    errorMessage = 'Informe usuario e senha';
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
                        labelText: 'Usuario',
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
      _showMapSnack('Nao existe sessao autenticada.');
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
      _showMapSnack('Sessao encerrada.');
    } catch (_) {
      _showMapSnack('Nao foi possivel encerrar sessao agora.');
    } finally {
      if (mounted) {
        setState(() {
          _isPlanAuthBusy = false;
        });
      }
    }
  }

  void _onPlanPicked(AppPlanTier selectedTier, BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    if (selectedTier == AppPlanTier.free) {
      unawaited(_activateFreePlan());
      return;
    }
    unawaited(_startStoreCheckout(selectedTier));
  }

  Future<void> _startStoreCheckout(AppPlanTier tier) async {
    final service = _planSubscriptionService;
    if (service == null) {
      _showMapSnack('Assinatura ainda esta inicializando. Tente novamente.');
      return;
    }
    if (_isStartingStoreCheckout) {
      return;
    }
    if (!_isPlayStoreAvailable) {
      _showMapSnack(
        _formatBillingFailure(StateError('play_store_unavailable')),
      );
      return;
    }
    final productId = _planProductIds[tier];
    if (productId == null || productId.trim().isEmpty) {
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
      if (!mounted) {
        return;
      }
      _showMapSnack('Finalize o pagamento no Google Play para ativar o plano.');
    } catch (error) {
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
          if (errorMessage != null && errorMessage.isNotEmpty) {
            _showMapSnack(errorMessage);
          } else {
            _showMapSnack('Falha ao processar compra no Google Play.');
          }
          continue;
        case PurchaseStatus.canceled:
          _showMapSnack('Pagamento cancelado no Google Play.');
          continue;
      }
    }
  }

  Future<void> _processPlayPurchase(PurchaseDetails purchase) async {
    final service = _planSubscriptionService;
    if (service == null) {
      _showMapSnack('Assinatura ainda esta inicializando. Tente novamente.');
      return;
    }
    final token = purchase.verificationData.serverVerificationData.trim();
    final productId = purchase.productID.trim();
    final tier = _tierFromProductId(productId);
    if (tier == null) {
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
      _showMapSnack(
        'Assinatura ${kPlanCatalog[tier]!.label} ativada com sucesso.',
      );
      await _completePlayPurchaseIfNeeded(purchase);
    } catch (error) {
      if (!mounted) {
        return;
      }
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
        'Compra validada, mas nao foi possivel finalizar no Google Play.',
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
    setState(() {
      _activePlan = _tierFromPlanKey(snapshot.activePlanKey);
      _activePlanExpiresAtUtc = snapshot.expiresAt;
    });
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
      return 'R\$ 0/mes';
    }
    final playProduct = _playProductForTier(tier);
    if (playProduct != null) {
      final price = playProduct.price.trim();
      if (price.isNotEmpty) {
        return '$price/mes';
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
          ? 'Continuar gratis'
          : 'Voltar ao gratuito';
    }
    if (_planTierWeight(tier) > _planTierWeight(current)) {
      return current == AppPlanTier.free ? 'Assinar' : 'Fazer upgrade';
    }
    return 'Trocar plano';
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

  Widget _buildPlanOfferCard({
    required BuildContext sheetContext,
    required AppPlanTier tier,
    required AppPlanTier current,
    required bool isRecommended,
  }) {
    final plan = kPlanCatalog[tier]!;
    final isCurrent = tier == current;
    final isActionEnabled =
        !_isLoadingPlanSubscription && !_isStartingStoreCheckout && !isCurrent;
    final isPrimaryTrialCta =
        current == AppPlanTier.free && tier == AppPlanTier.pro;
    final actionLabel =
        isPrimaryTrialCta ? 'Comecar agora' : _planActionLabel(tier, current);
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
          color:
              isRecommended
                  ? withUiOpacity(
                    Theme.of(sheetContext).colorScheme.primary,
                    0.4,
                  )
                  : withUiOpacity(GymMapColors.northControl, 0.10),
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
                  color:
                      isRecommended
                          ? withUiOpacity(
                            Theme.of(sheetContext).colorScheme.primary,
                            0.12,
                          )
                          : withUiOpacity(GymMapColors.northControl, 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _planIcon(tier),
                  size: 16,
                  color:
                      isRecommended
                          ? Theme.of(sheetContext).colorScheme.primary
                          : GymMapColors.textStrong,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color:
                        isRecommended
                            ? Theme.of(sheetContext).colorScheme.primary
                            : GymMapColors.textPrimary,
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
                    color: withUiOpacity(
                      Theme.of(sheetContext).colorScheme.primary,
                      0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'MAIS POPULAR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(sheetContext).colorScheme.primary,
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
          ...plan.insights
              .take(4)
              .map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color:
                            isRecommended
                                ? Theme.of(sheetContext).colorScheme.primary
                                : GymMapColors.occupancyLow,
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
                      ),
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(actionLabel),
                    )
                    : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
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
        ],
      ),
    );
  }

  Widget _buildPlanComparisonMatrix() {
    const rows = <({String feature, Set<AppPlanTier> available})>[
      (
        feature: 'Lotacao em tempo real',
        available: {
          AppPlanTier.free,
          AppPlanTier.smart,
          AppPlanTier.pro,
          AppPlanTier.elite,
        },
      ),
      (
        feature: 'Historico 24h',
        available: {AppPlanTier.smart, AppPlanTier.pro, AppPlanTier.elite},
      ),
      (
        feature: 'Pico e comparativo',
        available: {AppPlanTier.pro, AppPlanTier.elite},
      ),
      (feature: 'Previsao e alertas', available: {AppPlanTier.elite}),
      (feature: 'Cobertura nacional', available: {AppPlanTier.elite}),
    ];
    const featureColumnWidth = 164.0;
    const tierColumnWidth = 52.0;
    final matrixMinWidth =
        featureColumnWidth + (tierColumnWidth * AppPlanTier.values.length);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: withUiOpacity(GymMapColors.northControl, 0.10),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: matrixMinWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comparativo rapido',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: GymMapColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: featureColumnWidth),
                  for (final tier in AppPlanTier.values)
                    SizedBox(
                      width: tierColumnWidth,
                      child: Center(
                        child: Text(
                          kPlanCatalog[tier]!.label[0],
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: GymMapColors.textStrong,
                          ),
                        ),
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
                        width: featureColumnWidth,
                        child: Text(
                          row.feature,
                          style: const TextStyle(
                            fontSize: 12,
                            color: GymMapColors.textStrong,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (final tier in AppPlanTier.values)
                        SizedBox(
                          width: tierColumnWidth,
                          child: Center(
                            child: Icon(
                              row.available.contains(tier)
                                  ? Icons.check_circle
                                  : Icons.remove_circle_outline,
                              size: 16,
                              color:
                                  row.available.contains(tier)
                                      ? GymMapColors.occupancyLow
                                      : GymMapColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlanSettings() {
    unawaited(_syncPlanFromStorage(showExpiryNotice: true));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final current = _activePlan;
        final service = _planSubscriptionService;
        final hasRemoteBackend = service?.hasRemoteBackend ?? false;
        final hasAuthSession = service?.hasAuthSession ?? false;
        const recommendedTier = AppPlanTier.pro;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Desbloqueie o maximo do GymMap',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Escolha o plano ideal para lotacao, previsao e comparativos.',
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
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '+10.000 usuarios premium ativos',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
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
                        label: const Text('Comecar no Pro'),
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
    final mapFlexWhenPanelOpen =
        (_layoutTotalFlex - _panelFlex)
            .clamp(
              _layoutTotalFlex - _panelMaxFlex,
              _layoutTotalFlex - _panelMinFlex,
            )
            .toInt();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GymMapColors.headerGradientStart,
              GymMapColors.headerGradientMid,
              GymMapColors.headerGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              GymPageHeader(
                planLabel: activePlan.label,
                onOpenPlanSettings: _openPlanSettings,
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: GymMapColors.pageBackground,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GymSearchField(
                          controller: _searchController,
                          searchTerm: _searchTerm,
                          isResolvingSearchLocation: _isResolvingSearchLocation,
                          onChanged: _updateSearchTerm,
                          onSubmitted: _submitSearch,
                          onClear: _clearSearch,
                          onSearchTap:
                              () => _submitSearch(_searchController.text),
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: MapQuickFiltersBar(
                            key: ValueKey<int>(_activeQuickFilters.length),
                            filters: quickFilterChips,
                            onToggle: _toggleQuickFilterById,
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (_isFreePlan) ...[
                          const SizedBox(height: 8),
                          const AdBannerCard(),
                        ],
                        Expanded(
                          flex: selectedGym == null ? 9 : mapFlexWhenPanelOpen,
                          child: _buildMap(
                            markerGyms,
                            snapshotsByGymId,
                            filteredMapPois,
                          ),
                        ),
                        if (selectedGym == null) ...[
                          const SizedBox(height: 10),
                          SelectionHintCard(
                            hasNoResults: hasNoSearchResults,
                            hasNoNearbyGyms: hasNoNearbyGyms,
                            hasActiveFilters: _activeQuickFilters.isNotEmpty,
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          Expanded(
                            flex: _panelFlex,
                            child: AnimatedContainer(
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(
    List<Gym> gyms,
    Map<String, GymCrowdSnapshot> snapshotsByGymId,
    List<MapGymPoi> mapPois,
  ) {
    const controlsRight = 14.0;
    const controlsTop = 16.0;
    const controlsGap = 58.0;

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
            width: 250 * markerScale,
            height: 145 * markerScale,
            child: Transform.scale(
              scale: markerScale,
              alignment: Alignment.bottomCenter,
              child: GymMarkerBubble(
                label: gym.name,
                percent:
                    snapshotsByGymId[gym.id]?.occupancyPercent ??
                    gym.baseOccupancyPercent,
                selected: gym.id == _selectedGym?.id,
                revealDetails: _showMarkerDetails,
                onTap:
                    () =>
                        _handleMarkerTap(() => _selectGym(gym, moveMap: false)),
              ),
            ),
          );
        }(),
      for (final poi in mapPois) _buildPoiMarker(poi),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
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
      ),
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

  Marker _buildPoiMarker(MapGymPoi poi) {
    final poiGym = _gymFromPoi(poi);
    final poiPercent = _crowdService.snapshotFor(poiGym).occupancyPercent;
    final markerScale = _markerScaleForPosition(poi.position);
    return Marker(
      key: ValueKey<String>('poi-marker-${poi.id}-$_mapVisualReloadTick'),
      point: poi.position,
      width: 250 * markerScale,
      height: 145 * markerScale,
      child: Transform.scale(
        scale: markerScale,
        alignment: Alignment.bottomCenter,
        child: GymMarkerBubble(
          label: poi.name,
          percent: poiPercent,
          selected: poiGym.id == _selectedGym?.id,
          revealDetails: _showMarkerDetails,
          onTap:
              () => _handleMarkerTap(() => _selectGym(poiGym, moveMap: false)),
        ),
      ),
    );
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
