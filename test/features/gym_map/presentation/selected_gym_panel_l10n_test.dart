import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/core/l10n/l10n.dart';
import 'package:gymmap/features/gym_map/domain/gym_models.dart';
import 'package:gymmap/features/gym_map/domain/plan_insight_models.dart';
import 'package:gymmap/features/gym_map/presentation/widgets/selected_gym_panel.dart';
import 'package:latlong2/latlong.dart';

/// Palavras que só aparecem se algum texto do painel ficou em português.
final RegExp _portuguese = RegExp(
  r'[çãõáéíóúâêô]|\b(academia|lotação|relatos?|musculação|aulas|aberta|'
  r'fechada|hoje|amanhã|pico|previsão|comparativo|contribuir|rota)\b',
  caseSensitive: false,
);

void main() {
  testWidgets('selected gym panel has no Portuguese text in English', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 10, 18, 18);
    // Academia vinda do mapa: nome, endereço e comodidades gravados pelo app.
    final gym = Gym(
      id: 'node-1',
      name: kUnnamedGymName,
      address: kMapGymAddress,
      position: const LatLng(-2.53, -44.28),
      capacity: 120,
      baseOccupancyPercent: 40,
      amenities: const [kAmenityWeights, kAmenityCardio, kAmenityGroupClasses],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: AppL10n.english,
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder:
            (context, child) =>
                AppL10nScope(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelectedGymPanel(
              gym: gym,
              snapshot: GymCrowdSnapshot(
                occupancyPercent: 55,
                reportsCount: 12,
                recentReportsCount: 3,
                lastReportAt: now.subtract(const Duration(minutes: 20)),
              ),
              isOpenNow: true,
              openStatusLabel: 'Open until 22h',
              openHoursLabel: 'Today: 06h - 22h',
              isFavorite: false,
              onToggleFavorite: () {},
              reportPercent: 50,
              onReportPercentChanged: (_) {},
              isSubmittingCrowdReport: false,
              onSubmitCrowdReport: () {},
              onOpenRoute: () {},
              onVerticalDragStart: (_) {},
              onVerticalDragUpdate: (_) {},
              onVerticalDragEnd: (_) {},
              onVerticalDragCancel: () {},
              hasHistoryInsights: true,
              hasProInsights: true,
              hasEliteInsights: true,
              historySampled: [
                for (var h = 0; h < 8; h++)
                  HourlyOccupancyPoint(
                    time: now.subtract(Duration(hours: 8 - h)),
                    occupancyPercent: 30 + h * 5,
                  ),
              ],
              peakWindow: const PeakWindowInsight(
                hour: 19,
                occupancyPercent: 80,
              ),
              comparison: const [
                GymComparisonInsight(
                  gymName: kUnnamedGymName,
                  occupancyPercent: 35,
                  deltaFromSelected: -20,
                ),
              ],
              forecast: [
                ForecastInsightPoint(
                  time: now.add(const Duration(hours: 1)),
                  occupancyPercent: 60,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final texts = <String>[
      for (final widget in tester.widgetList<Text>(find.byType(Text)))
        widget.data ?? widget.textSpan?.toPlainText() ?? '',
      // Comodidades são ícones; o nome fica no balão.
      for (final tooltip in tester.widgetList<Tooltip>(find.byType(Tooltip)))
        tooltip.message ?? '',
    ];
    final portuguese = texts.where(_portuguese.hasMatch).toList();

    expect(portuguese, isEmpty, reason: 'Textos em português: $portuguese');
    expect(find.byTooltip('Weight training'), findsOneWidget);
    expect(texts, contains('Gym'));
  });
}
