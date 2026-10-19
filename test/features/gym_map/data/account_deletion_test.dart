import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/features/gym_map/data/plan_subscription_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'subscription.auth.user_id': 'usr_test',
      'subscription.auth.token': 'session-token',
      'subscription.auth.device_secret': 'device-secret',
      'subscription.active_plan': 'elite',
      'gymmap_favorite_gym_ids_v1': <String>['gym-1'],
      'gym_map.cached_locations.v1': 'cached-data',
    });
  });

  test(
    'deletes remotely with auth before clearing local account data',
    () async {
      final service = await PlanSubscriptionService.create(
        backendBaseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/account/delete');
          expect(request.headers['Authorization'], 'Bearer session-token');
          expect(jsonDecode(request.body), {
            'password': 'password',
            'confirm': true,
          });
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('subscription.auth.token'), 'session-token');
          return http.Response('{"deleted":true}', 200);
        }),
      );
      await service.deleteAccount(password: 'password');
      expect(service.hasAuthSession, isFalse);
      expect(service.userId, 'local-device-user');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );

  test('keeps credentials and cached data if deletion fails', () async {
    final service = await PlanSubscriptionService.create(
      backendBaseUrl: 'https://api.test',
      httpClient: MockClient(
        (_) async => http.Response('{"error":"invalid_credentials"}', 401),
      ),
    );
    await expectLater(
      service.deleteAccount(password: 'wrong'),
      throwsStateError,
    );
    expect(service.hasAuthSession, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('subscription.auth.device_secret'), 'device-secret');
    expect(prefs.getStringList('gymmap_favorite_gym_ids_v1'), ['gym-1']);
  });
}
