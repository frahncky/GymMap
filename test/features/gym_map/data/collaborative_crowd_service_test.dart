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

  group('CollaborativeCrowdService consensus threshold', () {
    final gym = _gymFixture(
      id: 'gym_consensus',
      name: 'Gym Consensus',
      lat: -23.5635,
      lon: -46.6588,
      baseOccupancyPercent: 45,
    );

    test('single opinion does not change snapshot occupancy', () {
      final service = CollaborativeCrowdService();
      final before = service.snapshotFor(gym);

      final submit = service.submitReport(
        gym: gym,
        reporterId: 'u1',
        occupancyPercent: 82,
      );
      final after = service.snapshotFor(gym);

      expect(submit.accepted, isTrue);
      expect(after.occupancyPercent, before.occupancyPercent);
      expect(after.occupancyPercent, gym.baseOccupancyPercent);
    });

    test('two distinct reporters are still not enough', () {
      final service = CollaborativeCrowdService();

      service.submitReport(gym: gym, reporterId: 'u1', occupancyPercent: 80);
      service.submitReport(gym: gym, reporterId: 'u2', occupancyPercent: 84);
      final snapshot = service.snapshotFor(gym);

      expect(snapshot.occupancyPercent, gym.baseOccupancyPercent);
    });

    test('three distinct reporters can change snapshot occupancy', () {
      final service = CollaborativeCrowdService();

      service.submitReport(gym: gym, reporterId: 'u1', occupancyPercent: 80);
      service.submitReport(gym: gym, reporterId: 'u2', occupancyPercent: 84);
      service.submitReport(gym: gym, reporterId: 'u3', occupancyPercent: 88);
      final snapshot = service.snapshotFor(gym);

      expect(snapshot.occupancyPercent, isNot(gym.baseOccupancyPercent));
      expect(snapshot.occupancyPercent, greaterThan(gym.baseOccupancyPercent));
    });

    test('tolerance reduces the impact of an outlier vote', () {
      final now = DateTime.now();
      final reports = <CrowdReport>[
        CrowdReport(
          gymId: gym.id,
          occupancyPercent: 50,
          createdAt: now,
          reporterId: 'u1',
        ),
        CrowdReport(
          gymId: gym.id,
          occupancyPercent: 52,
          createdAt: now,
          reporterId: 'u2',
        ),
        CrowdReport(
          gymId: gym.id,
          occupancyPercent: 95,
          createdAt: now,
          reporterId: 'u3',
        ),
      ];

      final strictTolerance = CollaborativeCrowdService(voteTolerancePercent: 10);
      final wideTolerance = CollaborativeCrowdService(voteTolerancePercent: 40);
      strictTolerance.mergeReports(reports);
      wideTolerance.mergeReports(reports);

      final strictSnapshot = strictTolerance.snapshotFor(gym);
      final wideSnapshot = wideTolerance.snapshotFor(gym);

      expect(strictSnapshot.occupancyPercent, lessThan(wideSnapshot.occupancyPercent));
      expect(strictSnapshot.occupancyPercent, inInclusiveRange(45, 60));
      expect(wideSnapshot.occupancyPercent, inInclusiveRange(60, 95));
    });

    test('multiple reports from same user do not satisfy consensus', () {
      final service = CollaborativeCrowdService(
        cooldownWindow: Duration.zero,
      );

      service.submitReport(gym: gym, reporterId: 'u1', occupancyPercent: 78);
      service.submitReport(gym: gym, reporterId: 'u1', occupancyPercent: 82);
      service.submitReport(gym: gym, reporterId: 'u1', occupancyPercent: 86);
      final snapshot = service.snapshotFor(gym);

      expect(snapshot.occupancyPercent, gym.baseOccupancyPercent);
    });
  });
}
