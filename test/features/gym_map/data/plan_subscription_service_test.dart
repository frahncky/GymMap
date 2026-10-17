import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/features/gym_map/data/plan_subscription_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwtFor(String subject, {required DateTime expiresAt}) {
  String encode(Map<String, Object> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final payload = <String, Object>{
    'sub': subject,
    'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
  };
  return '${encode(<String, Object>{'alg': 'HS256'})}.${encode(payload)}.sig';
}

/// Backend falso com o mínimo de /v1/auth/* para exercitar o fluxo de sessão.
class _FakeAuthBackend {
  final Map<String, String> anonymousSecrets = <String, String>{};
  final Map<String, String> passwordsByUsername = <String, String>{};
  final Map<String, String> userIdByUsername = <String, String>{};
  final List<String> calls = <String>[];
  DateTime tokenExpiresAt = DateTime.now().toUtc().add(
    const Duration(days: 30),
  );
  int _nextId = 1;

  late final MockClient client = MockClient((request) async {
    calls.add('${request.method} ${request.url.path}');
    final body =
        request.body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(request.body) as Map);
    switch (request.url.path) {
      case '/v1/auth/anonymous':
        final userId = 'anon_${_nextId++}';
        anonymousSecrets[userId] = 'secret-$userId';
        return _session(
          userId,
          kind: 'anonymous',
          status: 201,
          extra: <String, Object>{'deviceSecret': 'secret-$userId'},
        );
      case '/v1/auth/login':
        final identifier = '${body['userId']}';
        final password = '${body['password']}';
        if (anonymousSecrets[identifier] == password) {
          return _session(identifier, kind: 'anonymous');
        }
        if (passwordsByUsername[identifier] == password) {
          return _session(
            userIdByUsername[identifier]!,
            kind: 'registered',
            username: identifier,
          );
        }
        return http.Response(
          jsonEncode(<String, Object>{'error': 'invalid_credentials'}),
          401,
        );
      case '/v1/auth/register':
        final username = '${body['username']}';
        final bearer = request.headers['authorization'] ?? '';
        final currentUser = bearer.isEmpty ? null : _subjectOf(bearer);
        final userId =
            currentUser != null && anonymousSecrets.containsKey(currentUser)
                ? currentUser
                : 'usr_${_nextId++}';
        anonymousSecrets.remove(userId);
        passwordsByUsername[username] = '${body['password']}';
        userIdByUsername[username] = userId;
        return _session(userId, kind: 'registered', username: username);
    }
    return http.Response('{}', 404);
  });

  http.Response _session(
    String userId, {
    required String kind,
    String? username,
    int status = 200,
    Map<String, Object> extra = const <String, Object>{},
  }) {
    return http.Response(
      jsonEncode(<String, Object>{
        'accessToken': _jwtFor(userId, expiresAt: tokenExpiresAt),
        'userId': userId,
        'accountKind': kind,
        if (username != null) 'username': username,
        ...extra,
      }),
      status,
    );
  }

  String? _subjectOf(String bearer) {
    final parts = bearer.substring('Bearer '.length).split('.');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return (payload as Map)['sub'] as String?;
  }
}

void main() {
  group('PlanSubscriptionService session', () {
    late _FakeAuthBackend backend;

    Future<PlanSubscriptionService> createService() {
      return PlanSubscriptionService.create(
        backendBaseUrl: 'https://api.test',
        httpClient: backend.client,
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      backend = _FakeAuthBackend();
    });

    test('creates an anonymous account on first run', () async {
      final service = await createService();

      await service.ensureSession();

      expect(service.hasAuthSession, isTrue);
      expect(service.isAnonymousSession, isTrue);
      expect(service.userId, 'anon_1');
      expect(backend.calls, <String>['POST /v1/auth/anonymous']);
    });

    test('keeps a valid anonymous session without network calls', () async {
      final first = await createService();
      await first.ensureSession();
      backend.calls.clear();

      final second = await createService();
      await second.ensureSession();

      expect(second.userId, 'anon_1');
      expect(backend.calls, isEmpty);
    });

    test('renews an expiring anonymous session with the device secret', () async {
      backend.tokenExpiresAt = DateTime.now().toUtc().add(
        const Duration(hours: 1),
      );
      final first = await createService();
      await first.ensureSession();
      backend.calls.clear();

      final second = await createService();
      await second.ensureSession();

      expect(second.userId, 'anon_1');
      expect(backend.calls, <String>['POST /v1/auth/login']);
    });

    test('register upgrades the anonymous account keeping its userId', () async {
      final service = await createService();
      await service.ensureSession();

      await service.register(username: 'maria', password: 'senha-forte');

      expect(service.userId, 'anon_1');
      expect(service.isAnonymousSession, isFalse);
      expect(service.username, 'maria');
    });

    test('sign out falls back to a fresh anonymous account after upgrade', () async {
      final service = await createService();
      await service.ensureSession();
      await service.register(username: 'maria', password: 'senha-forte');

      await service.signOut();
      await service.ensureSession();

      // O segredo da conta promovida foi descartado, então nasce outra.
      expect(service.isAnonymousSession, isTrue);
      expect(service.userId, 'anon_2');
    });

    test('sign out returns to the device anonymous account', () async {
      backend.passwordsByUsername['joao'] = 'senha-joao';
      backend.userIdByUsername['joao'] = 'usr_99';
      final service = await createService();
      await service.ensureSession();

      await service.signIn(userId: 'joao', password: 'senha-joao');
      expect(service.userId, 'usr_99');
      expect(service.isAnonymousSession, isFalse);

      await service.signOut();
      await service.ensureSession();

      expect(service.userId, 'anon_1');
      expect(service.isAnonymousSession, isTrue);
    });
  });
}
