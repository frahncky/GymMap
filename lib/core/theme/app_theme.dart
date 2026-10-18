import 'package:flutter/material.dart';

/// Cores da marca, tiradas do símbolo (tool/brand/gymmap_symbol.svg).
class AppBrand {
  const AppBrand._();

  /// Azul-noite do centro do pino, do splash e do ícone.
  static const Color ink = Color(0xFF1B222B);
  static const Color inkText = Color(0xFF1F2730);

  /// Gradiente do anel do pino: azul, verde-água e verde.
  static const Color sky = Color(0xFF3FC6F0);
  static const Color teal = Color(0xFF22B7A8);
  static const Color lime = Color(0xFF7EDB5A);
  static const List<Color> gradient = <Color>[sky, teal, lime];

  /// Laranja da mochila; destaque pontual.
  static const Color orange = Color(0xFFEC6A2C);

  /// Versões escuras o bastante para texto e ícones sobre fundo claro.
  static const Color tealDeep = Color(0xFF13897E);
  static const Color orangeDeep = Color(0xFFC9501F);

  static const Color line = Color(0xFFE3E8EC);
}

/// Tema do app. A cor principal acompanha o plano ativo; o resto (tinta,
/// fonte, formas, snackbars, diálogos) é sempre o da marca.
ThemeData buildAppTheme({required Color primary, required Color onPrimary}) {
  final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    secondary: AppBrand.tealDeep,
    onSecondary: Colors.white,
    tertiary: AppBrand.orangeDeep,
    onTertiary: Colors.white,
    surface: Color.alphaBlend(primary.withValues(alpha: 0.05), Colors.white),
    onSurface: AppBrand.inkText,
    inverseSurface: AppBrand.ink,
    onInverseSurface: Colors.white,
    outlineVariant: AppBrand.line,
  );

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: primary.withValues(alpha: 0.18)),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  const buttonText = TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.1);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Color.alphaBlend(
      primary.withValues(alpha: 0.08),
      Colors.white,
    ),
    fontFamily: 'PlusJakartaSans',
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.1),
      bodyMedium: TextStyle(height: 1.28),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.56)),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        foregroundColor: onPrimary,
        backgroundColor: primary,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: buttonPadding,
        shape: buttonShape,
        side: BorderSide(color: primary.withValues(alpha: 0.32)),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: buttonShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4.5,
      activeTrackColor: primary,
      inactiveTrackColor: primary.withValues(alpha: 0.20),
      thumbColor: primary,
      overlayColor: primary.withValues(alpha: 0.18),
      valueIndicatorColor: primary,
      valueIndicatorTextStyle: TextStyle(
        color: onPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: primary.withValues(alpha: 0.14),
      circularTrackColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: AppBrand.line),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppBrand.ink,
      contentTextStyle: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: AppBrand.lime,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      iconColor: primary,
      titleTextStyle: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        color: AppBrand.inkText,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: AppBrand.ink.withValues(alpha: 0.18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppBrand.ink,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppBrand.line),
    // Menu inferior com os ícones da marca: a aba ativa fica no verde-água
    // da marca em qualquer plano.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppBrand.teal.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: AppBrand.tealDeep,
            fontWeight: FontWeight.w700,
          );
        }
        return const TextStyle(fontWeight: FontWeight.w500);
      }),
    ),
  );
}
