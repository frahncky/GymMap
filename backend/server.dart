import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:googleapis/androidpublisher/v3.dart' as androidpublisher;
import 'package:googleapis_auth/auth_io.dart' as google_auth;
import 'package:postgres/postgres.dart';

const Map<String, int> _planPricesCents = <String, int>{
  'free': 0,
  'smart': 490,
  'pro': 990,
  'elite': 1490,
};

Future<void> main() async {
  final host = Platform.environment['HOST'] ?? '0.0.0.0';
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final storePath =
      Platform.environment['STORE_PATH'] ?? 'backend/data/store.json';
  final productionMode = _parseBoolEnv(
    Platform.environment['BACKEND_PRODUCTION_MODE'] ?? '',
  );
  final corsAllowOrigin =
      (Platform.environment['CORS_ALLOW_ORIGIN'] ?? '*').trim();
  final databaseUrl = Platform.environment['DATABASE_URL'] ?? '';
  final webhookToken = Platform.environment['WEBHOOK_TOKEN'] ?? '';
  final webhookSecrets = _normalizeWebhookSecrets(
    currentSecret: Platform.environment['WEBHOOK_SIGNING_SECRET'] ?? '',
    previousSecretsRaw:
        Platform.environment['WEBHOOK_SIGNING_SECRET_PREVIOUS'] ?? '',
  );
  final webhookToleranceSec =
      int.tryParse(
        Platform.environment['WEBHOOK_SIGNATURE_TOLERANCE_SEC'] ?? '',
      ) ??
      300;
  final adminApiToken = Platform.environment['ADMIN_API_TOKEN'] ?? '';
  final pixProviderMode =
      (Platform.environment['PIX_PROVIDER_MODE'] ?? 'mock')
          .trim()
          .toLowerCase();
  final pixProviderVendor =
      (Platform.environment['PIX_PROVIDER_VENDOR'] ?? 'generic')
          .trim()
          .toLowerCase();
  final pixProviderBaseUrl =
      Platform.environment['PIX_PROVIDER_BASE_URL'] ?? '';
  final pixProviderApiKey = Platform.environment['PIX_PROVIDER_API_KEY'] ?? '';
  final pixMpDefaultPayerEmail =
      Platform.environment['PIX_MP_DEFAULT_PAYER_EMAIL'] ?? '';
  final pixMpNotificationUrl =
      Platform.environment['PIX_MP_NOTIFICATION_URL'] ?? '';
  final pixProviderChargePath =
      (Platform.environment['PIX_PROVIDER_CHARGE_PATH'] ?? '/v1/pix/charges')
          .trim();
  final pixProviderStatusPathTemplate =
      (Platform.environment['PIX_PROVIDER_STATUS_PATH_TEMPLATE'] ??
              '/v1/pix/charges/{chargeId}')
          .trim();
  final pixProviderTimeoutSec =
      int.tryParse(Platform.environment['PIX_PROVIDER_TIMEOUT_SEC'] ?? '') ??
      12;
  final jwtSecret = Platform.environment['JWT_HS256_SECRET'] ?? '';
  final jwtIssuer =
      (Platform.environment['JWT_ISSUER'] ?? 'gymmap-backend').trim();
  final jwtAccessTtlSec =
      int.tryParse(Platform.environment['JWT_ACCESS_TTL_SEC'] ?? '') ??
      30 * 24 * 60 * 60;
  final globalRequestsPerMin =
      int.tryParse(Platform.environment['RATE_LIMIT_REQUESTS_PER_MIN'] ?? '') ??
      240;
  final loginAttemptsPerMin =
      int.tryParse(
        Platform.environment['RATE_LIMIT_LOGIN_ATTEMPTS_PER_MIN'] ?? '',
      ) ??
      15;
  final billingAttemptsPerMin =
      int.tryParse(
        Platform.environment['RATE_LIMIT_BILLING_ATTEMPTS_PER_MIN'] ?? '',
      ) ??
      20;
  final chargeRetentionDays =
      int.tryParse(Platform.environment['CHARGE_RETENTION_DAYS'] ?? '') ?? 120;
  final webhookRetentionDays =
      int.tryParse(Platform.environment['WEBHOOK_RETENTION_DAYS'] ?? '') ?? 60;
  final crowdReportRetentionDays =
      int.tryParse(Platform.environment['CROWD_REPORT_RETENTION_DAYS'] ?? '') ??
      45;
  final requestLogEnabled =
      !_parseBoolEnv(Platform.environment['REQUEST_LOG_DISABLED'] ?? '');
  final authUsers = _parseAuthUsers(
    Platform.environment['AUTH_USERS_JSON'] ?? '',
  );
  final authDefaultPassword =
      Platform.environment['AUTH_DEFAULT_PASSWORD'] ?? '';
  final playPackageName =
      (Platform.environment['PLAY_PACKAGE_NAME'] ?? '').trim();
  final playServiceAccountJson = _resolvePlayServiceAccountJson(
    rawJson: Platform.environment['PLAY_SERVICE_ACCOUNT_JSON'] ?? '',
    base64Json: Platform.environment['PLAY_SERVICE_ACCOUNT_JSON_BASE64'] ?? '',
  );
  final playAllowUnverifiedInDev = _parseBoolEnv(
    Platform.environment['PLAY_BILLING_ALLOW_UNVERIFIED'] ?? '',
  );
  final playProductIdsByPlan = <String, String>{
    'smart':
        (Platform.environment['PLAY_PRODUCT_ID_SMART'] ?? 'smart_mensal')
            .trim(),
    'pro': (Platform.environment['PLAY_PRODUCT_ID_PRO'] ?? 'pro_mensal').trim(),
    'elite':
        (Platform.environment['PLAY_PRODUCT_ID_ELITE'] ?? 'elite_mensal')
            .trim(),
  };

  final startupIssues = _validateProductionConfig(
    productionMode: productionMode,
    databaseUrl: databaseUrl,
    jwtSecret: jwtSecret,
    webhookToken: webhookToken,
    webhookSecrets: webhookSecrets,
    authDefaultPassword: authDefaultPassword,
    corsAllowOrigin: corsAllowOrigin,
    adminApiToken: adminApiToken,
    pixProviderMode: pixProviderMode,
    pixProviderVendor: pixProviderVendor,
    pixProviderBaseUrl: pixProviderBaseUrl,
    pixProviderApiKey: pixProviderApiKey,
    pixMpDefaultPayerEmail: pixMpDefaultPayerEmail,
    globalRequestsPerMin: globalRequestsPerMin,
    loginAttemptsPerMin: loginAttemptsPerMin,
    billingAttemptsPerMin: billingAttemptsPerMin,
    playPackageName: playPackageName,
    playServiceAccountJson: playServiceAccountJson,
    playProductIdsByPlan: playProductIdsByPlan,
  );
  if (startupIssues.isNotEmpty) {
    stderr.writeln('[pix-backend] invalid production configuration:');
    for (final issue in startupIssues) {
      stderr.writeln(' - $issue');
    }
    exitCode = 64;
    return;
  }

  final backend = await _PixBillingBackend.create(
    storeFile: File(storePath),
    productionMode: productionMode,
    corsAllowOrigin: corsAllowOrigin,
    databaseUrl: databaseUrl,
    webhookToken: webhookToken,
    webhookSecrets: webhookSecrets,
    webhookToleranceSec: webhookToleranceSec,
    adminApiToken: adminApiToken,
    jwtSecret: jwtSecret,
    jwtIssuer: jwtIssuer.isEmpty ? 'gymmap-backend' : jwtIssuer,
    jwtAccessTtlSec: jwtAccessTtlSec,
    pixProviderMode: pixProviderMode,
    pixProviderVendor: pixProviderVendor,
    pixProviderBaseUrl: pixProviderBaseUrl,
    pixProviderApiKey: pixProviderApiKey,
    pixMpDefaultPayerEmail: pixMpDefaultPayerEmail,
    pixMpNotificationUrl: pixMpNotificationUrl,
    pixProviderChargePath: pixProviderChargePath,
    pixProviderStatusPathTemplate: pixProviderStatusPathTemplate,
    pixProviderTimeoutSec: pixProviderTimeoutSec,
    globalRequestsPerMin: globalRequestsPerMin,
    loginAttemptsPerMin: loginAttemptsPerMin,
    billingAttemptsPerMin: billingAttemptsPerMin,
    chargeRetentionDays: chargeRetentionDays,
    webhookRetentionDays: webhookRetentionDays,
    crowdReportRetentionDays: crowdReportRetentionDays,
    requestLogEnabled: requestLogEnabled,
    authUsers: authUsers,
    authDefaultPassword: authDefaultPassword,
    playPackageName: playPackageName,
    playServiceAccountJson: playServiceAccountJson,
    playAllowUnverifiedInDev: playAllowUnverifiedInDev,
    playProductIdsByPlan: playProductIdsByPlan,
  );

  final server = await HttpServer.bind(host, port);
  stdout.writeln(
    '[pix-backend] listening on http://$host:$port (storage: ${backend.storageLabel})',
  );
  await for (final request in server) {
    await backend.handle(request);
  }
}

class _PixBillingBackend {
  _PixBillingBackend._({
    required this.storageLabel,
    required this.storeFile,
    required this.db,
    required this.productionMode,
    required this.corsAllowOrigin,
    required this.webhookToken,
    required this.webhookSecrets,
    required this.webhookToleranceSec,
    required this.adminApiToken,
    required this.jwtSecret,
    required this.jwtIssuer,
    required this.jwtAccessTtlSec,
    required this.pixProviderMode,
    required this.pixProviderVendor,
    required this.pixProviderBaseUrl,
    required this.pixProviderApiKey,
    required this.pixMpDefaultPayerEmail,
    required this.pixMpNotificationUrl,
    required this.pixProviderChargePath,
    required this.pixProviderStatusPathTemplate,
    required this.pixProviderTimeoutSec,
    required this.globalRequestsPerMin,
    required this.loginAttemptsPerMin,
    required this.billingAttemptsPerMin,
    required this.chargeRetentionDays,
    required this.webhookRetentionDays,
    required this.crowdReportRetentionDays,
    required this.requestLogEnabled,
    required this.authUsers,
    required this.authDefaultPassword,
    required this.playPackageName,
    required this.playAllowUnverifiedInDev,
    required this.playProductIdsByPlan,
    required this.playBillingClient,
    required this.subscriptions,
    required this.charges,
    required this.webhookEvents,
    required this.gymLocations,
    required this.crowdReports,
  });

  final String storageLabel;
  final File storeFile;
  final PostgreSQLConnection? db;
  final bool productionMode;
  final String corsAllowOrigin;
  final String webhookToken;
  final List<String> webhookSecrets;
  final int webhookToleranceSec;
  final String adminApiToken;
  final String jwtSecret;
  final String jwtIssuer;
  final int jwtAccessTtlSec;
  final String pixProviderMode;
  final String pixProviderVendor;
  final String pixProviderBaseUrl;
  final String pixProviderApiKey;
  final String pixMpDefaultPayerEmail;
  final String pixMpNotificationUrl;
  final String pixProviderChargePath;
  final String pixProviderStatusPathTemplate;
  final int pixProviderTimeoutSec;
  final int globalRequestsPerMin;
  final int loginAttemptsPerMin;
  final int billingAttemptsPerMin;
  final int chargeRetentionDays;
  final int webhookRetentionDays;
  final int crowdReportRetentionDays;
  final bool requestLogEnabled;
  final Map<String, String> authUsers;
  final String authDefaultPassword;
  final String playPackageName;
  final bool playAllowUnverifiedInDev;
  final Map<String, String> playProductIdsByPlan;
  final _GooglePlayBillingClient? playBillingClient;
  final Map<String, Map<String, dynamic>> subscriptions;
  final Map<String, Map<String, dynamic>> charges;
  final Map<String, Map<String, dynamic>> webhookEvents;
  final Map<String, Map<String, dynamic>> gymLocations;
  final Map<String, Map<String, dynamic>> crowdReports;
  final math.Random _random = math.Random();
  static const Duration _crowdReportCooldownWindow = Duration(minutes: 10);
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static const Duration _retentionSweepInterval = Duration(minutes: 20);
  static const int _requestLogSampleBodyBytes = 220;
  final _SlidingWindowRateLimiter _globalRateLimiter =
      _SlidingWindowRateLimiter();
  final _SlidingWindowRateLimiter _loginRateLimiter =
      _SlidingWindowRateLimiter();
  final _SlidingWindowRateLimiter _billingRateLimiter =
      _SlidingWindowRateLimiter();
  final DateTime _startedAtUtc = DateTime.now().toUtc();
  DateTime _nextRetentionSweepAtUtc = DateTime.now().toUtc();
  bool _retentionSweepRunning = false;
  int _requestTotal = 0;
  int _request2xx = 0;
  int _request4xx = 0;
  int _request5xx = 0;
  int _requestInFlight = 0;
  int _lastRateLimitedAtMs = 0;
  final Map<String, int> _routeHits = <String, int>{};
  final Map<String, int> _routeErrors = <String, int>{};

  bool get _dbMode => db != null;
  bool get _jwtEnabled => jwtSecret.trim().isNotEmpty;
  bool get _adminEnabled => adminApiToken.trim().isNotEmpty;
  bool get _externalPixProviderEnabled =>
      pixProviderMode == 'external' &&
      pixProviderBaseUrl.trim().isNotEmpty &&
      pixProviderApiKey.trim().isNotEmpty;
  bool get _isMercadoPagoProvider =>
      pixProviderVendor == 'mercado_pago' || pixProviderVendor == 'mercadopago';
  bool get _loginEnabled =>
      _jwtEnabled && (authUsers.isNotEmpty || authDefaultPassword.isNotEmpty);
  bool get _playBillingConfigured =>
      playBillingClient != null && playPackageName.trim().isNotEmpty;

  static Future<_PixBillingBackend> create({
    required File storeFile,
    required bool productionMode,
    required String corsAllowOrigin,
    required String databaseUrl,
    required String webhookToken,
    required List<String> webhookSecrets,
    required int webhookToleranceSec,
    required String adminApiToken,
    required String jwtSecret,
    required String jwtIssuer,
    required int jwtAccessTtlSec,
    required String pixProviderMode,
    required String pixProviderVendor,
    required String pixProviderBaseUrl,
    required String pixProviderApiKey,
    required String pixMpDefaultPayerEmail,
    required String pixMpNotificationUrl,
    required String pixProviderChargePath,
    required String pixProviderStatusPathTemplate,
    required int pixProviderTimeoutSec,
    required int globalRequestsPerMin,
    required int loginAttemptsPerMin,
    required int billingAttemptsPerMin,
    required int chargeRetentionDays,
    required int webhookRetentionDays,
    required int crowdReportRetentionDays,
    required bool requestLogEnabled,
    required Map<String, String> authUsers,
    required String authDefaultPassword,
    required String playPackageName,
    required String playServiceAccountJson,
    required bool playAllowUnverifiedInDev,
    required Map<String, String> playProductIdsByPlan,
  }) async {
    PostgreSQLConnection? dbConnection;
    _State state;
    var label = storeFile.path;

    final normalizedDbUrl = databaseUrl.trim();
    if (normalizedDbUrl.isNotEmpty) {
      try {
        dbConnection = await _openDb(normalizedDbUrl);
        await _ensureDbSchema(dbConnection);
        state = await _loadFromDb(dbConnection);
        label = 'postgres:$normalizedDbUrl';
      } catch (error) {
        stderr.writeln(
          '[pix-backend] postgres init failed: $error. Falling back to file.',
        );
        await dbConnection?.close();
        dbConnection = null;
        state = await _loadFromFile(storeFile);
      }
    } else {
      state = await _loadFromFile(storeFile);
    }

    final playClient = _GooglePlayBillingClient.tryCreate(
      packageName: playPackageName,
      serviceAccountJson: playServiceAccountJson,
    );

    final backend = _PixBillingBackend._(
      storageLabel: label,
      storeFile: storeFile,
      db: dbConnection,
      productionMode: productionMode,
      corsAllowOrigin: corsAllowOrigin,
      webhookToken: webhookToken,
      webhookSecrets: webhookSecrets,
      webhookToleranceSec: webhookToleranceSec,
      adminApiToken: adminApiToken,
      jwtSecret: jwtSecret.trim(),
      jwtIssuer: jwtIssuer.trim().isEmpty ? 'gymmap-backend' : jwtIssuer.trim(),
      jwtAccessTtlSec: jwtAccessTtlSec,
      pixProviderMode: pixProviderMode,
      pixProviderVendor: pixProviderVendor,
      pixProviderBaseUrl: pixProviderBaseUrl,
      pixProviderApiKey: pixProviderApiKey,
      pixMpDefaultPayerEmail: pixMpDefaultPayerEmail,
      pixMpNotificationUrl: pixMpNotificationUrl,
      pixProviderChargePath: pixProviderChargePath,
      pixProviderStatusPathTemplate: pixProviderStatusPathTemplate,
      pixProviderTimeoutSec: pixProviderTimeoutSec,
      globalRequestsPerMin: globalRequestsPerMin.clamp(30, 6000),
      loginAttemptsPerMin: loginAttemptsPerMin.clamp(3, 600),
      billingAttemptsPerMin: billingAttemptsPerMin.clamp(3, 600),
      chargeRetentionDays: chargeRetentionDays.clamp(15, 720),
      webhookRetentionDays: webhookRetentionDays.clamp(7, 365),
      crowdReportRetentionDays: crowdReportRetentionDays.clamp(7, 365),
      requestLogEnabled: requestLogEnabled,
      authUsers: Map<String, String>.from(authUsers),
      authDefaultPassword: authDefaultPassword,
      playPackageName: playPackageName,
      playAllowUnverifiedInDev: playAllowUnverifiedInDev,
      playProductIdsByPlan: Map<String, String>.from(playProductIdsByPlan),
      playBillingClient: playClient,
      subscriptions: state.subscriptions,
      charges: state.charges,
      webhookEvents: state.webhookEvents,
      gymLocations: state.gymLocations,
      crowdReports: state.crowdReports,
    );
    await backend._persist();
    return backend;
  }

  Future<void> handle(HttpRequest req) async {
    final startedAt = DateTime.now().toUtc();
    final segments =
        req.uri.pathSegments.where((x) => x.trim().isNotEmpty).toList();
    final routeKey = _routeLabel(req.method, segments);
    final clientKey = _clientKeyFor(req);
    final requestId = _nextRequestId();

    _requestInFlight++;
    _requestTotal++;
    _routeHits[routeKey] = (_routeHits[routeKey] ?? 0) + 1;

    req.response.headers.set('X-Request-Id', requestId);
    _applyCors(req.response, allowOrigin: corsAllowOrigin);
    if (req.method == 'OPTIONS') {
      req.response.statusCode = HttpStatus.noContent;
      await req.response.close();
      _requestInFlight = math.max(0, _requestInFlight - 1);
      _request2xx++;
      _logRequest(
        routeKey: routeKey,
        method: req.method,
        statusCode: HttpStatus.noContent,
        latencyMs: 0,
        clientKey: clientKey,
        requestId: requestId,
      );
      return;
    }

    final rateLimitRetry = _consumeRateLimit(
      routeKey: routeKey,
      clientKey: clientKey,
      now: startedAt,
    );
    if (rateLimitRetry != null) {
      final nowMs = startedAt.millisecondsSinceEpoch;
      if (nowMs - _lastRateLimitedAtMs >= 250) {
        _lastRateLimitedAtMs = nowMs;
        _logRequest(
          routeKey: routeKey,
          method: req.method,
          statusCode: HttpStatus.tooManyRequests,
          latencyMs: 0,
          clientKey: clientKey,
          requestId: requestId,
          note: 'rate_limited_${rateLimitRetry.inSeconds}s',
        );
      }
      _requestInFlight = math.max(0, _requestInFlight - 1);
      _request4xx++;
      _routeErrors[routeKey] = (_routeErrors[routeKey] ?? 0) + 1;
      return _json(req, HttpStatus.tooManyRequests, <String, dynamic>{
        'error': 'rate_limited',
        'retryAfterSec': rateLimitRetry.inSeconds.clamp(1, 3600),
        'requestId': requestId,
      });
    }

    unawaited(_maybeRunRetentionSweep());

    try {
      if (req.method == 'GET' &&
          segments.length == 2 &&
          segments[0] == 'v1' &&
          segments[1] == 'health') {
        return _json(req, HttpStatus.ok, <String, dynamic>{
          'status': 'ok',
          'storage': _dbMode ? 'postgres' : 'file',
          'productionMode': productionMode,
          'pixProviderMode': pixProviderMode,
          'pixProviderVendor': pixProviderVendor,
          'playBillingConfigured': _playBillingConfigured,
          'uptimeSec':
              DateTime.now().toUtc().difference(_startedAtUtc).inSeconds,
          'requests': <String, dynamic>{
            'total': _requestTotal,
            'success2xx': _request2xx,
            'client4xx': _request4xx,
            'server5xx': _request5xx,
            'inFlight': _requestInFlight,
          },
          'serverTime': DateTime.now().toUtc().toIso8601String(),
          'requestId': requestId,
        });
      }

      if (req.method == 'GET' &&
          segments.length == 2 &&
          segments[0] == 'v1' &&
          segments[1] == 'metrics') {
        if (!_adminEnabled) {
          return _json(req, HttpStatus.serviceUnavailable, <String, dynamic>{
            'error': 'admin_metrics_disabled',
            'requestId': requestId,
          });
        }
        if (!_isAdminAuthorized(req)) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized_admin',
            'requestId': requestId,
          });
        }
        final now = DateTime.now().toUtc();
        final uptimeSec = now.difference(_startedAtUtc).inSeconds;
        final memoryRssMb = (ProcessInfo.currentRss / (1024 * 1024))
            .toStringAsFixed(1);
        return _json(req, HttpStatus.ok, <String, dynamic>{
          'status': 'ok',
          'timestamp': now.toIso8601String(),
          'uptimeSec': uptimeSec,
          'storage': _dbMode ? 'postgres' : 'file',
          'productionMode': productionMode,
          'pixProviderMode': pixProviderMode,
          'pixProviderVendor': pixProviderVendor,
          'playBillingConfigured': _playBillingConfigured,
          'requests': <String, dynamic>{
            'total': _requestTotal,
            'success2xx': _request2xx,
            'client4xx': _request4xx,
            'server5xx': _request5xx,
            'inFlight': _requestInFlight,
            'perRoute': Map<String, int>.from(_routeHits),
            'perRouteErrors': Map<String, int>.from(_routeErrors),
          },
          'rateLimit': <String, dynamic>{
            'globalRequestsPerMin': globalRequestsPerMin,
            'loginAttemptsPerMin': loginAttemptsPerMin,
            'billingAttemptsPerMin': billingAttemptsPerMin,
          },
          'retentionDays': <String, dynamic>{
            'charges': chargeRetentionDays,
            'webhooks': webhookRetentionDays,
            'crowdReports': crowdReportRetentionDays,
          },
          'stateCounters': <String, dynamic>{
            'subscriptions': subscriptions.length,
            'charges': charges.length,
            'webhookEvents': webhookEvents.length,
            'gymLocations': gymLocations.length,
            'crowdReports': crowdReports.length,
          },
          'memoryRssMb': memoryRssMb,
          'requestId': requestId,
        });
      }

      if (req.method == 'POST' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'auth' &&
          segments[2] == 'login') {
        if (!_jwtEnabled) {
          return _json(req, HttpStatus.serviceUnavailable, <String, dynamic>{
            'error': 'jwt_not_configured',
          });
        }
        if (!_loginEnabled) {
          return _json(req, HttpStatus.serviceUnavailable, <String, dynamic>{
            'error': 'login_not_configured',
          });
        }
        final payload = await _readJson(req);
        final userId =
            '${payload['userId'] ?? payload['username'] ?? ''}'.trim();
        final password = '${payload['password'] ?? ''}';
        if (userId.isEmpty || password.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_credentials',
          });
        }
        if (!_validateLogin(userId, password)) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'invalid_credentials',
          });
        }

        final token = _issueJwt(userId);
        final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final effectiveTtl = _normalizedJwtTtlSec();
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
          (nowSec + effectiveTtl) * 1000,
          isUtc: true,
        );
        return _json(req, HttpStatus.ok, <String, dynamic>{
          'tokenType': 'Bearer',
          'accessToken': token,
          'expiresAt': expiresAt.toIso8601String(),
          'expiresInSec': effectiveTtl,
          'userId': userId,
        });
      }

      if (req.method == 'GET' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'subscriptions') {
        final requested = segments[2].trim();
        final authUser = _authenticate(req, expectedUserId: requested);
        if (_jwtEnabled && authUser == null) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized',
          });
        }
        final userId = authUser ?? requested;
        if (userId.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_user_id',
          });
        }
        return _json(req, HttpStatus.ok, <String, dynamic>{
          'subscription': _subscriptionFor(userId),
        });
      }

      if (req.method == 'POST' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'subscriptions' &&
          segments[2] == 'downgrade') {
        final payload = await _readJson(req);
        final requested = '${payload['userId'] ?? ''}'.trim();
        final authUser = _authenticate(req, expectedUserId: requested);
        if (_jwtEnabled && authUser == null) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized',
          });
        }
        final userId = _jwtEnabled ? authUser! : requested;
        if (userId.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_user_id',
          });
        }
        subscriptions.remove(userId);
        await _persist();
        return _json(req, HttpStatus.ok, <String, dynamic>{
          'subscription': _free(userId),
        });
      }

      if (req.method == 'GET' &&
          segments.length == 4 &&
          segments[0] == 'v1' &&
          segments[1] == 'gyms' &&
          segments[2] == 'locations') {
        final requested = segments[3].trim();
        final authUser = _authenticate(req, expectedUserId: requested);
        if (_jwtEnabled && authUser == null) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized',
          });
        }
        final userId = authUser ?? requested;
        if (userId.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_user_id',
          });
        }

        final locations = gymLocations.values
          .where((raw) => '${raw['userId'] ?? ''}'.trim() == userId)
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList(growable: false)..sort(
          (a, b) => '${b['updatedAtUtc'] ?? ''}'.compareTo(
            '${a['updatedAtUtc'] ?? ''}',
          ),
        );
        return _json(req, HttpStatus.ok, <String, dynamic>{
          'userId': userId,
          'locations': locations,
        });
      }

      if (req.method == 'POST' &&
          segments.length == 4 &&
          segments[0] == 'v1' &&
          segments[1] == 'gyms' &&
          segments[2] == 'locations' &&
          segments[3] == 'upsert') {
        final payload = await _readJson(req);
        final requested = '${payload['userId'] ?? ''}'.trim();
        final authUser = _authenticate(req, expectedUserId: requested);
        if (_jwtEnabled && authUser == null) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized',
          });
        }
        final userId = _jwtEnabled ? authUser! : requested;
        if (userId.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_user_id',
          });
        }
        final rawLocations = payload['locations'];
        if (rawLocations is! List) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_locations',
          });
        }

        var upserted = 0;
        for (final raw in rawLocations) {
          if (raw is! Map) {
            continue;
          }
          final gymId = '${raw['id'] ?? ''}'.trim();
          if (gymId.isEmpty) {
            continue;
          }
          final lat = double.tryParse('${raw['lat'] ?? ''}');
          final lng = double.tryParse('${raw['lng'] ?? ''}');
          if (lat == null || lng == null) {
            continue;
          }

          final nowIso = DateTime.now().toUtc().toIso8601String();
          final location = <String, dynamic>{
            'id': gymId,
            'userId': userId,
            'name': '${raw['name'] ?? 'Academia'}'.trim(),
            'address':
                '${raw['address'] ?? 'Academia encontrada no mapa'}'.trim(),
            'lat': lat,
            'lng': lng,
            'updatedAtUtc': '${raw['updatedAtUtc'] ?? nowIso}'.trim(),
          };
          gymLocations[_gymLocationCompositeKey(userId, gymId)] = location;
          upserted++;
        }

        if (upserted > 0) {
          await _persist();
        }
        return _json(req, HttpStatus.ok, <String, dynamic>{
          'userId': userId,
          'upserted': upserted,
        });
      }

      if (req.method == 'GET' &&
          segments.length == 4 &&
          segments[0] == 'v1' &&
          segments[1] == 'crowd' &&
          segments[2] == 'leaderboard') {
        final requested = segments[3].trim();
        final authUser = _authenticate(req, expectedUserId: requested);
        if (_jwtEnabled && authUser == null) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized',
          });
        }
        final userId = authUser ?? requested;
        if (userId.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_user_id',
          });
        }

        final windowDays =
            int.tryParse(req.uri.queryParameters['windowDays'] ?? '') ?? 7;
        final normalizedWindowDays = windowDays.clamp(1, 30);
        final limit =
            int.tryParse(req.uri.queryParameters['limit'] ?? '') ?? 10;
        final normalizedLimit = limit.clamp(1, 50);
        final requestedRegionLabel =
            (req.uri.queryParameters['regionLabel'] ?? '').trim();
        final requestedRegionKey = _normalizeCrowdRegionKey(
          req.uri.queryParameters['regionKey'] ?? '',
        );

        final now = DateTime.now().toUtc();
        final cutoff = now.subtract(Duration(days: normalizedWindowDays));

        final filteredReports = <Map<String, dynamic>>[];
        for (final raw in crowdReports.values) {
          final createdAt =
              DateTime.tryParse('${raw['createdAt'] ?? ''}')?.toUtc();
          if (createdAt == null || createdAt.isBefore(cutoff)) {
            continue;
          }
          final regionKey = _normalizeCrowdRegionKey(
            '${raw['regionKey'] ?? raw['region'] ?? ''}',
          );
          if (requestedRegionKey.isNotEmpty &&
              regionKey != requestedRegionKey) {
            continue;
          }
          filteredReports.add(Map<String, dynamic>.from(raw));
        }

        final pointsByUser = <String, int>{};
        for (final report in filteredReports) {
          final reportUserId = '${report['userId'] ?? ''}'.trim();
          if (reportUserId.isEmpty) {
            continue;
          }
          pointsByUser[reportUserId] = (pointsByUser[reportUserId] ?? 0) + 5;
        }

        final ranking = pointsByUser.entries.toList(growable: false)
          ..sort((left, right) {
            final byPoints = right.value.compareTo(left.value);
            if (byPoints != 0) {
              return byPoints;
            }
            return left.key.compareTo(right.key);
          });

        var userRank = 0;
        for (var i = 0; i < ranking.length; i++) {
          if (ranking[i].key == userId) {
            userRank = i + 1;
            break;
          }
        }
        final userPoints = pointsByUser[userId] ?? 0;
        final resolvedRegionLabel = _resolveCrowdRegionLabel(
          explicitLabel: requestedRegionLabel,
          normalizedRegionKey: requestedRegionKey,
          reports: filteredReports,
        );

        final entries = <Map<String, dynamic>>[];
        final maxIndex =
            normalizedLimit <= ranking.length
                ? normalizedLimit
                : ranking.length;
        for (var i = 0; i < maxIndex; i++) {
          final entry = ranking[i];
          entries.add(<String, dynamic>{
            'userId': entry.key,
            'displayName': _crowdLeaderboardDisplayName(entry.key),
            'points': entry.value,
            'rank': i + 1,
            'isCurrentUser': entry.key == userId,
          });
        }

        return _json(req, HttpStatus.ok, <String, dynamic>{
          'userId': userId,
          'regionKey': requestedRegionKey,
          'regionLabel': resolvedRegionLabel,
          'windowDays': normalizedWindowDays,
          'entries': entries,
          'userRank': userRank,
          'userPoints': userPoints,
        });
      }

      if (req.method == 'GET' &&
          segments.length == 4 &&
          segments[0] == 'v1' &&
          segments[1] == 'crowd' &&
          segments[2] == 'reports') {
        final requested = segments[3].trim();
        final authUser = _authenticate(req, expectedUserId: requested);
        if (_jwtEnabled && authUser == null) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized',
          });
        }
        final userId = authUser ?? requested;
        if (userId.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_user_id',
          });
        }

        final gymIdsRaw = (req.uri.queryParameters['gymIds'] ?? '').trim();
        final gymIdFilter = <String>{};
        if (gymIdsRaw.isNotEmpty) {
          for (final raw in gymIdsRaw.split(',')) {
            final gymId = raw.trim();
            if (gymId.isNotEmpty) {
              gymIdFilter.add(gymId);
            }
          }
        }
        final limitPerGym =
            int.tryParse(req.uri.queryParameters['limitPerGym'] ?? '') ?? 60;
        final maxPerGym = limitPerGym.clamp(1, 200);

        final reports = crowdReports.values
          .where((raw) => '${raw['userId'] ?? ''}'.trim() == userId)
          .where((raw) {
            if (gymIdFilter.isEmpty) {
              return true;
            }
            final gymId = '${raw['gymId'] ?? ''}'.trim();
            return gymIdFilter.contains(gymId);
          })
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList(growable: false)..sort(
          (a, b) =>
              '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'),
        );

        final limitedByGym = <Map<String, dynamic>>[];
        if (reports.isNotEmpty) {
          final perGymCount = <String, int>{};
          for (final report in reports) {
            final gymId = '${report['gymId'] ?? ''}'.trim();
            if (gymId.isEmpty) {
              continue;
            }
            final current = perGymCount[gymId] ?? 0;
            if (current >= maxPerGym) {
              continue;
            }
            perGymCount[gymId] = current + 1;
            limitedByGym.add(report);
          }
        }

        return _json(req, HttpStatus.ok, <String, dynamic>{
          'userId': userId,
          'reports': limitedByGym,
        });
      }

      if (req.method == 'POST' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'crowd' &&
          segments[2] == 'reports') {
        final payload = await _readJson(req);
        final requested = '${payload['userId'] ?? ''}'.trim();
        final authUser = _authenticate(req, expectedUserId: requested);
        if (_jwtEnabled && authUser == null) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized',
          });
        }
        final userId = _jwtEnabled ? authUser! : requested;
        if (userId.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_user_id',
          });
        }

        final gymId = '${payload['gymId'] ?? ''}'.trim();
        final occupancy = int.tryParse('${payload['occupancyPercent'] ?? ''}');
        if (gymId.isEmpty || occupancy == null) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_required_fields',
          });
        }
        final normalizedOccupancy = occupancy.clamp(0, 100);
        final reporterIdRaw = '${payload['reporterId'] ?? ''}'.trim();
        final reporterId =
            reporterIdRaw.isEmpty ? 'user:$userId' : reporterIdRaw;
        var regionKey = _normalizeCrowdRegionKey(
          '${payload['regionKey'] ?? payload['region'] ?? ''}',
        );
        final regionLabel = '${payload['regionLabel'] ?? ''}'.trim();
        if (regionKey.isEmpty && regionLabel.isNotEmpty) {
          regionKey = _normalizeCrowdRegionKey(regionLabel);
        }

        final now = DateTime.now().toUtc();
        final retryAfter = _remainingCrowdReportCooldown(
          userId: userId,
          gymId: gymId,
          reporterId: reporterId,
          now: now,
        );
        if (retryAfter != null) {
          return _json(req, HttpStatus.tooManyRequests, <String, dynamic>{
            'accepted': false,
            'retryAfterSec': retryAfter.inSeconds,
          });
        }

        final reliabilityWeight = _estimateCrowdReliabilityWeight(
          userId: userId,
          gymId: gymId,
          occupancyPercent: normalizedOccupancy,
          now: now,
        );

        final reportId =
            'rpt_${gymId}_${now.millisecondsSinceEpoch}_${1000 + _random.nextInt(9000)}';
        final report = <String, dynamic>{
          'id': reportId,
          'userId': userId,
          'gymId': gymId,
          'occupancyPercent': normalizedOccupancy,
          'createdAt': now.toIso8601String(),
          'reporterId': reporterId,
          'reliabilityWeight': reliabilityWeight,
          'regionKey': regionKey,
          'regionLabel': regionLabel,
        };
        crowdReports[reportId] = report;
        await _persist();
        return _json(req, HttpStatus.created, <String, dynamic>{
          'accepted': true,
          'report': report,
        });
      }

      if (req.method == 'POST' &&
          segments.length == 4 &&
          segments[0] == 'v1' &&
          segments[1] == 'billing' &&
          segments[2] == 'pix' &&
          segments[3] == 'charge') {
        final payload = await _readJson(req);
        final requested = '${payload['userId'] ?? ''}'.trim();
        final authUser = _authenticate(req, expectedUserId: requested);
        if (_jwtEnabled && authUser == null) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized',
          });
        }
        final userId = _jwtEnabled ? authUser! : requested;
        final planKey = '${payload['planKey'] ?? ''}'.trim();
        final monthlyPriceInput = '${payload['monthlyPrice'] ?? ''}'.trim();
        if (userId.isEmpty || planKey.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_required_fields',
          });
        }
        if (planKey == 'free') {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'free_plan_does_not_require_payment',
          });
        }

        final targetPlanCents = _planPriceCents(
          planKey,
          fallbackMonthlyPrice: monthlyPriceInput,
        );
        if (targetPlanCents <= 0) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'invalid_plan_price',
          });
        }

        final now = DateTime.now().toUtc();
        final currentSubscription = _subscriptionFor(userId);
        final currentPlanKey =
            '${currentSubscription['activePlanKey'] ?? 'free'}'.trim();
        final currentStartsAt =
            DateTime.tryParse(
              '${currentSubscription['startsAt'] ?? ''}',
            )?.toUtc();
        final currentExpiresAt =
            DateTime.tryParse(
              '${currentSubscription['expiresAt'] ?? ''}',
            )?.toUtc();
        final hasActivePaidPlan =
            currentPlanKey != 'free' &&
            currentExpiresAt != null &&
            now.isBefore(currentExpiresAt);

        var isProratedMigration = false;
        var creditCents = 0;
        var amountDueCents = targetPlanCents;
        String? preserveExpiresAtIso;
        String? previousPlanKey;
        if (hasActivePaidPlan && currentPlanKey != planKey) {
          isProratedMigration = true;
          previousPlanKey = currentPlanKey;
          preserveExpiresAtIso = currentExpiresAt.toIso8601String();
          final currentPlanCents = _planPriceCents(currentPlanKey);
          final remainingRatio = _remainingCycleRatio(
            now: now,
            startsAt: currentStartsAt,
            expiresAt: currentExpiresAt,
          );
          final targetRemainingCents =
              (targetPlanCents * remainingRatio).round();
          final currentRemainingCents =
              (currentPlanCents * remainingRatio).round();
          creditCents = currentRemainingCents;
          amountDueCents = targetRemainingCents - currentRemainingCents;
          if (amountDueCents < 0) {
            amountDueCents = 0;
          }
        }

        final amountDueLabel = _formatBrlFromCents(amountDueCents);
        final chargeId =
            'pix_${planKey}_${now.millisecondsSinceEpoch}_${1000 + _random.nextInt(9000)}';
        var expiresAt = now.add(const Duration(minutes: 20));
        var copyPasteCode =
            amountDueCents <= 0
                ? ''
                : _pixCode(chargeId, planKey, amountDueLabel);
        String? providerChargeId;
        String? providerFailure;
        String providerStatus = amountDueCents <= 0 ? 'paid' : 'pending';
        Map<String, dynamic>? providerPayload;
        if (amountDueCents > 0 && _externalPixProviderEnabled) {
          try {
            final providerCharge = await _createExternalPixCharge(
              localChargeId: chargeId,
              userId: userId,
              planKey: planKey,
              amountDueCents: amountDueCents,
            );
            providerChargeId = providerCharge.chargeId;
            providerStatus = providerCharge.status;
            providerPayload = providerCharge.rawPayload;
            if (providerCharge.copyPasteCode.trim().isNotEmpty) {
              copyPasteCode = providerCharge.copyPasteCode.trim();
            }
            if (providerCharge.expiresAt != null &&
                providerCharge.expiresAt!.isAfter(now)) {
              expiresAt = providerCharge.expiresAt!;
            }
          } catch (error) {
            providerFailure = '$error';
            if (productionMode) {
              return _json(req, HttpStatus.badGateway, <String, dynamic>{
                'error': 'pix_provider_unavailable',
                'message': 'Failed to create charge in external PIX provider.',
                'requestId': requestId,
              });
            }
          }
        }
        final charge = <String, dynamic>{
          'chargeId': chargeId,
          'userId': userId,
          'planKey': planKey,
          'monthlyPrice': amountDueLabel,
          'copyPasteCode': copyPasteCode,
          'status': amountDueCents <= 0 ? 'paid' : 'pending',
          'createdAt': now.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
          'paidAt': amountDueCents <= 0 ? now.toIso8601String() : null,
          'amountDueCents': amountDueCents,
          'targetPlanMonthlyPriceCents': targetPlanCents,
          'targetPlanMonthlyPrice': _formatBrlFromCents(targetPlanCents),
          'isProratedMigration': isProratedMigration,
          'creditCents': creditCents,
          'previousPlanKey': previousPlanKey,
          'preserveExpiresAt': preserveExpiresAtIso,
          'providerMode': _externalPixProviderEnabled ? 'external' : 'mock',
          'providerChargeId': providerChargeId,
          'providerStatus': providerStatus,
          'providerLastSyncAt':
              providerChargeId == null
                  ? null
                  : DateTime.now().toUtc().toIso8601String(),
          'providerPayload': providerPayload,
          'providerFailure': providerFailure,
        };
        charges[chargeId] = charge;
        if (amountDueCents <= 0) {
          final subscription = _activate(
            userId,
            planKey,
            expiresAt: currentExpiresAt,
          );
          await _persist();
          return _json(req, HttpStatus.ok, <String, dynamic>{
            'charge': charge,
            'subscription': subscription,
            'autoApplied': true,
          });
        }
        await _persist();
        return _json(req, HttpStatus.created, <String, dynamic>{
          'charge': charge,
        });
      }

      if (req.method == 'POST' &&
          segments.length == 4 &&
          segments[0] == 'v1' &&
          segments[1] == 'billing' &&
          segments[2] == 'play' &&
          segments[3] == 'validate') {
        final payload = await _readJson(req);
        final requested = '${payload['userId'] ?? ''}'.trim();
        final authUser = _authenticate(req, expectedUserId: requested);
        if (_jwtEnabled && authUser == null) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized',
          });
        }
        final userId = _jwtEnabled ? authUser! : requested;
        final planKey = '${payload['planKey'] ?? ''}'.trim().toLowerCase();
        final productId = '${payload['productId'] ?? ''}'.trim();
        final purchaseToken = '${payload['purchaseToken'] ?? ''}'.trim();
        final purchaseId = '${payload['purchaseId'] ?? ''}'.trim();

        if (userId.isEmpty ||
            planKey.isEmpty ||
            productId.isEmpty ||
            purchaseToken.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_required_fields',
            'message':
                'userId, planKey, productId and purchaseToken are required.',
            'requestId': requestId,
          });
        }
        if (planKey == 'free') {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'free_plan_does_not_require_payment',
            'requestId': requestId,
          });
        }

        final expectedProductId = (playProductIdsByPlan[planKey] ?? '').trim();
        if (expectedProductId.isNotEmpty && expectedProductId != productId) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'play_product_mismatch',
            'expectedProductId': expectedProductId,
            'requestId': requestId,
          });
        }

        late final _PlayPurchaseValidationResult validation;
        try {
          validation = await _validatePlayPurchase(
            productId: productId,
            purchaseToken: purchaseToken,
          );
        } on StateError catch (error) {
          final errorCode = error.message.toString().trim().ifEmpty(
            'play_api_unavailable',
          );
          var statusCode = HttpStatus.badGateway;
          if (errorCode == 'play_purchase_not_found') {
            statusCode = HttpStatus.notFound;
          } else if (errorCode == 'play_product_mismatch' ||
              errorCode == 'play_package_mismatch') {
            statusCode = HttpStatus.badRequest;
          } else if (errorCode == 'play_validation_unavailable' ||
              errorCode == 'play_api_unavailable') {
            statusCode = HttpStatus.serviceUnavailable;
          }
          return _json(req, statusCode, <String, dynamic>{
            'error': errorCode,
            'requestId': requestId,
          });
        } catch (_) {
          return _json(req, HttpStatus.badGateway, <String, dynamic>{
            'error': 'play_api_unavailable',
            'requestId': requestId,
          });
        }

        if (!validation.isActive) {
          return _json(req, HttpStatus.conflict, <String, dynamic>{
            'error': 'play_purchase_not_active',
            'subscriptionState': validation.subscriptionState,
            'expiresAt': validation.expiresAt?.toIso8601String(),
            'requestId': requestId,
          });
        }

        final now = DateTime.now().toUtc();
        final planMonthlyCents = _planPriceCents(planKey);
        final chargeId =
            'play_${planKey}_${now.millisecondsSinceEpoch}_${1000 + _random.nextInt(9000)}';
        final charge = <String, dynamic>{
          'chargeId': chargeId,
          'userId': userId,
          'planKey': planKey,
          'monthlyPrice': _formatBrlFromCents(planMonthlyCents),
          'copyPasteCode': '',
          'status': 'paid',
          'createdAt': now.toIso8601String(),
          'expiresAt':
              (validation.expiresAt ?? now.add(const Duration(days: 30)))
                  .toIso8601String(),
          'paidAt': now.toIso8601String(),
          'amountDueCents': planMonthlyCents,
          'targetPlanMonthlyPriceCents': planMonthlyCents,
          'targetPlanMonthlyPrice': _formatBrlFromCents(planMonthlyCents),
          'isProratedMigration': false,
          'creditCents': 0,
          'previousPlanKey': null,
          'preserveExpiresAt': null,
          'providerMode': 'google_play',
          'providerChargeId': purchaseId.ifEmpty(
            validation.latestOrderId ?? purchaseToken,
          ),
          'providerStatus': validation.subscriptionState,
          'providerLastSyncAt': now.toIso8601String(),
          'providerPayload': validation.rawPayload,
          'providerFailure': null,
        };
        charges[chargeId] = charge;
        final subscription = _activate(
          userId,
          planKey,
          expiresAt: validation.expiresAt,
        );
        await _persist();
        return _json(req, HttpStatus.ok, <String, dynamic>{
          'subscription': subscription,
          'charge': charge,
          'playPurchase': validation.toJson(),
          'requestId': requestId,
        });
      }

      if (req.method == 'POST' &&
          segments.length == 4 &&
          segments[0] == 'v1' &&
          segments[1] == 'billing' &&
          segments[2] == 'pix' &&
          segments[3] == 'confirm') {
        if (productionMode) {
          return _json(req, HttpStatus.forbidden, <String, dynamic>{
            'error': 'manual_confirmation_disabled',
            'message':
                'Use signed webhook /v1/webhooks/pix to confirm payment in production mode.',
          });
        }
        final payload = await _readJson(req);
        final chargeId = '${payload['chargeId'] ?? ''}'.trim();
        final requested = '${payload['userId'] ?? ''}'.trim();
        if (chargeId.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_charge_id',
          });
        }
        final charge = charges[chargeId];
        if (charge == null) {
          return _json(req, HttpStatus.notFound, <String, dynamic>{
            'error': 'charge_not_found',
          });
        }
        final authUser = _authenticate(req, expectedUserId: requested);
        if (_jwtEnabled && authUser == null) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized',
          });
        }
        final effectiveUser =
            _jwtEnabled ? authUser : (requested.isEmpty ? null : requested);
        if (effectiveUser != null &&
            effectiveUser.isNotEmpty &&
            '${charge['userId'] ?? ''}'.trim() != effectiveUser) {
          return _json(req, HttpStatus.forbidden, <String, dynamic>{
            'error': 'forbidden_charge_owner_mismatch',
          });
        }
        final result = await _confirmPaid(chargeId);
        if (result == null) {
          return _json(req, HttpStatus.notFound, <String, dynamic>{
            'error': 'charge_not_found',
          });
        }
        return _json(req, HttpStatus.ok, result);
      }

      if (req.method == 'POST' &&
          segments.length == 5 &&
          segments[0] == 'v1' &&
          segments[1] == 'billing' &&
          segments[2] == 'pix' &&
          segments[3] == 'reconcile') {
        if (!_adminEnabled) {
          return _json(req, HttpStatus.serviceUnavailable, <String, dynamic>{
            'error': 'admin_reconcile_disabled',
            'requestId': requestId,
          });
        }
        if (!_isAdminAuthorized(req)) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'unauthorized_admin',
            'requestId': requestId,
          });
        }
        final chargeId = segments[4].trim();
        if (chargeId.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_charge_id',
            'requestId': requestId,
          });
        }
        final charge = charges[chargeId];
        if (charge == null) {
          return _json(req, HttpStatus.notFound, <String, dynamic>{
            'error': 'charge_not_found',
            'requestId': requestId,
          });
        }
        final reconciled = await _reconcileChargeWithProvider(chargeId, charge);
        if (reconciled == null) {
          return _json(req, HttpStatus.badGateway, <String, dynamic>{
            'error': 'pix_provider_not_configured',
            'requestId': requestId,
          });
        }
        return _json(req, HttpStatus.ok, <String, dynamic>{
          'charge': charge,
          'reconciled': reconciled,
          'requestId': requestId,
        });
      }

      if (req.method == 'POST' &&
          segments.length == 3 &&
          segments[0] == 'v1' &&
          segments[1] == 'webhooks' &&
          segments[2] == 'pix') {
        final token = req.headers.value('x-webhook-token') ?? '';
        if (!_isMercadoPagoProvider &&
            webhookToken.isNotEmpty &&
            token != webhookToken) {
          return _json(req, HttpStatus.unauthorized, <String, dynamic>{
            'error': 'invalid_webhook_token',
          });
        }

        final rawBody = await utf8.decoder.bind(req).join();
        if (webhookSecrets.isNotEmpty) {
          if (_isMercadoPagoProvider) {
            if (!_validMercadoPagoWebhookSignature(req)) {
              return _json(req, HttpStatus.unauthorized, <String, dynamic>{
                'error': 'invalid_webhook_signature',
              });
            }
          } else {
            final timestamp = req.headers.value('x-webhook-timestamp') ?? '';
            final signature = req.headers.value('x-webhook-signature') ?? '';
            if (!_validWebhookSignature(timestamp, signature, rawBody)) {
              return _json(req, HttpStatus.unauthorized, <String, dynamic>{
                'error': 'invalid_webhook_signature',
              });
            }
          }
        }

        final payload = _decodeJsonObject(rawBody);
        final incomingChargeId = _resolveIncomingWebhookChargeId(req, payload);
        var status = '${payload['status'] ?? ''}'.trim().toLowerCase();
        final eventIdFromPayload =
            '${payload['eventId'] ?? payload['id'] ?? ''}'.trim();
        final eventIdFromHeader =
            (req.headers.value('x-webhook-event-id') ?? '').trim();
        final action =
            '${payload['action'] ?? payload['type'] ?? ''}'
                .trim()
                .toLowerCase();

        if (incomingChargeId.isEmpty) {
          return _json(req, HttpStatus.badRequest, <String, dynamic>{
            'error': 'missing_webhook_fields',
          });
        }
        final localChargeId = _resolveLocalChargeId(incomingChargeId);
        if (localChargeId == null) {
          return _json(req, HttpStatus.notFound, <String, dynamic>{
            'error': 'charge_not_found',
            'message':
                'No local charge matches incoming chargeId/providerChargeId.',
          });
        }
        Map<String, dynamic>? reconciledFromProvider;
        if (_isMercadoPagoProvider) {
          final localCharge = charges[localChargeId];
          if (localCharge != null) {
            reconciledFromProvider = await _reconcileChargeWithProvider(
              localChargeId,
              localCharge,
            );
          }
          final providerStatus =
              '${reconciledFromProvider?['providerStatus'] ?? ''}'
                  .trim()
                  .toLowerCase();
          if (status.isEmpty) {
            status = providerStatus;
          }
        }
        if (status.isEmpty) {
          status = 'unknown';
        }

        final eventId = (eventIdFromPayload.isNotEmpty
                ? eventIdFromPayload
                : eventIdFromHeader)
            .ifEmpty('evt_${incomingChargeId}_${action.ifEmpty(status)}');

        final alreadyProcessed = webhookEvents[eventId];
        if (alreadyProcessed != null) {
          final replay = Map<String, dynamic>.from(
            alreadyProcessed['response'] is Map
                ? Map<String, dynamic>.from(alreadyProcessed['response'] as Map)
                : <String, dynamic>{'accepted': true, 'eventId': eventId},
          );
          replay['idempotent'] = true;
          return _json(req, HttpStatus.ok, replay);
        }

        late Map<String, dynamic> responseBody;
        late int responseCode;
        if (!_isProviderPaidStatus(status)) {
          final local = charges[localChargeId];
          if (local != null) {
            local['providerStatus'] = status;
            local['providerLastSyncAt'] =
                DateTime.now().toUtc().toIso8601String();
          }
          responseCode = HttpStatus.accepted;
          responseBody = <String, dynamic>{
            'accepted': true,
            'eventId': eventId,
            'message': 'status_ignored',
          };
        } else {
          final reconciledPaymentResult =
              reconciledFromProvider?['paymentResult'];
          final result =
              reconciledPaymentResult is Map
                  ? Map<String, dynamic>.from(reconciledPaymentResult)
                  : await _confirmPaid(localChargeId);
          if (result == null) {
            return _json(req, HttpStatus.notFound, <String, dynamic>{
              'error': 'charge_not_found',
            });
          }
          final local = charges[localChargeId];
          if (local != null) {
            local['providerStatus'] = status;
            local['providerLastSyncAt'] =
                DateTime.now().toUtc().toIso8601String();
          }
          responseCode = HttpStatus.ok;
          responseBody = <String, dynamic>{
            'accepted': true,
            'eventId': eventId,
            'result': result,
          };
        }

        webhookEvents[eventId] = <String, dynamic>{
          'eventId': eventId,
          'chargeId': localChargeId,
          'incomingChargeId': incomingChargeId,
          'status': status,
          'processedAt': DateTime.now().toUtc().toIso8601String(),
          'response': responseBody,
        };
        await _persist();
        return _json(req, responseCode, responseBody);
      }

      return _json(req, HttpStatus.notFound, <String, dynamic>{
        'error': 'route_not_found',
      });
    } on FormatException catch (e) {
      return _json(req, HttpStatus.badRequest, <String, dynamic>{
        'error': 'invalid_json',
        'message': e.message,
      });
    } catch (e) {
      return _json(req, HttpStatus.internalServerError, <String, dynamic>{
        'error': 'internal_error',
        'message': '$e',
      });
    } finally {
      final statusCode = req.response.statusCode;
      _requestInFlight = math.max(0, _requestInFlight - 1);
      if (statusCode >= 500) {
        _request5xx++;
        _routeErrors[routeKey] = (_routeErrors[routeKey] ?? 0) + 1;
      } else if (statusCode >= 400) {
        _request4xx++;
        _routeErrors[routeKey] = (_routeErrors[routeKey] ?? 0) + 1;
      } else if (statusCode >= 200 && statusCode < 300) {
        _request2xx++;
      }
      final latencyMs =
          DateTime.now().toUtc().difference(startedAt).inMilliseconds;
      _logRequest(
        routeKey: routeKey,
        method: req.method,
        statusCode: statusCode,
        latencyMs: latencyMs,
        clientKey: clientKey,
        requestId: requestId,
      );
    }
  }

  String? _authenticate(HttpRequest req, {String? expectedUserId}) {
    if (!_jwtEnabled) return null;
    final authHeader = req.headers.value(HttpHeaders.authorizationHeader) ?? '';
    final authParts = authHeader.trim().split(' ');
    if (authParts.length != 2 || authParts[0].toLowerCase() != 'bearer') {
      return null;
    }
    final token = authParts[1].trim();
    if (token.isEmpty) return null;

    final claims = _verifyJwtHs256(token);
    if (claims == null) return null;
    final subject = '${claims['sub'] ?? ''}'.trim();
    if (subject.isEmpty) return null;
    if (expectedUserId != null &&
        expectedUserId.isNotEmpty &&
        expectedUserId != subject) {
      return null;
    }
    return subject;
  }

  bool _isAdminAuthorized(HttpRequest req) {
    if (!_adminEnabled) {
      return false;
    }
    final headerToken = (req.headers.value('x-admin-token') ?? '').trim();
    if (headerToken.isNotEmpty &&
        _secureTextEquals(headerToken, adminApiToken.trim())) {
      return true;
    }
    final authHeader = req.headers.value(HttpHeaders.authorizationHeader) ?? '';
    final authParts = authHeader.trim().split(' ');
    if (authParts.length == 2 && authParts[0].toLowerCase() == 'bearer') {
      final bearerToken = authParts[1].trim();
      if (bearerToken.isNotEmpty &&
          _secureTextEquals(bearerToken, adminApiToken.trim())) {
        return true;
      }
    }
    return false;
  }

  String _nextRequestId() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'req_${now}_${1000 + _random.nextInt(9000)}';
  }

  String _clientKeyFor(HttpRequest req) {
    final ip = req.connectionInfo?.remoteAddress.address ?? 'unknown-ip';
    final forwardedFor = req.headers.value('x-forwarded-for');
    if (forwardedFor != null && forwardedFor.trim().isNotEmpty) {
      final first = forwardedFor.split(',').first.trim();
      if (first.isNotEmpty) {
        return first;
      }
    }
    return ip;
  }

  String _routeLabel(String method, List<String> segments) {
    if (segments.isEmpty) {
      return '$method /';
    }
    if (segments.length == 2 &&
        segments[0] == 'v1' &&
        segments[1] == 'health') {
      return '$method /v1/health';
    }
    if (segments.length == 2 &&
        segments[0] == 'v1' &&
        segments[1] == 'metrics') {
      return '$method /v1/metrics';
    }
    if (segments.length == 3 &&
        segments[0] == 'v1' &&
        segments[1] == 'auth' &&
        segments[2] == 'login') {
      return '$method /v1/auth/login';
    }
    if (segments.length == 4 &&
        segments[0] == 'v1' &&
        segments[1] == 'billing' &&
        segments[2] == 'pix' &&
        segments[3] == 'charge') {
      return '$method /v1/billing/pix/charge';
    }
    if (segments.length == 4 &&
        segments[0] == 'v1' &&
        segments[1] == 'billing' &&
        segments[2] == 'play' &&
        segments[3] == 'validate') {
      return '$method /v1/billing/play/validate';
    }
    if (segments.length == 4 &&
        segments[0] == 'v1' &&
        segments[1] == 'billing' &&
        segments[2] == 'pix' &&
        segments[3] == 'confirm') {
      return '$method /v1/billing/pix/confirm';
    }
    if (segments.length == 5 &&
        segments[0] == 'v1' &&
        segments[1] == 'billing' &&
        segments[2] == 'pix' &&
        segments[3] == 'reconcile') {
      return '$method /v1/billing/pix/reconcile/:chargeId';
    }
    if (segments.length == 3 &&
        segments[0] == 'v1' &&
        segments[1] == 'webhooks' &&
        segments[2] == 'pix') {
      return '$method /v1/webhooks/pix';
    }
    if (segments.length == 3 &&
        segments[0] == 'v1' &&
        segments[1] == 'subscriptions' &&
        segments[2] == 'downgrade') {
      return '$method /v1/subscriptions/downgrade';
    }
    if (segments.length == 3 &&
        segments[0] == 'v1' &&
        segments[1] == 'subscriptions') {
      return '$method /v1/subscriptions/:userId';
    }
    if (segments.length == 4 &&
        segments[0] == 'v1' &&
        segments[1] == 'gyms' &&
        segments[2] == 'locations' &&
        segments[3] == 'upsert') {
      return '$method /v1/gyms/locations/upsert';
    }
    if (segments.length == 4 &&
        segments[0] == 'v1' &&
        segments[1] == 'gyms' &&
        segments[2] == 'locations') {
      return '$method /v1/gyms/locations/:userId';
    }
    if (segments.length == 4 &&
        segments[0] == 'v1' &&
        segments[1] == 'crowd' &&
        segments[2] == 'leaderboard') {
      return '$method /v1/crowd/leaderboard/:userId';
    }
    if (segments.length == 4 &&
        segments[0] == 'v1' &&
        segments[1] == 'crowd' &&
        segments[2] == 'reports') {
      return '$method /v1/crowd/reports/:userId';
    }
    if (segments.length == 3 &&
        segments[0] == 'v1' &&
        segments[1] == 'crowd' &&
        segments[2] == 'reports') {
      return '$method /v1/crowd/reports';
    }
    return '$method /${segments.take(5).join('/')}';
  }

  Duration? _consumeRateLimit({
    required String routeKey,
    required String clientKey,
    required DateTime now,
  }) {
    final globalRetry = _globalRateLimiter.hit(
      key: clientKey,
      now: now,
      window: _rateLimitWindow,
      limit: globalRequestsPerMin,
    );
    if (globalRetry != null) {
      return globalRetry;
    }
    if (routeKey == 'POST /v1/auth/login') {
      return _loginRateLimiter.hit(
        key: clientKey,
        now: now,
        window: _rateLimitWindow,
        limit: loginAttemptsPerMin,
      );
    }
    if (routeKey == 'POST /v1/billing/pix/charge' ||
        routeKey == 'POST /v1/billing/pix/confirm' ||
        routeKey == 'POST /v1/billing/play/validate') {
      return _billingRateLimiter.hit(
        key: clientKey,
        now: now,
        window: _rateLimitWindow,
        limit: billingAttemptsPerMin,
      );
    }
    return null;
  }

  void _logRequest({
    required String routeKey,
    required String method,
    required int statusCode,
    required int latencyMs,
    required String clientKey,
    required String requestId,
    String? note,
  }) {
    if (!requestLogEnabled) {
      return;
    }
    final logLine = <String, dynamic>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      'requestId': requestId,
      'method': method,
      'route': routeKey,
      'status': statusCode,
      'latencyMs': latencyMs,
      'client': clientKey,
      if (note != null && note.isNotEmpty)
        'note': note.substring(
          0,
          math.min(note.length, _requestLogSampleBodyBytes),
        ),
    };
    stdout.writeln('[pix-backend] ${jsonEncode(logLine)}');
  }

  Future<void> _maybeRunRetentionSweep() async {
    final now = DateTime.now().toUtc();
    if (now.isBefore(_nextRetentionSweepAtUtc) || _retentionSweepRunning) {
      return;
    }
    _retentionSweepRunning = true;
    _nextRetentionSweepAtUtc = now.add(_retentionSweepInterval);
    try {
      final chargeCutoff = now.subtract(Duration(days: chargeRetentionDays));
      final webhookCutoff = now.subtract(Duration(days: webhookRetentionDays));
      final crowdCutoff = now.subtract(
        Duration(days: crowdReportRetentionDays),
      );

      final removedCharges = _removeByDate(
        source: charges,
        rawDateExtractor:
            (value) => '${value['paidAt'] ?? value['createdAt'] ?? ''}'.trim(),
        cutoff: chargeCutoff,
      );
      final removedWebhooks = _removeByDate(
        source: webhookEvents,
        rawDateExtractor: (value) => '${value['processedAt'] ?? ''}'.trim(),
        cutoff: webhookCutoff,
      );
      final removedCrowd = _removeByDate(
        source: crowdReports,
        rawDateExtractor: (value) => '${value['createdAt'] ?? ''}'.trim(),
        cutoff: crowdCutoff,
      );
      final totalRemoved = removedCharges + removedWebhooks + removedCrowd;
      if (totalRemoved > 0) {
        await _persist();
        _logRequest(
          routeKey: 'SYSTEM retention-sweep',
          method: 'SWEEP',
          statusCode: HttpStatus.ok,
          latencyMs: 0,
          clientKey: 'local',
          requestId: _nextRequestId(),
          note:
              'removed charges=$removedCharges webhooks=$removedWebhooks crowd=$removedCrowd',
        );
      }
    } catch (_) {
      _logRequest(
        routeKey: 'SYSTEM retention-sweep',
        method: 'SWEEP',
        statusCode: HttpStatus.internalServerError,
        latencyMs: 0,
        clientKey: 'local',
        requestId: _nextRequestId(),
        note: 'failed',
      );
    } finally {
      _retentionSweepRunning = false;
    }
  }

  int _removeByDate({
    required Map<String, Map<String, dynamic>> source,
    required String Function(Map<String, dynamic>) rawDateExtractor,
    required DateTime cutoff,
  }) {
    final toRemove = <String>[];
    for (final entry in source.entries) {
      final rawDate = rawDateExtractor(entry.value).trim();
      final parsed = DateTime.tryParse(rawDate)?.toUtc();
      if (parsed == null || parsed.isBefore(cutoff)) {
        toRemove.add(entry.key);
      }
    }
    for (final key in toRemove) {
      source.remove(key);
    }
    return toRemove.length;
  }

  bool _validateLogin(String userId, String password) {
    final perUserPassword = authUsers[userId];
    if (perUserPassword != null) {
      return _secureTextEquals(perUserPassword, password);
    }
    if (authDefaultPassword.isNotEmpty) {
      return _secureTextEquals(authDefaultPassword, password);
    }
    return false;
  }

  int _normalizedJwtTtlSec() {
    final requested = jwtAccessTtlSec;
    if (requested < 60) return 60;
    const maxTtl = 365 * 24 * 60 * 60;
    if (requested > maxTtl) return maxTtl;
    return requested;
  }

  String _issueJwt(String userId) {
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final expSec = nowSec + _normalizedJwtTtlSec();
    final header = <String, dynamic>{'alg': 'HS256', 'typ': 'JWT'};
    final payload = <String, dynamic>{
      'sub': userId,
      'iss': jwtIssuer,
      'iat': nowSec,
      'exp': expSec,
    };
    final encodedHeader = _base64UrlNoPad(utf8.encode(jsonEncode(header)));
    final encodedPayload = _base64UrlNoPad(utf8.encode(jsonEncode(payload)));
    final signingInput = '$encodedHeader.$encodedPayload';
    final signature =
        Hmac(
          sha256,
          utf8.encode(jwtSecret),
        ).convert(utf8.encode(signingInput)).bytes;
    final encodedSignature = _base64UrlNoPad(signature);
    return '$signingInput.$encodedSignature';
  }

  String _base64UrlNoPad(List<int> input) {
    return base64Url.encode(input).replaceAll('=', '');
  }

  Map<String, dynamic>? _verifyJwtHs256(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    List<int>? decode(String raw) {
      try {
        return base64Url.decode(base64Url.normalize(raw));
      } catch (_) {
        return null;
      }
    }

    final headerBytes = decode(parts[0]);
    final payloadBytes = decode(parts[1]);
    final signatureBytes = decode(parts[2]);
    if (headerBytes == null || payloadBytes == null || signatureBytes == null) {
      return null;
    }

    Map<String, dynamic>? decodeMap(List<int> bytes) {
      try {
        final value = jsonDecode(utf8.decode(bytes));
        if (value is Map<String, dynamic>) return value;
        if (value is Map) return Map<String, dynamic>.from(value);
      } catch (_) {}
      return null;
    }

    final header = decodeMap(headerBytes);
    final payload = decodeMap(payloadBytes);
    if (header == null || payload == null) return null;

    if ('${header['alg'] ?? ''}'.trim().toUpperCase() != 'HS256') return null;

    final signingInput = '${parts[0]}.${parts[1]}';
    final expected =
        Hmac(
          sha256,
          utf8.encode(jwtSecret),
        ).convert(utf8.encode(signingInput)).bytes;
    if (!_secureBytesEquals(expected, signatureBytes)) return null;

    final exp = payload['exp'];
    if (exp is num) {
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (nowSec >= exp.toInt()) return null;
    }

    return payload;
  }

  String _resolveIncomingWebhookChargeId(
    HttpRequest req,
    Map<String, dynamic> payload,
  ) {
    final fromPayload = '${payload['chargeId'] ?? ''}'.trim();
    if (fromPayload.isNotEmpty) {
      return fromPayload;
    }
    final data = payload['data'];
    if (data is Map) {
      final fromData = '${data['id'] ?? ''}'.trim();
      if (fromData.isNotEmpty) {
        return fromData;
      }
    }
    final fromQueryDataId = (req.uri.queryParameters['data.id'] ?? '').trim();
    if (fromQueryDataId.isNotEmpty) {
      return fromQueryDataId;
    }
    final fromQueryId = (req.uri.queryParameters['id'] ?? '').trim();
    if (fromQueryId.isNotEmpty) {
      return fromQueryId;
    }
    return '';
  }

  bool _validMercadoPagoWebhookSignature(HttpRequest req) {
    final signatureHeader = req.headers.value('x-signature') ?? '';
    final requestId = (req.headers.value('x-request-id') ?? '').trim();
    final dataId =
        (req.uri.queryParameters['data.id'] ??
                req.uri.queryParameters['id'] ??
                '')
            .trim()
            .toLowerCase();
    if (signatureHeader.trim().isEmpty ||
        requestId.isEmpty ||
        dataId.isEmpty ||
        webhookSecrets.isEmpty) {
      return false;
    }
    final signatureParts = <String, String>{};
    for (final raw in signatureHeader.split(',')) {
      final trimmed = raw.trim();
      final idx = trimmed.indexOf('=');
      if (idx <= 0 || idx + 1 >= trimmed.length) {
        continue;
      }
      signatureParts[trimmed.substring(0, idx).trim().toLowerCase()] =
          trimmed.substring(idx + 1).trim();
    }
    final tsRaw = signatureParts['ts'] ?? '';
    final v1 = (signatureParts['v1'] ?? '').trim().toLowerCase();
    if (tsRaw.isEmpty || v1.isEmpty) {
      return false;
    }
    final tsNum = int.tryParse(tsRaw);
    if (tsNum == null) {
      return false;
    }
    final tsSec = tsNum > 9999999999 ? tsNum ~/ 1000 : tsNum;
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if ((nowSec - tsSec).abs() > webhookToleranceSec) {
      return false;
    }

    final manifest = 'id:$dataId;request-id:$requestId;ts:$tsRaw;';
    for (final secret in webhookSecrets) {
      final digest =
          Hmac(
            sha256,
            utf8.encode(secret),
          ).convert(utf8.encode(manifest)).toString();
      if (_secureTextEquals(digest, v1)) {
        return true;
      }
    }
    return false;
  }

  bool _validWebhookSignature(
    String timestamp,
    String signatureHeader,
    String rawBody,
  ) {
    final timestampSec = int.tryParse(timestamp);
    if (timestampSec == null) return false;
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if ((nowSec - timestampSec).abs() > webhookToleranceSec) return false;

    var normalized = signatureHeader.trim().toLowerCase();
    if (normalized.startsWith('sha256=')) {
      normalized = normalized.substring('sha256='.length);
    }
    if (normalized.isEmpty) return false;

    final message = '$timestamp.$rawBody';
    for (final secret in webhookSecrets) {
      final digest =
          Hmac(
            sha256,
            utf8.encode(secret),
          ).convert(utf8.encode(message)).toString();
      if (_secureTextEquals(digest, normalized)) {
        return true;
      }
    }
    return false;
  }

  bool _secureTextEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  bool _secureBytesEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  String? _resolveLocalChargeId(String incomingChargeId) {
    final normalized = incomingChargeId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (charges.containsKey(normalized)) {
      return normalized;
    }
    for (final entry in charges.entries) {
      if ('${entry.value['providerChargeId'] ?? ''}'.trim() == normalized) {
        return entry.key;
      }
    }
    return null;
  }

  _ExternalPixClient? _externalPixClient() {
    if (!_externalPixProviderEnabled) {
      return null;
    }
    final parsed = Uri.tryParse(pixProviderBaseUrl.trim());
    if (parsed == null || !(parsed.hasScheme && parsed.hasAuthority)) {
      return null;
    }
    return _ExternalPixClient(
      baseUri: parsed,
      apiKey: pixProviderApiKey,
      vendor: pixProviderVendor,
      defaultPayerEmail: pixMpDefaultPayerEmail,
      notificationUrl: pixMpNotificationUrl,
      chargePath: pixProviderChargePath,
      statusPathTemplate: pixProviderStatusPathTemplate,
      timeout: Duration(seconds: pixProviderTimeoutSec.clamp(4, 60)),
    );
  }

  Future<_PlayPurchaseValidationResult> _validatePlayPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    final client = playBillingClient;
    if (client == null) {
      if (!productionMode && playAllowUnverifiedInDev) {
        final now = DateTime.now().toUtc();
        return _PlayPurchaseValidationResult(
          packageName: playPackageName,
          productIds: <String>[productId],
          latestOrderId: 'dev-unverified',
          subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
          isAcknowledged: true,
          isActive: true,
          expiresAt: now.add(const Duration(days: 30)),
          rawPayload: <String, dynamic>{
            'mode': 'dev_unverified',
            'reason': 'PLAY_BILLING_ALLOW_UNVERIFIED=true',
          },
        );
      }
      throw StateError('play_validation_unavailable');
    }
    try {
      final result = await client.validateSubscription(
        productId: productId,
        purchaseToken: purchaseToken,
      );
      final expectedPackage = playPackageName.trim();
      final actualPackage = result.packageName.trim();
      if (expectedPackage.isNotEmpty &&
          actualPackage.isNotEmpty &&
          expectedPackage != actualPackage) {
        throw StateError('play_package_mismatch');
      }
      if (result.productIds.isNotEmpty &&
          !result.productIds.contains(productId)) {
        throw StateError('play_product_mismatch');
      }
      return result;
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError('play_api_unavailable');
    }
  }

  Future<_ExternalPixCreateChargeResult> _createExternalPixCharge({
    required String localChargeId,
    required String userId,
    required String planKey,
    required int amountDueCents,
  }) async {
    final client = _externalPixClient();
    if (client == null) {
      throw StateError('external_pix_provider_not_configured');
    }
    final result = await client.createCharge(
      externalReference: localChargeId,
      userId: userId,
      planKey: planKey,
      amountDueCents: amountDueCents,
    );
    return result;
  }

  Future<Map<String, dynamic>?> _reconcileChargeWithProvider(
    String localChargeId,
    Map<String, dynamic> charge,
  ) async {
    final client = _externalPixClient();
    if (client == null) {
      return null;
    }
    final providerChargeId = '${charge['providerChargeId'] ?? localChargeId}'
        .trim()
        .ifEmpty(localChargeId);
    final providerStatus = await client.fetchChargeStatus(providerChargeId);
    charge['providerChargeId'] = providerChargeId;
    charge['providerStatus'] = providerStatus.status;
    charge['providerLastSyncAt'] = DateTime.now().toUtc().toIso8601String();
    charge['providerPayload'] = providerStatus.rawPayload;

    Map<String, dynamic>? paymentResult;
    if (_isProviderPaidStatus(providerStatus.status)) {
      paymentResult = await _confirmPaid(localChargeId);
    } else if (_isProviderCancelledStatus(providerStatus.status)) {
      if ('${charge['status'] ?? ''}'.toLowerCase() == 'pending') {
        charge['status'] = 'expired';
      }
      await _persist();
    } else {
      await _persist();
    }

    return <String, dynamic>{
      'providerChargeId': providerChargeId,
      'providerStatus': providerStatus.status,
      'providerRaw': providerStatus.rawPayload,
      'paymentResult': paymentResult,
      'confirmedAsPaid': paymentResult != null,
    };
  }

  bool _isProviderPaidStatus(String statusRaw) {
    final status = statusRaw.trim().toLowerCase();
    return status == 'paid' ||
        status == 'approved' ||
        status == 'confirmed' ||
        status == 'succeeded' ||
        status == 'complete';
  }

  bool _isProviderCancelledStatus(String statusRaw) {
    final status = statusRaw.trim().toLowerCase();
    return status == 'cancelled' ||
        status == 'canceled' ||
        status == 'expired' ||
        status == 'failed' ||
        status == 'refused';
  }

  Future<Map<String, dynamic>?> _confirmPaid(String chargeId) async {
    final charge = charges[chargeId];
    if (charge == null) return null;

    final now = DateTime.now().toUtc();
    final expiresAt =
        DateTime.tryParse('${charge['expiresAt'] ?? ''}')?.toUtc();
    if (expiresAt != null && now.isAfter(expiresAt)) {
      charge['status'] = 'expired';
      await _persist();
      return <String, dynamic>{
        'charge': charge,
        'subscription': _free('${charge['userId'] ?? ''}'),
      };
    }

    final userId = '${charge['userId'] ?? ''}'.trim();
    final planKey = '${charge['planKey'] ?? ''}'.trim();
    final status = '${charge['status'] ?? ''}'.toLowerCase();
    if (status == 'paid') {
      final current = _subscriptionFor(userId);
      if ('${current['activePlanKey'] ?? ''}'.trim() == planKey) {
        return <String, dynamic>{
          'charge': charge,
          'subscription': current,
          'idempotent': true,
        };
      }
    } else {
      charge['status'] = 'paid';
      charge['paidAt'] = now.toIso8601String();
    }

    final preserveExpiresAt =
        DateTime.tryParse('${charge['preserveExpiresAt'] ?? ''}')?.toUtc();
    final subscription = _activate(
      userId,
      planKey,
      expiresAt: preserveExpiresAt,
    );
    await _persist();
    return <String, dynamic>{'charge': charge, 'subscription': subscription};
  }

  Map<String, dynamic> _subscriptionFor(String userId) {
    final current = subscriptions[userId];
    if (current == null) return _free(userId);

    final now = DateTime.now().toUtc();
    final expiresAt =
        DateTime.tryParse('${current['expiresAt'] ?? ''}')?.toUtc();
    if (expiresAt == null || now.isAfter(expiresAt)) {
      subscriptions.remove(userId);
      unawaited(_persist());
      return _free(userId);
    }
    return Map<String, dynamic>.from(current);
  }

  Map<String, dynamic> _activate(
    String userId,
    String planKey, {
    DateTime? startsAt,
    DateTime? expiresAt,
  }) {
    final now = (startsAt ?? DateTime.now().toUtc()).toUtc();
    var next = (expiresAt ?? _addOneMonth(now)).toUtc();
    if (!next.isAfter(now)) {
      next = _addOneMonth(now);
    }
    final result = <String, dynamic>{
      'userId': userId,
      'activePlanKey': planKey,
      'startsAt': now.toIso8601String(),
      'expiresAt': next.toIso8601String(),
      'status': 'active',
      'monthlyPrice': _formatBrlFromCents(_planPriceCents(planKey)),
    };
    subscriptions[userId] = result;
    return result;
  }

  DateTime _addOneMonth(DateTime sourceUtc) {
    final nextMonth =
        sourceUtc.month == 12
            ? DateTime.utc(sourceUtc.year + 1, 1, 1)
            : DateTime.utc(sourceUtc.year, sourceUtc.month + 1, 1);
    final maxDay = DateTime.utc(nextMonth.year, nextMonth.month + 1, 0).day;
    final day = math.min(sourceUtc.day, maxDay);
    return DateTime.utc(
      nextMonth.year,
      nextMonth.month,
      day,
      sourceUtc.hour,
      sourceUtc.minute,
      sourceUtc.second,
      sourceUtc.millisecond,
      sourceUtc.microsecond,
    );
  }

  Map<String, dynamic> _free(String userId) {
    return <String, dynamic>{
      'userId': userId,
      'activePlanKey': 'free',
      'startsAt': null,
      'expiresAt': null,
      'status': 'free',
    };
  }

  String _pixCode(String chargeId, String planKey, String monthlyPrice) {
    final cents = monthlyPrice.replaceAll(RegExp(r'[^0-9]'), '');
    return '00020126360014BR.GOV.BCB.PIX0114spacegym.app520400005303986'
        '540${cents.padLeft(4, '0')}5802BR5910SPACEGYM6009SAOPAULO62070503***'
        '6304${chargeId.substring(chargeId.length - 4)}'
        'PLAN$planKey';
  }

  int _planPriceCents(String planKey, {String fallbackMonthlyPrice = ''}) {
    final known = _planPricesCents[planKey];
    if (known != null) {
      return known;
    }
    return _parsePriceCents(fallbackMonthlyPrice);
  }

  int _parsePriceCents(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return 0;
    }
    return int.tryParse(digits) ?? 0;
  }

  String _formatBrlFromCents(int cents) {
    final safe = cents < 0 ? 0 : cents;
    final reais = safe ~/ 100;
    final centavos = (safe % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }

  double _remainingCycleRatio({
    required DateTime now,
    required DateTime expiresAt,
    DateTime? startsAt,
  }) {
    final remainingMs = expiresAt.difference(now).inMilliseconds;
    if (remainingMs <= 0) {
      return 0;
    }
    final fallbackCycleMs = const Duration(days: 30).inMilliseconds;
    final cycleMs =
        startsAt != null && startsAt.isBefore(expiresAt)
            ? expiresAt.difference(startsAt).inMilliseconds
            : fallbackCycleMs;
    final safeCycleMs = cycleMs <= 0 ? fallbackCycleMs : cycleMs;
    final ratio = remainingMs / safeCycleMs;
    return ratio.clamp(0.0, 1.0);
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest req) async {
    final body = await utf8.decoder.bind(req).join();
    return _decodeJsonObject(body);
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Expected a JSON object');
  }

  String _gymLocationCompositeKey(String userId, String gymId) {
    return '$userId::$gymId';
  }

  Future<void> _persist() async {
    if (_dbMode) {
      await _persistDb();
    } else {
      await _persistFile();
    }
  }

  Future<void> _persistFile() async {
    if (!storeFile.parent.existsSync()) {
      await storeFile.parent.create(recursive: true);
    }
    final payload = <String, dynamic>{
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'subscriptions': subscriptions,
      'charges': charges,
      'processedWebhookEvents': webhookEvents,
      'gymLocations': gymLocations,
      'crowdReports': crowdReports,
    };
    await storeFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<void> _persistDb() async {
    final connection = db;
    if (connection == null) return;
    await _ensureDbSchema(connection);
    await connection.transaction((ctx) async {
      await ctx.query('DELETE FROM app_state');
      Future<void> insertKind(
        String kind,
        Map<String, Map<String, dynamic>> source,
      ) async {
        for (final entry in source.entries) {
          await ctx.query(
            'INSERT INTO app_state(kind,id,payload_json,updated_at) VALUES (@k,@i,@p,NOW())',
            substitutionValues: <String, dynamic>{
              'k': kind,
              'i': entry.key,
              'p': jsonEncode(entry.value),
            },
          );
        }
      }

      await insertKind('subscription', subscriptions);
      await insertKind('charge', charges);
      await insertKind('webhook_event', webhookEvents);
      await insertKind('gym_location', gymLocations);
      await insertKind('crowd_report', crowdReports);
    });
  }

  static Future<PostgreSQLConnection> _openDb(String databaseUrl) async {
    final uri = Uri.parse(databaseUrl);
    final host = uri.host;
    final port = uri.hasPort ? uri.port : 5432;
    final dbName =
        uri.pathSegments.isEmpty ? '' : uri.pathSegments.first.trim();
    final userInfo = uri.userInfo.split(':');
    final user = userInfo.isEmpty ? '' : Uri.decodeComponent(userInfo.first);
    final pass =
        userInfo.length > 1
            ? Uri.decodeComponent(userInfo.sublist(1).join(':'))
            : '';
    final sslMode = (uri.queryParameters['sslmode'] ?? '').toLowerCase();
    final useSSL = sslMode == 'require' || sslMode == 'verify-full';
    if (host.isEmpty || dbName.isEmpty || user.isEmpty) {
      throw StateError('DATABASE_URL is missing host/database/user');
    }

    final connection = PostgreSQLConnection(
      host,
      port,
      dbName,
      username: user,
      password: pass,
      useSSL: useSSL,
      timeoutInSeconds: 15,
    );
    await connection.open();
    return connection;
  }

  static Future<void> _ensureDbSchema(PostgreSQLConnection db) async {
    await db.query('''
CREATE TABLE IF NOT EXISTS app_state (
  kind TEXT NOT NULL,
  id TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY(kind, id)
)
''');
  }

  static Future<_State> _loadFromDb(PostgreSQLConnection db) async {
    final subscriptions = <String, Map<String, dynamic>>{};
    final charges = <String, Map<String, dynamic>>{};
    final webhookEvents = <String, Map<String, dynamic>>{};
    final gymLocations = <String, Map<String, dynamic>>{};
    final crowdReports = <String, Map<String, dynamic>>{};
    final rows = await db.query('SELECT kind,id,payload_json FROM app_state');
    for (final row in rows) {
      if (row.length < 3) continue;
      final kind = '${row[0] ?? ''}'.trim();
      final id = '${row[1] ?? ''}'.trim();
      final payloadText = '${row[2] ?? ''}';
      if (kind.isEmpty || id.isEmpty || payloadText.isEmpty) continue;
      final decoded = jsonDecode(payloadText);
      if (decoded is! Map) continue;
      final payload = Map<String, dynamic>.from(decoded);
      if (kind == 'subscription') subscriptions[id] = payload;
      if (kind == 'charge') charges[id] = payload;
      if (kind == 'webhook_event') webhookEvents[id] = payload;
      if (kind == 'gym_location') gymLocations[id] = payload;
      if (kind == 'crowd_report') crowdReports[id] = payload;
    }
    return _State(
      subscriptions,
      charges,
      webhookEvents,
      gymLocations,
      crowdReports,
    );
  }

  static Future<_State> _loadFromFile(File file) async {
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    final subscriptions = <String, Map<String, dynamic>>{};
    final charges = <String, Map<String, dynamic>>{};
    final webhookEvents = <String, Map<String, dynamic>>{};
    final gymLocations = <String, Map<String, dynamic>>{};
    final crowdReports = <String, Map<String, dynamic>>{};
    if (!file.existsSync()) {
      return _State(
        subscriptions,
        charges,
        webhookEvents,
        gymLocations,
        crowdReports,
      );
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        final rawSubs = decoded['subscriptions'];
        if (rawSubs is Map) {
          for (final entry in rawSubs.entries) {
            if (entry.value is Map) {
              subscriptions[entry.key.toString()] = Map<String, dynamic>.from(
                entry.value as Map,
              );
            }
          }
        }
        final rawCharges = decoded['charges'];
        if (rawCharges is Map) {
          for (final entry in rawCharges.entries) {
            if (entry.value is Map) {
              charges[entry.key.toString()] = Map<String, dynamic>.from(
                entry.value as Map,
              );
            }
          }
        }
        final rawEvents = decoded['processedWebhookEvents'];
        if (rawEvents is Map) {
          for (final entry in rawEvents.entries) {
            if (entry.value is Map) {
              webhookEvents[entry.key.toString()] = Map<String, dynamic>.from(
                entry.value as Map,
              );
            }
          }
        }
        final rawGymLocations = decoded['gymLocations'];
        if (rawGymLocations is Map) {
          for (final entry in rawGymLocations.entries) {
            if (entry.value is Map) {
              gymLocations[entry.key.toString()] = Map<String, dynamic>.from(
                entry.value as Map,
              );
            }
          }
        }
        final rawCrowdReports = decoded['crowdReports'];
        if (rawCrowdReports is Map) {
          for (final entry in rawCrowdReports.entries) {
            if (entry.value is Map) {
              crowdReports[entry.key.toString()] = Map<String, dynamic>.from(
                entry.value as Map,
              );
            }
          }
        }
      }
    } catch (_) {}

    return _State(
      subscriptions,
      charges,
      webhookEvents,
      gymLocations,
      crowdReports,
    );
  }

  Duration? _remainingCrowdReportCooldown({
    required String userId,
    required String gymId,
    required String reporterId,
    required DateTime now,
  }) {
    DateTime? latest;
    for (final report in crowdReports.values) {
      if ('${report['userId'] ?? ''}'.trim() != userId) {
        continue;
      }
      if ('${report['gymId'] ?? ''}'.trim() != gymId) {
        continue;
      }
      if ('${report['reporterId'] ?? ''}'.trim() != reporterId) {
        continue;
      }
      final createdAt =
          DateTime.tryParse('${report['createdAt'] ?? ''}')?.toUtc();
      if (createdAt == null) {
        continue;
      }
      if (latest == null || createdAt.isAfter(latest)) {
        latest = createdAt;
      }
    }
    if (latest == null) {
      return null;
    }
    final elapsed = now.difference(latest);
    if (elapsed >= _crowdReportCooldownWindow) {
      return null;
    }
    return _crowdReportCooldownWindow - elapsed;
  }

  String _normalizeCrowdRegionKey(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }
    final collapsedWhitespace = trimmed.replaceAll(RegExp(r'\s+'), '-');
    final sanitized = collapsedWhitespace.replaceAll(
      RegExp(r'[^a-z0-9,._-]'),
      '',
    );
    if (sanitized.length <= 64) {
      return sanitized;
    }
    return sanitized.substring(0, 64);
  }

  String _resolveCrowdRegionLabel({
    required String explicitLabel,
    required String normalizedRegionKey,
    required Iterable<Map<String, dynamic>> reports,
  }) {
    final fromQuery = explicitLabel.trim();
    if (fromQuery.isNotEmpty) {
      return fromQuery;
    }
    if (normalizedRegionKey.isEmpty) {
      return 'Todas as regioes';
    }
    for (final report in reports) {
      final reportRegionKey = _normalizeCrowdRegionKey(
        '${report['regionKey'] ?? report['region'] ?? ''}',
      );
      if (reportRegionKey != normalizedRegionKey) {
        continue;
      }
      final label = '${report['regionLabel'] ?? ''}'.trim();
      if (label.isNotEmpty) {
        return label;
      }
    }
    return 'Regiao atual';
  }

  String _crowdLeaderboardDisplayName(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return 'Usuario';
    }
    if (normalized == 'local-device-user') {
      return 'Usuario local';
    }
    final compact = normalized.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (compact.isEmpty) {
      return 'Usuario';
    }
    final prefix = compact.length <= 4 ? compact : compact.substring(0, 4);
    return 'Usuario $prefix';
  }

  double _estimateCrowdReliabilityWeight({
    required String userId,
    required String gymId,
    required int occupancyPercent,
    required DateTime now,
  }) {
    final recent = crowdReports.values
        .where((raw) => '${raw['userId'] ?? ''}'.trim() == userId)
        .where((raw) => '${raw['gymId'] ?? ''}'.trim() == gymId)
        .where((raw) {
          final createdAt =
              DateTime.tryParse('${raw['createdAt'] ?? ''}')?.toUtc();
          if (createdAt == null) {
            return false;
          }
          return now.difference(createdAt).inHours < 2;
        })
        .toList(growable: false);
    if (recent.isEmpty) {
      return 0.9;
    }
    final avg =
        recent
            .map((raw) => int.tryParse('${raw['occupancyPercent'] ?? ''}') ?? 0)
            .fold<int>(0, (sum, value) => sum + value) ~/
        recent.length;
    final delta = (occupancyPercent - avg).abs();
    if (delta <= 12) {
      return 1.0;
    }
    if (delta <= 25) {
      return 0.85;
    }
    if (delta <= 38) {
      return 0.72;
    }
    return 0.6;
  }
}

class _State {
  const _State(
    this.subscriptions,
    this.charges,
    this.webhookEvents,
    this.gymLocations,
    this.crowdReports,
  );
  final Map<String, Map<String, dynamic>> subscriptions;
  final Map<String, Map<String, dynamic>> charges;
  final Map<String, Map<String, dynamic>> webhookEvents;
  final Map<String, Map<String, dynamic>> gymLocations;
  final Map<String, Map<String, dynamic>> crowdReports;
}

class _SlidingWindowRateLimiter {
  final Map<String, List<int>> _hitsByKey = <String, List<int>>{};

  Duration? hit({
    required String key,
    required DateTime now,
    required Duration window,
    required int limit,
  }) {
    if (limit <= 0) {
      return null;
    }
    final nowMs = now.millisecondsSinceEpoch;
    final windowMs = window.inMilliseconds;
    final minAcceptedMs = nowMs - windowMs;
    final buffer = _hitsByKey.putIfAbsent(key, () => <int>[]);
    buffer.removeWhere((seenMs) => seenMs < minAcceptedMs);
    if (buffer.length >= limit) {
      final oldestMs = buffer.isEmpty ? nowMs : buffer.first;
      final retryMs = (oldestMs + windowMs - nowMs).clamp(1, windowMs);
      return Duration(milliseconds: retryMs);
    }
    buffer.add(nowMs);
    if (_hitsByKey.length > 5000) {
      _hitsByKey.removeWhere((_, values) => values.isEmpty);
    }
    return null;
  }
}

class _ExternalPixCreateChargeResult {
  const _ExternalPixCreateChargeResult({
    required this.chargeId,
    required this.copyPasteCode,
    required this.status,
    required this.expiresAt,
    required this.rawPayload,
  });

  final String chargeId;
  final String copyPasteCode;
  final String status;
  final DateTime? expiresAt;
  final Map<String, dynamic> rawPayload;
}

class _ExternalPixStatusResult {
  const _ExternalPixStatusResult({
    required this.status,
    required this.rawPayload,
  });

  final String status;
  final Map<String, dynamic> rawPayload;
}

class _ExternalPixClient {
  const _ExternalPixClient({
    required this.baseUri,
    required this.apiKey,
    required this.vendor,
    required this.defaultPayerEmail,
    required this.notificationUrl,
    required this.chargePath,
    required this.statusPathTemplate,
    required this.timeout,
  });

  final Uri baseUri;
  final String apiKey;
  final String vendor;
  final String defaultPayerEmail;
  final String notificationUrl;
  final String chargePath;
  final String statusPathTemplate;
  final Duration timeout;

  Future<_ExternalPixCreateChargeResult> createCharge({
    required String externalReference,
    required String userId,
    required String planKey,
    required int amountDueCents,
  }) async {
    final effectiveVendor = vendor.trim().toLowerCase();
    final isMercadoPago =
        effectiveVendor == 'mercado_pago' || effectiveVendor == 'mercadopago';
    final payload =
        isMercadoPago
            ? <String, dynamic>{
              'transaction_amount': amountDueCents / 100,
              'description': 'GymMap plano $planKey',
              'payment_method_id': 'pix',
              'external_reference': externalReference,
              'payer': <String, dynamic>{
                'email': _sanitizePayerEmail(userId, defaultPayerEmail),
              },
              if (notificationUrl.trim().isNotEmpty)
                'notification_url': notificationUrl.trim(),
            }
            : <String, dynamic>{
              'externalReference': externalReference,
              'userId': userId,
              'planKey': planKey,
              'amountCents': amountDueCents,
              'currency': 'BRL',
              'paymentMethod': 'pix',
            };
    final extraHeaders =
        isMercadoPago
            ? <String, String>{'X-Idempotency-Key': externalReference}
            : const <String, String>{};
    final response = await _sendJson(
      method: 'POST',
      uri: _resolveUri(chargePath),
      payload: payload,
      extraHeaders: extraHeaders,
    );
    final chargeId =
        '${response['chargeId'] ?? response['id'] ?? response['txid'] ?? externalReference}'
            .trim()
            .ifEmpty(externalReference);
    final copyPasteCode =
        isMercadoPago
            ? _copyPasteFromMercadoPago(response)
            : '${response['copyPasteCode'] ?? response['pixCopiaECola'] ?? response['brCode'] ?? response['emv'] ?? ''}'
                .trim();
    final status = '${response['status'] ?? 'pending'}'.trim().toLowerCase();
    final expiresAt =
        isMercadoPago
            ? _expiresAtFromMercadoPago(response)
            : DateTime.tryParse(
              '${response['expiresAt'] ?? response['expiration'] ?? ''}',
            )?.toUtc();
    return _ExternalPixCreateChargeResult(
      chargeId: chargeId,
      copyPasteCode: copyPasteCode,
      status: status,
      expiresAt: expiresAt,
      rawPayload: response,
    );
  }

  Future<_ExternalPixStatusResult> fetchChargeStatus(String chargeId) async {
    final safeChargeId = Uri.encodeComponent(chargeId);
    final path = statusPathTemplate.replaceAll('{chargeId}', safeChargeId);
    final response = await _sendJson(method: 'GET', uri: _resolveUri(path));
    final status =
        '${response['status'] ?? response['paymentStatus'] ?? response['state'] ?? 'unknown'}'
            .trim()
            .toLowerCase();
    return _ExternalPixStatusResult(status: status, rawPayload: response);
  }

  Uri _resolveUri(String path) {
    final normalized = path.trim();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Uri.parse(normalized);
    }
    final withLeadingSlash =
        normalized.isEmpty
            ? '/'
            : (normalized.startsWith('/') ? normalized : '/$normalized');
    return baseUri.resolve(withLeadingSlash);
  }

  Future<Map<String, dynamic>> _sendJson({
    required String method,
    required Uri uri,
    Map<String, dynamic>? payload,
    Map<String, String> extraHeaders = const <String, String>{},
  }) async {
    final httpClient = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request;
      if (method == 'POST') {
        request = await httpClient.postUrl(uri);
      } else {
        request = await httpClient.getUrl(uri);
      }
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        apiKey.toLowerCase().startsWith('bearer ') ? apiKey : 'Bearer $apiKey',
      );
      for (final entry in extraHeaders.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (payload != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(jsonEncode(payload));
      }
      final response = await request.close().timeout(timeout);
      final rawBody = await utf8.decoder.bind(response).join();
      final parsed = _decodeJsonMap(rawBody);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = '${parsed['error'] ?? parsed['message'] ?? ''}'.trim();
        final message =
            error.isEmpty ? 'provider_http_${response.statusCode}' : error;
        throw StateError(message);
      }
      return parsed;
    } finally {
      httpClient.close(force: true);
    }
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  String _sanitizePayerEmail(String userId, String fallback) {
    final normalizedFallback = fallback.trim().toLowerCase();
    if (normalizedFallback.contains('@') && normalizedFallback.length >= 6) {
      return normalizedFallback;
    }
    final safeUser = userId
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '')
        .ifEmpty('gymmap-user');
    return '$safeUser@gymmap.app';
  }

  String _copyPasteFromMercadoPago(Map<String, dynamic> payload) {
    final poi = payload['point_of_interaction'];
    if (poi is Map) {
      final transactionData = poi['transaction_data'];
      if (transactionData is Map) {
        final qrCode = '${transactionData['qr_code'] ?? ''}'.trim();
        if (qrCode.isNotEmpty) {
          return qrCode;
        }
      }
    }
    return '';
  }

  DateTime? _expiresAtFromMercadoPago(Map<String, dynamic> payload) {
    final raw =
        '${payload['date_of_expiration'] ?? payload['expiration_date'] ?? ''}'
            .trim();
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }
}

class _PlayPurchaseValidationResult {
  const _PlayPurchaseValidationResult({
    required this.packageName,
    required this.productIds,
    required this.latestOrderId,
    required this.subscriptionState,
    required this.isAcknowledged,
    required this.isActive,
    required this.expiresAt,
    required this.rawPayload,
  });

  final String packageName;
  final List<String> productIds;
  final String? latestOrderId;
  final String subscriptionState;
  final bool isAcknowledged;
  final bool isActive;
  final DateTime? expiresAt;
  final Map<String, dynamic> rawPayload;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'packageName': packageName,
      'productIds': productIds,
      'latestOrderId': latestOrderId,
      'subscriptionState': subscriptionState,
      'isAcknowledged': isAcknowledged,
      'isActive': isActive,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }
}

class _GooglePlayBillingClient {
  _GooglePlayBillingClient._({
    required this.packageName,
    required this.credentials,
  });

  final String packageName;
  final google_auth.ServiceAccountCredentials credentials;

  static _GooglePlayBillingClient? tryCreate({
    required String packageName,
    required String serviceAccountJson,
  }) {
    final normalizedPackage = packageName.trim();
    final normalizedJson = serviceAccountJson.trim();
    if (normalizedPackage.isEmpty || normalizedJson.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(normalizedJson);
      if (decoded is! Map) {
        return null;
      }
      final credentials = google_auth.ServiceAccountCredentials.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return _GooglePlayBillingClient._(
        packageName: normalizedPackage,
        credentials: credentials,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_PlayPurchaseValidationResult> validateSubscription({
    required String productId,
    required String purchaseToken,
  }) async {
    final authClient = await google_auth.clientViaServiceAccount(
      credentials,
      const <String>[
        androidpublisher.AndroidPublisherApi.androidpublisherScope,
      ],
    );
    try {
      final api = androidpublisher.AndroidPublisherApi(authClient);
      final purchase = await api.purchases.subscriptionsv2.get(
        packageName,
        purchaseToken,
      );

      final rawPayload = purchase.toJson();
      final productIds = <String>{};
      DateTime? latestExpiry;
      for (final lineItem
          in purchase.lineItems ??
              const <androidpublisher.SubscriptionPurchaseLineItem>[]) {
        final rawProductId = (lineItem.productId ?? '').trim();
        if (rawProductId.isNotEmpty) {
          productIds.add(rawProductId);
        }
        final expiry = _parseUtcDate((lineItem.expiryTime ?? '').trim());
        if (expiry == null) {
          continue;
        }
        if (latestExpiry == null || expiry.isAfter(latestExpiry)) {
          latestExpiry = expiry;
        }
      }

      final subscriptionState =
          (purchase.subscriptionState ?? 'SUBSCRIPTION_STATE_UNSPECIFIED')
              .trim();
      final acknowledgementState =
          (purchase.acknowledgementState ?? '').trim().toUpperCase();
      final isAcknowledged =
          acknowledgementState == 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED';
      final now = DateTime.now().toUtc();
      final stateUpper = subscriptionState.toUpperCase();
      final isStateActive =
          stateUpper == 'SUBSCRIPTION_STATE_ACTIVE' ||
          stateUpper == 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD';
      final isNotExpired = latestExpiry == null || now.isBefore(latestExpiry);
      final hasProductMatch =
          productIds.isEmpty || productIds.contains(productId.trim());
      final isActive = isStateActive && isNotExpired && hasProductMatch;
      final latestOrderId = (purchase.latestOrderId ?? '').trim();

      return _PlayPurchaseValidationResult(
        packageName: packageName,
        productIds: productIds.toList(growable: false),
        latestOrderId: latestOrderId.isEmpty ? null : latestOrderId,
        subscriptionState: subscriptionState,
        isAcknowledged: isAcknowledged,
        isActive: isActive,
        expiresAt: latestExpiry,
        rawPayload: Map<String, dynamic>.from(rawPayload),
      );
    } catch (error) {
      final raw = '$error'.toLowerCase();
      if (raw.contains('404') || raw.contains('not found')) {
        throw StateError('play_purchase_not_found');
      }
      if (raw.contains('401') || raw.contains('403')) {
        throw StateError('play_api_unauthorized');
      }
      throw StateError('play_api_unavailable');
    } finally {
      authClient.close();
    }
  }
}

DateTime? _parseUtcDate(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return DateTime.tryParse(normalized)?.toUtc();
}

List<String> _normalizeWebhookSecrets({
  required String currentSecret,
  required String previousSecretsRaw,
}) {
  final out = <String>[];
  final seen = <String>{};
  void addSecret(String raw) {
    final secret = raw.trim();
    if (secret.isEmpty || !seen.add(secret)) return;
    out.add(secret);
  }

  addSecret(currentSecret);
  for (final raw in previousSecretsRaw.split(',')) {
    addSecret(raw);
  }
  return out;
}

Map<String, String> _parseAuthUsers(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) return const <String, String>{};
  try {
    final decoded = jsonDecode(normalized);
    if (decoded is! Map) return const <String, String>{};
    final out = <String, String>{};
    for (final entry in decoded.entries) {
      final userId = '${entry.key}'.trim();
      final password = '${entry.value}';
      if (userId.isEmpty || password.isEmpty) continue;
      out[userId] = password;
    }
    return out;
  } catch (_) {
    return const <String, String>{};
  }
}

void _applyCors(HttpResponse response, {required String allowOrigin}) {
  response.headers
    ..set('Access-Control-Allow-Origin', allowOrigin)
    ..set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization, X-Webhook-Token, X-Webhook-Timestamp, X-Webhook-Signature, X-Webhook-Event-Id',
    )
    ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    ..set('X-Content-Type-Options', 'nosniff')
    ..set('X-Frame-Options', 'DENY')
    ..set('Referrer-Policy', 'no-referrer')
    ..set('Cache-Control', 'no-store')
    ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
}

Future<void> _json(
  HttpRequest req,
  int status,
  Map<String, dynamic> body,
) async {
  req.response.statusCode = status;
  req.response.write(jsonEncode(body));
  await req.response.close();
}

bool _parseBoolEnv(String raw) {
  final value = raw.trim().toLowerCase();
  return value == '1' || value == 'true' || value == 'yes' || value == 'on';
}

String _resolvePlayServiceAccountJson({
  required String rawJson,
  required String base64Json,
}) {
  final direct = rawJson.trim();
  if (direct.isNotEmpty) {
    return direct;
  }
  final encoded = base64Json.trim();
  if (encoded.isEmpty) {
    return '';
  }
  try {
    return utf8.decode(base64Decode(encoded));
  } catch (_) {
    return '';
  }
}

List<String> _validateProductionConfig({
  required bool productionMode,
  required String databaseUrl,
  required String jwtSecret,
  required String webhookToken,
  required List<String> webhookSecrets,
  required String authDefaultPassword,
  required String corsAllowOrigin,
  required String adminApiToken,
  required String pixProviderMode,
  required String pixProviderVendor,
  required String pixProviderBaseUrl,
  required String pixProviderApiKey,
  required String pixMpDefaultPayerEmail,
  required int globalRequestsPerMin,
  required int loginAttemptsPerMin,
  required int billingAttemptsPerMin,
  required String playPackageName,
  required String playServiceAccountJson,
  required Map<String, String> playProductIdsByPlan,
}) {
  if (!productionMode) {
    return const <String>[];
  }

  final issues = <String>[];
  if (databaseUrl.trim().isEmpty) {
    issues.add('DATABASE_URL is required when BACKEND_PRODUCTION_MODE=true');
  }
  if (jwtSecret.trim().isEmpty) {
    issues.add('JWT_HS256_SECRET is required in production mode');
  }
  if (webhookSecrets.isEmpty) {
    issues.add('WEBHOOK_SIGNING_SECRET is required in production mode');
  }
  if (authDefaultPassword.trim().isNotEmpty) {
    issues.add('AUTH_DEFAULT_PASSWORD must be empty in production mode');
  }
  if (corsAllowOrigin.trim().isEmpty || corsAllowOrigin.trim() == '*') {
    issues.add(
      'CORS_ALLOW_ORIGIN must be a specific origin in production mode',
    );
  }
  if (adminApiToken.trim().length < 24) {
    issues.add(
      'ADMIN_API_TOKEN is required in production mode and should be at least 24 chars',
    );
  }
  if (pixProviderMode.trim().toLowerCase() != 'external') {
    issues.add(
      'PIX_PROVIDER_MODE must be external in production mode for commercial billing',
    );
  }
  final providerVendor = pixProviderVendor.trim().toLowerCase();
  final isMercadoPago =
      providerVendor == 'mercado_pago' || providerVendor == 'mercadopago';
  if (!(providerVendor == 'generic' || isMercadoPago)) {
    issues.add('PIX_PROVIDER_VENDOR must be one of: generic, mercado_pago');
  }
  if (!isMercadoPago && webhookToken.trim().isEmpty) {
    issues.add('WEBHOOK_TOKEN is required in production mode');
  }
  if (pixProviderBaseUrl.trim().isEmpty) {
    issues.add('PIX_PROVIDER_BASE_URL is required in production mode');
  }
  if (pixProviderApiKey.trim().isEmpty) {
    issues.add('PIX_PROVIDER_API_KEY is required in production mode');
  }
  if (isMercadoPago && pixMpDefaultPayerEmail.trim().isEmpty) {
    issues.add(
      'PIX_MP_DEFAULT_PAYER_EMAIL is required for PIX_PROVIDER_VENDOR=mercado_pago',
    );
  }
  if (globalRequestsPerMin < 30 || globalRequestsPerMin > 6000) {
    issues.add('RATE_LIMIT_REQUESTS_PER_MIN must be between 30 and 6000');
  }
  if (loginAttemptsPerMin < 3 || loginAttemptsPerMin > 600) {
    issues.add('RATE_LIMIT_LOGIN_ATTEMPTS_PER_MIN must be between 3 and 600');
  }
  if (billingAttemptsPerMin < 3 || billingAttemptsPerMin > 600) {
    issues.add('RATE_LIMIT_BILLING_ATTEMPTS_PER_MIN must be between 3 and 600');
  }
  final hasPlayConfig =
      playPackageName.trim().isNotEmpty ||
      playServiceAccountJson.trim().isNotEmpty;
  if (hasPlayConfig) {
    if (playPackageName.trim().isEmpty) {
      issues.add(
        'PLAY_PACKAGE_NAME is required when Play Billing validation is configured',
      );
    }
    if (playServiceAccountJson.trim().isEmpty) {
      issues.add(
        'PLAY_SERVICE_ACCOUNT_JSON or PLAY_SERVICE_ACCOUNT_JSON_BASE64 is required when Play Billing validation is configured',
      );
    }
    for (final plan in <String>['smart', 'pro', 'elite']) {
      if ((playProductIdsByPlan[plan] ?? '').trim().isEmpty) {
        issues.add('PLAY_PRODUCT_ID_${plan.toUpperCase()} is required');
      }
    }
  }
  return issues;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
