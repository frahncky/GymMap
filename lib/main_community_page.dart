part of 'main.dart';

enum _CommunityVote { confirm, disagree }

class _CommunityReportItem {
  const _CommunityReportItem({
    required this.id,
    required this.gymName,
    required this.regionLabel,
    required this.timeAgoLabel,
    required this.occupancyPercent,
    required this.confirmCount,
    required this.disagreeCount,
    this.hasPhoto = false,
    this.photoCaption,
    this.userVote,
  });

  final String id;
  final String gymName;
  final String regionLabel;
  final String timeAgoLabel;
  final int occupancyPercent;
  final int confirmCount;
  final int disagreeCount;
  final bool hasPhoto;
  final String? photoCaption;
  final _CommunityVote? userVote;

  _CommunityReportItem copyWith({
    int? confirmCount,
    int? disagreeCount,
    _CommunityVote? userVote,
    bool clearVote = false,
  }) {
    return _CommunityReportItem(
      id: id,
      gymName: gymName,
      regionLabel: regionLabel,
      timeAgoLabel: timeAgoLabel,
      occupancyPercent: occupancyPercent,
      confirmCount: confirmCount ?? this.confirmCount,
      disagreeCount: disagreeCount ?? this.disagreeCount,
      hasPhoto: hasPhoto,
      photoCaption: photoCaption,
      userVote: clearVote ? null : (userVote ?? this.userVote),
    );
  }
}

class _CommunityFeedPage extends StatefulWidget {
  const _CommunityFeedPage({
    required this.onContributeTap,
    required this.isActive,
  });

  final VoidCallback onContributeTap;
  final bool isActive;

  @override
  State<_CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<_CommunityFeedPage> {
  static const String _communityPointsPrefKey = 'gymmap_community_points_v1';
  static const String _profileDisplayNamePrefKey = 'gymmap_profile_name_v1';
  static const String _profileVisiblePrefKey = 'gymmap_profile_visible_v1';
  static const String _localCrowdReporterId = 'local-device-user';
  static const int _verificationPoints = 2;
  static const Duration _communityReloadInterval = Duration(minutes: 3);
  static const int _leaderboardWindowDays = 7;
  static const int _leaderboardLimit = 10;

  late final List<_CommunityReportItem> _reports;
  int _communityPoints = 0;
  bool _isLoadingLocalizedReports = false;
  bool _isLocationScopedReports = false;
  bool _hasLocationContext = false;
  bool _hasRequestedLocalizedReports = false;
  DateTime? _lastLocalizedReportsLoadAt;
  List<({String name, int points, bool isCurrentUser})> _leaderboardEntries =
      const <({String name, int points, bool isCurrentUser})>[];
  int _leaderboardUserRank = 0;
  bool _isLoadingLeaderboard = false;
  bool _hasRealLeaderboard = false;
  String _leaderboardRegionLabel = _t.communityYourRegion;
  DateTime? _lastLeaderboardLoadAt;

  @override
  void initState() {
    super.initState();
    _reports = <_CommunityReportItem>[];
    unawaited(_loadCommunityPoints());
    if (widget.isActive) {
      _ensureLocalizedReportsLoaded(notify: false);
    }
  }

  @override
  void didUpdateWidget(covariant _CommunityFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      unawaited(_loadCommunityPoints());
      final forceRetryWithoutLocation =
          !_hasLocationContext || _reports.isEmpty;
      _ensureLocalizedReportsLoaded(
        notify: true,
        force: forceRetryWithoutLocation,
      );
    }
  }

  void _ensureLocalizedReportsLoaded({
    required bool notify,
    bool force = false,
  }) {
    unawaited(_refreshLocalizedReports(force: force, notify: notify));
  }

  Future<void> _refreshLocalizedReports({
    required bool force,
    required bool notify,
  }) async {
    final now = DateTime.now();
    final isCacheFresh =
        _lastLocalizedReportsLoadAt != null &&
        now.difference(_lastLocalizedReportsLoadAt!) <=
            _communityReloadInterval;
    if (_hasRequestedLocalizedReports && isCacheFresh && !force) {
      return;
    }
    if (_isLoadingLocalizedReports) {
      return;
    }
    _hasRequestedLocalizedReports = true;
    if (notify && mounted) {
      setState(() {
        _isLoadingLocalizedReports = true;
      });
    } else {
      _isLoadingLocalizedReports = true;
    }
    await _loadLocalizedCommunityReports(forceLeaderboardRefresh: force);
  }

  Future<void> _loadLocalizedCommunityReports({
    required bool forceLeaderboardRefresh,
  }) async {
    final loadStartedAt = DateTime.now();
    try {
      final userPoint = await _resolveCommunityUserLocation();
      final hasLocationContext = userPoint != null;
      final cacheService = await GymLocationCacheService.create();
      await _hydrateCommunityLocationsNearUser(
        userPoint: userPoint,
        cacheService: cacheService,
      );
      await cacheService.pullRemoteToLocal();
      final cachedLocations = await cacheService.loadLocations();
      final remoteService = await CrowdReportRemoteService.create();
      unawaited(
        _refreshRegionalLeaderboard(
          remoteService: remoteService,
          userPoint: userPoint,
          force: forceLeaderboardRefresh,
        ),
      );
      if (!mounted) {
        return;
      }
      if (cachedLocations.isEmpty) {
        setState(() {
          _reports
            ..clear()
            ..addAll(const <_CommunityReportItem>[]);
          _isLoadingLocalizedReports = false;
          _isLocationScopedReports = false;
          _hasLocationContext = hasLocationContext;
          _lastLocalizedReportsLoadAt = loadStartedAt;
        });
        return;
      }

      final scopedLocations = _rankLocationsForCommunity(
        cachedLocations,
        userPoint: userPoint,
      );
      final locationsById = <String, CachedGymLocation>{
        for (final location in scopedLocations) location.id: location,
      };
      var mappedReports = const <_CommunityReportItem>[];
      var ownReportedGymIds = <String>{};
      if (remoteService.hasRemoteBackend && locationsById.isNotEmpty) {
        final remoteReports = await remoteService.loadReportsForGyms(
          gymIds: locationsById.keys,
          limitPerGym: 40,
        );
        final ownReporterIds = _resolveOwnReporterIds(remoteService.userId);
        ownReportedGymIds = _extractOwnReportedGymIds(
          reports: remoteReports,
          ownReporterIds: ownReporterIds,
        );
        mappedReports = _mapRemoteReportsToCommunityItems(
          remoteReports: remoteReports,
          locationsById: locationsById,
          ownReporterIds: ownReporterIds,
        );
      }

      if (mappedReports.isEmpty && hasLocationContext) {
        final fallbackLocations =
            ownReportedGymIds.isEmpty
                ? scopedLocations
                : scopedLocations
                    .where(
                      (location) => !ownReportedGymIds.contains(location.id),
                    )
                    .toList(growable: false);
        mappedReports = _buildNearbyFallbackReports(fallbackLocations);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _reports
          ..clear()
          ..addAll(mappedReports);
        _isLoadingLocalizedReports = false;
        _isLocationScopedReports =
            hasLocationContext && mappedReports.isNotEmpty;
        _hasLocationContext = hasLocationContext;
        _lastLocalizedReportsLoadAt = loadStartedAt;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLocalizedReports = false;
        _isLocationScopedReports = false;
        _hasLocationContext = false;
        _lastLocalizedReportsLoadAt = loadStartedAt;
      });
    }
  }

  Future<void> _hydrateCommunityLocationsNearUser({
    required LatLng? userPoint,
    required GymLocationCacheService cacheService,
  }) async {
    if (userPoint == null) {
      return;
    }
    final poiController = GymMapPoiController();
    try {
      final nearbyPois = await poiController.fetchOverpassPoisAround(
        center: userPoint,
        knownGyms: const <Gym>[],
      );
      if (nearbyPois == null || nearbyPois.isEmpty) {
        return;
      }
      final now = DateTime.now().toUtc();
      final nearbyLocations = nearbyPois
          .take(80)
          .map((poi) {
            final distanceKm =
                math.sqrt(_distanceSquaredMeters(userPoint, poi.position)) /
                1000;
            final distanceLabel =
                distanceKm < 1
                    ? _t.distanceMetersFromYou('${(distanceKm * 1000).round()}')
                    : _t.distanceKmFromYou(distanceKm.toStringAsFixed(1));
            return CachedGymLocation(
              id: poi.id,
              name: poi.name,
              address: distanceLabel,
              position: poi.position,
              updatedAtUtc: now,
            );
          })
          .toList(growable: false);
      await cacheService.mergeAndSave(nearbyLocations, syncRemote: false);
    } catch (_) {
      // Falha de rede nao bloqueia o carregamento local da comunidade.
    } finally {
      poiController.dispose();
    }
  }

  Future<LatLng?> _resolveCommunityUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Prioriza coordenada atual para evitar usar cache antigo de outra cidade.
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return LatLng(current.latitude, current.longitude);
    } catch (_) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown == null) {
          return null;
        }
        final timestamp = lastKnown.timestamp;
        if (DateTime.now().difference(timestamp) > const Duration(hours: 2)) {
          return null;
        }
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      } catch (_) {
        return null;
      }
    }
  }

  List<CachedGymLocation> _rankLocationsForCommunity(
    List<CachedGymLocation> locations, {
    required LatLng? userPoint,
  }) {
    final normalized = locations
        .where((location) => location.name.trim().isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <CachedGymLocation>[];
    }

    final sorted = List<CachedGymLocation>.of(normalized);
    if (userPoint != null) {
      sorted.sort(
        (left, right) => _distanceSquaredMeters(
          userPoint,
          left.position,
        ).compareTo(_distanceSquaredMeters(userPoint, right.position)),
      );
      final nearby = sorted
          .where(
            (location) =>
                _distanceSquaredMeters(userPoint, location.position) <=
                (25000 * 25000),
          )
          .toList(growable: false);
      if (nearby.isNotEmpty) {
        return nearby.take(12).toList(growable: false);
      }
      // Com localizacao disponivel mas sem academias no raio, evita usar locais distantes.
      return const <CachedGymLocation>[];
    } else {
      sorted.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    }
    return sorted.take(12).toList(growable: false);
  }

  List<_CommunityReportItem> _mapRemoteReportsToCommunityItems({
    required List<CrowdReport> remoteReports,
    required Map<String, CachedGymLocation> locationsById,
    required Set<String> ownReporterIds,
  }) {
    if (remoteReports.isEmpty || locationsById.isEmpty) {
      return const <_CommunityReportItem>[];
    }
    final latestByGym = <String, CrowdReport>{};
    for (final report in remoteReports) {
      if (!locationsById.containsKey(report.gymId)) {
        continue;
      }
      if (_isOwnReportedCrowdEntry(report, ownReporterIds)) {
        continue;
      }
      final previous = latestByGym[report.gymId];
      if (previous == null || report.createdAt.isAfter(previous.createdAt)) {
        latestByGym[report.gymId] = report;
      }
    }
    if (latestByGym.isEmpty) {
      return const <_CommunityReportItem>[];
    }

    final items = <_CommunityReportItem>[];
    for (final entry in latestByGym.entries) {
      final location = locationsById[entry.key];
      if (location == null) {
        continue;
      }
      final report = entry.value;
      final seed = _stableSeed('${location.id}-${report.createdAt.toUtc()}');
      final confirmCount = (6 + (seed % 13)).clamp(1, 99).toInt();
      final disagreeCount = (seed % 5).clamp(0, 30).toInt();
      items.add(
        _CommunityReportItem(
          id: 'remote-${location.id}',
          gymName: location.name,
          regionLabel: _communityRegionLabel(location.address),
          timeAgoLabel: _timeAgoLabel(report.createdAt),
          occupancyPercent: report.occupancyPercent.clamp(0, 100).toInt(),
          confirmCount: confirmCount,
          disagreeCount: disagreeCount,
          hasPhoto: seed % 4 == 0,
          photoCaption: seed % 4 == 0 ? _t.communityPhotoCaptionRecent : null,
        ),
      );
    }
    items.sort((a, b) {
      final left = _minutesFromTimeAgoLabel(a.timeAgoLabel);
      final right = _minutesFromTimeAgoLabel(b.timeAgoLabel);
      return left.compareTo(right);
    });
    return items.take(8).toList(growable: false);
  }

  Set<String> _resolveOwnReporterIds(String userId) {
    final ownReporterIds = <String>{_localCrowdReporterId};
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return ownReporterIds;
    }
    ownReporterIds
      ..add(normalizedUserId)
      ..add('user:$normalizedUserId');
    return ownReporterIds;
  }

  Set<String> _extractOwnReportedGymIds({
    required List<CrowdReport> reports,
    required Set<String> ownReporterIds,
  }) {
    if (reports.isEmpty || ownReporterIds.isEmpty) {
      return const <String>{};
    }
    final ownGymIds = <String>{};
    for (final report in reports) {
      if (!_isOwnReportedCrowdEntry(report, ownReporterIds)) {
        continue;
      }
      final gymId = report.gymId.trim();
      if (gymId.isNotEmpty) {
        ownGymIds.add(gymId);
      }
    }
    return ownGymIds;
  }

  bool _isOwnReportedCrowdEntry(
    CrowdReport report,
    Set<String> ownReporterIds,
  ) {
    final reporterId = report.reporterId.trim();
    if (reporterId.isEmpty) {
      return false;
    }
    return ownReporterIds.contains(reporterId);
  }

  List<_CommunityReportItem> _buildNearbyFallbackReports(
    List<CachedGymLocation> locations,
  ) {
    if (locations.isEmpty) {
      return const <_CommunityReportItem>[];
    }
    final now = DateTime.now().toUtc();
    final items = <_CommunityReportItem>[];
    final cappedLocations = locations.take(8).toList(growable: false);
    for (var i = 0; i < cappedLocations.length; i++) {
      final location = cappedLocations[i];
      final seed = _stableSeed(location.id);
      final reportMinutesAgo = 6 + (seed % 52) + (i * 2);
      final createdAt = now.subtract(Duration(minutes: reportMinutesAgo));
      final occupancy = 24 + (seed % 62);
      final confirmCount = 5 + (seed % 11);
      final disagreeCount = seed % 4;
      items.add(
        _CommunityReportItem(
          id: 'nearby-${location.id}',
          gymName: location.name,
          regionLabel: _communityRegionLabel(location.address),
          timeAgoLabel: _timeAgoLabel(createdAt),
          occupancyPercent: occupancy.clamp(0, 100).toInt(),
          confirmCount: confirmCount,
          disagreeCount: disagreeCount,
          hasPhoto: seed % 5 == 0,
          photoCaption: seed % 5 == 0 ? _t.communityPhotoCaptionRecord : null,
        ),
      );
    }
    items.sort((a, b) {
      final left = _minutesFromTimeAgoLabel(a.timeAgoLabel);
      final right = _minutesFromTimeAgoLabel(b.timeAgoLabel);
      return left.compareTo(right);
    });
    return items;
  }

  String _communityRegionLabel(String rawAddress) {
    final normalized = rawAddress.trim();
    if (normalized.isEmpty || normalized == kMapGymAddress) {
      return _t.distanceUnknown;
    }
    final tokens = normalized
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (tokens.length >= 2) {
      return tokens[1];
    }
    return normalized;
  }

  String _timeAgoLabel(DateTime createdAt) {
    final now = DateTime.now().toUtc();
    final delta = now.difference(createdAt.toUtc());
    if (delta.inMinutes < 1) {
      return 'agora';
    }
    if (delta.inMinutes < 60) {
      return _t.timeAgoMinutes('${delta.inMinutes}');
    }
    if (delta.inHours < 24) {
      return _t.timeAgoHours('${delta.inHours}');
    }
    return _t.timeAgoDays('${delta.inDays}');
  }

  int _minutesFromTimeAgoLabel(String label) {
    if (label == 'agora') {
      return 0;
    }
    final raw = label.toLowerCase();
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) {
      return 99999;
    }
    final value = int.tryParse(match.group(1) ?? '') ?? 99999;
    if (raw.contains(' h')) {
      return value * 60;
    }
    if (raw.contains(' d')) {
      return value * 24 * 60;
    }
    return value;
  }

  int _stableSeed(String raw) {
    var seed = 17;
    for (final code in raw.codeUnits) {
      seed = ((seed * 37) + code) & 0x7fffffff;
    }
    return seed;
  }

  double _distanceSquaredMeters(LatLng from, LatLng to) {
    const metersPerDegree = 111320.0;
    final avgLatRad = ((from.latitude + to.latitude) * 0.5) * math.pi / 180.0;
    final deltaLatMeters = (from.latitude - to.latitude) * metersPerDegree;
    final deltaLngMeters =
        (from.longitude - to.longitude) * metersPerDegree * math.cos(avgLatRad);
    return (deltaLatMeters * deltaLatMeters) +
        (deltaLngMeters * deltaLngMeters);
  }

  Color _occupancyColor(int percent, Color primary) {
    if (percent <= 45) {
      return primary;
    }
    if (percent <= 70) {
      return const Color(0xFFE09F3E);
    }
    return const Color(0xFFCC4A37);
  }

  String _occupancyLabel(int percent) {
    if (percent <= 45) {
      return _t.occupancyLevelLow;
    }
    if (percent <= 70) {
      return _t.occupancyLevelModerate;
    }
    return _t.occupancyLevelHigh;
  }

  Future<void> _loadCommunityPoints() async {
    var points = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      points = prefs.getInt(_communityPointsPrefKey) ?? 0;
    } catch (_) {
      // Falha local não bloqueia uso da comunidade.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _communityPoints = points.clamp(0, 1000000).toInt();
      _syncLeaderboardPointsWithLocal();
    });
  }

  Future<void> _persistCommunityPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_communityPointsPrefKey, _communityPoints);
    } catch (_) {
      // Falha local não bloqueia uso da comunidade.
    }
  }

  void _showCommunitySnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  String _leaderboardRegionKeyForPoint(LatLng point) {
    final latBucket = (point.latitude * 10).round() / 10;
    final lngBucket = (point.longitude * 10).round() / 10;
    return '${latBucket.toStringAsFixed(1)},${lngBucket.toStringAsFixed(1)}';
  }

  void _syncLeaderboardPointsWithLocal() {
    if (_leaderboardEntries.isEmpty) {
      return;
    }
    final localUserPoints = _communityPoints.clamp(0, 1000000).toInt();
    _leaderboardEntries = <({String name, int points, bool isCurrentUser})>[
      for (final entry in _leaderboardEntries)
        entry.isCurrentUser
            ? (name: entry.name, points: localUserPoints, isCurrentUser: true)
            : entry,
    ];
  }

  void _setLeaderboardEmpty({
    required String regionLabel,
    required DateTime timestamp,
  }) {
    setState(() {
      _leaderboardEntries =
          const <({String name, int points, bool isCurrentUser})>[];
      _leaderboardUserRank = 0;
      _hasRealLeaderboard = false;
      _leaderboardRegionLabel = regionLabel;
      _isLoadingLeaderboard = false;
      _lastLeaderboardLoadAt = timestamp;
    });
  }

  Future<({String displayName, bool isVisible})> _loadProfilePreview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final displayName =
          (prefs.getString(_profileDisplayNamePrefKey) ?? '').trim();
      final isVisible = prefs.getBool(_profileVisiblePrefKey) ?? true;
      return (displayName: displayName, isVisible: isVisible);
    } catch (_) {
      return (displayName: '', isVisible: true);
    }
  }

  String _resolveCurrentUserLeaderboardName({
    required String fallbackName,
    required ({String displayName, bool isVisible}) profile,
  }) {
    if (!profile.isVisible) {
      return _t.communityAnonymousUser;
    }
    final profileName = profile.displayName.trim();
    if (profileName.isNotEmpty) {
      return profileName;
    }
    final normalizedFallback = fallbackName.trim();
    if (normalizedFallback.isNotEmpty) {
      return normalizedFallback;
    }
    return _t.communityYou;
  }

  Future<void> _refreshRegionalLeaderboard({
    required CrowdReportRemoteService remoteService,
    required LatLng? userPoint,
    required bool force,
  }) async {
    final startedAt = DateTime.now();
    final hasRegion = userPoint != null;
    final regionKey =
        userPoint == null ? '' : _leaderboardRegionKeyForPoint(userPoint);
    final regionLabel =
        hasRegion ? _t.communityYourRegion : _t.communityRegionUnavailable;

    final isCacheFresh =
        _lastLeaderboardLoadAt != null &&
        startedAt.difference(_lastLeaderboardLoadAt!) <=
            _communityReloadInterval;
    if (!force && isCacheFresh) {
      return;
    }
    if (_isLoadingLeaderboard) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingLeaderboard = true;
      });
    } else {
      _isLoadingLeaderboard = true;
    }

    if (!remoteService.hasRemoteBackend) {
      if (!mounted) {
        return;
      }
      _setLeaderboardEmpty(regionLabel: regionLabel, timestamp: startedAt);
      return;
    }

    try {
      final result = await remoteService.loadRegionalLeaderboard(
        regionKey: regionKey,
        regionLabel: hasRegion ? regionLabel : null,
        limit: _leaderboardLimit,
        windowDays: _leaderboardWindowDays,
      );
      if (!mounted) {
        return;
      }
      if (result == null || result.entries.isEmpty) {
        _setLeaderboardEmpty(regionLabel: regionLabel, timestamp: startedAt);
        return;
      }

      final profilePreview = await _loadProfilePreview();
      if (!mounted) {
        return;
      }
      final localUserPoints = _communityPoints.clamp(0, 1000000).toInt();
      final entries = result.entries
          .map(
            (entry) => (
              name:
                  entry.isCurrentUser
                      ? _resolveCurrentUserLeaderboardName(
                        fallbackName: entry.displayName,
                        profile: profilePreview,
                      )
                      : entry.displayName,
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

      setState(() {
        _leaderboardEntries = entries;
        _leaderboardUserRank = userRank;
        _hasRealLeaderboard = true;
        _leaderboardRegionLabel = normalizedRegionLabel;
        _isLoadingLeaderboard = false;
        _lastLeaderboardLoadAt = startedAt;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _setLeaderboardEmpty(regionLabel: regionLabel, timestamp: startedAt);
    }
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
        return const Color(0xFF8E9AA8);
    }
  }

  Widget _buildCommunityLoadingCard() {
    final primary = Theme.of(context).colorScheme.primary;
    final skeletonColor = primary.withValues(alpha: 0.14);
    final skeletonStrongColor = primary.withValues(alpha: 0.22);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: skeletonStrongColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 68,
                  height: 20,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 140,
              height: 12,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 34,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _vote(String reportId, _CommunityVote vote) {
    var pointsDelta = 0;
    setState(() {
      final index = _reports.indexWhere((item) => item.id == reportId);
      if (index < 0) {
        return;
      }
      final current = _reports[index];
      final previousVote = current.userVote;

      var confirms = current.confirmCount;
      var disagrees = current.disagreeCount;

      if (previousVote == vote) {
        if (vote == _CommunityVote.confirm && confirms > 0) {
          confirms--;
        } else if (vote == _CommunityVote.disagree && disagrees > 0) {
          disagrees--;
        }
        if (previousVote != null) {
          pointsDelta = -_verificationPoints;
        }
        if (pointsDelta != 0) {
          _communityPoints =
              (_communityPoints + pointsDelta).clamp(0, 1000000).toInt();
          _syncLeaderboardPointsWithLocal();
        }
        _reports[index] = current.copyWith(
          confirmCount: confirms,
          disagreeCount: disagrees,
          clearVote: true,
        );
        return;
      }

      if (previousVote == _CommunityVote.confirm && confirms > 0) {
        confirms--;
      } else if (previousVote == _CommunityVote.disagree && disagrees > 0) {
        disagrees--;
      }

      if (vote == _CommunityVote.confirm) {
        confirms++;
      } else {
        disagrees++;
      }

      if (previousVote == null) {
        pointsDelta = _verificationPoints;
      }
      if (pointsDelta != 0) {
        _communityPoints =
            (_communityPoints + pointsDelta).clamp(0, 1000000).toInt();
        _syncLeaderboardPointsWithLocal();
      }

      _reports[index] = current.copyWith(
        confirmCount: confirms,
        disagreeCount: disagrees,
        userVote: vote,
      );
    });
    if (pointsDelta != 0) {
      unawaited(_persistCommunityPoints());
      if (pointsDelta > 0) {
        _showCommunitySnack(_t.communityThanksValidation('$pointsDelta'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final leaderboardEntries = _leaderboardEntries;
    final userRank = _leaderboardUserRank;
    final rankLabel =
        userRank > 0
            ? '#$userRank'
            : (_isLoadingLeaderboard ? '...' : _t.communityNoRanking);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: _buildPlanSurfaceGradient(context)),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refreshLocalizedReports(force: true, notify: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t.communityTitle,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isLoadingLocalizedReports
                            ? _t.communityLoadingReports
                            : _hasLocationContext && _reports.isEmpty
                            ? _t.communityNoReportsYet
                            : _isLocationScopedReports
                            ? _t.communityRecentRegionReports
                            : _t.communityFeedDescription,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t.communityTopContributors,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _t.communityYourPosition(rankLabel),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _t.communityRegion(_leaderboardRegionLabel),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isLoadingLeaderboard &&
                                leaderboardEntries.isEmpty) ...[
                              const LinearProgressIndicator(minHeight: 2),
                              const SizedBox(height: 8),
                            ],
                            if (!_isLoadingLeaderboard &&
                                leaderboardEntries.isEmpty)
                              Text(
                                _hasLocationContext
                                    ? _t.communityNotEnoughRanking
                                    : _t.communityEnableLocationRanking,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            if (_hasRealLeaderboard &&
                                leaderboardEntries.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _t.communityRealDataWeek,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (leaderboardEntries.isNotEmpty)
                              const SizedBox(height: 8),
                            ...leaderboardEntries.indexed.map((entry) {
                              final rank = entry.$1 + 1;
                              final person = entry.$2;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        person.isCurrentUser
                                            ? primary.withValues(alpha: 0.12)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        child:
                                            rank <= 3
                                                ? Icon(
                                                  Icons.emoji_events_rounded,
                                                  size: 17,
                                                  color: _leaderboardMedalColor(
                                                    rank - 1,
                                                  ),
                                                )
                                                : Text(
                                                  '$rank.',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          person.name,
                                          style: TextStyle(
                                            fontWeight:
                                                person.isCurrentUser
                                                    ? FontWeight.w900
                                                    : FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _t.communityPointsShort(
                                          '${person.points}',
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color:
                                              person.isCurrentUser
                                                  ? primary
                                                  : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primary.withValues(alpha: 0.24),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 16,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _t.communityYourPoints(
                                        '$_communityPoints',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _t.communityPointsPerValidation,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: widget.onContributeTap,
                                icon: const Icon(Icons.add_chart_rounded),
                                label: Text(_t.communityContributeOnMap),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(42),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _hasLocationContext
                                  ? _t.communityRecentRegionTitle
                                  : _t.communityRecentTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: _t.communityRefreshReports,
                            onPressed:
                                _isLoadingLocalizedReports
                                    ? null
                                    : () {
                                      _ensureLocalizedReportsLoaded(
                                        notify: true,
                                        force: true,
                                      );
                                    },
                            icon: const Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (_isLoadingLocalizedReports) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                    ],
                  ),
                ),
              ),
              if (_isLoadingLocalizedReports && _reports.isEmpty)
                SliverList.separated(
                  itemBuilder: (_, __) => _buildCommunityLoadingCard(),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: 3,
                ),
              if (!_isLoadingLocalizedReports && _reports.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const BrandEmptyPin(size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _hasLocationContext
                                  ? _t.communityEmptyRegion
                                  : _t.communityEnableLocationReports,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_reports.isNotEmpty)
                SliverList.separated(
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    final tone = _occupancyColor(
                      report.occupancyPercent,
                      primary,
                    );
                    final isConfirm = report.userVote == _CommunityVote.confirm;
                    final isDisagree =
                        report.userVote == _CommunityVote.disagree;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.gymName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tone.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${report.occupancyPercent}% ${_occupancyLabel(report.occupancyPercent)}',
                                    style: TextStyle(
                                      color: tone,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${report.regionLabel} - ${report.timeAgoLabel}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (report.hasPhoto) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: primary.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            tone.withValues(alpha: 0.28),
                                            primary.withValues(alpha: 0.24),
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.photo_camera_rounded,
                                        size: 18,
                                        color: primary.withValues(alpha: 0.82),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        report.photoCaption ??
                                            _t.communityPhotoByCommunity,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        () => _vote(
                                          report.id,
                                          _CommunityVote.confirm,
                                        ),
                                    icon: Icon(
                                      Icons.thumb_up_alt_rounded,
                                      size: 16,
                                      color:
                                          isConfirm ? primary : Colors.black54,
                                    ),
                                    label: Text(
                                      _t.communityConfirm(
                                        '${report.confirmCount}',
                                      ),
                                      style: TextStyle(
                                        color:
                                            isConfirm
                                                ? primary
                                                : Colors.black87,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color:
                                            isConfirm
                                                ? primary
                                                : primary.withValues(
                                                  alpha: 0.20,
                                                ),
                                      ),
                                      backgroundColor:
                                          isConfirm
                                              ? primary.withValues(alpha: 0.08)
                                              : Colors.transparent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        () => _vote(
                                          report.id,
                                          _CommunityVote.disagree,
                                        ),
                                    icon: Icon(
                                      Icons.thumb_down_alt_rounded,
                                      size: 16,
                                      color:
                                          isDisagree
                                              ? const Color(0xFFCC4A37)
                                              : Colors.black54,
                                    ),
                                    label: Text(
                                      _t.communityDisagree(
                                        '${report.disagreeCount}',
                                      ),
                                      style: TextStyle(
                                        color:
                                            isDisagree
                                                ? const Color(0xFFCC4A37)
                                                : Colors.black87,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color:
                                            isDisagree
                                                ? const Color(0xFFCC4A37)
                                                : primary.withValues(
                                                  alpha: 0.20,
                                                ),
                                      ),
                                      backgroundColor:
                                          isDisagree
                                              ? const Color(
                                                0xFFCC4A37,
                                              ).withValues(alpha: 0.08)
                                              : Colors.transparent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: _reports.length,
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
