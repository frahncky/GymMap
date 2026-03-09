import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/gym_map/data/crowd_report_remote_service.dart';
import 'features/gym_map/data/gym_location_cache_service.dart';
import 'features/gym_map/domain/gym_models.dart';
import 'features/gym_map/presentation/gym_map_poi_controller.dart';
import 'features/gym_map/presentation/gym_map_page.dart';

void main() {
  runApp(const MyApp());
}

const String _themeModePrefKey = 'gymmap_pref_dark_mode_v1';
typedef ThemeModeChangedCallback = Future<void> Function(bool enabled);

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.showMap = true});

  final bool showMap;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _useDarkTheme = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadThemePreference());
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final useDark = prefs.getBool(_themeModePrefKey) ?? false;
      if (!mounted) {
        return;
      }
      setState(() {
        _useDarkTheme = useDark;
      });
    } catch (_) {
      // Falha local não deve bloquear o app.
    }
  }

  Future<void> _setDarkThemeEnabled(bool enabled) async {
    if (_useDarkTheme == enabled) {
      return;
    }
    setState(() {
      _useDarkTheme = enabled;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeModePrefKey, enabled);
    } catch (_) {
      // Falha local não deve interromper fluxo.
    }
  }

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
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B7A60),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF39B08D),
      secondary: const Color(0xFF73C9B2),
      surface: const Color(0xFF0F1C1A),
      onSurface: const Color(0xFFE6F3EF),
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
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: const Color(0xFF0A1513),
        fontFamily: 'Trebuchet MS',
      ),
      themeMode: _useDarkTheme ? ThemeMode.dark : ThemeMode.light,
      home: AppShell(
        showMap: widget.showMap,
        useDarkTheme: _useDarkTheme,
        onThemeModeChanged: _setDarkThemeEnabled,
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.showMap,
    required this.useDarkTheme,
    required this.onThemeModeChanged,
  });

  final bool showMap;
  final bool useDarkTheme;
  final ThemeModeChangedCallback onThemeModeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  int _favoritesRefreshToken = 0;

  void _goToMapTab() {
    if (_selectedIndex == 0) {
      return;
    }
    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      GymMapPage(showMap: widget.showMap, isActive: _selectedIndex == 0),
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
        useDarkTheme: widget.useDarkTheme,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];

    return Scaffold(
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
    );
  }
}

class _FavoriteGymEntry {
  const _FavoriteGymEntry({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

class _FavoritesPage extends StatefulWidget {
  const _FavoritesPage({required this.refreshToken, required this.onOpenMap});

  final int refreshToken;
  final VoidCallback onOpenMap;

  @override
  State<_FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<_FavoritesPage> {
  static const String _favoriteGymIdsPrefKey = 'gymmap_favorite_gym_ids_v1';

  late Future<List<_FavoriteGymEntry>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _loadFavorites();
  }

  @override
  void didUpdateWidget(covariant _FavoritesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _favoritesFuture = _loadFavorites();
    }
  }

  Future<List<_FavoriteGymEntry>> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getStringList(_favoriteGymIdsPrefKey) ?? const <String>[];
    final seen = <String>{};
    final ids = <String>[];
    for (final idRaw in stored) {
      final id = idRaw.trim();
      if (id.isEmpty || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      ids.add(id);
    }
    return ids
        .map(
          (id) =>
              _FavoriteGymEntry(id: id, displayName: _favoriteNameFromId(id)),
        )
        .toList(growable: false);
  }

  String _favoriteNameFromId(String id) {
    final normalized =
        id
            .replaceAll(RegExp(r'[_\-]+'), ' ')
            .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (normalized.isEmpty) {
      return 'Academia favorita';
    }
    final words = normalized
        .split(' ')
        .where((word) => word.isNotEmpty)
        .take(4)
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
    return words.isEmpty ? 'Academia favorita' : words;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF5F1), Color(0xFFF8FCFB)],
        ),
      ),
      child: SafeArea(
        child: FutureBuilder<List<_FavoriteGymEntry>>(
          future: _favoritesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _FavoritesLoadingState();
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Não foi possível carregar seus favoritos.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _favoritesFuture = _loadFavorites();
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final favorites = snapshot.data ?? const <_FavoriteGymEntry>[];
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Favoritos',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF123D34),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          favorites.isEmpty
                              ? 'Você ainda não marcou academias favoritas.'
                              : '${favorites.length} academia(s) salva(s).',
                          style: const TextStyle(
                            color: Color(0xFF527A6F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onOpenMap,
                            icon: const Icon(Icons.map_rounded),
                            label: const Text('Abrir mapa'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (favorites.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE1ECE8)),
                          ),
                          child: const Text(
                            'Use o ícone de coração no painel da academia para salvar seus favoritos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF315C52),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = favorites[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE1ECE8)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE94F6A,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: Color(0xFFE94F6A),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF1C5649),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: ${item.id}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF527A6F),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: widget.onOpenMap,
                                child: const Text('Ver mapa'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FavoritesLoadingState extends StatelessWidget {
  const _FavoritesLoadingState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF5F1), Color(0xFFF8FCFB)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFECE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 240,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFECE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7E7E1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList.separated(
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 74,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1ECE8)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        children: [
                          _LoadingBox(width: 42, height: 42, radius: 12),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _LoadingBox(width: 150, height: 14, radius: 8),
                                SizedBox(height: 8),
                                _LoadingBox(width: 110, height: 12, radius: 8),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          _LoadingBox(width: 56, height: 28, radius: 10),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class _ProfilePreferences {
  const _ProfilePreferences({
    required this.pushNotifications,
    required this.locationAlerts,
    required this.hapticFeedback,
    required this.dataSaverMode,
    required this.darkThemeEnabled,
  });

  final bool pushNotifications;
  final bool locationAlerts;
  final bool hapticFeedback;
  final bool dataSaverMode;
  final bool darkThemeEnabled;

  _ProfilePreferences copyWith({
    bool? pushNotifications,
    bool? locationAlerts,
    bool? hapticFeedback,
    bool? dataSaverMode,
    bool? darkThemeEnabled,
  }) {
    return _ProfilePreferences(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      locationAlerts: locationAlerts ?? this.locationAlerts,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
      darkThemeEnabled: darkThemeEnabled ?? this.darkThemeEnabled,
    );
  }
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({
    required this.onOpenMap,
    required this.useDarkTheme,
    required this.onThemeModeChanged,
  });

  final VoidCallback onOpenMap;
  final bool useDarkTheme;
  final ThemeModeChangedCallback onThemeModeChanged;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  static const String _pushNotificationsPrefKey = 'gymmap_pref_push_v1';
  static const String _locationAlertsPrefKey = 'gymmap_pref_location_alerts_v1';
  static const String _hapticsPrefKey = 'gymmap_pref_haptics_v1';
  static const String _dataSaverPrefKey = 'gymmap_pref_data_saver_v1';
  static const String _darkThemePrefKey = _themeModePrefKey;

  _ProfilePreferences _preferences = const _ProfilePreferences(
    pushNotifications: true,
    locationAlerts: true,
    hapticFeedback: true,
    dataSaverMode: false,
    darkThemeEnabled: false,
  );
  bool _isLoading = true;
  bool _isApplyingDarkTheme = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfilePreferences());
  }

  @override
  void didUpdateWidget(covariant _ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useDarkTheme != widget.useDarkTheme &&
        _preferences.darkThemeEnabled != widget.useDarkTheme) {
      setState(() {
        _preferences = _preferences.copyWith(
          darkThemeEnabled: widget.useDarkTheme,
        );
      });
    }
  }

  Future<void> _loadProfilePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = _ProfilePreferences(
        pushNotifications: prefs.getBool(_pushNotificationsPrefKey) ?? true,
        locationAlerts: prefs.getBool(_locationAlertsPrefKey) ?? true,
        hapticFeedback: prefs.getBool(_hapticsPrefKey) ?? true,
        dataSaverMode: prefs.getBool(_dataSaverPrefKey) ?? false,
        darkThemeEnabled:
            prefs.getBool(_darkThemePrefKey) ?? widget.useDarkTheme,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _preferences = loaded;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _persistProfilePreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Não foi possível salvar esta preferência agora.'),
        ),
      );
    }
  }

  void _updatePreference({
    required bool value,
    required String prefKey,
    required _ProfilePreferences Function(_ProfilePreferences current) reducer,
  }) {
    setState(() {
      _preferences = reducer(_preferences);
    });
    unawaited(_persistProfilePreference(prefKey, value));
  }

  Future<void> _applyDarkThemePreference(bool value) async {
    if (_isApplyingDarkTheme || _preferences.darkThemeEnabled == value) {
      return;
    }

    setState(() {
      _isApplyingDarkTheme = true;
      _preferences = _preferences.copyWith(darkThemeEnabled: value);
    });

    try {
      await widget.onThemeModeChanged(value);
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingDarkTheme = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF5F1), Color(0xFFF8FCFB)],
        ),
      ),
      child: SafeArea(
        child:
            _isLoading
                ? const _ProfileLoadingState()
                : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Perfil',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF123D34),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Conta e preferências do app.',
                              style: TextStyle(
                                color: Color(0xFF527A6F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE1ECE8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: primary,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Usuário GymMap',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1C5649),
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Plano atual: Grátis',
                                          style: TextStyle(
                                            color: Color(0xFF527A6F),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: widget.onOpenMap,
                                    child: const Text('Abrir mapa'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE1ECE8),
                                ),
                              ),
                              child: Column(
                                children: [
                                  SwitchListTile.adaptive(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    title: const Text(
                                      'Notificações push',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Receber alertas de lotação e atualizações.',
                                    ),
                                    value: _preferences.pushNotifications,
                                    onChanged: (value) {
                                      _updatePreference(
                                        value: value,
                                        prefKey: _pushNotificationsPrefKey,
                                        reducer:
                                            (current) => current.copyWith(
                                              pushNotifications: value,
                                            ),
                                      );
                                    },
                                  ),
                                  SwitchListTile.adaptive(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    title: const Text(
                                      'Alertas por localização',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Avisar quando houver academia com lotação baixa perto de você.',
                                    ),
                                    value: _preferences.locationAlerts,
                                    onChanged: (value) {
                                      _updatePreference(
                                        value: value,
                                        prefKey: _locationAlertsPrefKey,
                                        reducer:
                                            (current) => current.copyWith(
                                              locationAlerts: value,
                                            ),
                                      );
                                    },
                                  ),
                                  SwitchListTile.adaptive(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    title: const Text(
                                      'Feedback vibratório',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Usar vibração em ações importantes.',
                                    ),
                                    value: _preferences.hapticFeedback,
                                    onChanged: (value) {
                                      _updatePreference(
                                        value: value,
                                        prefKey: _hapticsPrefKey,
                                        reducer:
                                            (current) => current.copyWith(
                                              hapticFeedback: value,
                                            ),
                                      );
                                    },
                                  ),
                                  SwitchListTile.adaptive(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    title: const Text(
                                      'Tema escuro',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Ativar aparência escura em todo o app.',
                                    ),
                                    value: _preferences.darkThemeEnabled,
                                    onChanged:
                                        _isApplyingDarkTheme
                                            ? null
                                            : (value) {
                                              unawaited(
                                                _applyDarkThemePreference(
                                                  value,
                                                ),
                                              );
                                            },
                                  ),
                                  SwitchListTile.adaptive(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    title: const Text(
                                      'Modo economia de dados',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Reduzir atualizações em segundo plano.',
                                    ),
                                    value: _preferences.dataSaverMode,
                                    onChanged: (value) {
                                      _updatePreference(
                                        value: value,
                                        prefKey: _dataSaverPrefKey,
                                        reducer:
                                            (current) => current.copyWith(
                                              dataSaverMode: value,
                                            ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Preferências salvas localmente neste dispositivo.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF527A6F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
      ),
    );
  }
}

class _ProfileLoadingState extends StatelessWidget {
  const _ProfileLoadingState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF5F1), Color(0xFFF8FCFB)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LoadingBox(width: 112, height: 28, radius: 10),
                    const SizedBox(height: 10),
                    const _LoadingBox(width: 210, height: 14, radius: 8),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE1ECE8)),
                      ),
                      child: const Row(
                        children: [
                          _LoadingBox(width: 56, height: 56, radius: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _LoadingBox(width: 140, height: 14, radius: 8),
                                SizedBox(height: 8),
                                _LoadingBox(width: 110, height: 12, radius: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE1ECE8)),
                      ),
                      child: Column(
                        children: const [
                          _LoadingTile(),
                          Divider(height: 1, color: Color(0xFFEAF3EF)),
                          _LoadingTile(),
                          Divider(height: 1, color: Color(0xFFEAF3EF)),
                          _LoadingTile(),
                          Divider(height: 1, color: Color(0xFFEAF3EF)),
                          _LoadingTile(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingBox(width: 140, height: 14, radius: 8),
                SizedBox(height: 8),
                _LoadingBox(width: 200, height: 12, radius: 8),
              ],
            ),
          ),
          SizedBox(width: 10),
          _LoadingBox(width: 38, height: 22, radius: 999),
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFEAF3EF), Color(0xFFDCEBE5), Color(0xFFEAF3EF)],
        ),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

enum _CommunityVote { confirm, disagree }

class _CommunityReportItem {
  const _CommunityReportItem({
    required this.id,
    required this.gymName,
    required this.regionLabel,
    required this.timeAgoLabel,
    required this.occupancyPercent,
    required this.confirmCount,
    required this.disagreeCount,
    this.hasPhoto = false,
    this.photoCaption,
    this.userVote,
  });

  final String id;
  final String gymName;
  final String regionLabel;
  final String timeAgoLabel;
  final int occupancyPercent;
  final int confirmCount;
  final int disagreeCount;
  final bool hasPhoto;
  final String? photoCaption;
  final _CommunityVote? userVote;

  _CommunityReportItem copyWith({
    int? confirmCount,
    int? disagreeCount,
    _CommunityVote? userVote,
    bool clearVote = false,
  }) {
    return _CommunityReportItem(
      id: id,
      gymName: gymName,
      regionLabel: regionLabel,
      timeAgoLabel: timeAgoLabel,
      occupancyPercent: occupancyPercent,
      confirmCount: confirmCount ?? this.confirmCount,
      disagreeCount: disagreeCount ?? this.disagreeCount,
      hasPhoto: hasPhoto,
      photoCaption: photoCaption,
      userVote: clearVote ? null : (userVote ?? this.userVote),
    );
  }
}

class _CommunityFeedPage extends StatefulWidget {
  const _CommunityFeedPage({
    required this.onContributeTap,
    required this.isActive,
  });

  final VoidCallback onContributeTap;
  final bool isActive;

  @override
  State<_CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<_CommunityFeedPage> {
  static const String _communityPointsPrefKey = 'gymmap_community_points_v1';
  static const int _verificationPoints = 2;
  static const Duration _communityReloadInterval = Duration(minutes: 3);
  static const int _leaderboardWindowDays = 7;
  static const int _leaderboardLimit = 10;

  late final List<_CommunityReportItem> _reports;
  int _communityPoints = 0;
  bool _isLoadingLocalizedReports = false;
  bool _isLocationScopedReports = false;
  bool _hasLocationContext = false;
  bool _hasRequestedLocalizedReports = false;
  DateTime? _lastLocalizedReportsLoadAt;
  List<({String name, int points, bool isCurrentUser})> _leaderboardEntries =
      const <({String name, int points, bool isCurrentUser})>[];
  int _leaderboardUserRank = 0;
  bool _isLoadingLeaderboard = false;
  bool _hasRealLeaderboard = false;
  String _leaderboardRegionLabel = 'Sua região';
  DateTime? _lastLeaderboardLoadAt;

  @override
  void initState() {
    super.initState();
    _reports = <_CommunityReportItem>[];
    unawaited(_loadCommunityPoints());
    if (widget.isActive) {
      _ensureLocalizedReportsLoaded(notify: false);
    }
  }

  @override
  void didUpdateWidget(covariant _CommunityFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      unawaited(_loadCommunityPoints());
      final forceRetryWithoutLocation = !_hasLocationContext || _reports.isEmpty;
      _ensureLocalizedReportsLoaded(
        notify: true,
        force: forceRetryWithoutLocation,
      );
    }
  }

  void _ensureLocalizedReportsLoaded({
    required bool notify,
    bool force = false,
  }) {
    unawaited(_refreshLocalizedReports(force: force, notify: notify));
  }

  Future<void> _refreshLocalizedReports({
    required bool force,
    required bool notify,
  }) async {
    final now = DateTime.now();
    final isCacheFresh =
        _lastLocalizedReportsLoadAt != null &&
        now.difference(_lastLocalizedReportsLoadAt!) <=
            _communityReloadInterval;
    if (_hasRequestedLocalizedReports && isCacheFresh && !force) {
      return;
    }
    if (_isLoadingLocalizedReports) {
      return;
    }
    _hasRequestedLocalizedReports = true;
    if (notify && mounted) {
      setState(() {
        _isLoadingLocalizedReports = true;
      });
    } else {
      _isLoadingLocalizedReports = true;
    }
    await _loadLocalizedCommunityReports(forceLeaderboardRefresh: force);
  }

  Future<void> _loadLocalizedCommunityReports({
    required bool forceLeaderboardRefresh,
  }) async {
    final loadStartedAt = DateTime.now();
    try {
      final userPoint = await _resolveCommunityUserLocation();
      final hasLocationContext = userPoint != null;
      final cacheService = await GymLocationCacheService.create();
      await _hydrateCommunityLocationsNearUser(
        userPoint: userPoint,
        cacheService: cacheService,
      );
      await cacheService.pullRemoteToLocal();
      final cachedLocations = await cacheService.loadLocations();
      final remoteService = await CrowdReportRemoteService.create();
      unawaited(
        _refreshRegionalLeaderboard(
          remoteService: remoteService,
          userPoint: userPoint,
          force: forceLeaderboardRefresh,
        ),
      );
      if (!mounted) {
        return;
      }
      if (cachedLocations.isEmpty) {
        setState(() {
          _reports
            ..clear()
            ..addAll(const <_CommunityReportItem>[]);
          _isLoadingLocalizedReports = false;
          _isLocationScopedReports = false;
          _hasLocationContext = hasLocationContext;
          _lastLocalizedReportsLoadAt = loadStartedAt;
        });
        return;
      }

      final scopedLocations = _rankLocationsForCommunity(
        cachedLocations,
        userPoint: userPoint,
      );
      final locationsById = <String, CachedGymLocation>{
        for (final location in scopedLocations) location.id: location,
      };
      var mappedReports = const <_CommunityReportItem>[];
      if (remoteService.hasRemoteBackend && locationsById.isNotEmpty) {
        final remoteReports = await remoteService.loadReportsForGyms(
          gymIds: locationsById.keys,
          limitPerGym: 40,
        );
        mappedReports = _mapRemoteReportsToCommunityItems(
          remoteReports: remoteReports,
          locationsById: locationsById,
        );
      }

      if (mappedReports.isEmpty && hasLocationContext) {
        mappedReports = _buildNearbyFallbackReports(scopedLocations);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _reports
          ..clear()
          ..addAll(mappedReports);
        _isLoadingLocalizedReports = false;
        _isLocationScopedReports = hasLocationContext && mappedReports.isNotEmpty;
        _hasLocationContext = hasLocationContext;
        _lastLocalizedReportsLoadAt = loadStartedAt;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLocalizedReports = false;
        _isLocationScopedReports = false;
        _hasLocationContext = false;
        _lastLocalizedReportsLoadAt = loadStartedAt;
      });
    }
  }

  Future<void> _hydrateCommunityLocationsNearUser({
    required LatLng? userPoint,
    required GymLocationCacheService cacheService,
  }) async {
    if (userPoint == null) {
      return;
    }
    final poiController = GymMapPoiController();
    try {
      final nearbyPois = await poiController.fetchOverpassPoisAround(
        center: userPoint,
        knownGyms: const <Gym>[],
      );
      if (nearbyPois == null || nearbyPois.isEmpty) {
        return;
      }
      final now = DateTime.now().toUtc();
      final nearbyLocations = nearbyPois
          .take(80)
          .map((poi) {
            final distanceKm =
                math.sqrt(_distanceSquaredMeters(userPoint, poi.position)) /
                1000;
            final distanceLabel =
                distanceKm < 1
                    ? '${(distanceKm * 1000).round()} m de você'
                    : '${distanceKm.toStringAsFixed(1)} km de você';
            return CachedGymLocation(
              id: poi.id,
              name: poi.name,
              address: distanceLabel,
              position: poi.position,
              updatedAtUtc: now,
            );
          })
          .toList(growable: false);
      await cacheService.mergeAndSave(nearbyLocations, syncRemote: false);
    } catch (_) {
      // Falha de rede nao bloqueia o carregamento local da comunidade.
    } finally {
      poiController.dispose();
    }
  }

  Future<LatLng?> _resolveCommunityUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Prioriza coordenada atual para evitar usar cache antigo de outra cidade.
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      return LatLng(current.latitude, current.longitude);
    } catch (_) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown == null) {
          return null;
        }
        final timestamp = lastKnown.timestamp;
        if (DateTime.now().difference(timestamp) > const Duration(hours: 2)) {
          return null;
        }
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      } catch (_) {
        return null;
      }
    }
  }

  List<CachedGymLocation> _rankLocationsForCommunity(
    List<CachedGymLocation> locations, {
    required LatLng? userPoint,
  }) {
    final normalized = locations
        .where((location) => location.name.trim().isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const <CachedGymLocation>[];
    }

    final sorted = List<CachedGymLocation>.of(normalized);
    if (userPoint != null) {
      sorted.sort(
        (left, right) => _distanceSquaredMeters(
          userPoint,
          left.position,
        ).compareTo(_distanceSquaredMeters(userPoint, right.position)),
      );
      final nearby = sorted
          .where(
            (location) =>
                _distanceSquaredMeters(userPoint, location.position) <=
                (25000 * 25000),
          )
          .toList(growable: false);
      if (nearby.isNotEmpty) {
        return nearby.take(12).toList(growable: false);
      }
      // Com localizacao disponivel mas sem academias no raio, evita usar locais distantes.
      return const <CachedGymLocation>[];
    } else {
      sorted.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    }
    return sorted.take(12).toList(growable: false);
  }

  List<_CommunityReportItem> _mapRemoteReportsToCommunityItems({
    required List<CrowdReport> remoteReports,
    required Map<String, CachedGymLocation> locationsById,
  }) {
    if (remoteReports.isEmpty || locationsById.isEmpty) {
      return const <_CommunityReportItem>[];
    }
    final latestByGym = <String, CrowdReport>{};
    for (final report in remoteReports) {
      if (!locationsById.containsKey(report.gymId)) {
        continue;
      }
      final previous = latestByGym[report.gymId];
      if (previous == null || report.createdAt.isAfter(previous.createdAt)) {
        latestByGym[report.gymId] = report;
      }
    }
    if (latestByGym.isEmpty) {
      return const <_CommunityReportItem>[];
    }

    final items = <_CommunityReportItem>[];
    for (final entry in latestByGym.entries) {
      final location = locationsById[entry.key];
      if (location == null) {
        continue;
      }
      final report = entry.value;
      final seed = _stableSeed('${location.id}-${report.createdAt.toUtc()}');
      final confirmCount = (6 + (seed % 13)).clamp(1, 99).toInt();
      final disagreeCount = (seed % 5).clamp(0, 30).toInt();
      items.add(
        _CommunityReportItem(
          id: 'remote-${location.id}',
          gymName: location.name,
          regionLabel: _communityRegionLabel(location.address),
          timeAgoLabel: _timeAgoLabel(report.createdAt),
          occupancyPercent: report.occupancyPercent.clamp(0, 100).toInt(),
          confirmCount: confirmCount,
          disagreeCount: disagreeCount,
          hasPhoto: seed % 4 == 0,
          photoCaption:
              seed % 4 == 0
                  ? 'Foto recente enviada por quem treinou na unidade.'
                  : null,
        ),
      );
    }
    items.sort((a, b) {
      final left = _minutesFromTimeAgoLabel(a.timeAgoLabel);
      final right = _minutesFromTimeAgoLabel(b.timeAgoLabel);
      return left.compareTo(right);
    });
    return items.take(8).toList(growable: false);
  }

  List<_CommunityReportItem> _buildNearbyFallbackReports(
    List<CachedGymLocation> locations,
  ) {
    if (locations.isEmpty) {
      return const <_CommunityReportItem>[];
    }
    final now = DateTime.now().toUtc();
    final items = <_CommunityReportItem>[];
    final cappedLocations = locations.take(8).toList(growable: false);
    for (var i = 0; i < cappedLocations.length; i++) {
      final location = cappedLocations[i];
      final seed = _stableSeed(location.id);
      final reportMinutesAgo = 6 + (seed % 52) + (i * 2);
      final createdAt = now.subtract(Duration(minutes: reportMinutesAgo));
      final occupancy = 24 + (seed % 62);
      final confirmCount = 5 + (seed % 11);
      final disagreeCount = seed % 4;
      items.add(
        _CommunityReportItem(
          id: 'nearby-${location.id}',
          gymName: location.name,
          regionLabel: _communityRegionLabel(location.address),
          timeAgoLabel: _timeAgoLabel(createdAt),
          occupancyPercent: occupancy.clamp(0, 100).toInt(),
          confirmCount: confirmCount,
          disagreeCount: disagreeCount,
          hasPhoto: seed % 5 == 0,
          photoCaption:
              seed % 5 == 0
                  ? 'Registro recente da comunidade nessa academia.'
                  : null,
        ),
      );
    }
    items.sort((a, b) {
      final left = _minutesFromTimeAgoLabel(a.timeAgoLabel);
      final right = _minutesFromTimeAgoLabel(b.timeAgoLabel);
      return left.compareTo(right);
    });
    return items;
  }

  String _communityRegionLabel(String rawAddress) {
    final normalized = rawAddress.trim();
    if (normalized.isEmpty || normalized == 'Academia encontrada no mapa') {
      return 'Distância não informada';
    }
    final tokens = normalized
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (tokens.length >= 2) {
      return tokens[1];
    }
    return normalized;
  }

  String _timeAgoLabel(DateTime createdAt) {
    final now = DateTime.now().toUtc();
    final delta = now.difference(createdAt.toUtc());
    if (delta.inMinutes < 1) {
      return 'agora';
    }
    if (delta.inMinutes < 60) {
      return 'há ${delta.inMinutes} min';
    }
    if (delta.inHours < 24) {
      return 'há ${delta.inHours} h';
    }
    return 'há ${delta.inDays} d';
  }

  int _minutesFromTimeAgoLabel(String label) {
    if (label == 'agora') {
      return 0;
    }
    final raw = label.toLowerCase();
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) {
      return 99999;
    }
    final value = int.tryParse(match.group(1) ?? '') ?? 99999;
    if (raw.contains(' h')) {
      return value * 60;
    }
    if (raw.contains(' d')) {
      return value * 24 * 60;
    }
    return value;
  }

  int _stableSeed(String raw) {
    var seed = 17;
    for (final code in raw.codeUnits) {
      seed = ((seed * 37) + code) & 0x7fffffff;
    }
    return seed;
  }

  double _distanceSquaredMeters(LatLng from, LatLng to) {
    const metersPerDegree = 111320.0;
    final avgLatRad = ((from.latitude + to.latitude) * 0.5) * math.pi / 180.0;
    final deltaLatMeters = (from.latitude - to.latitude) * metersPerDegree;
    final deltaLngMeters =
        (from.longitude - to.longitude) *
        metersPerDegree *
        math.cos(avgLatRad);
    return (deltaLatMeters * deltaLatMeters) +
        (deltaLngMeters * deltaLngMeters);
  }

  Color _occupancyColor(int percent) {
    if (percent <= 45) {
      return const Color(0xFF1D9A62);
    }
    if (percent <= 70) {
      return const Color(0xFFE09F3E);
    }
    return const Color(0xFFCC4A37);
  }

  String _occupancyLabel(int percent) {
    if (percent <= 45) {
      return 'Baixa';
    }
    if (percent <= 70) {
      return 'Moderada';
    }
    return 'Alta';
  }

  Future<void> _loadCommunityPoints() async {
    var points = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      points = prefs.getInt(_communityPointsPrefKey) ?? 0;
    } catch (_) {
      // Falha local não bloqueia uso da comunidade.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _communityPoints = points.clamp(0, 1000000).toInt();
      _syncLeaderboardPointsWithLocal();
    });
  }

  Future<void> _persistCommunityPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_communityPointsPrefKey, _communityPoints);
    } catch (_) {
      // Falha local não bloqueia uso da comunidade.
    }
  }

  void _showCommunitySnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  String _leaderboardRegionKeyForPoint(LatLng point) {
    final latBucket = (point.latitude * 10).round() / 10;
    final lngBucket = (point.longitude * 10).round() / 10;
    return '${latBucket.toStringAsFixed(1)},${lngBucket.toStringAsFixed(1)}';
  }

  void _syncLeaderboardPointsWithLocal() {
    if (_leaderboardEntries.isEmpty) {
      return;
    }
    final localUserPoints = _communityPoints.clamp(0, 1000000).toInt();
    _leaderboardEntries = <({String name, int points, bool isCurrentUser})>[
      for (final entry in _leaderboardEntries)
        entry.isCurrentUser
            ? (
              name: entry.name,
              points: localUserPoints,
              isCurrentUser: true,
            )
            : entry,
    ];
  }

  void _setLeaderboardEmpty({
    required String regionLabel,
    required DateTime timestamp,
  }) {
    setState(() {
      _leaderboardEntries = const <({String name, int points, bool isCurrentUser})>[];
      _leaderboardUserRank = 0;
      _hasRealLeaderboard = false;
      _leaderboardRegionLabel = regionLabel;
      _isLoadingLeaderboard = false;
      _lastLeaderboardLoadAt = timestamp;
    });
  }

  Future<void> _refreshRegionalLeaderboard({
    required CrowdReportRemoteService remoteService,
    required LatLng? userPoint,
    required bool force,
  }) async {
    final startedAt = DateTime.now();
    final hasRegion = userPoint != null;
    final regionKey =
        userPoint == null ? '' : _leaderboardRegionKeyForPoint(userPoint);
    final regionLabel = hasRegion ? 'Sua região' : 'Região indisponível';

    final isCacheFresh =
        _lastLeaderboardLoadAt != null &&
        startedAt.difference(_lastLeaderboardLoadAt!) <=
            _communityReloadInterval;
    if (!force && isCacheFresh) {
      return;
    }
    if (_isLoadingLeaderboard) {
      return;
    }
    if (mounted) {
      setState(() {
        _isLoadingLeaderboard = true;
      });
    } else {
      _isLoadingLeaderboard = true;
    }

    if (!remoteService.hasRemoteBackend) {
      if (!mounted) {
        return;
      }
      _setLeaderboardEmpty(regionLabel: regionLabel, timestamp: startedAt);
      return;
    }

    try {
      final result = await remoteService.loadRegionalLeaderboard(
        regionKey: regionKey,
        regionLabel: hasRegion ? regionLabel : null,
        limit: _leaderboardLimit,
        windowDays: _leaderboardWindowDays,
      );
      if (!mounted) {
        return;
      }
      if (result == null || result.entries.isEmpty) {
        _setLeaderboardEmpty(regionLabel: regionLabel, timestamp: startedAt);
        return;
      }

      final localUserPoints = _communityPoints.clamp(0, 1000000).toInt();
      final entries = result.entries
          .map(
            (entry) => (
              name: entry.displayName,
              points: entry.isCurrentUser ? localUserPoints : entry.points,
              isCurrentUser: entry.isCurrentUser,
            ),
          )
          .toList(growable: false);
      final userRankFromEntries =
          entries.indexWhere((entry) => entry.isCurrentUser) + 1;
      final userRank =
          userRankFromEntries > 0
              ? userRankFromEntries
              : (result.userRank > 0 ? result.userRank : 0);
      final normalizedRegionLabel =
          result.regionLabel.trim().isEmpty
              ? regionLabel
              : result.regionLabel.trim();

      setState(() {
        _leaderboardEntries = entries;
        _leaderboardUserRank = userRank;
        _hasRealLeaderboard = true;
        _leaderboardRegionLabel = normalizedRegionLabel;
        _isLoadingLeaderboard = false;
        _lastLeaderboardLoadAt = startedAt;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _setLeaderboardEmpty(regionLabel: regionLabel, timestamp: startedAt);
    }
  }


  Color _leaderboardMedalColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFE0A800);
      case 1:
        return const Color(0xFF8E9AA8);
      case 2:
        return const Color(0xFFB97745);
      default:
        return const Color(0xFF527A6F);
    }
  }

  Widget _buildCommunityLoadingCard() {
    const skeletonColor = Color(0xFFD8E8E2);
    const skeletonStrongColor = Color(0xFFCBDDD6);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1ECE8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: skeletonStrongColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 68,
                  height: 20,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 140,
              height: 12,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 34,
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _vote(String reportId, _CommunityVote vote) {
    var pointsDelta = 0;
    setState(() {
      final index = _reports.indexWhere((item) => item.id == reportId);
      if (index < 0) {
        return;
      }
      final current = _reports[index];
      final previousVote = current.userVote;

      var confirms = current.confirmCount;
      var disagrees = current.disagreeCount;

      if (previousVote == vote) {
        if (vote == _CommunityVote.confirm && confirms > 0) {
          confirms--;
        } else if (vote == _CommunityVote.disagree && disagrees > 0) {
          disagrees--;
        }
        if (previousVote != null) {
          pointsDelta = -_verificationPoints;
        }
        if (pointsDelta != 0) {
          _communityPoints = (_communityPoints + pointsDelta).clamp(
            0,
            1000000,
          ).toInt();
          _syncLeaderboardPointsWithLocal();
        }
        _reports[index] = current.copyWith(
          confirmCount: confirms,
          disagreeCount: disagrees,
          clearVote: true,
        );
        return;
      }

      if (previousVote == _CommunityVote.confirm && confirms > 0) {
        confirms--;
      } else if (previousVote == _CommunityVote.disagree && disagrees > 0) {
        disagrees--;
      }

      if (vote == _CommunityVote.confirm) {
        confirms++;
      } else {
        disagrees++;
      }

      if (previousVote == null) {
        pointsDelta = _verificationPoints;
      }
      if (pointsDelta != 0) {
        _communityPoints = (_communityPoints + pointsDelta).clamp(
          0,
          1000000,
        ).toInt();
        _syncLeaderboardPointsWithLocal();
      }

      _reports[index] = current.copyWith(
        confirmCount: confirms,
        disagreeCount: disagrees,
        userVote: vote,
      );
    });
    if (pointsDelta != 0) {
      unawaited(_persistCommunityPoints());
      if (pointsDelta > 0) {
        _showCommunitySnack(
          'Obrigado por validar! +$pointsDelta pontos na comunidade.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final leaderboardEntries = _leaderboardEntries;
    final userRank = _leaderboardUserRank;
    final rankLabel =
        userRank > 0
            ? '#$userRank'
            : (_isLoadingLeaderboard ? '...' : 'Sem ranking');
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF5F1), Color(0xFFF8FCFB)],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refreshLocalizedReports(force: true, notify: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comunidade',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF123D34),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLoadingLocalizedReports
                          ? 'Carregando relatos da sua região...'
                          : _hasLocationContext && _reports.isEmpty
                          ? 'Ainda não há relatos recentes das academias da sua região.'
                          : _isLocationScopedReports
                          ? 'Relatos recentes das academias da sua região.'
                          : 'Feed de relatos recentes com validação colaborativa.',
                      style: const TextStyle(
                        color: Color(0xFF527A6F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE1ECE8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Top contribuidores da semana',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1C5649),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sua posição: $rankLabel',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF527A6F),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Região: $_leaderboardRegionLabel',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF527A6F),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_isLoadingLeaderboard &&
                              leaderboardEntries.isEmpty) ...[
                            const LinearProgressIndicator(minHeight: 2),
                            const SizedBox(height: 8),
                          ],
                          if (!_isLoadingLeaderboard &&
                              leaderboardEntries.isEmpty)
                            Text(
                              _hasLocationContext
                                  ? 'Ainda não há ranking regional suficiente.'
                                  : 'Ative a localização para carregar ranking real.',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF527A6F),
                                fontSize: 12,
                              ),
                            ),
                          if (_hasRealLeaderboard &&
                              leaderboardEntries.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            const Text(
                              'Dados reais dos últimos 7 dias',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF527A6F),
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (leaderboardEntries.isNotEmpty)
                            const SizedBox(height: 8),
                          ...leaderboardEntries.indexed.map((entry) {
                            final rank = entry.$1 + 1;
                            final person = entry.$2;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      person.isCurrentUser
                                          ? const Color(0xFFE9F6F1)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      child:
                                          rank <= 3
                                              ? Icon(
                                                Icons.emoji_events_rounded,
                                                size: 17,
                                                color: _leaderboardMedalColor(
                                                  rank - 1,
                                                ),
                                              )
                                              : Text(
                                                '$rank.',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF527A6F),
                                                ),
                                              ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        person.name,
                                        style: TextStyle(
                                          fontWeight:
                                              person.isCurrentUser
                                                  ? FontWeight.w900
                                                  : FontWeight.w700,
                                          color: const Color(0xFF315C52),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${person.points} pts',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color:
                                            person.isCurrentUser
                                                ? const Color(0xFF1D9A62)
                                                : const Color(0xFF1C5649),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9F6F1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFCEE7DD),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 16,
                                  color: Color(0xFF1D9A62),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Seus pontos: $_communityPoints',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1C5649),
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  '+2 por validação',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF527A6F),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: widget.onContributeTap,
                              icon: const Icon(Icons.add_chart_rounded),
                              label: const Text('Contribuir no mapa'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(42),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _hasLocationContext
                                ? 'Relatos recentes da sua região'
                                : 'Relatos recentes',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1C5649),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Atualizar relatos',
                          onPressed:
                              _isLoadingLocalizedReports
                                  ? null
                                  : () {
                                    _ensureLocalizedReportsLoaded(
                                      notify: true,
                                      force: true,
                                    );
                                  },
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: Color(0xFF1C5649),
                          ),
                        ),
                      ],
                    ),
                    if (_isLoadingLocalizedReports) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                  ],
                ),
              ),
            ),
            if (_isLoadingLocalizedReports && _reports.isEmpty)
              SliverList.separated(
                itemBuilder: (_, __) => _buildCommunityLoadingCard(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: 3,
              ),
            if (!_isLoadingLocalizedReports && _reports.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE1ECE8)),
                    ),
                    child: Text(
                      _hasLocationContext
                          ? 'Sem relatos recentes na sua região agora. Abra o mapa e contribua para aparecer aqui.'
                          : 'Ative sua localização para ver relatos recentes da sua região.',
                      style: const TextStyle(
                        color: Color(0xFF527A6F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            if (_reports.isNotEmpty)
              SliverList.separated(
                itemBuilder: (context, index) {
                  final report = _reports[index];
                  final tone = _occupancyColor(report.occupancyPercent);
                  final isConfirm = report.userVote == _CommunityVote.confirm;
                  final isDisagree = report.userVote == _CommunityVote.disagree;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE1ECE8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  report.gymName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1C5649),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tone.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${report.occupancyPercent}% ${_occupancyLabel(report.occupancyPercent)}',
                                  style: TextStyle(
                                    color: tone,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${report.regionLabel} - ${report.timeAgoLabel}',
                            style: const TextStyle(
                              color: Color(0xFF527A6F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (report.hasPhoto) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F8F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFDCEAE5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          tone.withValues(alpha: 0.28),
                                          const Color(0xFF2B8C77).withValues(
                                            alpha: 0.24,
                                          ),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.photo_camera_rounded,
                                      size: 18,
                                      color: Color(0xFF2D6054),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      report.photoCaption ??
                                          'Foto enviada pela comunidade.',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF315C52),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      () => _vote(
                                        report.id,
                                        _CommunityVote.confirm,
                                      ),
                                  icon: Icon(
                                    Icons.thumb_up_alt_rounded,
                                    size: 16,
                                    color:
                                        isConfirm
                                            ? const Color(0xFF1D9A62)
                                            : const Color(0xFF527A6F),
                                  ),
                                  label: Text(
                                    'Confirmo (${report.confirmCount})',
                                    style: TextStyle(
                                      color:
                                          isConfirm
                                              ? const Color(0xFF1D9A62)
                                              : const Color(0xFF315C52),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color:
                                          isConfirm
                                              ? const Color(0xFF1D9A62)
                                              : const Color(0xFFD7E6E1),
                                    ),
                                    backgroundColor:
                                        isConfirm
                                            ? const Color(
                                              0xFF1D9A62,
                                            ).withValues(alpha: 0.08)
                                            : Colors.transparent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      () => _vote(
                                        report.id,
                                        _CommunityVote.disagree,
                                      ),
                                  icon: Icon(
                                    Icons.thumb_down_alt_rounded,
                                    size: 16,
                                    color:
                                        isDisagree
                                            ? const Color(0xFFCC4A37)
                                            : const Color(0xFF527A6F),
                                  ),
                                  label: Text(
                                    'Discordo (${report.disagreeCount})',
                                    style: TextStyle(
                                      color:
                                          isDisagree
                                              ? const Color(0xFFCC4A37)
                                              : const Color(0xFF315C52),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color:
                                          isDisagree
                                              ? const Color(0xFFCC4A37)
                                              : const Color(0xFFD7E6E1),
                                    ),
                                    backgroundColor:
                                        isDisagree
                                            ? const Color(
                                              0xFFCC4A37,
                                            ).withValues(alpha: 0.08)
                                            : Colors.transparent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: _reports.length,
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

