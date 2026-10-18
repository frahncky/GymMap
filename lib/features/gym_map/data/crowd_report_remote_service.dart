import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/gym_models.dart';

class RemoteCrowdSubmitResult {
  const RemoteCrowdSubmitResult({
    required this.accepted,
    this.retryAfter,
    this.report,
    this.pointsBalance,
  });

  final bool accepted;
  final Duration? retryAfter;
  final CrowdReport? report;

  /// Saldo de pontos no servidor depois do relato.
  final int? pointsBalance;
}

/// Saldo de pontos e a troca por dias de plano.
class RemoteRewards {
  const RemoteRewards({
    required this.balance,
    required this.costPoints,
    required this.planKey,
    required this.planDays,
    required this.canRedeem,
    this.blockedReason,
  });

  final int balance;
  final int costPoints;
  final String planKey;
  final int planDays;
  final bool canRedeem;

  /// `not_enough_points` ou `higher_plan_active` quando não dá para trocar.
  final String? blockedReason;

  static RemoteRewards? fromJson(Map<String, dynamic> json) {
    final balance = int.tryParse('${json['balance'] ?? ''}');
    final cost = int.tryParse('${json['costPoints'] ?? ''}');
    final days = int.tryParse('${json['planDays'] ?? ''}');
    if (balance == null || cost == null || days == null) {
      return null;
    }
    final blocked = '${json['blockedReason'] ?? ''}'.trim();
    return RemoteRewards(
      balance: balance.clamp(0, 1000000),
      costPoints: cost,
      planKey: '${json['planKey'] ?? 'smart'}',
      planDays: days,
      canRedeem: json['canRedeem'] == true,
      blockedReason: blocked.isEmpty ? null : blocked,
    );
  }
}

/// Resultado de marcar comodidades: a situação atualizada e os pontos.
class RemoteAmenityVoteResult {
  const RemoteAmenityVoteResult({
    required this.amenities,
    required this.pointsAwarded,
    this.pointsBalance,
  });

  final List<GymAmenityVotes> amenities;
  final int pointsAwarded;
  final int? pointsBalance;
}

class RemoteCrowdLeaderboardEntry {
  const RemoteCrowdLeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.points,
    required this.rank,
    required this.isCurrentUser,
  });

  final String userId;
  final String displayName;
  final int points;
  final int rank;
  final bool isCurrentUser;
}

class RemoteCrowdLeaderboardResult {
  const RemoteCrowdLeaderboardResult({
    required this.regionKey,
    required this.regionLabel,
    required this.windowDays,
    required this.userRank,
    required this.userPoints,
    required this.entries,
  });

  final String regionKey;
  final String regionLabel;
  final int windowDays;
  final int userRank;
  final int userPoints;
  final List<RemoteCrowdLeaderboardEntry> entries;
}

class CrowdReportRemoteService {
  CrowdReportRemoteService._({
    required SharedPreferences prefs,
    required Uri? backendBaseUri,
    required String userId,
    required String authToken,
    http.Client? httpClient,
  }) : _prefs = prefs,
       _backendBaseUri = backendBaseUri,
       _userId = userId,
       _authToken = authToken,
       _httpClient = httpClient ?? http.Client();

  static const String _authUserIdKey = 'subscription.auth.user_id';
  static const String _authTokenKey = 'subscription.auth.token';
  static const Duration _requestTimeout = Duration(seconds: 12);

  final SharedPreferences _prefs;
  final Uri? _backendBaseUri;
  final http.Client _httpClient;
  String _userId;
  String _authToken;

  bool get hasRemoteBackend => _backendBaseUri != null;
  bool get hasAuthSession => _authToken.trim().isNotEmpty;
  String get userId => _userId;

  static Future<CrowdReportRemoteService> create({
    String? backendBaseUrl,
    String? userId,
    String? authToken,
    http.Client? httpClient,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fromEnv = const String.fromEnvironment('PLAN_BACKEND_BASE_URL');
    final rawBaseUrl = (backendBaseUrl ?? fromEnv).trim();
    final parsedBaseUrl = rawBaseUrl.isEmpty ? null : Uri.tryParse(rawBaseUrl);

    final fromEnvUserId = const String.fromEnvironment(
      'PLAN_USER_ID',
      defaultValue: 'local-device-user',
    );
    final fromEnvAuthToken = const String.fromEnvironment('PLAN_AUTH_TOKEN');
    final fromStorageUserId = prefs.getString(_authUserIdKey);
    final fromStorageAuthToken = prefs.getString(_authTokenKey);
    final normalizedUserId =
        (userId ?? fromStorageUserId ?? fromEnvUserId).trim();
    final normalizedAuthToken =
        (authToken ?? fromStorageAuthToken ?? fromEnvAuthToken).trim();

    return CrowdReportRemoteService._(
      prefs: prefs,
      backendBaseUri: parsedBaseUrl,
      userId: normalizedUserId.isEmpty ? 'local-device-user' : normalizedUserId,
      authToken: normalizedAuthToken,
      httpClient: httpClient,
    );
  }

  void refreshAuthFromStorage() {
    final storageUserId = (_prefs.getString(_authUserIdKey) ?? '').trim();
    final storageToken = (_prefs.getString(_authTokenKey) ?? '').trim();
    _userId = storageUserId.isEmpty ? 'local-device-user' : storageUserId;
    _authToken = storageToken;
  }

  Future<RemoteCrowdSubmitResult> submitReport({
    required String gymId,
    required int occupancyPercent,
    required String reporterId,
    String? regionKey,
    String? regionLabel,
  }) async {
    if (!hasRemoteBackend) {
      throw StateError('Backend crowd service not configured');
    }
    refreshAuthFromStorage();
    final userId = _userId.trim();
    if (userId.isEmpty) {
      throw StateError('missing_user_id');
    }

    final response = await _httpClient
        .post(
          _buildRemoteUri(<String>['v1', 'crowd', 'reports']),
          headers: _remoteHeaders(contentTypeJson: true),
          body: jsonEncode(<String, dynamic>{
            'userId': userId,
            'gymId': gymId,
            'occupancyPercent': occupancyPercent.clamp(0, 100),
            'reporterId': reporterId,
            if ((regionKey ?? '').trim().isNotEmpty)
              'regionKey': regionKey!.trim(),
            if ((regionLabel ?? '').trim().isNotEmpty)
              'regionLabel': regionLabel!.trim(),
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode == HttpStatus.tooManyRequests) {
      final decoded = _decodeJsonMap(response.body);
      final retryAfterSec = int.tryParse('${decoded['retryAfterSec'] ?? ''}');
      return RemoteCrowdSubmitResult(
        accepted: false,
        retryAfter:
            retryAfterSec == null
                ? const Duration(minutes: 1)
                : Duration(seconds: retryAfterSec.clamp(1, 3600)),
      );
    }
    if (response.statusCode != HttpStatus.created &&
        response.statusCode != HttpStatus.ok) {
      throw StateError(_parseBackendError(response));
    }

    final decoded = _decodeJsonMap(response.body);
    final accepted = decoded['accepted'] != false;
    final reportRaw = decoded['report'];
    CrowdReport? report;
    if (reportRaw is Map) {
      report = _crowdReportFromJson(Map<String, dynamic>.from(reportRaw));
    }

    return RemoteCrowdSubmitResult(
      accepted: accepted,
      report: report,
      pointsBalance: int.tryParse('${decoded['pointsBalance'] ?? ''}'),
    );
  }

  /// Comodidades votadas de cada academia em [gymIds] (até 80 por vez).
  Future<Map<String, List<GymAmenityVotes>>> loadAmenities(
    Iterable<String> gymIds,
  ) async {
    if (!hasRemoteBackend) {
      return const <String, List<GymAmenityVotes>>{};
    }
    refreshAuthFromStorage();
    final ids = gymIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(80)
        .toList(growable: false);
    if (ids.isEmpty) {
      return const <String, List<GymAmenityVotes>>{};
    }
    final uri = _buildRemoteUri(<String>['v1', 'gyms', 'amenities']).replace(
      queryParameters: <String, String>{
        'gymIds': ids.join(','),
        'userId': _userId,
      },
    );
    final response = await _httpClient
        .get(uri, headers: _remoteHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      return const <String, List<GymAmenityVotes>>{};
    }
    final gyms = _decodeJsonMap(response.body)['gyms'];
    if (gyms is! Map) {
      return const <String, List<GymAmenityVotes>>{};
    }
    return <String, List<GymAmenityVotes>>{
      for (final entry in gyms.entries)
        '${entry.key}': parseAmenityVotes(entry.value),
    };
  }

  /// Marca comodidades de [gymId]: `true` (tem), `false` (não tem) ou `null`
  /// (retira o voto).
  Future<RemoteAmenityVoteResult> submitAmenityVotes({
    required String gymId,
    required Map<GymAmenity, bool?> votes,
  }) async {
    if (!hasRemoteBackend) {
      throw StateError('Backend crowd service not configured');
    }
    refreshAuthFromStorage();
    final response = await _httpClient
        .post(
          _buildRemoteUri(<String>['v1', 'gyms', 'amenities', 'votes']),
          headers: _remoteHeaders(contentTypeJson: true),
          body: jsonEncode(<String, dynamic>{
            'userId': _userId,
            'gymId': gymId,
            'votes': <String, bool?>{
              for (final entry in votes.entries) entry.key.key: entry.value,
            },
          }),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_parseBackendError(response));
    }
    final decoded = _decodeJsonMap(response.body);
    return RemoteAmenityVoteResult(
      amenities: parseAmenityVotes(decoded['amenities']),
      pointsAwarded: int.tryParse('${decoded['pointsAwarded'] ?? ''}') ?? 0,
      pointsBalance: int.tryParse('${decoded['pointsBalance'] ?? ''}'),
    );
  }

  /// Saldo de pontos e se dá para trocar por dias de plano.
  Future<RemoteRewards?> loadRewards() async {
    if (!hasRemoteBackend) {
      return null;
    }
    refreshAuthFromStorage();
    final response = await _httpClient
        .get(
          _buildRemoteUri(<String>['v1', 'rewards', _userId]),
          headers: _remoteHeaders(),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }
    return RemoteRewards.fromJson(_decodeJsonMap(response.body));
  }

  /// Troca pontos por dias de plano. Lança [StateError] com o motivo
  /// (`not_enough_points`, `higher_plan_active`...) quando não dá.
  Future<RemoteRewards?> redeemReward() async {
    if (!hasRemoteBackend) {
      throw StateError('Backend crowd service not configured');
    }
    refreshAuthFromStorage();
    final response = await _httpClient
        .post(
          _buildRemoteUri(<String>['v1', 'rewards', 'redeem']),
          headers: _remoteHeaders(contentTypeJson: true),
          body: jsonEncode(<String, dynamic>{'userId': _userId}),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_parseBackendError(response));
    }
    return RemoteRewards.fromJson(_decodeJsonMap(response.body));
  }

  /// Lê a lista de comodidades votadas do servidor. Pública para testes.
  static List<GymAmenityVotes> parseAmenityVotes(Object? raw) {
    if (raw is! List) {
      return const <GymAmenityVotes>[];
    }
    final result = <GymAmenityVotes>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final amenity = GymAmenity.fromKey('${item['amenity'] ?? ''}');
      if (amenity == null) {
        continue;
      }
      final status = switch ('${item['status'] ?? ''}') {
        'confirmed' => AmenityVoteStatus.confirmed,
        'rejected' => AmenityVoteStatus.rejected,
        _ => AmenityVoteStatus.pending,
      };
      final userVote = item['userVote'];
      result.add(
        GymAmenityVotes(
          amenity: amenity,
          yes: int.tryParse('${item['yes'] ?? ''}') ?? 0,
          no: int.tryParse('${item['no'] ?? ''}') ?? 0,
          status: status,
          userVote: userVote is bool ? userVote : null,
        ),
      );
    }
    return List<GymAmenityVotes>.unmodifiable(result);
  }

  Future<List<CrowdReport>> loadReportsForGyms({
    required Iterable<String> gymIds,
    int limitPerGym = 60,
  }) async {
    if (!hasRemoteBackend) {
      return const <CrowdReport>[];
    }
    refreshAuthFromStorage();
    final userId = _userId.trim();
    if (userId.isEmpty) {
      return const <CrowdReport>[];
    }

    final filteredGymIds = gymIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (filteredGymIds.isEmpty) {
      return const <CrowdReport>[];
    }

    final uri = _buildRemoteUri(<String>[
      'v1',
      'crowd',
      'reports',
      userId,
    ]).replace(
      queryParameters: <String, String>{
        'gymIds': filteredGymIds.join(','),
        'limitPerGym': '${limitPerGym.clamp(1, 200)}',
      },
    );
    final response = await _httpClient
        .get(uri, headers: _remoteHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      return const <CrowdReport>[];
    }

    final decoded = _decodeJsonMap(response.body);
    final rawReports = decoded['reports'];
    if (rawReports is! List) {
      return const <CrowdReport>[];
    }
    final reports = <CrowdReport>[];
    for (final raw in rawReports) {
      if (raw is! Map) {
        continue;
      }
      final report = _crowdReportFromJson(Map<String, dynamic>.from(raw));
      if (report != null) {
        reports.add(report);
      }
    }
    return reports;
  }

  Future<RemoteCrowdLeaderboardResult?> loadRegionalLeaderboard({
    required String regionKey,
    String? regionLabel,
    int limit = 10,
    int windowDays = 7,
  }) async {
    if (!hasRemoteBackend) {
      return null;
    }
    refreshAuthFromStorage();
    final userId = _userId.trim();
    if (userId.isEmpty) {
      return null;
    }

    final normalizedRegionKey = regionKey.trim();
    final normalizedRegionLabel = (regionLabel ?? '').trim();
    final uri = _buildRemoteUri(<String>[
      'v1',
      'crowd',
      'leaderboard',
      userId,
    ]).replace(
      queryParameters: <String, String>{
        'windowDays': '${windowDays.clamp(1, 30)}',
        'limit': '${limit.clamp(1, 50)}',
        if (normalizedRegionKey.isNotEmpty) 'regionKey': normalizedRegionKey,
        if (normalizedRegionLabel.isNotEmpty)
          'regionLabel': normalizedRegionLabel,
      },
    );

    final response = await _httpClient
        .get(uri, headers: _remoteHeaders())
        .timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }
    final decoded = _decodeJsonMap(response.body);
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      return null;
    }

    final entries = <RemoteCrowdLeaderboardEntry>[];
    for (final raw in rawEntries) {
      if (raw is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(raw);
      final entryUserId = '${map['userId'] ?? ''}'.trim();
      if (entryUserId.isEmpty) {
        continue;
      }
      final points = int.tryParse('${map['points'] ?? ''}') ?? 0;
      final rank = int.tryParse('${map['rank'] ?? ''}') ?? 0;
      final displayName = '${map['displayName'] ?? ''}'.trim();
      final isCurrentUser = map['isCurrentUser'] == true;
      entries.add(
        RemoteCrowdLeaderboardEntry(
          userId: entryUserId,
          displayName: displayName.isEmpty ? entryUserId : displayName,
          points: points.clamp(0, 1000000),
          rank: rank.clamp(0, 1000000),
          isCurrentUser: isCurrentUser,
        ),
      );
    }

    final userRank = int.tryParse('${decoded['userRank'] ?? ''}') ?? 0;
    final userPoints = int.tryParse('${decoded['userPoints'] ?? ''}') ?? 0;
    final responseRegionKey =
        '${decoded['regionKey'] ?? normalizedRegionKey}'.trim();
    final responseRegionLabel =
        '${decoded['regionLabel'] ?? normalizedRegionLabel}'.trim();
    final responseWindowDays =
        int.tryParse('${decoded['windowDays'] ?? ''}') ?? windowDays;

    return RemoteCrowdLeaderboardResult(
      regionKey: responseRegionKey,
      regionLabel: responseRegionLabel,
      windowDays: responseWindowDays.clamp(1, 30),
      userRank: userRank.clamp(0, 1000000),
      userPoints: userPoints.clamp(0, 1000000),
      entries: List<RemoteCrowdLeaderboardEntry>.unmodifiable(entries),
    );
  }

  Uri _buildRemoteUri(List<String> pathSegments) {
    final baseUri = _backendBaseUri;
    if (baseUri == null) {
      throw StateError('Backend base URL not configured');
    }
    final baseSegments = baseUri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    return baseUri.replace(
      pathSegments: <String>[...baseSegments, ...pathSegments],
      queryParameters: null,
    );
  }

  Map<String, String> _remoteHeaders({bool contentTypeJson = false}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (contentTypeJson) {
      headers['Content-Type'] = 'application/json';
    }
    final auth = _authorizationHeader();
    if (auth != null) {
      headers[HttpHeaders.authorizationHeader] = auth;
    }
    return headers;
  }

  String? _authorizationHeader() {
    final token = _authToken.trim();
    if (token.isEmpty) {
      return null;
    }
    if (token.toLowerCase().startsWith('bearer ')) {
      return token;
    }
    return 'Bearer $token';
  }

  Map<String, dynamic> _decodeJsonMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('Invalid backend payload');
  }

  String _parseBackendError(http.Response response) {
    try {
      final decoded = _decodeJsonMap(response.body);
      final error = '${decoded['error'] ?? ''}'.trim();
      if (error.isNotEmpty) {
        return error;
      }
      final message = '${decoded['message'] ?? ''}'.trim();
      if (message.isNotEmpty) {
        return message;
      }
    } catch (_) {}
    return 'Backend HTTP ${response.statusCode}';
  }

  CrowdReport? _crowdReportFromJson(Map<String, dynamic> json) {
    final gymId = '${json['gymId'] ?? json['gym_id'] ?? ''}'.trim();
    if (gymId.isEmpty) {
      return null;
    }
    final occupancyRaw = json['occupancyPercent'] ?? json['occupancy_percent'];
    final occupancy = int.tryParse('$occupancyRaw');
    if (occupancy == null) {
      return null;
    }
    final createdAtRaw =
        '${json['createdAt'] ?? json['created_at'] ?? ''}'.trim();
    final createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
    if (createdAt == null) {
      return null;
    }
    final reporterId =
        '${json['reporterId'] ?? json['reporter_id'] ?? 'anonymous'}'.trim();
    final reliabilityRaw =
        json['reliabilityWeight'] ?? json['reliability_weight'];
    final reliability = double.tryParse('$reliabilityRaw') ?? 1.0;

    return CrowdReport(
      gymId: gymId,
      occupancyPercent: occupancy.clamp(0, 100),
      createdAt: createdAt,
      reporterId: reporterId.isEmpty ? 'anonymous' : reporterId,
      reliabilityWeight: reliability.clamp(0.2, 1.6),
    );
  }
}
