import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

const Widget _pinImage = Image(
  image: AssetImage('assets/brand/pin.png'),
  width: 32,
  height: 32,
  fit: BoxFit.contain,
);

/// Tons de cinza (luminância), para o pino de academia fechada.
const ColorFilter _grayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Marcador de academia exibindo lotação e estado de seleção.
class GymMarkerBubble extends StatefulWidget {
  const GymMarkerBubble({
    super.key,
    required this.label,
    required this.percent,
    required this.isOpenNow,
    required this.isFavorite,
    required this.selected,
    required this.revealDetails,
    this.enablePulse = true,
    required this.onTap,
  });

  final String label;
  final int percent;
  final bool isOpenNow;
  final bool isFavorite;
  final bool selected;
  final bool revealDetails;
  final bool enablePulse;
  final VoidCallback onTap;

  @override
  State<GymMarkerBubble> createState() => _GymMarkerBubbleState();
}

class _GymMarkerBubbleState extends State<GymMarkerBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  bool get _isLowCrowd => widget.isOpenNow && widget.percent <= 35;
  bool get _shouldPulse =>
      widget.enablePulse &&
      widget.revealDetails &&
      _isLowCrowd &&
      !widget.selected;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _syncPulseAnimation();
  }

  @override
  void didUpdateWidget(covariant GymMarkerBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent ||
        oldWidget.isOpenNow != widget.isOpenNow ||
        oldWidget.selected != widget.selected ||
        oldWidget.revealDetails != widget.revealDetails ||
        oldWidget.enablePulse != widget.enablePulse) {
      _syncPulseAnimation();
    }
  }

  void _syncPulseAnimation() {
    if (_shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      return;
    }
    _pulseController.stop();
    _pulseController.value = 0;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isOpenNow
            ? occupancyColor(widget.percent)
            : GymMapColors.textSecondary;
    const markerInfoOffsetY = 18.0;
    final showLowCrowdTag = widget.revealDetails && _isLowCrowd;
    final occupancySemantics =
        widget.isOpenNow
            ? _t.markerOccupancySemantics('${widget.percent}')
            : _t.markerClosedNow;

    return Semantics(
      button: true,
      label:
          '${widget.label}, $occupancySemantics${widget.isFavorite ? _t.markerFavoriteSuffix : ''}',
      hint: _t.markerTapHint,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          // Encosta o conteúdo na base: a ponta do pino fica sempre à mesma
          // distância da base, qualquer que seja o tamanho do nome.
          alignment: Alignment.bottomCenter,
          transformAlignment: Alignment.bottomCenter,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          transform:
              Matrix4.identity()..scaleByDouble(
                widget.selected ? 1.05 : 1.0,
                widget.selected ? 1.05 : 1.0,
                1.0,
                1.0,
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fechada não tem selo: o próprio pino fica cinza e apagado.
              if (widget.isOpenNow) ...[
                Transform.translate(
                  offset: const Offset(0, markerInfoOffsetY),
                  child: AnimatedOpacity(
                    opacity: widget.revealDetails ? 1 : 0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    child: AnimatedScale(
                      scale: widget.revealDetails ? 1 : 0.84,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: color),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedColor, _) {
                          final badgeColor = animatedColor ?? color;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                  color: withUiOpacity(badgeColor, 0.32),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.groups_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.percent}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Transform.translate(
                offset: const Offset(0, markerInfoOffsetY),
                child: AnimatedOpacity(
                  opacity: widget.revealDetails ? 1 : 0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: AnimatedScale(
                    scale: widget.revealDetails ? 1 : 0.84,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    child: SizedBox(
                      width: 138,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.isFavorite) ...[
                            const Icon(
                              Icons.favorite_rounded,
                              size: 12,
                              color: GymMapColors.occupancyCritical,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    widget.isOpenNow
                                        ? GymMapColors.mapLabel
                                        : GymMapColors.textSecondary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                height: 1.04,
                                shadows: [
                                  Shadow(
                                    color: GymMapColors.textShadow,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 1),
              SizedBox(
                width: 86,
                height: 66,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulseFactor = Curves.easeInOut.transform(
                          _pulseController.value,
                        );
                        final pulseScale = 1 + (pulseFactor * 0.18);
                        final pulseOpacity = 0.08 + (pulseFactor * 0.12);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_shouldPulse)
                              Transform.scale(
                                scale: pulseScale,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: withUiOpacity(
                                      GymMapColors.occupancyLow,
                                      pulseOpacity,
                                    ),
                                    border: Border.all(
                                      color: withUiOpacity(
                                        GymMapColors.occupancyLow,
                                        pulseOpacity + 0.08,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius:
                                        widget.selected
                                            ? 12
                                            : 6 +
                                                (_shouldPulse
                                                    ? pulseFactor * 5
                                                    : 0),
                                    offset: const Offset(0, 3),
                                    color: withUiOpacity(
                                      color,
                                      widget.selected
                                          ? 0.30
                                          : 0.16 +
                                              (_shouldPulse
                                                  ? pulseFactor * 0.08
                                                  : 0),
                                    ),
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          ],
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            widget.isOpenNow
                                ? _pinImage
                                : const Opacity(
                                  opacity: 0.6,
                                  child: ColorFiltered(
                                    colorFilter: _grayscale,
                                    child: _pinImage,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child:
                    showLowCrowdTag
                        ? Padding(
                          key: const ValueKey<String>('low-crowd-tag-visible'),
                          padding: const EdgeInsets.only(top: 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: withUiOpacity(
                                GymMapColors.occupancyLow,
                                0.12,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: withUiOpacity(
                                  GymMapColors.occupancyLow,
                                  0.28,
                                ),
                              ),
                            ),
                            child: Text(
                              _t.markerGoodMoment,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: GymMapColors.occupancyLow,
                              ),
                            ),
                          ),
                        )
                        : const SizedBox.shrink(
                          key: ValueKey<String>('low-crowd-tag-hidden'),
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
