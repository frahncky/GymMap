import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/gym_models.dart';
import '../../domain/plan_insight_models.dart';
import '../../../../core/l10n/l10n.dart';
import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

class SelectedGymPanel extends StatelessWidget {
  const SelectedGymPanel({
    super.key,
    required this.gym,
    required this.snapshot,
    this.distanceFromUserLabel,
    required this.isOpenNow,
    required this.openStatusLabel,
    required this.openHoursLabel,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.reportPercent,
    required this.onReportPercentChanged,
    required this.isSubmittingCrowdReport,
    required this.onSubmitCrowdReport,
    required this.onOpenRoute,
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
  final String? distanceFromUserLabel;
  final bool isOpenNow;
  final String openStatusLabel;
  final String openHoursLabel;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final double reportPercent;
  final ValueChanged<double> onReportPercentChanged;
  final bool isSubmittingCrowdReport;
  final VoidCallback onSubmitCrowdReport;
  final VoidCallback onOpenRoute;
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
    final primary = Theme.of(context).colorScheme.primary;
    final showOccupancy = isOpenNow;
    final targetOccupancy = snapshot.occupancyPercent.clamp(0, 100).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FCFA)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: withUiOpacity(primary, 0.10)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            color: GymMapColors.cardShadow,
            offset: Offset(0, 8),
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
                          color: withUiOpacity(primary, 0.25),
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
                        displayGymName(gym.name),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: GymMapColors.panelTitle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gym.address == kMapGymAddress
                            ? _t.gymFoundOnMap
                            : gym.address,
                        style: const TextStyle(
                          fontSize: 13,
                          color: GymMapColors.panelSubtitle,
                        ),
                      ),
                      if (distanceFromUserLabel != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.near_me_rounded,
                              size: 14,
                              color: GymMapColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distanceFromUserLabel!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: GymMapColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: withUiOpacity(
                                isOpenNow
                                    ? GymMapColors.occupancyLow
                                    : GymMapColors.occupancyCritical,
                                0.10,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: withUiOpacity(
                                  isOpenNow
                                      ? GymMapColors.occupancyLow
                                      : GymMapColors.occupancyCritical,
                                  0.24,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOpenNow
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.schedule_rounded,
                                  size: 13,
                                  color:
                                      isOpenNow
                                          ? GymMapColors.occupancyLow
                                          : GymMapColors.occupancyCritical,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  openStatusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isOpenNow
                                            ? GymMapColors.occupancyLow
                                            : GymMapColors.occupancyCritical,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: withUiOpacity(
                                GymMapColors.textSecondary,
                                0.08,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: withUiOpacity(
                                  GymMapColors.textSecondary,
                                  0.18,
                                ),
                              ),
                            ),
                            child: Text(
                              openHoursLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: GymMapColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  selected: isFavorite,
                  label:
                      isFavorite
                          ? _t.panelFavoriteGym
                          : _t.panelAddGymToFavorites,
                  hint: _t.panelToggleFavoriteHint,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip:
                          isFavorite
                              ? _t.panelRemoveFavorite
                              : _t.panelAddFavorite,
                      onPressed: onToggleFavorite,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.72,
                              end: 1,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          key: ValueKey<bool>(isFavorite),
                          color:
                              isFavorite
                                  ? GymMapColors.occupancyCritical
                                  : GymMapColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showOccupancy)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: targetOccupancy),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedOccupancy, _) {
                      final occupancyPercent = animatedOccupancy.round().clamp(
                        0,
                        100,
                      );
                      final occupancyAccent = occupancyColorForValue(
                        animatedOccupancy,
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: withUiOpacity(occupancyAccent, 0.14),
                          border: Border.all(
                            color: withUiOpacity(occupancyAccent, 0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                              color: withUiOpacity(occupancyAccent, 0.12),
                            ),
                          ],
                        ),
                        child: Text(
                          '$occupancyPercent%',
                          style: TextStyle(
                            color: occupancyAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: withUiOpacity(GymMapColors.textSecondary, 0.12),
                      border: Border.all(
                        color: withUiOpacity(GymMapColors.textSecondary, 0.22),
                      ),
                    ),
                    child: Text(
                      _t.gymClosed,
                      style: TextStyle(
                        color: GymMapColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (showOccupancy)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: targetOccupancy),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                builder: (context, animatedOccupancy, _) {
                  final occupancyPercent = animatedOccupancy.round().clamp(
                    0,
                    100,
                  );
                  final occupancyAccent = occupancyColorForValue(
                    animatedOccupancy,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          minHeight: 11,
                          value: occupancyPercent / 100,
                          color: occupancyAccent,
                          backgroundColor: GymMapColors.progressBackground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: Text(
                          _t.panelStatus(occupancyLabel(occupancyPercent)),
                          key: ValueKey<String>(
                            'occupancy-status-$occupancyPercent',
                          ),
                          style: const TextStyle(
                            color: GymMapColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: withUiOpacity(GymMapColors.textSecondary, 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _t.panelClosedNotice,
                  style: TextStyle(
                    color: GymMapColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _t.panelReportsSummary(
                '${snapshot.reportsCount}',
                '${snapshot.recentReportsCount}',
              ),
              style: const TextStyle(
                color: GymMapColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _t.panelLastReport(formatRelativeTime(snapshot.lastReportAt)),
              style: const TextStyle(
                color: GymMapColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenRoute,
                icon: const Icon(Icons.directions_rounded),
                label: Text(_t.panelViewRoute),
              ),
            ),
            if (showOccupancy &&
                hasHistoryInsights &&
                historySampled.isNotEmpty) ...[
              const SizedBox(height: 12),
              _HistoryInsightsCard(sampled: historySampled),
            ],
            if (showOccupancy && hasProInsights && peakWindow != null) ...[
              const SizedBox(height: 12),
              _ProInsightsCard(peakWindow: peakWindow!, comparison: comparison),
            ],
            if (showOccupancy && hasEliteInsights) ...[
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
            if (showOccupancy)
              Text(
                _t.panelUpdateOccupancy,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (showOccupancy)
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: reportPercent,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${reportPercent.round()}%',
                      onChanged:
                          isSubmittingCrowdReport
                              ? null
                              : onReportPercentChanged,
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
            if (showOccupancy)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      isSubmittingCrowdReport ? null : onSubmitCrowdReport,
                  icon:
                      isSubmittingCrowdReport
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send),
                  label: Text(
                    isSubmittingCrowdReport
                        ? _t.panelSendingReport
                        : _t.panelContribute,
                  ),
                ),
              ),
            if (!showOccupancy)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: withUiOpacity(GymMapColors.textSecondary, 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _t.panelContributeClosed,
                  style: TextStyle(
                    color: GymMapColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
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
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final chartHeight =
        ((viewportHeight * 0.19) + ((textScale - 1) * 28))
            .clamp(132.0, 192.0)
            .toDouble();
    final peakPoint = sampled.reduce(
      (current, next) =>
          next.occupancyPercent > current.occupancyPercent ? next : current,
    );
    final average =
        sampled.fold<int>(0, (total, point) => total + point.occupancyPercent) /
        sampled.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _insightCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t.insightHistory24h,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: GymMapColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChartStatChip(
                label: _t.chartPeak,
                value:
                    '${peakPoint.occupancyPercent}% ${_hourTag(peakPoint.time)}',
              ),
              _ChartStatChip(
                label: _t.chartAverage,
                value: '${average.round()}%',
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8, right: 8, bottom: 25),
                  child: _HistoryAxisLabels(),
                ),
                Expanded(child: _HistoryLineChart(sampled: sampled)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartStatChip extends StatelessWidget {
  const _ChartStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: withUiOpacity(Theme.of(context).colorScheme.primary, 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: GymMapColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: GymMapColors.textStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryAxisLabels extends StatelessWidget {
  const _HistoryAxisLabels();

  @override
  Widget build(BuildContext context) {
    const axisStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: GymMapColors.chartText,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: const [
        Text('100', style: axisStyle),
        Text('50', style: axisStyle),
        Text('0', style: axisStyle),
      ],
    );
  }
}

class _HistoryLineChart extends StatelessWidget {
  const _HistoryLineChart({required this.sampled});

  final List<HourlyOccupancyPoint> sampled;

  List<int> _labelIndexes() {
    if (sampled.length <= 1) {
      return const <int>[0];
    }
    if (sampled.length <= 4) {
      return List<int>.generate(sampled.length, (index) => index);
    }

    final raw = <int>[
      0,
      sampled.length ~/ 3,
      (sampled.length * 2) ~/ 3,
      sampled.length - 1,
    ];
    final deduplicated = <int>[];
    for (final index in raw) {
      if (!deduplicated.contains(index)) {
        deduplicated.add(index);
      }
    }
    return deduplicated;
  }

  @override
  Widget build(BuildContext context) {
    final values = sampled
        .map((point) => point.occupancyPercent.clamp(0, 100).toDouble())
        .toList(growable: false);
    final labelIndexes = _labelIndexes();

    return Column(
      children: [
        Expanded(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _HistoryLineChartPainter(
                values: values,
                lineColor: Theme.of(context).colorScheme.primary,
                gridColor: withUiOpacity(
                  Theme.of(context).colorScheme.primary,
                  0.10,
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final index in labelIndexes)
              Text(
                _hourTag(sampled[index].time),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: GymMapColors.chartText,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HistoryLineChartPainter extends CustomPainter {
  _HistoryLineChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    const topPadding = 8.0;
    const bottomPadding = 8.0;
    final chartRect = Rect.fromLTWH(
      0,
      topPadding,
      size.width,
      size.height - topPadding - bottomPadding,
    );

    final gridPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = gridColor;
    for (var index = 0; index < 3; index++) {
      final y = chartRect.top + (chartRect.height * index / 2);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final points = _buildPoints(chartRect);
    if (points.isEmpty) {
      return;
    }

    if (points.length > 1) {
      final curvePath = _buildSmoothPath(points);
      final areaPath =
          Path.from(curvePath)
            ..lineTo(points.last.dx, chartRect.bottom)
            ..lineTo(points.first.dx, chartRect.bottom)
            ..close();

      final areaPaint =
          Paint()
            ..style = PaintingStyle.fill
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                withUiOpacity(lineColor, 0.30),
                withUiOpacity(lineColor, 0.03),
              ],
            ).createShader(chartRect);
      canvas.drawPath(areaPath, areaPaint);

      final linePaint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true
            ..color = lineColor;
      canvas.drawPath(curvePath, linePaint);
    }

    final borderPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white;
    final pointPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = lineColor;
    for (final point in points) {
      canvas.drawCircle(point, 4.2, borderPaint);
      canvas.drawCircle(point, 2.7, pointPaint);
    }
  }

  List<Offset> _buildPoints(Rect rect) {
    if (values.isEmpty) {
      return const <Offset>[];
    }
    if (values.length == 1) {
      final normalized = (values.first / 100).clamp(0.0, 1.0);
      final y = rect.bottom - (rect.height * normalized);
      return <Offset>[Offset(rect.center.dx, y)];
    }

    final step = rect.width / math.max(1, values.length - 1);
    return List<Offset>.generate(values.length, (index) {
      final normalized = (values[index] / 100).clamp(0.0, 1.0);
      final x = rect.left + (step * index);
      final y = rect.bottom - (rect.height * normalized);
      return Offset(x, y);
    }, growable: false);
  }

  Path _buildSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final control1 = Offset((current.dx + next.dx) / 2, current.dy);
      final control2 = Offset((current.dx + next.dx) / 2, next.dy);
      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        next.dx,
        next.dy,
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _HistoryLineChartPainter oldDelegate) {
    if (oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor) {
      return true;
    }
    if (oldDelegate.values.length != values.length) {
      return true;
    }
    for (var index = 0; index < values.length; index++) {
      if (oldDelegate.values[index] != values[index]) {
        return true;
      }
    }
    return false;
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
      padding: const EdgeInsets.all(14),
      decoration: _insightCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t.panelPeakOfDay,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: GymMapColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${peakWindow.hour.toString().padLeft(2, '0')}h (${peakWindow.occupancyPercent}%)',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: GymMapColors.textStrong,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _t.insightCompareGyms,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: GymMapColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...comparison.map((item) {
            final delta = item.deltaFromSelected;
            final deltaLabel =
                delta == 0
                    ? _t.panelReference
                    : '${delta > 0 ? '+' : ''}$delta pp';
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
      padding: const EdgeInsets.all(14),
      decoration: _insightCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t.panelForecast,
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
          Text(
            _t.insightAlerts,
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

BoxDecoration _insightCardDecoration(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFAFCFB), GymMapColors.insightPanelBackground],
    ),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: withUiOpacity(primary, 0.10)),
  );
}

String _hourTag(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}h';
}

/// Traduções do idioma em uso.
AppLocalizations get _t => AppL10n.current;
