import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

/// Escolha de idioma feita no Perfil.
enum AppLanguagePreference { system, portuguese, english }

/// Idiomas do app. Português do Brasil é o idioma base: vale para qualquer
/// aparelho cujo idioma não seja inglês.
abstract final class AppL10n {
  static const Locale portuguese = Locale('pt', 'BR');
  static const Locale english = Locale('en');
  static const List<Locale> supportedLocales = <Locale>[portuguese, english];

  static const String _preferencePrefKey = 'gymmap_language_v1';

  /// Traduções do idioma em uso, para código sem [BuildContext] (serviços que
  /// montam mensagens exibidas na interface). Atualizado por [AppL10nScope].
  static AppLocalizations current = lookupAppLocalizations(portuguese);

  /// Preferência atual; o `MaterialApp` reconstrói quando ela muda.
  static final ValueNotifier<AppLanguagePreference> preference =
      ValueNotifier<AppLanguagePreference>(AppLanguagePreference.system);

  /// Locale fixo da preferência, ou `null` para seguir o aparelho.
  static Locale? get forcedLocale => switch (preference.value) {
    AppLanguagePreference.system => null,
    AppLanguagePreference.portuguese => portuguese,
    AppLanguagePreference.english => english,
  };

  static Future<void> loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_preferencePrefKey);
      preference.value = AppLanguagePreference.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => AppLanguagePreference.system,
      );
    } catch (_) {
      preference.value = AppLanguagePreference.system;
    }
  }

  static Future<void> setPreference(AppLanguagePreference value) async {
    preference.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferencePrefKey, value.name);
    } catch (_) {
      // A escolha vale para a sessão mesmo sem persistir.
    }
  }

  /// Inglês quando o primeiro idioma do aparelho é inglês; senão, português.
  static Locale resolve(List<Locale>? deviceLocales) {
    final Locale? first =
        deviceLocales == null || deviceLocales.isEmpty
            ? null
            : deviceLocales.first;
    return first?.languageCode == english.languageCode ? english : portuguese;
  }
}

extension AppL10nContext on BuildContext {
  /// Traduções do idioma em uso. Sem `AppLocalizations` na árvore (telas
  /// montadas isoladamente), usa [AppL10n.current].
  AppLocalizations get l10n => AppLocalizations.of(this) ?? AppL10n.current;
}

/// Mantém [AppL10n.current] igual ao idioma resolvido pelo `MaterialApp`.
class AppL10nScope extends StatelessWidget {
  const AppL10nScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations != null) AppL10n.current = localizations;
    return child;
  }
}
