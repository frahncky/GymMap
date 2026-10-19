import '../../../core/l10n/l10n.dart';
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

  // Padrão por hora do dia (pico e previsão): relatos das últimas 4
  // semanas, com pelo menos 2 relatos naquele horário.
  static const Duration _patternWindow = Duration(days: 28);
  static const int _minReportsPerPatternHour = 2;

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
  /// 1) Só valem relatos das últimas 2 horas: relato antigo não diz como a
  ///    academia está agora (ele continua no pico e na previsão por hora).
  /// 2) Sem consenso mínimo de relatores distintos, fica sem informação.
  /// 3) Com consenso, aplica tolerância para reduzir impacto de outliers.
  GymCrowdSnapshot snapshotFor(Gym gym) {
    final now = DateTime.now();
    final gymReports =
        _reports.where((report) => report.gymId == gym.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final recentReports =
        gymReports
            .where((report) => now.difference(report.createdAt).inHours < 2)
            .toList();

    return GymCrowdSnapshot(
      occupancyPercent: _calculateAverageOccupancy(
        recentReports,
        minDistinctReporters: _minDistinctReportersForSnapshot,
        voteTolerancePercent: _voteTolerancePercent,
      ),
      reportsCount: gymReports.length,
      recentReportsCount: recentReports.length,
      lastReportAt: gymReports.isEmpty ? null : gymReports.first.createdAt,
    );
  }

  /// Últimas 24h: média dos relatos de cada hora, só nas horas que tiveram
  /// relato (Essencial+).
  List<HourlyOccupancyPoint> history24hFor(Gym gym, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    final start = DateTime(
      refNow.year,
      refNow.month,
      refNow.day,
      refNow.hour,
    ).subtract(const Duration(hours: 23));
    final byHour = <DateTime, List<int>>{};
    for (final report in _reports) {
      if (report.gymId != gym.id) {
        continue;
      }
      final local = report.createdAt.toLocal();
      if (local.isBefore(start) || local.isAfter(refNow)) {
        continue;
      }
      final slot = DateTime(local.year, local.month, local.day, local.hour);
      byHour.putIfAbsent(slot, () => <int>[]).add(report.occupancyPercent);
    }
    final slots = byHour.keys.toList()..sort();
    return <HourlyOccupancyPoint>[
      for (final slot in slots)
        HourlyOccupancyPoint(
          time: slot,
          occupancyPercent: _mean(byHour[slot]!),
        ),
    ];
  }

  /// Horário mais cheio pelos relatos das últimas semanas (Pro+), ou `null`
  /// sem relatos suficientes.
  PeakWindowInsight? peakWindowForToday(Gym gym, {DateTime? now}) {
    final pattern = _hourlyPattern(gym, now ?? DateTime.now());
    if (pattern.isEmpty) {
      return null;
    }
    final peak = pattern.entries.reduce(
      (best, entry) => entry.value > best.value ? entry : best,
    );
    return PeakWindowInsight(hour: peak.key, occupancyPercent: peak.value);
  }

  /// Compara a lotação atual entre academias que têm relatos (Pro+). Sem
  /// lotação conhecida na academia escolhida, não há comparação.
  List<GymComparisonInsight> compareGymsByOccupancy(
    List<Gym> gyms,
    Gym selectedGym, {
    DateTime? now,
  }) {
    final selectedOccupancy = snapshotFor(selectedGym).occupancyPercent;
    if (selectedOccupancy == null) {
      return const <GymComparisonInsight>[];
    }
    final rows = <GymComparisonInsight>[
      for (final gym in gyms)
        if (snapshotFor(gym).occupancyPercent case final occupancy?)
          GymComparisonInsight(
            gymName: gym.name,
            occupancyPercent: occupancy,
            deltaFromSelected: occupancy - selectedOccupancy,
          ),
    ]..sort((a, b) => a.occupancyPercent.compareTo(b.occupancyPercent));
    return rows;
  }

  /// Próximas horas pela média dos relatos daquele horário nas últimas
  /// semanas (Elite); horas sem relatos suficientes ficam de fora.
  List<ForecastInsightPoint> forecastNextHoursFor(
    Gym gym, {
    int hours = 6,
    DateTime? now,
  }) {
    final refNow = now ?? DateTime.now();
    final pattern = _hourlyPattern(gym, refNow);
    final currentHour = DateTime(
      refNow.year,
      refNow.month,
      refNow.day,
      refNow.hour,
    );
    return <ForecastInsightPoint>[
      for (var ahead = 1; ahead <= hours; ahead++)
        if (pattern[currentHour.add(Duration(hours: ahead)).hour]
            case final occupancy?)
          ForecastInsightPoint(
            time: currentHour.add(Duration(hours: ahead)),
            occupancyPercent: occupancy,
          ),
    ];
  }

  /// Alertas para o Elite, só a partir de dados reais. Sem dados, nenhum.
  List<String> personalizedAlertsFor({
    required Gym selectedGym,
    required List<Gym> gyms,
    DateTime? now,
  }) {
    final refNow = now ?? DateTime.now();
    final current = snapshotFor(selectedGym).occupancyPercent;
    final forecast = forecastNextHoursFor(selectedGym, now: refNow, hours: 6);
    final comparison =
        compareGymsByOccupancy(
          gyms,
          selectedGym,
          now: refNow,
        ).where((item) => item.gymName != selectedGym.name).toList();

    final alerts = <String>[];
    if (current == null) {
      return alerts;
    }

    if (current >= 85) {
      alerts.add(AppL10n.current.alertVeryHighNow);
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
        AppL10n.current.alertBestWindow(hh, '${bestFuture.occupancyPercent}'),
      );
    }

    final betterGym = comparison.where((item) => item.deltaFromSelected <= -15);
    if (betterGym.isNotEmpty) {
      final best = betterGym.first;
      alerts.add(
        AppL10n.current.alertLessCrowded(
          best.gymName,
          '${best.deltaFromSelected.abs()}',
        ),
      );
    }

    if (alerts.isEmpty) {
      alerts.add(AppL10n.current.alertStableFlow);
    }

    return alerts;
  }

  /// Média por hora do dia dos relatos das últimas 4 semanas; só horas com
  /// pelo menos [_minReportsPerPatternHour] relatos.
  Map<int, int> _hourlyPattern(Gym gym, DateTime refNow) {
    final since = refNow.subtract(_patternWindow);
    final byHour = <int, List<int>>{};
    for (final report in _reports) {
      if (report.gymId != gym.id) {
        continue;
      }
      final local = report.createdAt.toLocal();
      if (local.isBefore(since) || local.isAfter(refNow)) {
        continue;
      }
      byHour
          .putIfAbsent(local.hour, () => <int>[])
          .add(report.occupancyPercent);
    }
    return <int, int>{
      for (final entry in byHour.entries)
        if (entry.value.length >= _minReportsPerPatternHour)
          entry.key: _mean(entry.value),
    };
  }

  static int _mean(List<int> values) =>
      (values.reduce((a, b) => a + b) / values.length).round().clamp(0, 100);

  /// Média ponderada dos relatos, ou `null` sem consenso mínimo.
  int? _calculateAverageOccupancy(
    List<CrowdReport> basis, {
    required int minDistinctReporters,
    required int voteTolerancePercent,
  }) {
    if (basis.isEmpty) {
      return null;
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
      return null;
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
      return null;
    }

    final weightedTotal = uniqueReports.fold<double>(0, (sum, report) {
      final boundedVote =
          report.occupancyPercent.clamp(minAllowed, maxAllowed).toDouble();
      final boundedWeight = report.reliabilityWeight.clamp(0.2, 1.6);
      return sum + (boundedVote * boundedWeight.toDouble());
    });
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
    final previousTrust = _reporterTrust[reporterId] ?? 0.8;
    // Sem consenso ainda, não há com o que comparar o relato.
    if (baseline == null) {
      return previousTrust;
    }
    final delta = (occupancyPercent - baseline).abs();

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

  String _reportKey({
    required String gymId,
    required String reporterId,
    required DateTime createdAt,
    required int occupancyPercent,
  }) {
    return '$gymId|$reporterId|${createdAt.toUtc().millisecondsSinceEpoch}|$occupancyPercent';
  }
}
