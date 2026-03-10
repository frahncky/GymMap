import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/analytics/app_metrics_service.dart';
import 'features/gym_map/data/crowd_report_remote_service.dart';
import 'features/gym_map/data/gym_location_cache_service.dart';
import 'features/gym_map/domain/gym_models.dart';
import 'features/gym_map/presentation/gym_map_poi_controller.dart';
import 'features/gym_map/presentation/gym_map_page.dart';

part 'main_favorites_page.dart';
part 'main_profile_page.dart';
part 'main_community_page.dart';

void main() {
  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key, this.showMap = true});

  final bool showMap;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B7A60),
    ).copyWith(
      primary: const Color(0xFF0D8B6E),
      secondary: const Color(0xFF2B8C77),
      surface: const Color(0xFFF4FBF8),
      onSurface: const Color(0xFF143F36),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GymMap',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: const Color(0xFFEAF5F1),
        fontFamily: 'Trebuchet MS',
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          hintStyle: const TextStyle(color: Color(0xFF6A887F)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE0ECE8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE0ECE8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: lightColorScheme.primary, width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: lightColorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 4.5,
          activeTrackColor: lightColorScheme.primary,
          inactiveTrackColor: const Color(0xFFDDECE6),
          thumbColor: lightColorScheme.primary,
          overlayColor: const Color(0x2E0D8B6E),
          valueIndicatorColor: lightColorScheme.primary,
          valueIndicatorTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: AppShell(
        showMap: widget.showMap,
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.showMap,
  });

  final bool showMap;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _favoritesRefreshToken = 0;
  AppPlanTier _activePlanThemeTier = AppPlanTier.free;
  final AppMetricsService _metrics = AppMetricsService.instance;

  @override
  void initState() {
    super.initState();
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

  Color _planThemeColor(AppPlanTier tier) {
    return switch (tier) {
      AppPlanTier.free => const Color(0xFF8E949C),
      AppPlanTier.smart => const Color(0xFF0D8B6E),
      AppPlanTier.pro => const Color(0xFF153A73),
      AppPlanTier.elite => const Color(0xFFC79A22),
    };
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
    final onPrimary =
        ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final scheme = baseTheme.colorScheme.copyWith(
      primary: primary,
      secondary: primary,
      onPrimary: onPrimary,
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: primary, width: 1.4),
    );
    return baseTheme.copyWith(
      colorScheme: scheme,
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        focusedBorder: focusedBorder,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: onPrimary,
          backgroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: primary,
        thumbColor: primary,
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
            return TextStyle(
              color: primary,
              fontWeight: FontWeight.w700,
            );
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
      ),
      _FavoritesPage(
        refreshToken: _favoritesRefreshToken,
        onOpenMap: _goToMapTab,
      ),
      _CommunityFeedPage(
        onContributeTap: _goToMapTab,
        isActive: _selectedIndex == 2,
      ),
      _ProfilePage(
        onOpenMap: _goToMapTab,
      ),
    ];

    return Theme(
      data: themedData,
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
            unawaited(_trackTabSelection(index: index, origin: 'navigation_bar'));
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Favoritos',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_2_outlined),
              selectedIcon: Icon(Icons.groups_2_rounded),
              label: 'Comunidade',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

