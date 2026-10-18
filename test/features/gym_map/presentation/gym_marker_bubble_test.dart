import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/core/l10n/l10n.dart';
import 'package:gymmap/features/gym_map/presentation/widgets/gym_marker_bubble.dart';

Future<void> _pumpBubble(
  WidgetTester tester, {
  required int? percent,
  required bool isOpenNow,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: AppL10n.portuguese,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder:
          (context, child) =>
              AppL10nScope(child: child ?? const SizedBox.shrink()),
      home: Center(
        child: GymMarkerBubble(
          label: 'Selfit',
          percent: percent,
          isOpenNow: isOpenNow,
          isFavorite: false,
          selected: false,
          revealDetails: true,
          enablePulse: false,
          onTap: () {},
        ),
      ),
    ),
  );
}

String _pinAsset(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return (image.image as AssetImage).assetName;
}

void main() {
  group('GymMarkerBubble pin', () {
    for (final (percent, asset) in <(int, String)>[
      (20, 'assets/brand/pin_low.png'),
      (50, 'assets/brand/pin_medium.png'),
      (80, 'assets/brand/pin_high.png'),
      (95, 'assets/brand/pin_full.png'),
    ]) {
      testWidgets('open at $percent% uses $asset', (tester) async {
        await _pumpBubble(tester, percent: percent, isOpenNow: true);

        expect(_pinAsset(tester), asset);
        expect(find.text('$percent%'), findsOneWidget);
        expect(find.byType(ColorFiltered), findsNothing);
      });
    }

    testWidgets('open without reports is the brand pin without a badge', (
      tester,
    ) async {
      await _pumpBubble(tester, percent: null, isOpenNow: true);

      expect(_pinAsset(tester), 'assets/brand/pin.png');
      expect(find.byType(ColorFiltered), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('closed is the gray brand pin without a badge', (tester) async {
      await _pumpBubble(tester, percent: 95, isOpenNow: false);

      expect(_pinAsset(tester), 'assets/brand/pin.png');
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.text('95%'), findsNothing);
    });
  });
}
