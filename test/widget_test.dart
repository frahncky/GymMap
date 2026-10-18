import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gymmap/core/l10n/l10n.dart';
import 'package:gymmap/features/gym_map/presentation/widgets/gym_page_sections.dart';
import 'package:gymmap/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    AppL10n.preference.value = AppLanguagePreference.system;
  });

  testWidgets('renders collaborative gym experience', (
    WidgetTester tester,
  ) async {
    AppL10n.preference.value = AppLanguagePreference.portuguese;
    await tester.pumpWidget(const MyApp(showMap: false));
    await tester.pump();
    await tester.pump();

    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.text('Mapa desativado no modo de teste'), findsOneWidget);
    expect(find.textContaining('Toque no marcador'), findsNothing);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.textContaining('Anúncio ·'), findsOneWidget);
    expect(find.text('Enviar relato colaborativo'), findsNothing);
  });

  testWidgets('renders in English when English is selected', (
    WidgetTester tester,
  ) async {
    AppL10n.preference.value = AppLanguagePreference.english;
    await tester.pumpWidget(const MyApp(showMap: false));
    await tester.pump();
    await tester.pump();

    expect(find.text('Map disabled in test mode'), findsOneWidget);
    expect(find.textContaining('Ad ·'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Map'),
      ),
      findsOneWidget,
    );
    expect(find.text('Profile'), findsOneWidget);
  });
}
