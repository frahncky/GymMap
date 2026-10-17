part of 'main.dart';

class _ProfilePreferences {
  const _ProfilePreferences({
    required this.displayName,
    required this.photoBase64,
    required this.isProfileVisible,
    required this.pushNotifications,
    required this.locationAlerts,
    required this.hapticFeedback,
    required this.dataSaverMode,
  });

  final String displayName;
  final String photoBase64;
  final bool isProfileVisible;
  final bool pushNotifications;
  final bool locationAlerts;
  final bool hapticFeedback;
  final bool dataSaverMode;

  Uint8List? get photoBytes {
    final raw = photoBase64.trim();
    if (raw.isEmpty) {
      return null;
    }
    try {
      final decoded = base64Decode(raw);
      return decoded.isEmpty ? null : decoded;
    } catch (_) {
      return null;
    }
  }

  _ProfilePreferences copyWith({
    String? displayName,
    String? photoBase64,
    bool? isProfileVisible,
    bool? pushNotifications,
    bool? locationAlerts,
    bool? hapticFeedback,
    bool? dataSaverMode,
  }) {
    return _ProfilePreferences(
      displayName: displayName ?? this.displayName,
      photoBase64: photoBase64 ?? this.photoBase64,
      isProfileVisible: isProfileVisible ?? this.isProfileVisible,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      locationAlerts: locationAlerts ?? this.locationAlerts,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
    );
  }
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({required this.onOpenMap, required this.activePlan});

  final VoidCallback onOpenMap;

  /// Plano ativo, exibido no cartão do perfil.
  final AppPlanTier activePlan;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  static const String _displayNamePrefKey = 'gymmap_profile_name_v1';
  static const String _photoBase64PrefKey = 'gymmap_profile_photo_base64_v1';
  static const String _profileVisiblePrefKey = 'gymmap_profile_visible_v1';
  static const String _pushNotificationsPrefKey = 'gymmap_pref_push_v1';
  static const String _locationAlertsPrefKey = 'gymmap_pref_location_alerts_v1';
  static const String _hapticsPrefKey = 'gymmap_pref_haptics_v1';
  static const String _dataSaverPrefKey = 'gymmap_pref_data_saver_v1';
  static String get _defaultProfileName => _t.profileDefaultName;

  final ImagePicker _imagePicker = ImagePicker();

  _ProfilePreferences _preferences = _ProfilePreferences(
    displayName: _defaultProfileName,
    photoBase64: '',
    isProfileVisible: true,
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

  String _normalizeDisplayName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return _defaultProfileName;
    }
    return normalized;
  }

  void _showSaveErrorSnack() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(_t.profileSavePreferenceFailed),
      ),
    );
  }

  void _showProfileSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  Future<void> _loadProfilePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = _ProfilePreferences(
        displayName: _normalizeDisplayName(
          prefs.getString(_displayNamePrefKey) ?? _defaultProfileName,
        ),
        photoBase64: (prefs.getString(_photoBase64PrefKey) ?? '').trim(),
        isProfileVisible: prefs.getBool(_profileVisiblePrefKey) ?? true,
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
      _showSaveErrorSnack();
    }
  }

  Future<void> _persistProfileStringPreference({
    required String key,
    required String value,
    bool removeWhenEmpty = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (removeWhenEmpty && value.trim().isEmpty) {
        await prefs.remove(key);
        return;
      }
      await prefs.setString(key, value);
    } catch (_) {
      _showSaveErrorSnack();
      rethrow;
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

  void _setProfileVisibility(bool value) {
    _updatePreference(
      value: value,
      prefKey: _profileVisiblePrefKey,
      reducer: (current) => current.copyWith(isProfileVisible: value),
    );
  }

  void _toggleProfileVisibility() {
    _setProfileVisibility(!_preferences.isProfileVisible);
  }

  Future<bool> _saveProfileIdentity({
    required String displayName,
    required String photoBase64,
  }) async {
    final normalizedName = _normalizeDisplayName(displayName);
    try {
      await _persistProfileStringPreference(
        key: _displayNamePrefKey,
        value: normalizedName,
      );
      await _persistProfileStringPreference(
        key: _photoBase64PrefKey,
        value: photoBase64,
        removeWhenEmpty: true,
      );
      if (!mounted) {
        return false;
      }
      setState(() {
        _preferences = _preferences.copyWith(
          displayName: normalizedName,
          photoBase64: photoBase64,
        );
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openEditProfileDialog() async {
    final nameController = TextEditingController(
      text: _preferences.displayName,
    );
    var draftPhotoBase64 = _preferences.photoBase64;
    var profileUpdated = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSaving = false;
        var isPickingPhoto = false;
        String? errorMessage;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final previewBytes =
                _ProfilePreferences(
                  displayName: _preferences.displayName,
                  photoBase64: draftPhotoBase64,
                  isProfileVisible: _preferences.isProfileVisible,
                  pushNotifications: _preferences.pushNotifications,
                  locationAlerts: _preferences.locationAlerts,
                  hapticFeedback: _preferences.hapticFeedback,
                  dataSaverMode: _preferences.dataSaverMode,
                ).photoBytes;

            Future<void> pickPhoto() async {
              if (isSaving || isPickingPhoto) {
                return;
              }
              setDialogState(() {
                isPickingPhoto = true;
                errorMessage = null;
              });
              try {
                final picked = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 640,
                  maxHeight: 640,
                  imageQuality: 80,
                );
                if (picked == null) {
                  return;
                }
                final bytes = await picked.readAsBytes();
                if (bytes.isEmpty) {
                  setDialogState(() {
                    errorMessage = _t.profileLoadPhotoFailed;
                  });
                  return;
                }
                setDialogState(() {
                  draftPhotoBase64 = base64Encode(bytes);
                });
              } catch (_) {
                setDialogState(() {
                  errorMessage = _t.profilePickPhotoFailed;
                });
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    isPickingPhoto = false;
                  });
                }
              }
            }

            Future<void> submitProfileUpdate() async {
              if (isSaving || isPickingPhoto) {
                return;
              }
              final rawName = nameController.text.trim();
              if (rawName.isEmpty) {
                setDialogState(() {
                  errorMessage = _t.profileNameRequired;
                });
                return;
              }
              setDialogState(() {
                isSaving = true;
                errorMessage = null;
              });
              final saved = await _saveProfileIdentity(
                displayName: rawName,
                photoBase64: draftPhotoBase64,
              );
              if (!dialogContext.mounted) {
                return;
              }
              if (saved) {
                profileUpdated = true;
                Navigator.of(dialogContext).pop();
                return;
              }
              setDialogState(() {
                isSaving = false;
                errorMessage = _t.profileSaveFailed;
              });
            }

            return AlertDialog(
              title: Text(_t.profileEdit),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.14),
                          foregroundImage:
                              previewBytes == null
                                  ? null
                                  : MemoryImage(previewBytes),
                          child:
                              previewBytes == null
                                  ? Icon(
                                    Icons.person_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 28,
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    (isSaving || isPickingPhoto)
                                        ? null
                                        : pickPhoto,
                                icon:
                                    isPickingPhoto
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.photo_library_outlined,
                                        ),
                                label: Text(_t.profileChangePhoto),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    (isSaving || isPickingPhoto)
                                        ? null
                                        : () {
                                          setDialogState(() {
                                            draftPhotoBase64 = '';
                                            errorMessage = null;
                                          });
                                        },
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: Text(_t.profileRemovePhoto),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        unawaited(submitProfileUpdate());
                      },
                      decoration: InputDecoration(
                        labelText: _t.profileNameLabel,
                        hintText: _t.profileNameHint,
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      (isSaving || isPickingPhoto)
                          ? null
                          : () {
                            Navigator.of(dialogContext).pop();
                          },
                  child: Text(_t.actionCancel),
                ),
                FilledButton(
                  onPressed:
                      (isSaving || isPickingPhoto) ? null : submitProfileUpdate,
                  child:
                      isSaving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(_t.actionSave),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    if (profileUpdated) {
      _showProfileSnack(_t.profileUpdated);
    }
  }

  Widget _buildProfileAvatar(Color primary) {
    final photoBytes = _preferences.photoBytes;
    return CircleAvatar(
      radius: 28,
      backgroundColor: primary.withValues(alpha: 0.14),
      foregroundImage: photoBytes == null ? null : MemoryImage(photoBytes),
      child:
          photoBytes == null
              ? Icon(Icons.person_rounded, color: primary, size: 30)
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isPublicProfile = _preferences.isProfileVisible;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: _buildPlanSurfaceGradient(context)),
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
                              _t.profileTitle,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: onSurface,
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
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _buildProfileAvatar(primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _preferences.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _t.profileCurrentPlan(
                                                kPlanCatalog[widget.activePlan]!
                                                    .label,
                                              ),
                                              style: TextStyle(
                                                color: onSurface.withValues(
                                                  alpha: 0.72,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _openEditProfileDialog,
                                        tooltip: _t.profileEdit,
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: _toggleProfileVisibility,
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            color:
                                                isPublicProfile
                                                    ? const Color(0xFFE9F7EF)
                                                    : const Color(0xFFF7EFE9),
                                            border: Border.all(
                                              color:
                                                  isPublicProfile
                                                      ? const Color(0xFFB2DEC0)
                                                      : const Color(0xFFE5C7B2),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isPublicProfile
                                                    ? Icons.public_rounded
                                                    : Icons
                                                        .visibility_off_rounded,
                                                size: 14,
                                                color:
                                                    isPublicProfile
                                                        ? const Color(
                                                          0xFF2E7D32,
                                                        )
                                                        : const Color(
                                                          0xFF8A4B2E,
                                                        ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isPublicProfile
                                                    ? _t.profileVisible
                                                    : _t.profilePrivate,
                                                style: TextStyle(
                                                  color:
                                                      isPublicProfile
                                                          ? const Color(
                                                            0xFF2E7D32,
                                                          )
                                                          : const Color(
                                                            0xFF8A4B2E,
                                                          ),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: widget.onOpenMap,
                                        child: Text(_t.actionOpenMap),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Material (e não Container com cor) para que o
                            // efeito de toque dos SwitchListTile apareça.
                            Material(
                              color: Colors.white,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: primary.withValues(alpha: 0.20),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    SwitchListTile.adaptive(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                      title: Text(
                                        _t.profilePublicTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      subtitle: Text(_t.profilePublicSubtitle),
                                      value: _preferences.isProfileVisible,
                                      onChanged: _setProfileVisibility,
                                    ),
                                    SwitchListTile.adaptive(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                      title: Text(
                                        _t.profilePushTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      subtitle: Text(_t.profilePushSubtitle),
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                      title: Text(
                                        _t.profileLocationAlertsTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      subtitle: Text(
                                        _t.profileLocationAlertsSubtitle,
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                      title: Text(
                                        _t.profileHapticsTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      subtitle: Text(_t.profileHapticsSubtitle),
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                      title: Text(
                                        _t.profileDataSaverTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      subtitle: Text(
                                        _t.profileDataSaverSubtitle,
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
                                    const _LanguagePreferenceTile(),
                                  ],
                                ),
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

/// Escolha do idioma: o do aparelho (padrão), português ou inglês.
class _LanguagePreferenceTile extends StatelessWidget {
  const _LanguagePreferenceTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<AppLanguagePreference>(
      valueListenable: AppL10n.preference,
      builder: (context, preference, _) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.language_rounded),
          title: Text(
            l10n.settingsLanguageTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          trailing: DropdownButton<AppLanguagePreference>(
            value: preference,
            underline: const SizedBox.shrink(),
            onChanged: (value) {
              if (value != null) {
                unawaited(AppL10n.setPreference(value));
              }
            },
            items: [
              DropdownMenuItem(
                value: AppLanguagePreference.system,
                child: Text(l10n.settingsLanguageSystem),
              ),
              DropdownMenuItem(
                value: AppLanguagePreference.portuguese,
                child: Text(l10n.settingsLanguagePortuguese),
              ),
              DropdownMenuItem(
                value: AppLanguagePreference.english,
                child: Text(l10n.settingsLanguageEnglish),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileLoadingState extends StatelessWidget {
  const _ProfileLoadingState();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: _buildPlanSurfaceGradient(context)),
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
