part of 'gym_map_page.dart';

/// Academias que não estão no mapa: sugerir (perto de onde a pessoa está) e
/// avaliar as sugestões de outras pessoas ("Existe" / "Não existe").
extension _GymMapPageSuggestions on _GymMapPageState {
  static const double _maxSuggestDistanceMeters = 1000;
  static const double _maxSuggestionVoteDistanceMeters = 500;
  static const double _duplicateGymDistanceMeters = 50;
  static const int _suggestionConfirmThreshold = 3;

  /// Sugestões perto de quem usa o app (ou do centro do mapa). As
  /// confirmadas entram na lista de academias do mapa na hora.
  Future<void> _loadGymSuggestions({bool force = false}) async {
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null ||
        !remoteService.hasRemoteBackend ||
        !widget.showMap) {
      return;
    }
    final center =
        _userLocation ?? (_isMapReady ? _mapController.camera.center : null);
    if (center == null) {
      return;
    }
    // Não repete a busca se a última foi há pouco tempo e ali perto.
    final lastCenter = _suggestionsLoadedAround;
    final lastAt = _suggestionsLoadedAt;
    if (!force &&
        lastCenter != null &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < const Duration(minutes: 2) &&
        _metersBetween(lastCenter, center) < 1000) {
      return;
    }
    _suggestionsLoadedAround = center;
    _suggestionsLoadedAt = DateTime.now();
    try {
      final loaded = await remoteService.loadGymSuggestions(center);
      if (!mounted) {
        return;
      }
      _setStateIfMapVisible(() {
        _gymSuggestions = loaded;
      });
      _addConfirmedSuggestionsToMap(loaded);
    } catch (_) {
      // Sem servidor, o mapa segue só com as academias conhecidas.
    }
  }

  void _addConfirmedSuggestionsToMap(Iterable<GymSuggestion> suggestions) {
    final knownIds = <String>{for (final poi in _mapPois) poi.id};
    final confirmed = <MapGymPoi>[
      for (final suggestion in suggestions)
        if (suggestion.status == GymSuggestionStatus.confirmed &&
            !knownIds.contains(suggestion.id))
          MapGymPoi(
            id: suggestion.id,
            position: suggestion.position,
            name: suggestion.name,
          ),
    ];
    if (confirmed.isNotEmpty) {
      _setMapPoisIfChanged(<MapGymPoi>[..._mapPois, ...confirmed]);
    }
  }

  double _metersBetween(LatLng a, LatLng b) =>
      math.sqrt(_distanceSquaredMeters(a, b));

  /// Entra no modo de posicionar: o mapa vai até a pessoa e um pino fixo no
  /// centro da área livre marca onde fica a academia.
  void _startGymSuggestion() {
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null || !remoteService.hasRemoteBackend) {
      _showMapSnack(_t.suggestUnavailable);
      return;
    }
    final userPoint = _userLocation;
    if (userPoint == null) {
      _showMapSnack(_t.suggestNeedsLocation);
      return;
    }
    _clearSelectedGym();
    _setStateIfMapVisible(() {
      _isPlacingSuggestion = true;
    });
    _moveMapTo(userPoint, 17);
  }

  void _cancelGymSuggestion() {
    _setStateIfMapVisible(() {
      _isPlacingSuggestion = false;
    });
  }

  /// Ponto (no widget do mapa) onde fica a ponta do pino de posicionar: o
  /// centro da área livre, acima do cartão de instruções. A reserva do
  /// cartão é fixa para o pino desenhado e o ponto gravado serem o mesmo.
  Offset _placementPinOffset(Size mapSize) {
    const placementCardReserve = 160.0;
    final covered = _mapCoveredInsets();
    final bottom = math.max(covered.bottom, placementCardReserve);
    return Offset(
      mapSize.width / 2,
      (covered.top + (mapSize.height - bottom)) / 2,
    );
  }

  Future<void> _confirmGymPlacement() async {
    final userPoint = _userLocation;
    if (userPoint == null) {
      _showMapSnack(_t.suggestNeedsLocation);
      return;
    }
    final camera = _mapController.camera;
    final position = camera.screenOffsetToLatLng(
      _placementPinOffset(camera.nonRotatedSize),
    );
    if (_metersBetween(userPoint, position) > _maxSuggestDistanceMeters) {
      _showMapSnack(_t.suggestTooFar);
      return;
    }
    final hasGymNear =
        _mapPois.any(
          (poi) =>
              _metersBetween(poi.position, position) <=
              _duplicateGymDistanceMeters,
        ) ||
        _gymSuggestions.any(
          (item) =>
              _metersBetween(item.position, position) <=
              _duplicateGymDistanceMeters,
        );
    if (hasGymNear) {
      _showMapSnack(_t.suggestDuplicate);
      return;
    }
    final form = await _askSuggestedGymForm();
    if (form == null || !mounted) {
      return;
    }
    await _submitGymSuggestion(form, position, userPoint);
  }

  Future<_SuggestedGymForm?> _askSuggestedGymForm({GymSuggestion? editing}) {
    return showDialog<_SuggestedGymForm>(
      context: context,
      builder: (_) => _SuggestedGymFormDialog(editing: editing),
    );
  }

  Future<void> _submitGymSuggestion(
    _SuggestedGymForm form,
    LatLng position,
    LatLng userPoint,
  ) async {
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null) {
      return;
    }
    try {
      final suggestion = await remoteService.suggestGym(
        name: form.name,
        position: position,
        userPosition: userPoint,
        amenities: form.amenities,
      );
      if (!mounted) {
        return;
      }
      _setStateIfMapVisible(() {
        _gymSuggestions = <GymSuggestion>[..._gymSuggestions, suggestion];
        _isPlacingSuggestion = false;
      });
      _showMapSnack(_t.suggestSent('$_suggestionConfirmThreshold'));
      unawaited(_metrics.trackEvent('gym_suggestion_submit'));
    } on StateError catch (error) {
      _showMapSnack(switch (error.message) {
        'too_far' => _t.suggestTooFar,
        'duplicate_nearby' => _t.suggestDuplicate,
        'daily_limit' => _t.suggestDailyLimit,
        _ => _t.suggestFailed,
      });
    } catch (_) {
      _showMapSnack(_t.suggestFailed);
    }
  }

  void _replaceSuggestion(GymSuggestion updated) {
    _setStateIfMapVisible(() {
      _gymSuggestions = <GymSuggestion>[
        for (final item in _gymSuggestions)
          item.id == updated.id ? updated : item,
      ];
    });
  }

  Future<GymSuggestion?> _editGymSuggestion(GymSuggestion suggestion) async {
    final remoteService = _crowdReportRemoteService;
    final form = await _askSuggestedGymForm(editing: suggestion);
    if (form == null || remoteService == null || !mounted) {
      return null;
    }
    try {
      final updated = await remoteService.updateGymSuggestion(
        suggestionId: suggestion.id,
        name: form.name,
        amenities: form.amenities,
      );
      _replaceSuggestion(updated);
      _showMapSnack(_t.suggestionUpdated);
      return updated;
    } on StateError catch (error) {
      _showMapSnack(
        error.message == 'already_voted'
            ? _t.suggestionLocked
            : _t.suggestionChangeFailed,
      );
    } catch (_) {
      _showMapSnack(_t.suggestionChangeFailed);
    }
    return null;
  }

  /// Exclui a sugestão (depois de confirmar); devolve `true` se saiu.
  Future<bool> _deleteGymSuggestion(GymSuggestion suggestion) async {
    final remoteService = _crowdReportRemoteService;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(_t.suggestionDeleteConfirmTitle),
            content: Text(_t.suggestionDeleteConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_t.suggestCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(_t.suggestionDelete),
              ),
            ],
          ),
    );
    if (confirmed != true || remoteService == null || !mounted) {
      return false;
    }
    try {
      await remoteService.deleteGymSuggestion(suggestion.id);
      _setStateIfMapVisible(() {
        _gymSuggestions = <GymSuggestion>[
          for (final item in _gymSuggestions)
            if (item.id != suggestion.id) item,
        ];
      });
      _showMapSnack(_t.suggestionDeleted);
      return true;
    } on StateError catch (error) {
      _showMapSnack(
        error.message == 'already_voted'
            ? _t.suggestionLocked
            : _t.suggestionChangeFailed,
      );
    } catch (_) {
      _showMapSnack(_t.suggestionChangeFailed);
    }
    return false;
  }

  void _openGymSuggestionSheet(GymSuggestion initial) {
    var suggestion = initial;
    var voting = false;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final userPoint = _userLocation;
            final distance =
                userPoint == null
                    ? null
                    : _metersBetween(userPoint, suggestion.position);
            final canVote =
                !suggestion.isMine &&
                distance != null &&
                distance <= _maxSuggestionVoteDistanceMeters;

            Future<void> vote(String value) async {
              final point = _userLocation;
              final remoteService = _crowdReportRemoteService;
              if (point == null || remoteService == null || voting) {
                return;
              }
              setSheetState(() => voting = true);
              try {
                final updated = await remoteService.voteGymSuggestion(
                  suggestionId: suggestion.id,
                  vote: suggestion.userVote == value ? null : value,
                  userPosition: point,
                );
                if (!mounted) {
                  return;
                }
                suggestion = updated;
                _replaceSuggestion(updated);
                unawaited(_refreshRewards());
                if (updated.status == GymSuggestionStatus.confirmed) {
                  _addConfirmedSuggestionsToMap(<GymSuggestion>[updated]);
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  _showMapSnack(_t.suggestionConfirmedNow);
                  return;
                }
                if (updated.userVote != null) {
                  _showMapSnack(_t.suggestionVoted);
                }
              } catch (_) {
                _showMapSnack(_t.suggestionVoteFailed);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => voting = false);
                }
              }
            }

            Widget voteButton(String value, String label) {
              final selected = suggestion.userVote == value;
              final onPressed =
                  canVote && !voting ? () => unawaited(vote(value)) : null;
              return Expanded(
                child:
                    selected
                        ? FilledButton(onPressed: onPressed, child: Text(label))
                        : OutlinedButton(
                          onPressed: onPressed,
                          child: Text(label),
                        ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t.suggestionSheetSubtitle('$_suggestionConfirmThreshold'),
                    style: const TextStyle(color: GymMapColors.panelSubtitle),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t.suggestionVotes(
                      '${suggestion.existsCount}',
                      '${suggestion.missingCount}',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (suggestion.amenities.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _t.suggestionClaims,
                      style: const TextStyle(
                        color: GymMapColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final amenity in suggestion.amenities)
                          Tooltip(
                            message: amenityLabel(amenity),
                            triggerMode: TooltipTriggerMode.tap,
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: withUiOpacity(AppBrand.teal, 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Image.asset(
                                amenityIconAsset(amenity),
                                width: 24,
                                height: 24,
                                semanticLabel: amenityLabel(amenity),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (suggestion.isMine) ...[
                    Text(
                      suggestion.hasVotes
                          ? '${_t.suggestionMine} ${_t.suggestionLocked}'
                          : _t.suggestionMine,
                      style: const TextStyle(
                        color: GymMapColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!suggestion.hasVotes) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: Text(_t.suggestionDelete),
                              onPressed: () async {
                                final deleted = await _deleteGymSuggestion(
                                  suggestion,
                                );
                                if (deleted && sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.edit_rounded),
                              label: Text(_t.suggestionEdit),
                              onPressed: () async {
                                final updated = await _editGymSuggestion(
                                  suggestion,
                                );
                                if (updated != null && sheetContext.mounted) {
                                  setSheetState(() => suggestion = updated);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    Row(
                      children: [
                        voteButton('exists', _t.suggestionExists),
                        const SizedBox(width: 10),
                        voteButton('missing', _t.suggestionMissing),
                      ],
                    ),
                    if (!canVote) ...[
                      const SizedBox(height: 8),
                      Text(
                        _t.suggestionTooFar,
                        style: const TextStyle(
                          color: GymMapColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Pinos das sugestões a confirmar (as confirmadas viram academias).
  List<Marker> _suggestionMarkers() {
    return <Marker>[
      for (final suggestion in _gymSuggestions)
        if (suggestion.status == GymSuggestionStatus.pending)
          () {
            // Mesma escala por distância dos pinos das academias.
            final scale = _markerScaleForPosition(suggestion.position);
            return Marker(
              key: ValueKey<String>('suggestion-${suggestion.id}'),
              point: suggestion.position,
              width: SuggestedGymMarker.width * scale,
              height: SuggestedGymMarker.height * scale,
              alignment: Alignment.topCenter,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: SuggestedGymMarker(
                  name: suggestion.name,
                  onTap:
                      () => _handleMarkerTap(
                        () => _openGymSuggestionSheet(suggestion),
                      ),
                ),
              ),
            );
          }(),
    ];
  }

  /// Pino fixo e cartão de instruções do modo de posicionar.
  List<Widget> _buildPlacementOverlay() {
    return <Widget>[
      Positioned.fill(
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tip = _placementPinOffset(constraints.biggest);
              return Stack(
                children: [
                  Positioned(
                    left: tip.dx - 21,
                    top: tip.dy - 56,
                    child: Image.asset(
                      'assets/brand/pin.png',
                      width: 42,
                      height: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 20,
        child: Material(
          color: Colors.white,
          elevation: 6,
          shadowColor: GymMapColors.floatingControlShadow,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _t.suggestPlaceHint,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: GymMapColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelGymSuggestion,
                        child: Text(_t.suggestCancel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => unawaited(_confirmGymPlacement()),
                        child: Text(_t.suggestContinue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

/// O que a pessoa informa ao sugerir (ou editar) uma academia.
class _SuggestedGymForm {
  const _SuggestedGymForm(this.name, this.amenities);

  final String name;
  final Set<GymAmenity> amenities;
}

/// Nome da academia e o que ela tem. O campo de texto é descartado só
/// quando a janela sai de vez (não no meio da animação de fechar).
class _SuggestedGymFormDialog extends StatefulWidget {
  const _SuggestedGymFormDialog({this.editing});

  /// Sugestão sendo editada; sem valor, é uma sugestão nova.
  final GymSuggestion? editing;

  @override
  State<_SuggestedGymFormDialog> createState() =>
      _SuggestedGymFormDialogState();
}

class _SuggestedGymFormDialogState extends State<_SuggestedGymFormDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.editing?.name ?? '',
  );
  late final Set<GymAmenity> _amenities = <GymAmenity>{
    ...?widget.editing?.amenities,
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _controller.text.trim();
    final valid = name.length >= 2 && name.length <= 80;
    final editing = widget.editing != null;
    return AlertDialog(
      title: Text(editing ? _t.suggestEditTitle : _t.suggestNameTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: _controller,
              autofocus: !editing,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: _t.suggestNameHint),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Text(
              _t.suggestFormAmenities,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final amenity in GymAmenity.values)
              CheckboxListTile(
                value: _amenities.contains(amenity),
                onChanged:
                    (checked) => setState(() {
                      if (checked == true) {
                        _amenities.add(amenity);
                      } else {
                        _amenities.remove(amenity);
                      }
                    }),
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppBrand.tealDeep,
                secondary: Image.asset(
                  amenityIconAsset(amenity),
                  width: 26,
                  height: 26,
                  excludeFromSemantics: true,
                ),
                title: Text(amenityLabel(amenity)),
              ),
            const SizedBox(height: 8),
            if (!editing)
              Text(
                _t.suggestPointsHint,
                style: const TextStyle(
                  color: AppBrand.tealDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t.suggestCancel),
        ),
        FilledButton(
          onPressed:
              valid
                  ? () => Navigator.of(
                    context,
                  ).pop(_SuggestedGymForm(name, _amenities))
                  : null,
          child: Text(editing ? _t.suggestSave : _t.suggestSend),
        ),
      ],
    );
  }
}
