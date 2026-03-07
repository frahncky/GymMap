import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/features/gym_map/data/gym_location_cache_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

CachedGymLocation _location({
  required String id,
  required String name,
  required double lat,
  required double lng,
}) {
  return CachedGymLocation(
    id: id,
    name: name,
    address: 'Endereco $name',
    position: LatLng(lat, lng),
    updatedAtUtc: DateTime.utc(2026, 1, 1, 12),
  );
}

void main() {
  group('GymLocationCacheService', () {
    test('persists and restores gym locations', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = await GymLocationCacheService.create();

      await service.mergeAndSave(<CachedGymLocation>[
        _location(id: 'node-1', name: 'Gym One', lat: -23.56, lng: -46.65),
        _location(id: 'node-2', name: 'Gym Two', lat: -23.57, lng: -46.66),
      ]);

      final restored = await service.loadLocations();
      expect(restored.length, 2);
      expect(restored.any((location) => location.id == 'node-1'), isTrue);
      expect(restored.any((location) => location.id == 'node-2'), isTrue);
    });

    test('merges by id and keeps latest coordinates', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = await GymLocationCacheService.create();

      await service.mergeAndSave(<CachedGymLocation>[
        _location(id: 'node-1', name: 'Gym One', lat: -23.56, lng: -46.65),
      ]);

      await service.mergeAndSave(<CachedGymLocation>[
        _location(id: 'node-1', name: 'Gym One', lat: -23.50, lng: -46.60),
      ]);

      final restored = await service.loadLocations();
      expect(restored.length, 1);
      expect(restored.first.id, 'node-1');
      expect(restored.first.position.latitude, -23.50);
      expect(restored.first.position.longitude, -46.60);
    });

    test('pulls remote locations and merges into local cache', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'subscription.auth.user_id': 'local-device-user',
      });
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://api.example.com/v1/gyms/locations/local-device-user',
        );
        return http.Response(
          jsonEncode(<String, dynamic>{
            'locations': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'node-remote',
                'name': 'Gym Remote',
                'address': 'Endereco remoto',
                'lat': -23.58,
                'lng': -46.67,
                'updatedAtUtc': '2026-01-03T10:00:00Z',
              },
            ],
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final service = await GymLocationCacheService.create(
        backendBaseUrl: 'https://api.example.com',
        httpClient: client,
      );
      final pulled = await service.pullRemoteToLocal();

      expect(pulled, 1);
      final restored = await service.loadLocations();
      expect(restored.length, 1);
      expect(restored.first.id, 'node-remote');
      expect(restored.first.name, 'Gym Remote');
    });

    test('avoids redundant remote sync when location payload is unchanged', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'subscription.auth.user_id': 'local-device-user',
      });
      var postCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          postCalls++;
        }
        return http.Response('{}', 200);
      });
      final service = await GymLocationCacheService.create(
        backendBaseUrl: 'https://api.example.com',
        httpClient: client,
      );

      final sample = _location(
        id: 'node-static',
        name: 'Gym Static',
        lat: -23.55,
        lng: -46.64,
      );
      await service.mergeAndSave(<CachedGymLocation>[sample]);
      await service.mergeAndSave(<CachedGymLocation>[sample]);

      expect(postCalls, 1);
    });
  });
}
