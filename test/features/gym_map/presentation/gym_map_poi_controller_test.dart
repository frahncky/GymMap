import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/features/gym_map/domain/gym_models.dart';
import 'package:gymmap/features/gym_map/presentation/gym_map_poi_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GymMapPoiController', () {
    test('parses common OpenStreetMap gym tags into POIs', () async {
      final controller = GymMapPoiController(
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['User-Agent'], 'gymmap/1.0');
          expect(request.body, contains('nwr["leisure"="fitness_centre"]'));
          expect(request.body, contains('nwr["sport"~'));
          expect(request.body, contains('out body center;'));

          return http.Response(
            jsonEncode(<String, Object?>{
              'elements': <Map<String, Object?>>[
                <String, Object?>{
                  'type': 'node',
                  'id': 1,
                  'lat': -10.01,
                  'lon': -50.01,
                  'tags': <String, String>{
                    'sport': 'fitness',
                    'name': 'Fit Center',
                  },
                },
                <String, Object?>{
                  'type': 'way',
                  'id': 2,
                  'center': <String, double>{'lat': -10.02, 'lon': -50.02},
                  'tags': <String, String>{'name': 'Academia Boa Forma'},
                },
                <String, Object?>{
                  'type': 'node',
                  'id': 3,
                  'lat': -10.03,
                  'lon': -50.03,
                  'tags': <String, String>{'name': 'Padaria Central'},
                },
              ],
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(controller.dispose);

      final pois = await controller.fetchOverpassPoisAround(
        center: const LatLng(-10.0, -50.0),
        knownGyms: const <Gym>[],
      );

      expect(pois, isNotNull);
      expect(
        pois!.map((poi) => poi.id),
        containsAll(<String>['node-1', 'way-2']),
      );
      expect(pois.map((poi) => poi.id), isNot(contains('node-3')));
    });
  });
}
