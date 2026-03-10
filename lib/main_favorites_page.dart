part of 'main.dart';

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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _buildPlanSurfaceGradient(context),
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
                        Text(
                          'Favoritos',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          favorites.isEmpty
                              ? 'Você ainda não marcou academias favoritas.'
                              : '${favorites.length} academia(s) salva(s).',
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.72),
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
                            border: Border.all(
                              color: primary.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Text(
                            'Use o ícone de coração no painel da academia para salvar seus favoritos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: onSurface.withValues(alpha: 0.84),
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
                            border: Border.all(
                              color: primary.withValues(alpha: 0.20),
                            ),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID: ${item.id}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: onSurface.withValues(alpha: 0.72),
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
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _buildPlanSurfaceGradient(context),
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
                        color: primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 240,
                      height: 14,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.22),
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
                      border: Border.all(
                        color: primary.withValues(alpha: 0.20),
                      ),
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

