part of 'gym_map_page.dart';

extension _GymMapPageCommunity on _GymMapPageState {
  String _resolveCrowdReporterId() {
    final remoteService = _crowdReportRemoteService;
    if (remoteService != null) {
      remoteService.refreshAuthFromStorage();
      final remoteUserId = remoteService.userId.trim();
      if (remoteUserId.isNotEmpty) {
        return 'user:$remoteUserId';
      }
    }
    return _GymMapPageState._localReporterId;
  }

  void _submitCrowdReport() {
    unawaited(_submitCrowdReportAsync());
  }

  /// Registra relato colaborativo (0-100) e recalcula snapshot da academia.
  Future<void> _submitCrowdReportAsync() async {
    if (_isSubmittingCrowdReport) {
      return;
    }
    final selectedGym = _selectedGym;
    if (selectedGym == null) {
      return;
    }
    if (!_isUserAtGym(selectedGym)) {
      _showMapSnack(
        _userLocation == null
            ? _t.presenceLocationRequired
            : _t.presenceReportHint,
      );
      return;
    }

    if (mounted) {
      _setStateIfMapVisible(() {
        _isSubmittingCrowdReport = true;
      });
    } else {
      _isSubmittingCrowdReport = true;
    }
    final int report = _reportPercent.round().clamp(0, 100).toInt();
    final reporterId = _resolveCrowdReporterId();
    final regionKey = _leaderboardRegionKey(preferredGym: selectedGym);
    final regionLabel = _leaderboardRegionLabel(preferredGym: selectedGym);
    final remoteService = _crowdReportRemoteService;
    try {
      if (remoteService != null && remoteService.hasRemoteBackend) {
        try {
          final remoteResult = await remoteService.submitReport(
            gymId: selectedGym.id,
            occupancyPercent: report,
            reporterId: reporterId,
            regionKey: regionKey,
            regionLabel: regionLabel,
            userPosition: _userLocation,
            gymPosition: selectedGym.position,
          );
          if (!remoteResult.accepted) {
            final retryAfter =
                remoteResult.retryAfter ?? const Duration(minutes: 1);
            final waitMinutes =
                retryAfter.inMinutes >= 1 ? retryAfter.inMinutes : 1;
            unawaited(
              _metrics.trackEvent(
                'crowd_report_submit',
                params: <String, Object?>{
                  'gymId': selectedGym.id,
                  'occupancyPercent': report,
                  'source': 'remote',
                  'result': 'blocked',
                  'waitMinutes': waitMinutes,
                },
              ),
            );
            _showMapSnack(_t.reportBlockedWait('$waitMinutes'));
            return;
          }

          final remoteReport = remoteResult.report;
          if (remoteReport != null) {
            final merged = _crowdService.mergeReports(<CrowdReport>[
              remoteReport,
            ]);
            if (merged > 0) {
              _markCrowdDataChanged();
            }
          } else {
            final merged = _crowdService.mergeReports(<CrowdReport>[
              CrowdReport(
                gymId: selectedGym.id,
                occupancyPercent: report,
                createdAt: DateTime.now().toUtc(),
                reporterId: reporterId,
                reliabilityWeight: 1,
              ),
            ]);
            if (merged > 0) {
              _markCrowdDataChanged();
            }
          }

          final snapshot = _crowdService.snapshotFor(selectedGym);
          if (mounted) {
            _setStateIfMapVisible(() {
              _reportPercent = (snapshot.occupancyPercent ?? report).toDouble();
              _communityPoints += 1;
            });
          }
          unawaited(_persistCommunityPoints());
          unawaited(_refreshRewards());

          final trust =
              ((remoteReport?.reliabilityWeight ?? 1) * 100)
                  .round()
                  .clamp(20, 160)
                  .toInt();
          _showContributionSnack(
            gymName: selectedGym.name,
            report: report,
            trust: trust,
          );
          unawaited(
            _metrics.trackEvent(
              'crowd_report_submit',
              params: <String, Object?>{
                'gymId': selectedGym.id,
                'occupancyPercent': report,
                'source': 'remote',
                'result': 'accepted',
              },
            ),
          );
          unawaited(
            _syncCrowdReportsForGyms(
              _crowdSyncGymIds(extraGymIds: [selectedGym.id]),
            ),
          );
          return;
        } on StateError catch (error) {
          // Recusado por distância: não vira relato local.
          if (error.message == 'too_far' ||
              error.message == 'location_required') {
            _showMapSnack(_t.presenceReportHint);
            return;
          }
        } catch (_) {
          // Sem rede/backend: segue fluxo local para não perder envio do usuário.
        }
      }

      final localResult = _crowdService.submitReport(
        gym: selectedGym,
        reporterId: reporterId,
        occupancyPercent: report,
      );
      if (!localResult.accepted) {
        final retryAfter = localResult.retryAfter ?? const Duration(minutes: 1);
        final waitMinutes =
            retryAfter.inMinutes >= 1 ? retryAfter.inMinutes : 1;
        unawaited(
          _metrics.trackEvent(
            'crowd_report_submit',
            params: <String, Object?>{
              'gymId': selectedGym.id,
              'occupancyPercent': report,
              'source': 'local',
              'result': 'blocked',
              'waitMinutes': waitMinutes,
            },
          ),
        );
        _showMapSnack(_t.reportBlockedWait('$waitMinutes'));
        return;
      }
      _markCrowdDataChanged();

      final snapshot = _crowdService.snapshotFor(selectedGym);
      if (mounted) {
        _setStateIfMapVisible(() {
          _reportPercent = (snapshot.occupancyPercent ?? report).toDouble();
          _communityPoints += 1;
        });
      }
      unawaited(_persistCommunityPoints());

      final trust = ((localResult.appliedWeight ?? 1) * 100).round();
      _showContributionSnack(
        gymName: selectedGym.name,
        report: report,
        trust: trust,
      );
      unawaited(
        _metrics.trackEvent(
          'crowd_report_submit',
          params: <String, Object?>{
            'gymId': selectedGym.id,
            'occupancyPercent': report,
            'source': 'local',
            'result': 'accepted',
          },
        ),
      );
    } finally {
      if (mounted) {
        _setStateIfMapVisible(() {
          _isSubmittingCrowdReport = false;
        });
      } else {
        _isSubmittingCrowdReport = false;
      }
    }
  }

  void _showMapSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  bool _markPurchaseSuccessNotified(String key) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return false;
    }
    final added = _purchaseSuccessNotificationKeys.add(normalizedKey);
    if (added && _purchaseSuccessNotificationKeys.length > 24) {
      _purchaseSuccessNotificationKeys.remove(
        _purchaseSuccessNotificationKeys.first,
      );
    }
    return added;
  }

  Future<void> _showPlanActivationSuccessDialog(AppPlanTier tier) async {
    if (!mounted) {
      return;
    }
    final plan = kPlanCatalog[tier]!;
    final highlights = plan.insights.take(2).toList(growable: false);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final primary = _planAccentColor(tier);
        final onPrimary = _planOnAccentColor(tier);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.88, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: withUiOpacity(primary, 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _t.subscriptionActivated,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: GymMapColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t.planUnlocked(plan.label),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GymMapColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final highlight in highlights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: withUiOpacity(primary, 0.90),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              highlight,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: GymMapColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: onPrimary,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: Text(_t.actionContinue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showContributionSnack({
    required String gymName,
    required int report,
    required int trust,
  }) {
    if (!mounted) {
      return;
    }
    HapticFeedback.lightImpact();
    _triggerContributionCelebration();
    final totalPoints = _communityPoints;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: GymMapColors.occupancyLow,
        content: Row(
          children: [
            const Icon(
              Icons.celebration_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t.reportThanks(gymName, '$report', '$trust'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: withUiOpacity(Colors.white, 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _t.communityPointsShort('$totalPoints'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerContributionCelebration() {
    if (!mounted) {
      return;
    }
    _contributionCelebrationTimer?.cancel();
    _setStateIfMapVisible(() {
      _showContributionCelebration = true;
      _contributionCelebrationTick++;
    });
    _contributionCelebrationTimer = Timer(
      const Duration(milliseconds: 1100),
      () {
        if (!mounted) {
          return;
        }
        _setStateIfMapVisible(() {
          _showContributionCelebration = false;
        });
      },
    );
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
        return GymMapColors.textSecondary;
    }
  }

  LatLng _leaderboardRegionPoint({Gym? preferredGym}) {
    if (preferredGym != null) {
      return preferredGym.position;
    }
    final userPoint = _userLocation;
    if (userPoint != null) {
      return userPoint;
    }
    final selected = _selectedGym;
    if (selected != null) {
      return selected.position;
    }
    if (_isMapReady) {
      try {
        return _mapController.camera.center;
      } catch (_) {
        // Ignora quando a câmera ainda não está pronta.
      }
    }
    return _GymMapPageState._fallbackMapCenter;
  }

  String _leaderboardRegionKey({Gym? preferredGym}) {
    final point = _leaderboardRegionPoint(preferredGym: preferredGym);
    return _leaderboardRegionKeyFromPoint(point);
  }

  String _leaderboardRegionKeyFromPoint(LatLng point) {
    final latBucket = (point.latitude * 10).round() / 10;
    final lngBucket = (point.longitude * 10).round() / 10;
    return '${latBucket.toStringAsFixed(1)},${lngBucket.toStringAsFixed(1)}';
  }

  String _leaderboardRegionLabel({Gym? preferredGym}) {
    final gym = preferredGym;
    if (gym != null) {
      final address = gym.address.trim();
      if (address.isNotEmpty && address != kMapGymAddress) {
        return address;
      }
    }
    if (_userLocation != null) {
      return _t.communityCurrentLocation;
    }
    final selected = _selectedGym;
    if (selected != null) {
      final selectedAddress = selected.address.trim();
      if (selectedAddress.isNotEmpty && selectedAddress != kMapGymAddress) {
        return selectedAddress;
      }
    }
    final searchLocation = (_searchLocationQuery ?? '').trim();
    if (searchLocation.isNotEmpty) {
      return searchLocation;
    }
    return _t.communityCurrentRegion;
  }

  _CommunityLeaderboardSheetData _buildLocalLeaderboardSheetData({
    required String regionLabel,
  }) {
    return _CommunityLeaderboardSheetData(
      entries: const <_CommunityLeaderboardEntry>[],
      userRank: 0,
      userPoints: _communityPoints.clamp(0, 1000000).toInt(),
      regionLabel: regionLabel,
      isRegional: false,
    );
  }

  Future<_CommunityLeaderboardSheetData> _loadRegionalLeaderboardSheetData({
    required String regionKey,
    required String regionLabel,
  }) async {
    final fallback = _buildLocalLeaderboardSheetData(regionLabel: regionLabel);
    final localUserPoints = _communityPoints.clamp(0, 1000000).toInt();
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null || !remoteService.hasRemoteBackend) {
      return fallback;
    }
    try {
      final result = await remoteService.loadRegionalLeaderboard(
        regionKey: regionKey,
        regionLabel: regionLabel,
        limit: 10,
        windowDays: 7,
      );
      if (result == null || result.entries.isEmpty) {
        return fallback;
      }
      final entries = result.entries
          .map(
            (entry) => _CommunityLeaderboardEntry(
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
      return _CommunityLeaderboardSheetData(
        entries: entries,
        userRank: userRank,
        userPoints: localUserPoints,
        regionLabel: normalizedRegionLabel,
        isRegional: true,
      );
    } catch (_) {
      return fallback;
    }
  }

  void _openCommunityLeaderboard() {
    if (!mounted) {
      return;
    }
    HapticFeedback.selectionClick();
    final userPoint = _userLocation;
    final regionKey =
        userPoint == null ? '' : _leaderboardRegionKeyFromPoint(userPoint);
    final regionLabel =
        userPoint == null
            ? _t.communityRegionUnavailable
            : _t.communityYourRegion;
    final fallbackData = _buildLocalLeaderboardSheetData(
      regionLabel: regionLabel,
    );
    final leaderboardFuture = _loadRegionalLeaderboardSheetData(
      regionKey: regionKey,
      regionLabel: regionLabel,
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final primary = Theme.of(sheetContext).colorScheme.primary;
        return FutureBuilder<_CommunityLeaderboardSheetData>(
          future: leaderboardFuture,
          initialData: fallbackData,
          builder: (context, snapshot) {
            final data = snapshot.data ?? fallbackData;
            final entries = data.entries;
            final userRank = data.userRank;
            final userPoints = data.userPoints;
            final rankLabel =
                userRank > 0 ? '#$userRank' : _t.communityNoRanking;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t.communityTop10,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t.communityCurrentPosition(rankLabel, '$userPoints'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GymMapColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _t.communityRegion(data.regionLabel),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GymMapColors.textSecondary,
                        ),
                      ),
                      if (_rewards case final rewards?) ...[
                        const SizedBox(height: 12),
                        _RewardsCard(initial: rewards, onRedeem: _redeemReward),
                      ],
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !data.isRegional) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _t.communityRankingUpdating,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: withUiOpacity(primary, 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: withUiOpacity(primary, 0.08),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data.isRegional
                                    ? _t.communityRankingRealInfo
                                    : _t.communityRankingInfo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: GymMapColors.textStrong,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < entries.length; i++) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color:
                                entries[i].isCurrentUser
                                    ? withUiOpacity(primary, 0.10)
                                    : Colors.white,
                            border: Border.all(
                              color:
                                  entries[i].isCurrentUser
                                      ? withUiOpacity(primary, 0.34)
                                      : withUiOpacity(primary, 0.10),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child:
                                    i < 3
                                        ? Icon(
                                          Icons.emoji_events_rounded,
                                          size: 19,
                                          color: _leaderboardMedalColor(i),
                                        )
                                        : Text(
                                          '#${i + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: GymMapColors.textSecondary,
                                          ),
                                        ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entries[i].name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color:
                                        entries[i].isCurrentUser
                                            ? GymMapColors.textPrimary
                                            : GymMapColors.textStrong,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: withUiOpacity(primary, 0.09),
                                ),
                                child: Text(
                                  _t.communityPointsShort(
                                    '${entries[i].points}',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: GymMapColors.textStrong,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (entries.isEmpty)
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            _t.communityRankingEmpty,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: GymMapColors.textSecondary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: Text(_t.actionClose),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
