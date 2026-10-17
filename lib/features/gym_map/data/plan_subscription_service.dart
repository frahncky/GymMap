import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PixCharge {
  const PixCharge({
    required this.chargeId,
    required this.planKey,
    required this.monthlyPrice,
    required this.copyPasteCode,
    required this.status,
    required this.isProratedMigration,
    required this.createdAt,
    required this.expiresAt,
    this.amountDueCents,
    this.creditCents,
    this.targetPlanMonthlyPrice,
    this.previousPlanKey,
  });

  factory PixCharge.fromJson(Map<String, dynamic> json) {
    final chargeId = '${json['chargeId'] ?? json['charge_id'] ?? ''}'.trim();
    if (chargeId.isEmpty) {
      throw const FormatException('Missing chargeId');
    }
    final targetPlanMonthlyPrice =
        '${json['targetPlanMonthlyPrice'] ?? json['target_plan_monthly_price'] ?? ''}'
            .trim();
    final previousPlanKey =
        '${json['previousPlanKey'] ?? json['previous_plan_key'] ?? ''}'.trim();
    return PixCharge(
      chargeId: chargeId,
      planKey: '${json['planKey'] ?? json['plan_key'] ?? ''}',
      monthlyPrice: '${json['monthlyPrice'] ?? json['monthly_price'] ?? ''}',
      copyPasteCode:
          '${json['copyPasteCode'] ?? json['copy_paste_code'] ?? ''}',
      status: '${json['status'] ?? 'pending'}'.trim().toLowerCase(),
      isProratedMigration:
          json['isProratedMigration'] == true ||
          json['is_prorated_migration'] == true,
      createdAt:
          _parseDateField(json['createdAt'] ?? json['created_at']) ??
          DateTime.now().toUtc(),
      expiresAt:
          _parseDateField(json['expiresAt'] ?? json['expires_at']) ??
          DateTime.now().toUtc().add(const Duration(minutes: 20)),
      amountDueCents: _parseIntField(
        json['amountDueCents'] ?? json['amount_due_cents'],
      ),
      creditCents: _parseIntField(json['creditCents'] ?? json['credit_cents']),
      targetPlanMonthlyPrice:
          targetPlanMonthlyPrice.isEmpty ? null : targetPlanMonthlyPrice,
      previousPlanKey: previousPlanKey.isEmpty ? null : previousPlanKey,
    );
  }

  final String chargeId;
  final String planKey;
  final String monthlyPrice;
  final String copyPasteCode;
  final String status;
  final bool isProratedMigration;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int? amountDueCents;
  final int? creditCents;
  final String? targetPlanMonthlyPrice;
  final String? previousPlanKey;

  bool get isPaid => status == 'paid';
}

class SubscriptionState {
  const SubscriptionState({
    required this.activePlanKey,
    this.startsAt,
    this.expiresAt,
  });

  factory SubscriptionState.fromJson(Map<String, dynamic> json) {
    final planKey =
        '${json['activePlanKey'] ?? json['active_plan_key'] ?? json['planKey'] ?? PlanSubscriptionService.freePlanKey}';
    return SubscriptionState(
      activePlanKey: planKey,
      startsAt: _parseDateField(json['startsAt'] ?? json['starts_at']),
      expiresAt: _parseDateField(json['expiresAt'] ?? json['expires_at']),
    );
  }

  final String activePlanKey;
  final DateTime? startsAt;
  final DateTime? expiresAt;

  bool get isFreePlan => activePlanKey == PlanSubscriptionService.freePlanKey;
}

class PlanAuthSession {
  const PlanAuthSession({
    required this.userId,
    required this.accessToken,
    this.expiresAt,
    this.expiresInSec,
  });

  final String userId;
  final String accessToken;
  final DateTime? expiresAt;
  final int? expiresInSec;
}

class PlanSubscriptionService {
  PlanSubscriptionService._({
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

  static const String freePlanKey = 'free';
  static const String _activePlanKey = 'subscription.active_plan';
  static const String _startsAtUtcKey = 'subscription.starts_at_utc';
  static const String _expiresAtUtcKey = 'subscription.expires_at_utc';
  static const String _authUserIdKey = 'subscription.auth.user_id';
  static const String _authTokenKey = 'subscription.auth.token';
  static const String _authAccountKindKey = 'subscription.auth.account_kind';
  static const String _authUsernameKey = 'subscription.auth.username';
  // Credencial da conta anônima deste aparelho; continua guardada quando o
  // usuário entra em outra conta, para que "Sair" volte para ela.
  static const String _deviceUserIdKey = 'subscription.auth.device_user_id';
  static const String _deviceSecretKey = 'subscription.auth.device_secret';
  static const Duration _sessionRefreshMargin = Duration(days: 3);
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _productionConfirmPollInterval = Duration(seconds: 3);
  static const Duration _productionConfirmMaxWait = Duration(seconds: 30);
  static const bool _productionMode = bool.fromEnvironment(
    'PLAN_PRODUCTION_MODE',
    defaultValue: false,
  );

  final SharedPreferences _prefs;
  final Uri? _backendBaseUri;
  String _userId;
  String _authToken;
  final http.Client _httpClient;
  final math.Random _random = math.Random();

  bool get hasRemoteBackend => _backendBaseUri != null;
  bool get hasAuthSession => _authToken.trim().isNotEmpty;

  /// Sessão criada automaticamente para o aparelho, sem usuário e senha.
  bool get isAnonymousSession =>
      hasAuthSession && _prefs.getString(_authAccountKindKey) == 'anonymous';
  String? get username {
    final value = (_prefs.getString(_authUsernameKey) ?? '').trim();
    return value.isEmpty ? null : value;
  }
  String get userId => _userId;
  bool get isProductionMode => _productionMode;
  bool get allowsManualPixConfirmation => !_productionMode;

  bool get _hasExplicitUserIdentity {
    final normalized = _userId.trim();
    return normalized.isNotEmpty && normalized != 'local-device-user';
  }

  static Future<PlanSubscriptionService> create({
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
    final tokenSubject = _extractJwtSubject(normalizedAuthToken);
    final effectiveUserId =
        normalizedUserId.isEmpty || normalizedUserId == 'local-device-user'
            ? (tokenSubject ?? normalizedUserId)
            : normalizedUserId;

    return PlanSubscriptionService._(
      prefs: prefs,
      backendBaseUri: parsedBaseUrl,
      userId: effectiveUserId.isEmpty ? 'local-device-user' : effectiveUserId,
      authToken: normalizedAuthToken,
      httpClient: httpClient,
    );
  }

  Future<PlanAuthSession> signIn({
    required String userId,
    required String password,
  }) async {
    final normalizedUserId = userId.trim();
    if (!hasRemoteBackend) {
      throw StateError('Backend base URL not configured');
    }
    if (normalizedUserId.isEmpty || password.isEmpty) {
      throw StateError('missing_credentials');
    }

    final uri = _buildRemoteUri(<String>['v1', 'auth', 'login']);
    final response = await _httpClient
        .post(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'userId': normalizedUserId,
            'password': password,
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_parseBackendError(response));
    }
    return _applyAuthResponse(response.body, fallbackUserId: normalizedUserId);
  }

  /// Cria a conta com usuário e senha. Se a sessão atual for anônima, o
  /// backend promove essa conta mantendo o userId (assinatura e relatos
  /// continuam vinculados).
  Future<PlanAuthSession> register({
    required String username,
    required String password,
  }) async {
    if (!hasRemoteBackend) {
      throw StateError('Backend base URL not configured');
    }
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw StateError('missing_credentials');
    }
    final upgradingAnonymous = isAnonymousSession;
    final response = await _httpClient
        .post(
          _buildRemoteUri(<String>['v1', 'auth', 'register']),
          headers: _remoteHeaders(contentTypeJson: true),
          body: jsonEncode(<String, dynamic>{
            'username': normalizedUsername,
            'password': password,
          }),
        )
        .timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.created) {
      throw StateError(_parseBackendError(response));
    }
    final session = await _applyAuthResponse(response.body);
    if (upgradingAnonymous) {
      // O segredo do aparelho deixa de valer quando a conta ganha senha.
      await _prefs.remove(_deviceUserIdKey);
      await _prefs.remove(_deviceSecretKey);
    }
    return session;
  }

  /// Garante uma sessão válida: renova a conta anônima do aparelho ou cria
  /// uma nova. Sessões de conta registrada expiradas exigem novo login.
  Future<void> ensureSession() async {
    if (!hasRemoteBackend) {
      return;
    }
    if (hasAuthSession && !isAnonymousSession) {
      // Conta registrada: sem a senha não há como renovar; se o token
      // vencer, o usuário entra de novo pela tela de planos.
      return;
    }
    final expiresAt = _extractJwtExpiry(_authToken);
    if (hasAuthSession &&
        (expiresAt == null ||
            expiresAt.isAfter(
              DateTime.now().toUtc().add(_sessionRefreshMargin),
            ))) {
      return;
    }

    final deviceUserId = (_prefs.getString(_deviceUserIdKey) ?? '').trim();
    final deviceSecret = _prefs.getString(_deviceSecretKey) ?? '';
    if (deviceUserId.isNotEmpty && deviceSecret.isNotEmpty) {
      try {
        await signIn(userId: deviceUserId, password: deviceSecret);
        return;
      } on StateError catch (error) {
        if (error.message != 'invalid_credentials') {
          rethrow;
        }
        await _prefs.remove(_deviceUserIdKey);
        await _prefs.remove(_deviceSecretKey);
      }
    }
    await _createAnonymousAccount();
  }

  Future<void> _createAnonymousAccount() async {
    final response = await _httpClient
        .post(
          _buildRemoteUri(<String>['v1', 'auth', 'anonymous']),
          headers: const <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: '{}',
        )
        .timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.created &&
        response.statusCode != HttpStatus.ok) {
      throw StateError(_parseBackendError(response));
    }
    final session = await _applyAuthResponse(response.body);
    final decoded = jsonDecode(response.body);
    final deviceSecret =
        decoded is Map ? '${decoded['deviceSecret'] ?? ''}'.trim() : '';
    if (deviceSecret.isEmpty) {
      throw const FormatException('Missing device secret');
    }
    await _prefs.setString(_deviceUserIdKey, session.userId);
    await _prefs.setString(_deviceSecretKey, deviceSecret);
  }

  Future<PlanAuthSession> _applyAuthResponse(
    String body, {
    String? fallbackUserId,
  }) async {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Invalid backend payload');
    }
    final payload = Map<String, dynamic>.from(decoded);
    final accessToken =
        '${payload['accessToken'] ?? payload['token'] ?? ''}'.trim();
    if (accessToken.isEmpty) {
      throw const FormatException('Missing access token');
    }

    final backendUserId =
        '${payload['userId'] ?? payload['sub'] ?? fallbackUserId ?? ''}'.trim();
    if (backendUserId.isEmpty) {
      throw const FormatException('Missing userId');
    }

    _userId = backendUserId;
    _authToken = accessToken;
    await _persistAuthSession();
    final accountKind = '${payload['accountKind'] ?? ''}'.trim();
    if (accountKind.isEmpty) {
      await _prefs.remove(_authAccountKindKey);
    } else {
      await _prefs.setString(_authAccountKindKey, accountKind);
    }
    final username = '${payload['username'] ?? ''}'.trim();
    if (username.isEmpty) {
      await _prefs.remove(_authUsernameKey);
    } else {
      await _prefs.setString(_authUsernameKey, username);
    }

    return PlanAuthSession(
      userId: backendUserId,
      accessToken: accessToken,
      expiresAt: _parseDateField(payload['expiresAt'] ?? payload['expires_at']),
      expiresInSec:
          (payload['expiresInSec'] is num)
              ? (payload['expiresInSec'] as num).toInt()
              : int.tryParse('${payload['expiresInSec'] ?? ''}'),
    );
  }

  Future<void> signOut() async {
    _authToken = '';
    await _prefs.remove(_authTokenKey);
    await _prefs.remove(_authUserIdKey);
    await _prefs.remove(_authAccountKindKey);
    await _prefs.remove(_authUsernameKey);
    await _prefs.setString(_activePlanKey, freePlanKey);
    await _prefs.remove(_startsAtUtcKey);
    await _prefs.remove(_expiresAtUtcKey);
  }

  Future<SubscriptionState> loadActiveSubscription() async {
    if (hasRemoteBackend) {
      try {
        final remoteState = await _loadRemoteSubscription();
        await _saveLocalSubscription(remoteState);
        return remoteState;
      } catch (_) {
        // Falls back to local cache when backend is unavailable.
      }
    }

    return _loadLocalSubscription();
  }

  Future<void> downgradeToFree() async {
    if (hasRemoteBackend) {
      try {
        await _postRemoteJson(
          ['v1', 'subscriptions', 'downgrade'],
          <String, dynamic>{'userId': _userId},
          expectedSuccessCodes: const <int>{200},
        );
      } catch (_) {
        // Keep local behavior even if remote is down.
      }
    }

    await _prefs.setString(_activePlanKey, freePlanKey);
    await _prefs.remove(_startsAtUtcKey);
    await _prefs.remove(_expiresAtUtcKey);
  }

  Future<SubscriptionState> activatePaidPlan(String planKey) async {
    final nowUtc = DateTime.now().toUtc();
    final expiresAtUtc = _addOneCalendarMonth(nowUtc);

    final snapshot = SubscriptionState(
      activePlanKey: planKey,
      startsAt: nowUtc,
      expiresAt: expiresAtUtc,
    );
    await _saveLocalSubscription(snapshot);
    return snapshot;
  }

  Future<PixCharge> createPixCharge({
    required String planKey,
    required String monthlyPrice,
  }) async {
    if (_productionMode) {
      if (!hasRemoteBackend) {
        throw StateError('backend_required_in_production');
      }
      if (!_hasExplicitUserIdentity) {
        throw StateError('user_identity_required_in_production');
      }
    }

    if (hasRemoteBackend) {
      final body = <String, dynamic>{
        'userId': _userId,
        'planKey': planKey,
        'monthlyPrice': monthlyPrice,
      };
      final decoded = await _postRemoteJson(
        ['v1', 'billing', 'pix', 'charge'],
        body,
        expectedSuccessCodes: const <int>{200, 201},
      );
      final rawCharge = _extractPayloadMap(decoded, preferredKey: 'charge');
      return PixCharge.fromJson(rawCharge);
    }

    return _createLocalPixCharge(planKey: planKey, monthlyPrice: monthlyPrice);
  }

  Future<SubscriptionState> confirmPixPayment({
    required PixCharge charge,
    required String planKey,
  }) async {
    if (_productionMode) {
      if (!hasRemoteBackend) {
        throw StateError('backend_required_in_production');
      }
      if (!_hasExplicitUserIdentity) {
        throw StateError('user_identity_required_in_production');
      }

      final deadline = DateTime.now().toUtc().add(_productionConfirmMaxWait);
      while (true) {
        final snapshot = await _loadRemoteSubscription();
        if (snapshot.activePlanKey == planKey) {
          await _saveLocalSubscription(snapshot);
          return snapshot;
        }
        if (DateTime.now().toUtc().isAfter(deadline)) {
          throw StateError('payment_pending_webhook');
        }
        await Future<void>.delayed(_productionConfirmPollInterval);
      }
    }

    if (hasRemoteBackend) {
      final body = <String, dynamic>{
        'userId': _userId,
        'chargeId': charge.chargeId,
        'planKey': planKey,
      };
      final decoded = await _postRemoteJson(
        ['v1', 'billing', 'pix', 'confirm'],
        body,
        expectedSuccessCodes: const <int>{200},
      );
      final rawSubscription = _extractPayloadMap(
        decoded,
        preferredKey: 'subscription',
      );
      final snapshot = SubscriptionState.fromJson(rawSubscription);
      await _saveLocalSubscription(snapshot);
      return snapshot;
    }

    final now = DateTime.now().toUtc();
    if (now.isAfter(charge.expiresAt)) {
      throw StateError('Cobranca Pix expirada');
    }
    return activatePaidPlan(planKey);
  }

  Future<SubscriptionState> confirmPlayStorePurchase({
    required String planKey,
    required String productId,
    required String purchaseToken,
    String? purchaseId,
  }) async {
    final normalizedPlanKey = planKey.trim().toLowerCase();
    final normalizedProductId = productId.trim();
    final normalizedToken = purchaseToken.trim();
    final normalizedPurchaseId = (purchaseId ?? '').trim();

    if (normalizedPlanKey.isEmpty || normalizedPlanKey == freePlanKey) {
      throw StateError('invalid_plan_key');
    }
    if (normalizedProductId.isEmpty) {
      throw StateError('play_product_id_missing');
    }
    if (normalizedToken.isEmpty) {
      throw StateError('play_purchase_token_missing');
    }

    if (_productionMode) {
      if (!hasRemoteBackend) {
        throw StateError('backend_required_in_production');
      }
      if (!_hasExplicitUserIdentity) {
        throw StateError('user_identity_required_in_production');
      }
    }

    if (!hasRemoteBackend) {
      return activatePaidPlan(normalizedPlanKey);
    }

    final payload = <String, dynamic>{
      'userId': _userId,
      'planKey': normalizedPlanKey,
      'productId': normalizedProductId,
      'purchaseToken': normalizedToken,
    };
    if (normalizedPurchaseId.isNotEmpty) {
      payload['purchaseId'] = normalizedPurchaseId;
    }
    final decoded = await _postRemoteJson(
      ['v1', 'billing', 'play', 'validate'],
      payload,
      expectedSuccessCodes: const <int>{200},
    );
    final rawSubscription = _extractPayloadMap(
      decoded,
      preferredKey: 'subscription',
    );
    final snapshot = SubscriptionState.fromJson(rawSubscription);
    await _saveLocalSubscription(snapshot);
    return snapshot;
  }

  Future<SubscriptionState> _loadRemoteSubscription() async {
    final decoded = await _getRemoteJson(
      ['v1', 'subscriptions', _userId],
      expectedSuccessCodes: const <int>{200},
    );
    final payload = _extractPayloadMap(decoded, preferredKey: 'subscription');
    return SubscriptionState.fromJson(payload);
  }

  Future<SubscriptionState> _loadLocalSubscription() async {
    final planKey = _prefs.getString(_activePlanKey) ?? freePlanKey;
    final startsAt = _parseStoredUtc(_prefs.getString(_startsAtUtcKey));
    final expiresAt = _parseStoredUtc(_prefs.getString(_expiresAtUtcKey));

    if (planKey == freePlanKey) {
      return const SubscriptionState(activePlanKey: freePlanKey);
    }

    if (expiresAt == null || DateTime.now().toUtc().isAfter(expiresAt)) {
      await downgradeToFree();
      return const SubscriptionState(activePlanKey: freePlanKey);
    }

    return SubscriptionState(
      activePlanKey: planKey,
      startsAt: startsAt,
      expiresAt: expiresAt,
    );
  }

  Future<void> _saveLocalSubscription(SubscriptionState snapshot) async {
    await _prefs.setString(_activePlanKey, snapshot.activePlanKey);
    if (snapshot.startsAt != null) {
      await _prefs.setString(
        _startsAtUtcKey,
        snapshot.startsAt!.toIso8601String(),
      );
    } else {
      await _prefs.remove(_startsAtUtcKey);
    }
    if (snapshot.expiresAt != null) {
      await _prefs.setString(
        _expiresAtUtcKey,
        snapshot.expiresAt!.toIso8601String(),
      );
    } else {
      await _prefs.remove(_expiresAtUtcKey);
    }
  }

  Future<Map<String, dynamic>> _getRemoteJson(
    List<String> pathSegments, {
    Set<int> expectedSuccessCodes = const <int>{200},
  }) async {
    final uri = _buildRemoteUri(pathSegments);
    final response = await _httpClient
        .get(uri, headers: _remoteHeaders())
        .timeout(_requestTimeout);

    if (!expectedSuccessCodes.contains(response.statusCode)) {
      throw StateError(_parseBackendError(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backend payload');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _postRemoteJson(
    List<String> pathSegments,
    Map<String, dynamic> body, {
    Set<int> expectedSuccessCodes = const <int>{200},
  }) async {
    final uri = _buildRemoteUri(pathSegments);
    final response = await _httpClient
        .post(
          uri,
          headers: _remoteHeaders(contentTypeJson: true),
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);

    if (!expectedSuccessCodes.contains(response.statusCode)) {
      throw StateError(_parseBackendError(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backend payload');
    }
    return decoded;
  }

  Uri _buildRemoteUri(List<String> pathSegments) {
    final baseUri = _backendBaseUri;
    if (baseUri == null) {
      throw StateError('Backend base URL not configured');
    }
    final baseSegments =
        baseUri.pathSegments
            .where((segment) => segment.trim().isNotEmpty)
            .toList();
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
    final authValue = _authorizationHeader();
    if (authValue != null) {
      headers[HttpHeaders.authorizationHeader] = authValue;
    }
    return headers;
  }

  Future<void> _persistAuthSession() async {
    await _prefs.setString(_authUserIdKey, _userId);
    await _prefs.setString(_authTokenKey, _authToken);
  }

  String _parseBackendError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = '${decoded['error'] ?? ''}'.trim();
        if (error == 'rate_limited') {
          final retryAfterRaw =
              decoded['retryAfterSec'] ?? decoded['retry_after_sec'];
          final retryAfterSec = int.tryParse('$retryAfterRaw');
          if (retryAfterSec != null && retryAfterSec > 0) {
            return 'rate_limited:$retryAfterSec';
          }
        }
        if (error.isNotEmpty) {
          return error;
        }
        final message = '${decoded['message'] ?? ''}'.trim();
        if (message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return 'Backend HTTP ${response.statusCode}';
  }

  String? _authorizationHeader() {
    if (_authToken.isEmpty) {
      return null;
    }
    final lower = _authToken.toLowerCase();
    if (lower.startsWith('bearer ')) {
      return _authToken;
    }
    return 'Bearer $_authToken';
  }

  Map<String, dynamic> _extractPayloadMap(
    Map<String, dynamic> decoded, {
    required String preferredKey,
  }) {
    final nested = decoded[preferredKey];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return decoded;
  }

  PixCharge _createLocalPixCharge({
    required String planKey,
    required String monthlyPrice,
  }) {
    final now = DateTime.now().toUtc();
    final chargeId =
        'pix_${planKey}_${now.millisecondsSinceEpoch}_${1000 + _random.nextInt(9000)}';
    final expiresAt = now.add(const Duration(minutes: 20));
    final copyPasteCode = _buildMockCopyPasteCode(
      chargeId: chargeId,
      planKey: planKey,
      monthlyPrice: monthlyPrice,
    );

    return PixCharge(
      chargeId: chargeId,
      planKey: planKey,
      monthlyPrice: monthlyPrice,
      copyPasteCode: copyPasteCode,
      status: 'pending',
      isProratedMigration: false,
      createdAt: now,
      expiresAt: expiresAt,
    );
  }

  DateTime _addOneCalendarMonth(DateTime sourceUtc) {
    final year = sourceUtc.year;
    final month = sourceUtc.month;
    final nextMonthDate =
        month == 12
            ? DateTime.utc(year + 1, 1, 1)
            : DateTime.utc(year, month + 1, 1);

    final maxDayInNextMonth =
        DateTime.utc(nextMonthDate.year, nextMonthDate.month + 1, 0).day;
    final safeDay = math.min(sourceUtc.day, maxDayInNextMonth);

    return DateTime.utc(
      nextMonthDate.year,
      nextMonthDate.month,
      safeDay,
      sourceUtc.hour,
      sourceUtc.minute,
      sourceUtc.second,
      sourceUtc.millisecond,
      sourceUtc.microsecond,
    );
  }

  DateTime? _parseStoredUtc(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  String _buildMockCopyPasteCode({
    required String chargeId,
    required String planKey,
    required String monthlyPrice,
  }) {
    final cents = monthlyPrice.replaceAll(RegExp(r'[^0-9]'), '');
    return '00020126360014BR.GOV.BCB.PIX0114spacegym.app520400005303986'
        '540${cents.padLeft(4, '0')}5802BR5910SPACEGYM6009SAOPAULO62070503***'
        '6304${chargeId.substring(chargeId.length - 4)}'
        'PLAN$planKey';
  }
}

DateTime? _parseDateField(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is String) {
    return DateTime.tryParse(raw)?.toUtc();
  }
  return DateTime.tryParse('$raw')?.toUtc();
}

int? _parseIntField(dynamic raw) {
  if (raw == null) {
    return null;
  }
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return int.tryParse('$raw');
}

String? _extractJwtSubject(String rawToken) {
  final subject = '${_decodeJwtPayload(rawToken)?['sub'] ?? ''}'.trim();
  return subject.isEmpty ? null : subject;
}

DateTime? _extractJwtExpiry(String rawToken) {
  final exp = _decodeJwtPayload(rawToken)?['exp'];
  if (exp is! num) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(
    exp.toInt() * 1000,
    isUtc: true,
  );
}

Map<dynamic, dynamic>? _decodeJwtPayload(String rawToken) {
  final trimmed = rawToken.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final token =
      trimmed.toLowerCase().startsWith('bearer ')
          ? trimmed.substring(7).trim()
          : trimmed;
  final parts = token.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final payloadBytes = base64Url.decode(base64Url.normalize(parts[1]));
    final payload = jsonDecode(utf8.decode(payloadBytes));
    return payload is Map ? payload : null;
  } catch (_) {
    return null;
  }
}
