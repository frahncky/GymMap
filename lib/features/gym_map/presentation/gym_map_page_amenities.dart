part of 'gym_map_page.dart';

/// Comodidades marcadas pela comunidade e a troca de pontos por dias do
/// plano Essencial (os dois dependem do servidor).
extension _GymMapPageAmenities on _GymMapPageState {
  /// Carrega os votos de comodidades de [gymIds] (até 80 por vez).
  Future<void> _loadAmenityVotes(Iterable<String> gymIds) async {
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null || !remoteService.hasRemoteBackend) {
      return;
    }
    try {
      final loaded = await remoteService.loadAmenities(gymIds);
      if (!mounted || loaded.isEmpty) {
        return;
      }
      _setStateIfMapVisible(() {
        _amenityVotesByGymId.addAll(loaded);
      });
    } catch (_) {
      // Sem servidor, o card segue com a lista gravada.
    }
  }

  /// Comodidades confirmadas pela comunidade, ou `null` se a academia ainda
  /// não tem nenhuma (aí o card mostra a lista gravada em [Gym.amenities]).
  List<GymAmenity>? _confirmedAmenitiesFor(Gym gym) {
    final confirmed = <GymAmenity>[
      for (final vote in _amenityVotesByGymId[gym.id] ?? const [])
        if (vote.status == AmenityVoteStatus.confirmed) vote.amenity,
    ];
    return confirmed.isEmpty ? null : confirmed;
  }

  /// O que a academia oferece, para os filtros: as confirmadas ou, sem
  /// nenhuma, as gravadas.
  bool _gymOffers(Gym gym, GymAmenity amenity) {
    final confirmed = _confirmedAmenitiesFor(gym);
    if (confirmed != null) {
      return confirmed.contains(amenity);
    }
    return gym.amenities.any(
      (stored) => GymAmenity.fromStored(stored) == amenity,
    );
  }

  void _openAmenitySheet(Gym gym) {
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null || !remoteService.hasRemoteBackend) {
      _showMapSnack(_t.amenityUnavailable);
      return;
    }
    showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (sheetContext) => FractionallySizedBox(
            heightFactor: 0.88,
            child: AmenityVoteSheet(
              gymName: displayGymName(gym.name),
              votes: _amenityVotesByGymId[gym.id] ?? const [],
              confirmThreshold: _GymMapPageState._amenityConfirmThreshold,
              defaultChecked: <GymAmenity>{
                ...?_confirmedAmenitiesFor(gym),
                if (_confirmedAmenitiesFor(gym) == null)
                  for (final stored in gym.amenities)
                    if (GymAmenity.fromStored(stored) case final amenity?)
                      amenity,
              },
              onSubmit: (changes) => _submitAmenityVotes(gym, changes),
            ),
          ),
    );
  }

  Future<bool> _submitAmenityVotes(
    Gym gym,
    Map<GymAmenity, bool?> changes,
  ) async {
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null) {
      return false;
    }
    try {
      final result = await remoteService.submitAmenityVotes(
        gymId: gym.id,
        votes: changes,
      );
      if (!mounted) {
        return true;
      }
      _setStateIfMapVisible(() {
        _amenityVotesByGymId[gym.id] = result.amenities;
      });
      unawaited(_refreshRewards());
      _showMapSnack(
        result.pointsAwarded > 0
            ? _t.amenitySaved('${result.pointsAwarded}')
            : _t.amenitySavedNoPoints,
      );
      unawaited(
        _metrics.trackEvent(
          'amenity_votes_submit',
          params: <String, Object?>{
            'gymId': gym.id,
            'changes': changes.length,
            'pointsAwarded': result.pointsAwarded,
          },
        ),
      );
      return true;
    } catch (_) {
      _showMapSnack(_t.amenitySaveFailed);
      return false;
    }
  }

  /// Saldo de pontos do servidor (o cabeçalho e o ranking usam este).
  Future<void> _refreshRewards() async {
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null || !remoteService.hasRemoteBackend) {
      return;
    }
    try {
      final rewards = await remoteService.loadRewards();
      if (!mounted || rewards == null) {
        return;
      }
      _setStateIfMapVisible(() {
        _rewards = rewards;
      });
    } catch (_) {
      // Sem servidor, o cabeçalho segue com os pontos do aparelho.
    }
  }

  /// Pontos mostrados no cabeçalho: os do servidor quando conectado.
  int get _displayedCommunityPoints => _rewards?.balance ?? _communityPoints;

  /// Troca pontos por dias do Essencial; devolve o saldo novo ou `null` se
  /// não deu (a mensagem já foi mostrada).
  Future<RemoteRewards?> _redeemReward() async {
    final remoteService = _crowdReportRemoteService;
    if (remoteService == null) {
      return null;
    }
    try {
      final rewards = await remoteService.redeemReward();
      if (!mounted) {
        return rewards;
      }
      _setStateIfMapVisible(() {
        _rewards = rewards;
      });
      unawaited(_syncPlanFromStorage(showExpiryNotice: false));
      _showMapSnack(_t.rewardsRedeemed('${rewards?.planDays ?? 7}'));
      unawaited(_metrics.trackEvent('reward_redeem'));
      return rewards;
    } on StateError catch (error) {
      _showMapSnack(
        error.message == 'higher_plan_active'
            ? _t.rewardsHigherPlan
            : _t.rewardsFailed,
      );
      unawaited(_refreshRewards());
      return null;
    } catch (_) {
      _showMapSnack(_t.rewardsFailed);
      return null;
    }
  }
}

/// Cartão do ranking com o saldo e a troca por dias do Essencial.
class _RewardsCard extends StatefulWidget {
  const _RewardsCard({required this.initial, required this.onRedeem});

  final RemoteRewards initial;
  final Future<RemoteRewards?> Function() onRedeem;

  @override
  State<_RewardsCard> createState() => _RewardsCardState();
}

class _RewardsCardState extends State<_RewardsCard> {
  late RemoteRewards _rewards = widget.initial;
  bool _redeeming = false;

  Future<void> _redeem() async {
    setState(() => _redeeming = true);
    final updated = await widget.onRedeem();
    if (!mounted) {
      return;
    }
    setState(() {
      _redeeming = false;
      if (updated != null) {
        _rewards = updated;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rewards = _rewards;
    final progress = (rewards.balance / rewards.costPoints).clamp(0.0, 1.0);
    final higherPlan = rewards.blockedReason == 'higher_plan_active';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: withUiOpacity(AppBrand.teal, 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: withUiOpacity(AppBrand.teal, 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t.rewardsTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            _t.rewardsOffer('${rewards.costPoints}', '${rewards.planDays}'),
            style: const TextStyle(color: GymMapColors.panelSubtitle),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppBrand.tealDeep,
              backgroundColor: withUiOpacity(AppBrand.teal, 0.16),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            higherPlan
                ? _t.rewardsHigherPlan
                : _t.rewardsProgress(
                  '${rewards.balance}',
                  '${rewards.costPoints}',
                ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            _t.rewardsHowToEarn,
            style: const TextStyle(
              fontSize: 12,
              color: GymMapColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: rewards.canRedeem && !_redeeming ? _redeem : null,
              child:
                  _redeeming
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                      : Text(_t.rewardsRedeem('${rewards.planDays}')),
            ),
          ),
        ],
      ),
    );
  }
}
