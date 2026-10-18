import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/gym_models.dart';
import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

/// Lista para marcar o que a academia oferece. Cada item mostra a situação
/// na comunidade e uma caixa. Marcar um item que o card não mostra é dizer
/// "tem"; desmarcar um que o card mostra é dizer "não tem". Nos dois casos a
/// mudança só vale para todos quando a comunidade concorda.
class AmenityVoteSheet extends StatefulWidget {
  const AmenityVoteSheet({
    super.key,
    required this.gymName,
    required this.votes,
    required this.confirmThreshold,
    required this.onSubmit,
    this.shown = const <GymAmenity>{},
  });

  /// O que o card mostra hoje: vem marcado, a menos que a pessoa já tenha
  /// dito "não tem". Só o que ela mudar é enviado.
  final Set<GymAmenity> shown;

  final String gymName;

  /// Votos atuais da academia (só os itens que já receberam algum voto).
  final List<GymAmenityVotes> votes;
  final int confirmThreshold;

  /// Envia só o que mudou; devolve `true` se deu certo (a lista fecha).
  final Future<bool> Function(Map<GymAmenity, bool?> changes) onSubmit;

  @override
  State<AmenityVoteSheet> createState() => _AmenityVoteSheetState();
}

class _AmenityVoteSheetState extends State<AmenityVoteSheet> {
  late final Map<GymAmenity, GymAmenityVotes> _votesByAmenity = {
    for (final vote in widget.votes) vote.amenity: vote,
  };
  late final Map<GymAmenity, bool?> _initial = {
    for (final amenity in widget.shown) amenity: true,
    for (final vote in widget.votes)
      if (vote.userVote != null) vote.amenity: vote.userVote,
  };
  late final Map<GymAmenity, bool?> _selection = {..._initial};
  bool _sending = false;

  /// O que a pessoa mudou em relação ao que viu ao abrir.
  Map<GymAmenity, bool?> get _changes => {
    for (final amenity in GymAmenity.values)
      if (_selection[amenity] != _initial[amenity])
        amenity: _selection[amenity],
  };

  /// Marcar = "tem". Desmarcar algo que o card mostra = "não tem"; desmarcar
  /// algo que não aparece só retira a marcação.
  void _toggle(GymAmenity amenity) {
    setState(() {
      _selection[amenity] =
          _selection[amenity] == true
              ? (widget.shown.contains(amenity) ? false : null)
              : true;
    });
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    final ok = await widget.onSubmit(_changes);
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changes = _changes;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t.amenitySheetTitle(widget.gymName),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _t.amenitySheetSubtitle('${widget.confirmThreshold}'),
              style: const TextStyle(color: GymMapColors.panelSubtitle),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: GymAmenity.values.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final amenity = GymAmenity.values[index];
                  return _AmenityVoteRow(
                    amenity: amenity,
                    votes: _votesByAmenity[amenity],
                    confirmThreshold: widget.confirmThreshold,
                    shown: widget.shown.contains(amenity),
                    checked: _selection[amenity] == true,
                    onToggle: () => _toggle(amenity),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t.amenityPointsHint,
              style: const TextStyle(
                color: AppBrand.tealDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: changes.isEmpty || _sending ? null : _submit,
                child:
                    _sending
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                        : Text(_t.amenitySave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmenityVoteRow extends StatelessWidget {
  const _AmenityVoteRow({
    required this.amenity,
    required this.votes,
    required this.confirmThreshold,
    required this.shown,
    required this.checked,
    required this.onToggle,
  });

  final GymAmenity amenity;
  final GymAmenityVotes? votes;
  final int confirmThreshold;

  /// Se o card mostra o item (aí os votos que contam são os de "não tem").
  final bool shown;
  final bool checked;
  final VoidCallback onToggle;

  String? get _statusLabel {
    final current = votes;
    if (current == null) {
      return null;
    }
    return switch (current.status) {
      AmenityVoteStatus.confirmed => _t.amenityStatusConfirmed(
        '${current.yes}',
      ),
      AmenityVoteStatus.rejected => _t.amenityStatusRejected,
      AmenityVoteStatus.pending =>
        shown && current.no > 0
            ? _t.amenityStatusRemovalPending(
              '${current.no}',
              '$confirmThreshold',
            )
            : current.yes > 0
            ? _t.amenityStatusPending('${current.yes}', '$confirmThreshold')
            : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel;
    final confirmed = votes?.status == AmenityVoteStatus.confirmed;
    return Semantics(
      checked: checked,
      label: amenityLabel(amenity),
      excludeSemantics: true,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: withUiOpacity(AppBrand.teal, 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  amenityIconAsset(amenity),
                  width: 26,
                  height: 26,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amenityLabel(amenity),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: GymMapColors.textPrimary,
                      ),
                    ),
                    if (status != null)
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              confirmed
                                  ? AppBrand.tealDeep
                                  : GymMapColors.textSecondary,
                          fontWeight:
                              confirmed ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Checkbox(
                value: checked,
                onChanged: (_) => onToggle(),
                activeColor: AppBrand.tealDeep,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Traduções do idioma em uso.
AppLocalizations get _t => AppL10n.current;
