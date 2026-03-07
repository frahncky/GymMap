import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:gymmap/features/gym_map/data/collaborative_crowd_service.dart';
import 'package:gymmap/features/gym_map/domain/gym_models.dart';

Gym _gymFixture({
  required String id,
  required String name,
  required double lat,
  required double lon,
  int baseOccupancyPercent = 45,
}) {
  return Gym(
    id: id,
    name: name,
    address: 'Endereco $name',
    position: LatLng(lat, lon),
    capacity: 120,
    baseOccupancyPercent: baseOccupancyPercent,
    amenities: const <String>['Musculacao'],
  );
}

void main() {
  group('CollaborativeCrowdService insights', () {
    final service = CollaborativeCrowdService.withSeedData();
    final gyms = <Gym>[
      _gymFixture(
        id: 'gym_a',
        name: 'Gym A',
        lat: -23.5605,
        lon: -46.6558,
        baseOccupancyPercent: 52,
      ),
      _gymFixture(
        id: 'gym_b',
        name: 'Gym B',
        lat: -23.5612,
        lon: -46.6564,
        baseOccupancyPercent: 38,
      ),
      _gymFixture(
        id: 'gym_c',
        name: 'Gym C',
        lat: -23.5621,
        lon: -46.6572,
        baseOccupancyPercent: 61,
      ),
    ];
    final selectedGym = gyms.first;

    test('history24hFor returns 24 points with valid percentages', () {
      final history = service.history24hFor(selectedGym);

      expect(history.length, 24);
      for (final point in history) {
        expect(point.occupancyPercent, inInclusiveRange(0, 100));
      }
    });

    test('peakWindowForToday returns valid hour and percentage', () {
      final peak = service.peakWindowForToday(selectedGym);

      expect(peak.hour, inInclusiveRange(0, 23));
      expect(peak.occupancyPercent, inInclusiveRange(0, 100));
    });

    test('compareGymsByOccupancy returns rows for all gyms', () {
      final rows = service.compareGymsByOccupancy(gyms, selectedGym);

      expect(rows.length, gyms.length);
      expect(rows.any((row) => row.gymName == selectedGym.name), isTrue);
    });

    test('forecastNextHoursFor returns monotonic time points', () {
      final forecast = service.forecastNextHoursFor(selectedGym, hours: 6);

      expect(forecast.length, 6);
      for (var i = 1; i < forecast.length; i++) {
        expect(forecast[i].time.isAfter(forecast[i - 1].time), isTrue);
      }
    });

    test('personalizedAlertsFor returns at least one alert', () {
      final alerts = service.personalizedAlertsFor(
        selectedGym: selectedGym,
        gyms: gyms,
      );

      expect(alerts, isNotEmpty);
    });
  });

  group('CollaborativeCrowdService report protection', () {
    final gym = _gymFixture(
      id: 'gym_rate_limit',
      name: 'Gym Rate',
      lat: -23.5631,
      lon: -46.6581,
    );

    test('submitReport rate limits repeated submissions per user and gym', () {
      final service = CollaborativeCrowdService(
        cooldownWindow: const Duration(minutes: 10),
      );

      final first = service.submitReport(
        gym: gym,
        reporterId: 'u1',
        occupancyPercent: 55,
      );
      final second = service.submitReport(
        gym: gym,
        reporterId: 'u1',
        occupancyPercent: 56,
      );

      expect(first.accepted, isTrue);
      expect(first.appliedWeight, inInclusiveRange(0.35, 1.25));
      expect(second.accepted, isFalse);
      expect(second.retryAfter, isNotNull);
    });

    test('submitReport allows different users during cooldown window', () {
      final service = CollaborativeCrowdService(
        cooldownWindow: const Duration(minutes: 10),
      );

      final first = service.submitReport(
        gym: gym,
        reporterId: 'u1',
        occupancyPercent: 60,
      );
      final second = service.submitReport(
        gym: gym,
        reporterId: 'u2',
        occupancyPercent: 62,
      );

      expect(first.accepted, isTrue);
      expect(second.accepted, isTrue);
    });
  });
}
