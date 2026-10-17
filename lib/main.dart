import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/analytics/app_metrics_service.dart';
import 'core/l10n/l10n.dart';
import 'features/gym_map/data/crowd_report_remote_service.dart';
import 'features/gym_map/data/gym_location_cache_service.dart';
import 'features/gym_map/domain/gym_models.dart';
import 'features/gym_map/presentation/gym_map_poi_controller.dart';
import 'features/gym_map/presentation/gym_map_page.dart';

part 'main_favorites_page.dart';
part 'main_profile_page.dart';
part 'main_community_page.dart';

/// Traduções do idioma em uso (válido também depois de `await`).
AppLocalizations get _t => AppL10n.current;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await MobileAds.instance.initialize();
  } catch (_) {
    // Falha na inicialização de anúncios não bloqueia o app.
  }
  await AppL10n.loadPreference();
  final initialPlanThemeTier = await _readCachedPlanTier();
  runApp(MyApp(initialPlanThemeTier: initialPlanThemeTier));
}

const String _subscriptionActivePlanPrefKey = 'subscription.active_plan';
const String _subscriptionExpiresAtUtcPrefKey = 'subscription.expires_at_utc';

Future<AppPlanTier> _readCachedPlanTier() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final rawPlanKey =
        (prefs.getString(_subscriptionActivePlanPrefKey) ?? '').trim();
    final rawExpiresAt = prefs.getString(_subscriptionExpiresAtUtcPrefKey);
    final expiresAtUtc = DateTime.tryParse(rawExpiresAt ?? '')?.toUtc();
    final nowUtc = DateTime.now().toUtc();
    if (rawPlanKey.isNotEmpty &&
        rawPlanKey != AppPlanTier.free.name &&
        expiresAtUtc != null &&
        nowUtc.isAfter(expiresAtUtc)) {
      return AppPlanTier.free;
    }
    return _planTierFromStorage(rawPlanKey);
  } catch (_) {
    return AppPlanTier.free;
  }
}

AppPlanTier _planTierFromStorage(String rawPlanKey) {
  final normalized = rawPlanKey.trim().toLowerCase();
  for (final tier in AppPlanTier.values) {
    if (tier.name == normalized) {
      return tier;
    }
  }
  return AppPlanTier.free;
}

LinearGradient _buildPlanSurfaceGradient(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color.alphaBlend(primary.withValues(alpha: 0.14), Colors.white),
      Color.alphaBlend(primary.withValues(alpha: 0.03), Colors.white),
    ],
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.showMap = true,
    this.initialPlanThemeTier = AppPlanTier.free,
  });

  final bool showMap;
  final AppPlanTier initialPlanThemeTier;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final basePlanPrimary = PlanThemePalette.colorFor(
      widget.initialPlanThemeTier,
    );
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: basePlanPrimary,
    ).copyWith(
      primary: basePlanPrimary,
      secondary: basePlanPrimary,
      surface: Color.alphaBlend(
        basePlanPrimary.withValues(alpha: 0.05),
        Colors.white,
      ),
      onSurface: const Color(0xFF1F2730),
    );

    return ValueListenableBuilder<AppLanguagePreference>(
      valueListenable: AppL10n.preference,
      builder:
          (context, _, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'GymMap',
            locale: AppL10n.forcedLocale,
            supportedLocales: AppL10n.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            localeListResolutionCallback:
                (deviceLocales, _) => AppL10n.resolve(deviceLocales),
            builder:
                (context, child) =>
                    AppL10nScope(child: child ?? const SizedBox.shrink()),
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: lightColorScheme,
              scaffoldBackgroundColor: Color.alphaBlend(
                basePlanPrimary.withValues(alpha: 0.08),
                Colors.white,
              ),
              fontFamily: 'PlusJakartaSans',
              textTheme: const TextTheme(
                titleLarge: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
                titleMedium: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
                bodyMedium: TextStyle(height: 1.28),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                hintStyle: TextStyle(
                  color: lightColorScheme.onSurface.withValues(alpha: 0.56),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: lightColorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: lightColorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: lightColorScheme.primary,
                    width: 1.4,
                  ),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  foregroundColor: Colors.white,
                  backgroundColor: lightColorScheme.primary,
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              sliderTheme: SliderThemeData(
                trackHeight: 4.5,
                activeTrackColor: lightColorScheme.primary,
                inactiveTrackColor: lightColorScheme.primary.withValues(
                  alpha: 0.20,
                ),
                thumbColor: lightColorScheme.primary,
                overlayColor: lightColorScheme.primary.withValues(alpha: 0.18),
                valueIndicatorColor: lightColorScheme.primary,
                valueIndicatorTextStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            home: AppShell(
              showMap: widget.showMap,
              initialPlanThemeTier: widget.initialPlanThemeTier,
            ),
          ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.showMap,
    this.initialPlanThemeTier = AppPlanTier.free,
  });

  final bool showMap;
  final AppPlanTier initialPlanThemeTier;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _favoritesRefreshToken = 0;
  int _mapFocusRequestToken = 0;
  String? _mapFocusGymId;
  AppPlanTier _activePlanThemeTier = AppPlanTier.free;
  final AppMetricsService _metrics = AppMetricsService.instance;

  @override
  void initState() {
    super.initState();
    _activePlanThemeTier = widget.initialPlanThemeTier;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_metrics.startSession(source: 'app_start'));
    unawaited(_trackTabSelection(index: _selectedIndex, origin: 'app_start'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_metrics.startSession(source: 'resume'));
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_metrics.endSession(reason: state.name));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_metrics.endSession(reason: 'dispose'));
    super.dispose();
  }

  String _tabNameForIndex(int index) {
    return switch (index) {
      0 => 'mapa',
      1 => 'favoritos',
      2 => 'comunidade',
      3 => 'perfil',
      _ => 'desconhecida',
    };
  }

  Future<void> _trackTabSelection({
    required int index,
    required String origin,
  }) async {
    final tabName = _tabNameForIndex(index);
    await _metrics.trackEvent(
      'tab_selected',
      params: <String, Object?>{
        'index': index,
        'tab': tabName,
        'origin': origin,
      },
    );
    await _metrics.trackScreen(tabName);
  }

  void _goToMapTab() {
    if (_selectedIndex == 0) {
      return;
    }
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _openMapForGymId(String gymId) {
    final normalizedGymId = gymId.trim();
    if (normalizedGymId.isEmpty) {
      _goToMapTab();
      return;
    }
    setState(() {
      _selectedIndex = 0;
      _mapFocusGymId = normalizedGymId;
      _mapFocusRequestToken++;
    });
  }

  Color _planThemeColor(AppPlanTier tier) {
    return PlanThemePalette.colorFor(tier);
  }

  void _handleActivePlanThemeChanged(AppPlanTier tier) {
    if (_activePlanThemeTier == tier) {
      return;
    }
    setState(() {
      _activePlanThemeTier = tier;
    });
  }

  ThemeData _themeForActivePlan(BuildContext context) {
    final baseTheme = Theme.of(context);
    final primary = _planThemeColor(_activePlanThemeTier);
    final onPrimary = PlanThemePalette.onColorFor(_activePlanThemeTier);
    final scheme = baseTheme.colorScheme.copyWith(
      primary: primary,
      secondary: primary,
      onPrimary: onPrimary,
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: primary, width: 1.4),
    );
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: primary.withValues(alpha: 0.18)),
    );
    return baseTheme.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Color.alphaBlend(
        primary.withValues(alpha: 0.08),
        Colors.white,
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.56)),
        border: enabledBorder,
        enabledBorder: enabledBorder,
        focusedBorder: focusedBorder,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: onPrimary,
          backgroundColor: primary,
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.1),
        ),
      ),
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: primary,
        inactiveTrackColor: primary.withValues(alpha: 0.20),
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.18),
        valueIndicatorColor: primary,
      ),
      navigationBarTheme: baseTheme.navigationBarTheme.copyWith(
        indicatorColor: primary.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return null;
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: primary, fontWeight: FontWeight.w700);
          }
          return null;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themedData = _themeForActivePlan(context);
    final pages = <Widget>[
      GymMapPage(
        showMap: widget.showMap,
        isActive: _selectedIndex == 0,
        onActivePlanChanged: _handleActivePlanThemeChanged,
        focusGymId: _mapFocusGymId,
        focusRequestToken: _mapFocusRequestToken,
      ),
      _FavoritesPage(
        refreshToken: _favoritesRefreshToken,
        onOpenMap: _goToMapTab,
        onOpenGymOnMap: _openMapForGymId,
      ),
      _CommunityFeedPage(
        onContributeTap: _goToMapTab,
        isActive: _selectedIndex == 2,
      ),
      _ProfilePage(onOpenMap: _goToMapTab, activePlan: _activePlanThemeTier),
    ];

    // A aba do mapa tem cabeçalho escuro atrás da barra de status; as demais
    // têm fundo quase branco. Os ícones da barra acompanham o fundo.
    final isDarkTop = _selectedIndex == 0;
    final statusBarStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkTop ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkTop ? Brightness.dark : Brightness.light,
    );

    return Theme(
      data: themedData,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: statusBarStyle,
        child: Scaffold(
          body: IndexedStack(index: _selectedIndex, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
                if (index == 1) {
                  _favoritesRefreshToken++;
                }
              });
              unawaited(
                _trackTabSelection(index: index, origin: 'navigation_bar'),
              );
            },
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: _t.navMap,
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border_rounded),
                selectedIcon: Icon(Icons.favorite_rounded),
                label: _t.navFavorites,
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_2_outlined),
                selectedIcon: Icon(Icons.groups_2_rounded),
                label: _t.navCommunity,
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: _t.navProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
