import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/features/gym_map/data/gym_route_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

Map<String, Object?> _osrmResponse() => <String, Object?>{
  'code': 'Ok',
  'routes': <Map<String, Object?>>[
    <String, Object?>{
      'distance': 6455.2,
      'duration': 5160.0,
      'geometry': <String, Object?>{
        'type': 'LineString',
        'coordinates': <List<double>>[
          <double>[-44.28, -2.53],
          <double>[-44.27, -2.52],
          <double>[-44.265, -2.515],
        ],
      },
    },
  ],
};

void main() {
  group('GymRouteService', () {
    test('parses the OSRM geometry as lat/lng points', () {
      final route = GymRouteService.parseRoute(
        _osrmResponse(),
        GymRouteMode.walking,
      );

      expect(route, isNotNull);
      expect(route!.points.first, const LatLng(-2.53, -44.28));
      expect(route.points, hasLength(3));
      expect(route.distanceMeters, 6455.2);
      expect(route.durationSeconds, 5160.0);
      expect(route.mode, GymRouteMode.walking);
    });

    test('returns null when OSRM finds no route', () {
      expect(
        GymRouteService.parseRoute(<String, Object?>{
          'code': 'NoRoute',
        }, GymRouteMode.driving),
        isNull,
      );
    });

    test('requests the profile of the chosen mode and caches it', () async {
      var calls = 0;
      late Uri requested;
      final service = GymRouteService(
        httpClient: MockClient((request) async {
          calls++;
          requested = request.url;
          return http.Response(jsonEncode(_osrmResponse()), 200);
        }),
      );
      addTearDown(service.dispose);

      Future<GymRoute?> fetch() => service.fetchRoute(
        origin: const LatLng(-2.53, -44.28),
        destination: const LatLng(-2.515, -44.265),
        mode: GymRouteMode.driving,
      );

      expect(await fetch(), isNotNull);
      expect(await fetch(), isNotNull);
      expect(calls, 1);
      expect(requested.path, contains('/routed-car/route/v1/driving/'));
      expect(requested.path, contains('-44.280000,-2.530000;'));
      expect(requested.queryParameters['geometries'], 'geojson');
    });

    test('distanceToRouteMeters is ~0 on the line and grows off it', () {
      // Rua reta de leste a oeste, ~1,1 km.
      const route = <LatLng>[LatLng(-2.53, -44.29), LatLng(-2.53, -44.28)];

      expect(
        GymRouteService.distanceToRouteMeters(
          const LatLng(-2.53, -44.285),
          route,
        ),
        lessThan(1),
      );
      // 0,0005° de latitude ≈ 55 m ao lado da rua: fora da tolerância a pé.
      expect(
        GymRouteService.distanceToRouteMeters(
          const LatLng(-2.5295, -44.285),
          route,
        ),
        closeTo(55, 3),
      );
      // Além da ponta, mede até a ponta (e não até a reta infinita).
      expect(
        GymRouteService.distanceToRouteMeters(
          const LatLng(-2.53, -44.275),
          route,
        ),
        closeTo(556, 10),
      );
    });

    test('returns null when the server fails', () async {
      final service = GymRouteService(
        httpClient: MockClient((_) async => http.Response('erro', 503)),
      );
      addTearDown(service.dispose);

      expect(
        await service.fetchRoute(
          origin: const LatLng(0, 0),
          destination: const LatLng(0.01, 0.01),
          mode: GymRouteMode.driving,
        ),
        isNull,
      );
    });
  });
}
