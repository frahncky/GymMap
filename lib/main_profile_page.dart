part of 'main.dart';

class _ProfilePreferences {
  const _ProfilePreferences({
    required this.pushNotifications,
    required this.locationAlerts,
    required this.hapticFeedback,
    required this.dataSaverMode,
  });

  final bool pushNotifications;
  final bool locationAlerts;
  final bool hapticFeedback;
  final bool dataSaverMode;

  _ProfilePreferences copyWith({
    bool? pushNotifications,
    bool? locationAlerts,
    bool? hapticFeedback,
    bool? dataSaverMode,
  }) {
    return _ProfilePreferences(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      locationAlerts: locationAlerts ?? this.locationAlerts,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
    );
  }
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({
    required this.onOpenMap,
  });

  final VoidCallback onOpenMap;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  static const String _pushNotificationsPrefKey = 'gymmap_pref_push_v1';
  static const String _locationAlertsPrefKey = 'gymmap_pref_location_alerts_v1';
  static const String _hapticsPrefKey = 'gymmap_pref_haptics_v1';
  static const String _dataSaverPrefKey = 'gymmap_pref_data_saver_v1';

  _ProfilePreferences _preferences = const _ProfilePreferences(
    pushNotifications: true,
    locationAlerts: true,
    hapticFeedback: true,
    dataSaverMode: false,
  );
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfilePreferences());
  }

  Future<void> _loadProfilePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = _ProfilePreferences(
        pushNotifications: prefs.getBool(_pushNotificationsPrefKey) ?? true,
        locationAlerts: prefs.getBool(_locationAlertsPrefKey) ?? true,
        hapticFeedback: prefs.getBool(_hapticsPrefKey) ?? true,
        dataSaverMode: prefs.getBool(_dataSaverPrefKey) ?? false,
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

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _buildPlanSurfaceGradient(context),
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
                            Text(
                              'Perfil',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Conta e preferências do app.',
                              style: TextStyle(
                                color: onSurface.withValues(alpha: 0.72),
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
                                  color: primary.withValues(alpha: 0.20),
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Usuário GymMap',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: onSurface,
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Plano atual: Grátis',
                                          style: TextStyle(
                                            color: onSurface.withValues(alpha: 0.72),
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
                                  color: primary.withValues(alpha: 0.20),
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
                            Text(
                              'Preferências salvas localmente neste dispositivo.',
                              style: TextStyle(
                                fontSize: 12,
                                color: onSurface.withValues(alpha: 0.72),
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
                        border: Border.all(
                          color: primary.withValues(alpha: 0.20),
                        ),
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
                        border: Border.all(
                          color: primary.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Column(
                        children: [
                          _LoadingTile(),
                          Divider(
                            height: 1,
                            color: primary.withValues(alpha: 0.14),
                          ),
                          _LoadingTile(),
                          Divider(
                            height: 1,
                            color: primary.withValues(alpha: 0.14),
                          ),
                          _LoadingTile(),
                          Divider(
                            height: 1,
                            color: primary.withValues(alpha: 0.14),
                          ),
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
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            primary.withValues(alpha: 0.14),
            primary.withValues(alpha: 0.24),
            primary.withValues(alpha: 0.14),
          ],
        ),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

