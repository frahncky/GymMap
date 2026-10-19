import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late Process server;
  late Uri base;
  late File store;
  final client = HttpClient();

  Future<(int, dynamic)> request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final req = await client.openUrl(method, base.resolve(path));
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    final text = await utf8.decoder.bind(res).join();
    return (
      res.statusCode,
      res.headers.contentType?.mimeType == 'text/html'
          ? text
          : jsonDecode(text),
    );
  }

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('gymmap-deletion-test-');
    store = File('${temp.path}/store.json');
    Map<String, dynamic> account(String id) => {
      'userId': id,
      'kind': 'anonymous',
      'deviceSecretSha256':
          sha256.convert(utf8.encode('secret-$id')).toString(),
    };
    final now = DateTime.now().toUtc().toIso8601String();
    await store.writeAsString(
      jsonEncode({
        'accounts': {'anon_a': account('anon_a'), 'anon_b': account('anon_b')},
        'subscriptions': {
          'anon_a': {'userId': 'anon_a'},
          'anon_b': {'userId': 'anon_b'},
        },
        'charges': {
          'charge-a': {'userId': 'anon_a', 'createdAt': now},
        },
        'processedWebhookEvents': {
          'event-a': {'chargeId': 'charge-a', 'processedAt': now},
        },
        'gymLocations': {
          'a::gym': {'userId': 'anon_a'},
          'b::gym': {'userId': 'anon_b'},
        },
        'crowdReports': {
          'report-a': {'userId': 'anon_a', 'createdAt': now},
          'report-b': {
            'userId': 'anon_b',
            'createdAt': now,
            'votes': {'anon_a': 'confirm', 'anon_b': 'confirm'},
          },
        },
        'amenityVotes': {
          'vote-a': {'userId': 'anon_a'},
        },
        'pointLedgers': {
          'anon_a': {'userId': 'anon_a'},
          'anon_b': {'userId': 'anon_b'},
        },
        'gymSuggestions': {
          'suggestion-a': {'userId': 'anon_a'},
          'suggestion-b': {
            'userId': 'anon_b',
            'votes': {'anon_a': 'exists'},
          },
        },
      }),
    );
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    base = Uri.parse('http://127.0.0.1:$port');
    final root =
        Directory.current.path.endsWith('backend')
            ? Directory.current.parent.path
            : Directory.current.path;
    server = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'backend/server.dart'],
      workingDirectory: root,
      environment: {
        'HOST': '127.0.0.1',
        'PORT': '$port',
        'STORE_PATH': store.path,
        'DATABASE_URL': '',
        'BACKEND_PRODUCTION_MODE': 'false',
        'JWT_HS256_SECRET': 'test-secret-account-deletion-only',
        'AUTH_USERS_JSON': '{}',
        'AUTH_DEFAULT_PASSWORD': '',
        'REQUEST_LOG_DISABLED': 'true',
        'RATE_LIMIT_LOGIN_ATTEMPTS_PER_MIN': '600',
      },
    );
    final ready = Completer<void>();
    final errors = StringBuffer();
    server.stderr.transform(utf8.decoder).listen(errors.write);
    server.stdout.transform(utf8.decoder).listen((text) {
      if (text.contains('listening on') && !ready.isCompleted) ready.complete();
    });
    unawaited(
      server.exitCode.then((code) {
        if (!ready.isCompleted)
          ready.completeError(StateError('Server exited ($code): $errors'));
      }),
    );
    await ready.future.timeout(const Duration(seconds: 60));
  });

  tearDownAll(() async {
    client.close(force: true);
    server.kill();
    await server.exitCode;
    await temp.delete(recursive: true);
  });

  test(
    'deletes only authenticated account data, persists removal and revokes JWT',
    () async {
      final login = await request(
        'POST',
        '/v1/auth/login',
        body: {'userId': 'anon_a', 'password': 'secret-anon_a'},
      );
      expect(login.$1, 200);
      final token = login.$2['accessToken'] as String;
      expect(
        (await request(
          'POST',
          '/v1/account/delete',
          body: {'confirm': true},
        )).$1,
        401,
      );
      expect(
        (await request(
          'POST',
          '/v1/account/delete',
          token: token,
          body: {},
        )).$1,
        400,
      );
      final deleted = await request(
        'POST',
        '/v1/account/delete',
        token: token,
        body: {'confirm': true, 'userId': 'anon_b'},
      );
      expect(deleted.$1, 200);
      expect(deleted.$2, {'deleted': true});
      expect(
        (await request('GET', '/v1/subscriptions/anon_a', token: token)).$1,
        401,
      );
      expect(
        (await request(
          'POST',
          '/v1/auth/login',
          body: {'userId': 'anon_a', 'password': 'secret-anon_a'},
        )).$1,
        401,
      );
      final state = jsonDecode(await store.readAsString()) as Map;
      expect(jsonEncode(state), isNot(contains('anon_a')));
      expect((state['accounts'] as Map).containsKey('anon_b'), isTrue);
      expect((state['crowdReports'] as Map).containsKey('report-b'), isTrue);
      expect(state['charges'], isEmpty);
      expect(state['processedWebhookEvents'], isEmpty);
    },
  );

  test(
    'registered account requires its password and username can be reused after deletion',
    () async {
      final created = await request(
        'POST',
        '/v1/auth/register',
        body: {'username': 'test_delete', 'password': 'secure-password-test'},
      );
      expect(created.$1, 201);
      final token = created.$2['accessToken'] as String;
      expect(
        (await request(
          'POST',
          '/v1/account/delete',
          token: token,
          body: {'confirm': true, 'password': 'wrong'},
        )).$1,
        401,
      );
      expect(
        (await request(
          'POST',
          '/v1/account/delete',
          token: token,
          body: {'confirm': true, 'password': 'secure-password-test'},
        )).$1,
        200,
      );
      expect(
        (await request(
          'POST',
          '/v1/auth/register',
          body: {'username': 'test_delete', 'password': 'secure-password-test'},
        )).$1,
        201,
      );
    },
  );

  test(
    'public privacy and deletion pages are served without authentication',
    () async {
      for (final path in ['/privacy', '/delete-account']) {
        final result = await request('GET', path);
        expect(result.$1, 200);
        expect(result.$2, contains('DevIA'));
        expect(result.$2, contains('francisco.dsantos.viana@gmail.com'));
      }
    },
  );
}
