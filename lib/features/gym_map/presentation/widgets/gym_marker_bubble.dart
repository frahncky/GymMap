import 'package:flutter/material.dart';

import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

/// Marcador de academia exibindo lotacao e estado de selecao.
class GymMarkerBubble extends StatefulWidget {
  const GymMarkerBubble({
    super.key,
    required this.label,
    required this.percent,
    required this.isFavorite,
    required this.selected,
    required this.revealDetails,
    required this.onTap,
  });

  final String label;
  final int percent;
  final bool isFavorite;
  final bool selected;
  final bool revealDetails;
  final VoidCallback onTap;

  @override
  State<GymMarkerBubble> createState() => _GymMarkerBubbleState();
}

class _GymMarkerBubbleState extends State<GymMarkerBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  bool get _isLowCrowd => widget.percent <= 35;
  bool get _shouldPulse => _isLowCrowd && !widget.selected;

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
        oldWidget.selected != widget.selected) {
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
    final color = occupancyColor(widget.percent);
    const markerInfoOffsetY = 18.0;

    return Semantics(
      button: true,
      label:
          '${widget.label}, lotacao de ${widget.percent} por cento${widget.isFavorite ? ', favorita' : ''}',
      hint: 'Toque para abrir os detalhes da academia',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          transform: Matrix4.identity()..scale(widget.selected ? 1.05 : 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                            color: withUiOpacity(color, 0.32),
                          ),
                        ],
                      ),
                      child: Text(
                        '${widget.percent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
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
                              style: const TextStyle(
                                color: GymMapColors.mapLabel,
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
                        child: Image.asset(
                          'assets/logo/pinGym.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: widget.revealDetails && _isLowCrowd ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: withUiOpacity(GymMapColors.occupancyLow, 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: withUiOpacity(GymMapColors.occupancyLow, 0.28),
                      ),
                    ),
                    child: const Text(
                      'Bom momento',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: GymMapColors.occupancyLow,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
