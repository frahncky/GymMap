import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/gym_map/presentation/gym_map_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.showMap = true});

  final bool showMap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
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
        colorScheme: colorScheme,
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
            borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: colorScheme.primary,
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
          activeTrackColor: colorScheme.primary,
          inactiveTrackColor: const Color(0xFFDDECE6),
          thumbColor: colorScheme.primary,
          overlayColor: const Color(0x2E0D8B6E),
          valueIndicatorColor: colorScheme.primary,
          valueIndicatorTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: AppShell(showMap: showMap),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.showMap});

  final bool showMap;

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
      GymMapPage(showMap: widget.showMap),
      _FavoritesPage(
        refreshToken: _favoritesRefreshToken,
        onOpenMap: _goToMapTab,
      ),
      _CommunityFeedPage(onContributeTap: _goToMapTab),
      _ShellPlaceholderPage(
        icon: Icons.person_rounded,
        title: 'Perfil',
        subtitle:
            'Gerencie sua conta, preferências e assinatura em um espaco dedicado.',
        tone: const Color(0xFF3B82F6),
        bullets: const <String>[
          'Dados da conta e seguranca',
          'Plano ativo e historico de assinatura',
          'Preferencias de notificacoes',
        ],
        ctaLabel: 'Abrir mapa',
        onPressed: _goToMapTab,
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
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Nao foi possivel carregar seus favoritos.',
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
                              ? 'Voce ainda nao marcou academias favoritas.'
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
                            'Use o icone de coracao no painel da academia para salvar seus favoritos.',
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
    this.userVote,
  });

  final String id;
  final String gymName;
  final String regionLabel;
  final String timeAgoLabel;
  final int occupancyPercent;
  final int confirmCount;
  final int disagreeCount;
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
      userVote: clearVote ? null : (userVote ?? this.userVote),
    );
  }
}

class _CommunityFeedPage extends StatefulWidget {
  const _CommunityFeedPage({required this.onContributeTap});

  final VoidCallback onContributeTap;

  @override
  State<_CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<_CommunityFeedPage> {
  static const List<_CommunityReportItem> _seedReports = <_CommunityReportItem>[
    _CommunityReportItem(
      id: 'report-1',
      gymName: 'UltraFit Paulista',
      regionLabel: 'Bela Vista',
      timeAgoLabel: 'ha 9 min',
      occupancyPercent: 38,
      confirmCount: 14,
      disagreeCount: 2,
    ),
    _CommunityReportItem(
      id: 'report-2',
      gymName: 'Shape Club Centro',
      regionLabel: 'Republica',
      timeAgoLabel: 'ha 17 min',
      occupancyPercent: 67,
      confirmCount: 11,
      disagreeCount: 3,
    ),
    _CommunityReportItem(
      id: 'report-3',
      gymName: 'Move One Jardins',
      regionLabel: 'Jardins',
      timeAgoLabel: 'ha 24 min',
      occupancyPercent: 44,
      confirmCount: 9,
      disagreeCount: 1,
    ),
    _CommunityReportItem(
      id: 'report-4',
      gymName: 'Ativa Club Zona Sul',
      regionLabel: 'Santo Amaro',
      timeAgoLabel: 'ha 31 min',
      occupancyPercent: 72,
      confirmCount: 7,
      disagreeCount: 4,
    ),
    _CommunityReportItem(
      id: 'report-5',
      gymName: 'PowerGym Tatuape',
      regionLabel: 'Tatuape',
      timeAgoLabel: 'ha 39 min',
      occupancyPercent: 29,
      confirmCount: 13,
      disagreeCount: 2,
    ),
  ];

  static const List<(String name, int points)> _leaderboard = <(String, int)>[
    ('Ana M.', 186),
    ('Rafael G.', 172),
    ('Bianca S.', 167),
  ];

  late final List<_CommunityReportItem> _reports;

  @override
  void initState() {
    super.initState();
    _reports = List<_CommunityReportItem>.of(_seedReports);
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

  void _vote(String reportId, _CommunityVote vote) {
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

      _reports[index] = current.copyWith(
        confirmCount: confirms,
        disagreeCount: disagrees,
        userVote: vote,
      );
    });
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
        child: CustomScrollView(
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
                    const Text(
                      'Feed de relatos recentes com validacao colaborativa.',
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
                          ..._leaderboard.indexed.map((entry) {
                            final rank = entry.$1 + 1;
                            final person = entry.$2;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    child: Text(
                                      '$rank.',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF527A6F),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      person.$1,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF315C52),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${person.$2} pts',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1C5649),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
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
                    const Text(
                      'Relatos recentes',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1C5649),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                          '${report.regionLabel} • ${report.timeAgoLabel}',
                          style: const TextStyle(
                            color: Color(0xFF527A6F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
    );
  }
}

class _ShellPlaceholderPage extends StatelessWidget {
  const _ShellPlaceholderPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.bullets,
    required this.ctaLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final List<String> bullets;
  final String ctaLabel;
  final VoidCallback onPressed;

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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE1ECE8)),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 20,
                      offset: Offset(0, 8),
                      color: Color(0x14000000),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: tone, size: 28),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF123D34),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.34,
                        color: Color(0xFF527A6F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...bullets.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: tone,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  color: Color(0xFF315C52),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onPressed,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(ctaLabel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tone,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
