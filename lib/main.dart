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
import 'core/theme/app_theme.dart';
import 'core/widgets/dialog_text_controllers.dart';
import 'features/gym_map/data/crowd_report_remote_service.dart';
import 'features/gym_map/data/gym_location_cache_service.dart';
import 'features/gym_map/domain/gym_models.dart';
import 'features/gym_map/presentation/gym_map_poi_controller.dart';
import 'features/gym_map/presentation/gym_map_page.dart';
import 'features/gym_map/presentation/widgets/gym_page_sections.dart'
    show BrandEmptyPin;

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
    final theme = buildAppTheme(
      primary: PlanThemePalette.colorFor(widget.initialPlanThemeTier),
      onPrimary: PlanThemePalette.onColorFor(widget.initialPlanThemeTier),
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
            theme: theme,
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

  ThemeData _themeForActivePlan() {
    return buildAppTheme(
      primary: _planThemeColor(_activePlanThemeTier),
      onPrimary: PlanThemePalette.onColorFor(_activePlanThemeTier),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themedData = _themeForActivePlan();
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
              for (final (name, label) in [
                ('nav_map', _t.navMap),
                ('nav_favorites', _t.navFavorites),
                ('nav_community', _t.navCommunity),
                ('nav_profile', _t.navProfile),
              ])
                NavigationDestination(
                  icon: _NavIcon(name),
                  // A aba ativa fica na cor do plano.
                  selectedIcon: _NavIcon(
                    '${name}_active_${_activePlanThemeTier.name}',
                  ),
                  label: label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícone da marca no menu inferior (tool/brand/gerar_marca.ps1): contorno
/// cinza na aba inativa, preenchido na cor do plano na ativa.
class _NavIcon extends StatelessWidget {
  const _NavIcon(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/$name.png',
      width: 26,
      height: 26,
      excludeFromSemantics: true,
    );
  }
}
