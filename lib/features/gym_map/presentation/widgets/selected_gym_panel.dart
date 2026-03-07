import 'package:flutter/material.dart';

import '../../domain/gym_models.dart';
import '../../domain/plan_insight_models.dart';
import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

class SelectedGymPanel extends StatelessWidget {
  const SelectedGymPanel({
    super.key,
    required this.gym,
    required this.snapshot,
    required this.reportPercent,
    required this.onReportPercentChanged,
    required this.onSubmitCrowdReport,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
    required this.hasHistoryInsights,
    required this.hasProInsights,
    required this.hasEliteInsights,
    required this.historySampled,
    this.peakWindow,
    this.comparison = const <GymComparisonInsight>[],
    this.forecast = const <ForecastInsightPoint>[],
    this.alerts = const <String>[],
  });

  final Gym gym;
  final GymCrowdSnapshot snapshot;
  final double reportPercent;
  final ValueChanged<double> onReportPercentChanged;
  final VoidCallback onSubmitCrowdReport;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final VoidCallback onVerticalDragCancel;
  final bool hasHistoryInsights;
  final bool hasProInsights;
  final bool hasEliteInsights;
  final List<HourlyOccupancyPoint> historySampled;
  final PeakWindowInsight? peakWindow;
  final List<GymComparisonInsight> comparison;
  final List<ForecastInsightPoint> forecast;
  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            color: GymMapColors.cardShadow,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: onVerticalDragStart,
              onVerticalDragUpdate: onVerticalDragUpdate,
              onVerticalDragEnd: onVerticalDragEnd,
              onVerticalDragCancel: onVerticalDragCancel,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 12),
                child: Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: GymMapColors.progressBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gym.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: GymMapColors.panelTitle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gym.address,
                        style: const TextStyle(
                          fontSize: 13,
                          color: GymMapColors.panelSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: withUiOpacity(
                      occupancyColor(snapshot.occupancyPercent),
                      0.16,
                    ),
                  ),
                  child: Text(
                    '${snapshot.occupancyPercent}%',
                    style: TextStyle(
                      color: occupancyColor(snapshot.occupancyPercent),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: snapshot.occupancyPercent / 100,
                color: occupancyColor(snapshot.occupancyPercent),
                backgroundColor: GymMapColors.progressBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${occupancyLabel(snapshot.occupancyPercent)}',
              style: const TextStyle(
                color: GymMapColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${snapshot.reportsCount} relatos totais | '
              '${snapshot.recentReportsCount} relatos recentes',
              style: const TextStyle(
                color: GymMapColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Último relato: ${formatRelativeTime(snapshot.lastReportAt)}',
              style: const TextStyle(
                color: GymMapColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasHistoryInsights && historySampled.isNotEmpty) ...[
              const SizedBox(height: 12),
              _HistoryInsightsCard(sampled: historySampled),
            ],
            if (hasProInsights && peakWindow != null) ...[
              const SizedBox(height: 12),
              _ProInsightsCard(peakWindow: peakWindow!, comparison: comparison),
            ],
            if (hasEliteInsights) ...[
              const SizedBox(height: 12),
              _EliteInsightsCard(forecast: forecast, alerts: alerts),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  gym.amenities
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: GymMapColors.chipBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item,
                            style: const TextStyle(
                              color: GymMapColors.tagText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              'Atualize a lotação desta academia',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: reportPercent,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${reportPercent.round()}%',
                    onChanged: onReportPercentChanged,
                  ),
                ),
                Container(
                  width: 56,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: GymMapColors.chipBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${reportPercent.round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: GymMapColors.valueChipText,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSubmitCrowdReport,
                icon: const Icon(Icons.send),
                label: const Text('Enviar relato colaborativo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryInsightsCard extends StatelessWidget {
  const _HistoryInsightsCard({required this.sampled});

  final List<HourlyOccupancyPoint> sampled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GymMapColors.insightPanelBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Histórico das últimas 24h',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: GymMapColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sampled.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final point = sampled[index];
                final barHeight = 12 + (point.occupancyPercent * 0.45);
                return SizedBox(
                  width: 34,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${point.occupancyPercent}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: GymMapColors.chartText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 14,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: occupancyColor(point.occupancyPercent),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hourTag(point.time),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: GymMapColors.chartText,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProInsightsCard extends StatelessWidget {
  const _ProInsightsCard({required this.peakWindow, required this.comparison});

  final PeakWindowInsight peakWindow;
  final List<GymComparisonInsight> comparison;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GymMapColors.insightPanelBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pico do dia: ${peakWindow.hour.toString().padLeft(2, '0')}h (${peakWindow.occupancyPercent}%)',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: GymMapColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Comparativo entre academias',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: GymMapColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...comparison.map((item) {
            final delta = item.deltaFromSelected;
            final deltaLabel =
                delta == 0 ? 'referencia' : '${delta > 0 ? '+' : ''}$delta pp';
            final deltaColor =
                delta <= -10
                    ? GymMapColors.occupancyLow
                    : delta >= 10
                    ? GymMapColors.occupancyCritical
                    : GymMapColors.comparisonNeutral;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.gymName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: GymMapColors.textStrong,
                      ),
                    ),
                  ),
                  Text(
                    '${item.occupancyPercent}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: GymMapColors.textStrong,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    deltaLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: deltaColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EliteInsightsCard extends StatelessWidget {
  const _EliteInsightsCard({required this.forecast, required this.alerts});

  final List<ForecastInsightPoint> forecast;
  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GymMapColors.insightPanelBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Previsao das próximas horas',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: GymMapColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                forecast
                    .map(
                      (point) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_hourTag(point.time)} ${point.occupancyPercent}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: GymMapColors.textStrong,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 10),
          const Text(
            'Alertas personalizados',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: GymMapColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...alerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.notification_important,
                      size: 16,
                      color: GymMapColors.alertIcon,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      alert,
                      style: const TextStyle(
                        color: GymMapColors.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _hourTag(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}h';
}
