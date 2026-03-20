import '../domain/gym_models.dart';
import '../domain/plan_insight_models.dart';

class ReportSubmissionResult {
  const ReportSubmissionResult._({
    required this.accepted,
    this.retryAfter,
    this.appliedWeight,
  });

  factory ReportSubmissionResult.accepted(double appliedWeight) {
    return ReportSubmissionResult._(
      accepted: true,
      appliedWeight: appliedWeight,
    );
  }

  factory ReportSubmissionResult.rateLimited(Duration retryAfter) {
    return ReportSubmissionResult._(accepted: false, retryAfter: retryAfter);
  }

  final bool accepted;
  final Duration? retryAfter;
  final double? appliedWeight;
}

/// Serviço local em memória para simular backend colaborativo.
class CollaborativeCrowdService {
  CollaborativeCrowdService({
    Duration? cooldownWindow,
    int minDistinctReportersForSnapshot = 3,
    int voteTolerancePercent = 18,
  }) : _reports = [],
       _cooldownWindow = cooldownWindow ?? const Duration(minutes: 10),
       _reporterTrust = {},
       _minDistinctReportersForSnapshot =
           minDistinctReportersForSnapshot.clamp(1, 8).toInt(),
       _voteTolerancePercent = voteTolerancePercent.clamp(0, 40).toInt();

  factory CollaborativeCrowdService.withSeedData() {
    return CollaborativeCrowdService();
  }

  final List<CrowdReport> _reports;
  final Duration _cooldownWindow;
  final Map<String, double> _reporterTrust;
  final Set<String> _reportKeys = <String>{};
  final int _minDistinctReportersForSnapshot;
  final int _voteTolerancePercent;

  /// Registra um relato com anti-spam e peso por confiabilidade do usuário.
  ReportSubmissionResult submitReport({
    required Gym gym,
    required String reporterId,
    required int occupancyPercent,
  }) {
    final now = DateTime.now();
    final retryAfter = _remainingCooldown(
      gymId: gym.id,
      reporterId: reporterId,
      now: now,
    );
    if (retryAfter != null) {
      return ReportSubmissionResult.rateLimited(retryAfter);
    }

    final normalized = occupancyPercent.clamp(0, 100).toInt();
    final trust = _calculateReporterTrust(
      gym: gym,
      reporterId: reporterId,
      occupancyPercent: normalized,
    );
    _reporterTrust[reporterId] = trust;

    _reports.add(
      CrowdReport(
        gymId: gym.id,
        occupancyPercent: normalized,
        createdAt: now,
        reporterId: reporterId,
        reliabilityWeight: trust,
      ),
    );
    _reportKeys.add(
      _reportKey(
        gymId: gym.id,
        reporterId: reporterId,
        createdAt: now,
        occupancyPercent: normalized,
      ),
    );

    return ReportSubmissionResult.accepted(trust);
  }

  int mergeReports(Iterable<CrowdReport> incoming) {
    var inserted = 0;
    for (final report in incoming) {
      final key = _reportKey(
        gymId: report.gymId,
        reporterId: report.reporterId,
        createdAt: report.createdAt,
        occupancyPercent: report.occupancyPercent,
      );
      if (_reportKeys.contains(key)) {
        continue;
      }
      _reports.add(report);
      _reportKeys.add(key);
      inserted++;
    }
    return inserted;
  }

  /// Calcula o snapshot da academia usando dados colaborativos:
  /// 1) Prioriza relatos das últimas 2 horas.
  /// 2) Se não houver relatos recentes, usa até 4 relatos mais novos.
  /// 3) Sem consenso minimo de relatores distintos, usa o valor base.
  /// 4) Com consenso, aplica tolerancia para reduzir impacto de outliers.
  GymCrowdSnapshot snapshotFor(Gym gym) {
    final now = DateTime.now();
    final gymReports =
        _reports.where((report) => report.gymId == gym.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final recentReports =
        gymReports
            .where((report) => now.difference(report.createdAt).inHours < 2)
            .toList();

    final basis =
        recentReports.isEmpty ? gymReports.take(4).toList() : recentReports;

    final occupancy = _calculateAverageOccupancy(
      basis,
      gym.baseOccupancyPercent,
      minDistinctReporters: _minDistinctReportersForSnapshot,
      voteTolerancePercent: _voteTolerancePercent,
    );

    return GymCrowdSnapshot(
      occupancyPercent: occupancy,
      reportsCount: gymReports.length,
      recentReportsCount: recentReports.length,
      lastReportAt: gymReports.isEmpty ? null : gymReports.first.createdAt,
    );
  }

  /// Serie horaria das últimas 24h para habilitar o plano Smart+.
  List<HourlyOccupancyPoint> history24hFor(Gym gym, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    final currentHour = DateTime(
      refNow.year,
      refNow.month,
      refNow.day,
      refNow.hour,
    );

    return List.generate(24, (index) {
      final time = currentHour.subtract(Duration(hours: 23 - index));
      final hoursFromNow = refNow.difference(time).inHours;
      return HourlyOccupancyPoint(
        time: time,
        occupancyPercent: _estimateOccupancyAt(
          gym,
          time,
          hoursFromNow: hoursFromNow,
        ),
      );
    });
  }

  /// Detecta o pico do dia atual para habilitar o plano Pro+.
  PeakWindowInsight peakWindowForToday(Gym gym, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    PeakWindowInsight peak = const PeakWindowInsight(
      hour: 0,
      occupancyPercent: 0,
    );

    for (var hour = 0; hour < 24; hour++) {
      final time = DateTime(refNow.year, refNow.month, refNow.day, hour);
      final estimated = _estimateOccupancyAt(
        gym,
        time,
        hoursFromNow: refNow.difference(time).inHours,
      );
      if (estimated > peak.occupancyPercent) {
        peak = PeakWindowInsight(hour: hour, occupancyPercent: estimated);
      }
    }

    return peak;
  }

  /// Compara lotação atual estimada entre academias para habilitar Pro+.
  List<GymComparisonInsight> compareGymsByOccupancy(
    List<Gym> gyms,
    Gym selectedGym, {
    DateTime? now,
  }) {
    final refNow = now ?? DateTime.now();
    final selectedOccupancy = _estimateOccupancyAt(
      selectedGym,
      refNow,
      hoursFromNow: 0,
    );

    final rows =
        gyms.map((gym) {
            final occupancy = _estimateOccupancyAt(
              gym,
              refNow,
              hoursFromNow: 0,
            );
            return GymComparisonInsight(
              gymName: gym.name,
              occupancyPercent: occupancy,
              deltaFromSelected: occupancy - selectedOccupancy,
            );
          }).toList()
          ..sort((a, b) => a.occupancyPercent.compareTo(b.occupancyPercent));

    return rows;
  }

  /// Previsão das próximas horas para habilitar Elite.
  List<ForecastInsightPoint> forecastNextHoursFor(
    Gym gym, {
    int hours = 6,
    DateTime? now,
  }) {
    final refNow = now ?? DateTime.now();
    final currentHour = DateTime(
      refNow.year,
      refNow.month,
      refNow.day,
      refNow.hour,
    );

    return List.generate(hours, (index) {
      final ahead = index + 1;
      final time = currentHour.add(Duration(hours: ahead));
      return ForecastInsightPoint(
        time: time,
        occupancyPercent: _estimateOccupancyAt(gym, time, hoursFromNow: -ahead),
      );
    });
  }

  /// Alertas personalizados para Elite usando previsão + comparativo.
  List<String> personalizedAlertsFor({
    required Gym selectedGym,
    required List<Gym> gyms,
    DateTime? now,
  }) {
    final refNow = now ?? DateTime.now();
    final current = _estimateOccupancyAt(selectedGym, refNow, hoursFromNow: 0);
    final forecast = forecastNextHoursFor(selectedGym, now: refNow, hours: 6);
    final comparison =
        compareGymsByOccupancy(
          gyms,
          selectedGym,
          now: refNow,
        ).where((item) => item.gymName != selectedGym.name).toList();

    final alerts = <String>[];

    if (current >= 85) {
      alerts.add(
        'Lotação muito alta agora. Considere treinar em outro horário.',
      );
    }

    ForecastInsightPoint? bestFuture;
    for (final point in forecast) {
      if (bestFuture == null ||
          point.occupancyPercent < bestFuture.occupancyPercent) {
        bestFuture = point;
      }
    }

    if (bestFuture != null && bestFuture.occupancyPercent <= current - 12) {
      final hh = bestFuture.time.hour.toString().padLeft(2, '0');
      alerts.add(
        'Melhor janela prevista perto de ${hh}h (${bestFuture.occupancyPercent}%).',
      );
    }

    final betterGym = comparison.where((item) => item.deltaFromSelected <= -15);
    if (betterGym.isNotEmpty) {
      final best = betterGym.first;
      alerts.add(
        '${best.gymName} está ${best.deltaFromSelected.abs()} pp menos lotada agora.',
      );
    }

    if (alerts.isEmpty) {
      alerts.add('Fluxo estável nas próximas horas para esta academia.');
    }

    return alerts;
  }

  /// Calcula a media dos relatos e usa fallback sem consenso minimo.
  int _calculateAverageOccupancy(
    List<CrowdReport> basis,
    int fallback, {
    required int minDistinctReporters,
    required int voteTolerancePercent,
  }) {
    if (basis.isEmpty) {
      return fallback;
    }
    final uniqueReports = <CrowdReport>[];
    final reporterIds = <String>{};
    for (final report in basis) {
      final normalizedReporterId = _normalizedReporterId(report.reporterId);
      if (reporterIds.add(normalizedReporterId)) {
        uniqueReports.add(report);
      }
    }
    if (reporterIds.length < minDistinctReporters) {
      return fallback;
    }
    final sortedVotes =
        uniqueReports
            .map((report) => report.occupancyPercent.clamp(0, 100).toInt())
            .toList()
          ..sort();
    final medianVote = sortedVotes[sortedVotes.length ~/ 2];
    final minAllowed = (medianVote - voteTolerancePercent).clamp(0, 100);
    final maxAllowed = (medianVote + voteTolerancePercent).clamp(0, 100);

    final totalWeight = uniqueReports.fold<double>(
      0,
      (sum, report) =>
          sum + report.reliabilityWeight.clamp(0.2, 1.6).toDouble(),
    );
    if (totalWeight <= 0) {
      return fallback;
    }

    final weightedTotal = uniqueReports.fold<double>(
      0,
      (sum, report) {
        final boundedVote =
            report.occupancyPercent.clamp(minAllowed, maxAllowed).toDouble();
        final boundedWeight = report.reliabilityWeight.clamp(0.2, 1.6);
        return sum + (boundedVote * boundedWeight.toDouble());
      },
    );
    return (weightedTotal / totalWeight).round().clamp(0, 100);
  }

  String _normalizedReporterId(String reporterId) {
    final normalized = reporterId.trim().toLowerCase();
    return normalized.isEmpty ? 'anonymous' : normalized;
  }

  Duration? _remainingCooldown({
    required String gymId,
    required String reporterId,
    required DateTime now,
  }) {
    for (var index = _reports.length - 1; index >= 0; index--) {
      final report = _reports[index];
      if (report.gymId != gymId || report.reporterId != reporterId) {
        continue;
      }
      final elapsed = now.difference(report.createdAt);
      if (elapsed >= _cooldownWindow) {
        return null;
      }
      return _cooldownWindow - elapsed;
    }
    return null;
  }

  double _calculateReporterTrust({
    required Gym gym,
    required String reporterId,
    required int occupancyPercent,
  }) {
    final baseline = snapshotFor(gym).occupancyPercent;
    final delta = (occupancyPercent - baseline).abs();
    final previousTrust = _reporterTrust[reporterId] ?? 0.8;

    double adjustment;
    if (delta <= 12) {
      adjustment = 0.06;
    } else if (delta <= 25) {
      adjustment = 0.0;
    } else if (delta <= 38) {
      adjustment = -0.08;
    } else {
      adjustment = -0.14;
    }

    return (previousTrust + adjustment).clamp(0.35, 1.25).toDouble();
  }

  /// Estima lotação para um horário combinando:
  /// - valor base da academia;
  /// - perfil de horário/dia;
  /// - ruido deterministico por academia;
  /// - sinal recente dos relatos colaborativos.
  int _estimateOccupancyAt(
    Gym gym,
    DateTime timestamp, {
    required int hoursFromNow,
  }) {
    final recentSignal =
        snapshotFor(gym).occupancyPercent - gym.baseOccupancyPercent;
    final attenuation = (12 - hoursFromNow.abs()).clamp(0, 12);
    final blendedSignal = ((recentSignal * attenuation) / 12).round();

    final raw =
        gym.baseOccupancyPercent +
        _hourProfile(timestamp.hour) +
        _dayProfile(timestamp.weekday, timestamp.hour) +
        _noiseForHour(gym, timestamp) +
        blendedSignal;

    return raw.clamp(5, 98);
  }

  int _hourProfile(int hour) {
    if (hour >= 5 && hour <= 7) {
      return 8;
    }
    if (hour >= 8 && hour <= 10) {
      return 14;
    }
    if (hour >= 11 && hour <= 13) {
      return 6;
    }
    if (hour >= 17 && hour <= 21) {
      return 20;
    }
    if (hour >= 22 || hour <= 4) {
      return -18;
    }
    return -4;
  }

  int _dayProfile(int weekday, int hour) {
    final isWeekend =
        weekday == DateTime.saturday || weekday == DateTime.sunday;
    if (!isWeekend) {
      return 0;
    }
    if (hour >= 9 && hour <= 13) {
      return 10;
    }
    if (hour >= 18 && hour <= 21) {
      return -6;
    }
    return 2;
  }

  int _noiseForHour(Gym gym, DateTime timestamp) {
    final seed =
        gym.id.codeUnits.fold<int>(0, (sum, code) => sum + code) +
        timestamp.day * 17 +
        timestamp.hour * 31;
    return (seed % 11) - 5;
  }

  String _reportKey({
    required String gymId,
    required String reporterId,
    required DateTime createdAt,
    required int occupancyPercent,
  }) {
    return '$gymId|$reporterId|${createdAt.toUtc().millisecondsSinceEpoch}|$occupancyPercent';
  }
}
