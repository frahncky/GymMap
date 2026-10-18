import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gymmap/core/l10n/l10n.dart';
import 'package:gymmap/main.dart';

/// Palavras e letras que só aparecem se algum texto ficou em português.
final RegExp _portuguese = RegExp(
  r'[çãõáéíóúâêô]|\b(academias?|lotação|relatos?|musculação|aulas|aberta|'
  r'fechada|hoje|amanhã|pico|previsão|comparativo|contribuir|rota|perfil|'
  r'favoritos?|comunidade|entrar|sair|plano|grátis|mapa|buscar|você|seus?|'
  r'sua|para|com|sem|ainda|agora|ativar|ative)\b',
  caseSensitive: false,
);

/// Textos visíveis na tela que parecem estar em português.
List<String> _portugueseTexts(WidgetTester tester) {
  final texts = <String>{
    for (final widget in tester.widgetList<Text>(find.byType(Text)))
      widget.data ?? widget.textSpan?.toPlainText() ?? '',
    for (final widget in tester.widgetList<RichText>(find.byType(RichText)))
      widget.text.toPlainText(),
  };
  return texts.where(_portuguese.hasMatch).toList()..sort();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppL10n.preference.value = AppLanguagePreference.english;
  });

  tearDown(() {
    AppL10n.preference.value = AppLanguagePreference.system;
  });

  testWidgets('every main screen is in English when English is selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp(showMap: false));
    await _settle(tester);

    final found = <String, List<String>>{};
    void check(String screen) {
      final portuguese = _portugueseTexts(tester);
      if (portuguese.isNotEmpty) found[screen] = portuguese;
    }

    check('Map');

    Future<void> closeOverlay() async {
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
    }

    for (final tab in ['Favorites', 'Community', 'Profile']) {
      await tester.tap(find.text(tab).last);
      await _settle(tester);
      check(tab);
    }

    // Janela de edição do perfil.
    await tester.tap(find.byTooltip('Edit profile').first);
    await _settle(tester);
    check('Edit profile');
    await tester.tap(find.text('Cancel').last);
    await _settle(tester);

    await tester.tap(find.text('Map').last);
    await _settle(tester);

    // Ranking da comunidade, aberto pelos pontos no cabeçalho.
    await tester.tap(find.byTooltip('Open community ranking').first);
    await _settle(tester);
    check('Community ranking');
    await closeOverlay();

    // Painel de planos e a janela de login.
    await tester.tap(find.byIcon(Icons.settings).first);
    await _settle(tester);
    check('Plans');
    final signIn = find.widgetWithText(OutlinedButton, 'Sign in');
    if (signIn.evaluate().isNotEmpty &&
        tester.widget<OutlinedButton>(signIn.first).onPressed != null) {
      await tester.tap(signIn.first);
      await _settle(tester);
      check('Sign in');
    }

    expect(found, isEmpty, reason: 'Português em inglês: $found');
  });
}
