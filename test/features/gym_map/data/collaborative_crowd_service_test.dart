import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:gymmap/features/gym_map/data/collaborative_crowd_service.dart';
import 'package:gymmap/features/gym_map/domain/gym_models.dart';

Gym _gymFixture({
  required String id,
  required String name,
  required double lat,
  required double lon,
}) {
  return Gym(
    id: id,
    name: name,
    address: 'Endereco $name',
    position: LatLng(lat, lon),
    amenities: const <String>['Musculacao'],
  );
}

CrowdReport _report(Gym gym, int percent, DateTime at, {required String by}) =>
    CrowdReport(
      gymId: gym.id,
      occupancyPercent: percent,
      createdAt: at,
      reporterId: by,
    );

void main() {
  final gymA = _gymFixture(
    id: 'gym_a',
    name: 'Gym A',
    lat: -23.56,
    lon: -46.65,
  );
  final gymB = _gymFixture(
    id: 'gym_b',
    name: 'Gym B',
    lat: -23.57,
    lon: -46.66,
  );
  final gymC = _gymFixture(
    id: 'gym_c',
    name: 'Gym C',
    lat: -23.58,
    lon: -46.67,
  );
  final gyms = <Gym>[gymA, gymB, gymC];

  group('CollaborativeCrowdService without reports invents nothing', () {
    final service = CollaborativeCrowdService();

    test('occupancy is unknown', () {
      expect(service.snapshotFor(gymA).occupancyPercent, isNull);
    });

    test('history, peak, forecast, comparison and alerts are empty', () {
      expect(service.history24hFor(gymA), isEmpty);
      expect(service.peakWindowForToday(gymA), isNull);
      expect(service.forecastNextHoursFor(gymA, hours: 6), isEmpty);
      expect(service.compareGymsByOccupancy(gyms, gymA), isEmpty);
      expect(
        service.personalizedAlertsFor(selectedGym: gymA, gyms: gyms),
        isEmpty,
      );
    });
  });

  group('CollaborativeCrowdService insights come from real reports', () {
    // 10h de hoje como referência, com relatos das últimas semanas.
    final now = DateTime(2026, 10, 19, 10, 30);
    final service = CollaborativeCrowdService();
    service.mergeReports(<CrowdReport>[
      // Últimas 24h: duas horas com relatos.
      _report(gymA, 40, DateTime(2026, 10, 19, 8, 10), by: 'u1'),
      _report(gymA, 60, DateTime(2026, 10, 19, 8, 40), by: 'u2'),
      _report(gymA, 70, DateTime(2026, 10, 18, 19, 5), by: 'u3'),
      // Padrão das semanas anteriores: 18h cheio, 12h vazio, 7h só um relato.
      _report(gymA, 90, DateTime(2026, 10, 12, 18, 0), by: 'u1'),
      _report(gymA, 80, DateTime(2026, 10, 5, 18, 0), by: 'u2'),
      _report(gymA, 20, DateTime(2026, 10, 12, 12, 0), by: 'u3'),
      _report(gymA, 30, DateTime(2026, 10, 5, 12, 0), by: 'u4'),
      _report(gymA, 99, DateTime(2026, 10, 12, 7, 0), by: 'u5'),
      // Fora da janela de 4 semanas: não conta.
      _report(gymA, 5, DateTime(2026, 8, 1, 13, 0), by: 'u6'),
      _report(gymA, 5, DateTime(2026, 8, 2, 13, 0), by: 'u7'),
    ]);

    test('history averages each hour of the last 24h that had reports', () {
      final history = service.history24hFor(gymA, now: now);

      expect(history.map((p) => p.time.hour), [19, 8]);
      expect(history.map((p) => p.occupancyPercent), [70, 50]);
    });

    test('peak is the busiest hour with at least 2 reports', () {
      final peak = service.peakWindowForToday(gymA, now: now);

      expect(peak, isNotNull);
      expect(peak!.hour, 18);
      expect(peak.occupancyPercent, 85);
    });

    test('forecast only includes hours with a pattern', () {
      final forecast = service.forecastNextHoursFor(gymA, hours: 9, now: now);

      expect(forecast.map((p) => p.time.hour), [12, 18]);
      expect(forecast.map((p) => p.occupancyPercent), [25, 85]);
    });

    test('comparison skips gyms without known occupancy', () {
      final withConsensus = CollaborativeCrowdService();
      final recent = DateTime.now();
      withConsensus.mergeReports(<CrowdReport>[
        for (final (gym, base) in <(Gym, int)>[(gymA, 60), (gymB, 30)])
          for (var i = 0; i < 3; i++)
            _report(gym, base + i, recent, by: '${gym.id}-$i'),
      ]);

      final rows = withConsensus.compareGymsByOccupancy(gyms, gymA);

      expect(rows.map((r) => r.gymName), ['Gym B', 'Gym A']);
      expect(rows.first.deltaFromSelected, -30);
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
    );

    test('single opinion keeps occupancy unknown', () {
      final service = CollaborativeCrowdService();

      final submit = service.submitReport(
        gym: gym,
        reporterId: 'u1',
        occupancyPercent: 82,
      );

      expect(submit.accepted, isTrue);
      expect(service.snapshotFor(gym).occupancyPercent, isNull);
    });

    test('two distinct reporters are still not enough', () {
      final service = CollaborativeCrowdService();

      service.submitReport(gym: gym, reporterId: 'u1', occupancyPercent: 80);
      service.submitReport(gym: gym, reporterId: 'u2', occupancyPercent: 84);

      expect(service.snapshotFor(gym).occupancyPercent, isNull);
    });

    test('three distinct reporters set the occupancy', () {
      final service = CollaborativeCrowdService();

      service.submitReport(gym: gym, reporterId: 'u1', occupancyPercent: 80);
      service.submitReport(gym: gym, reporterId: 'u2', occupancyPercent: 84);
      service.submitReport(gym: gym, reporterId: 'u3', occupancyPercent: 88);

      expect(
        service.snapshotFor(gym).occupancyPercent,
        inInclusiveRange(80, 88),
      );
    });

    test('tolerance reduces the impact of an outlier vote', () {
      final now = DateTime.now();
      final reports = <CrowdReport>[
        _report(gym, 50, now, by: 'u1'),
        _report(gym, 52, now, by: 'u2'),
        _report(gym, 95, now, by: 'u3'),
      ];

      final strictTolerance = CollaborativeCrowdService(
        voteTolerancePercent: 10,
      );
      final wideTolerance = CollaborativeCrowdService(voteTolerancePercent: 40);
      strictTolerance.mergeReports(reports);
      wideTolerance.mergeReports(reports);

      final strict = strictTolerance.snapshotFor(gym).occupancyPercent!;
      final wide = wideTolerance.snapshotFor(gym).occupancyPercent!;

      expect(strict, lessThan(wide));
      expect(strict, inInclusiveRange(45, 60));
      expect(wide, inInclusiveRange(60, 95));
    });

    test('reports older than 2 hours do not set the current occupancy', () {
      final old = DateTime.now().subtract(const Duration(hours: 3));
      final service =
          CollaborativeCrowdService()..mergeReports(<CrowdReport>[
            _report(gym, 90, old, by: 'u1'),
            _report(gym, 92, old, by: 'u2'),
            _report(gym, 94, old, by: 'u3'),
          ]);

      final snapshot = service.snapshotFor(gym);
      expect(snapshot.occupancyPercent, isNull);
      expect(snapshot.reportsCount, 3);
      expect(snapshot.recentReportsCount, 0);
    });

    test('multiple reports from same user do not satisfy consensus', () {
      final service = CollaborativeCrowdService(cooldownWindow: Duration.zero);

      service.submitReport(gym: gym, reporterId: 'u1', occupancyPercent: 78);
      service.submitReport(gym: gym, reporterId: 'u1', occupancyPercent: 82);
      service.submitReport(gym: gym, reporterId: 'u1', occupancyPercent: 86);

      expect(service.snapshotFor(gym).occupancyPercent, isNull);
    });
  });
}
