import 'package:flutter/material.dart';

import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

/// Marcador de academia exibindo lotacao e estado de selecao.
class GymMarkerBubble extends StatelessWidget {
  const GymMarkerBubble({
    super.key,
    required this.label,
    required this.percent,
    required this.selected,
    required this.revealDetails,
    required this.onTap,
  });

  final String label;
  final int percent;
  final bool selected;
  final bool revealDetails;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = occupancyColor(percent);
    final isLowCrowd = percent <= 35;

    return Semantics(
      button: true,
      label: '$label, lotacao de $percent por cento',
      hint: 'Toque para abrir os detalhes da academia',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          transform: Matrix4.identity()..scale(selected ? 1.05 : 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                opacity: revealDetails ? 1 : 0,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: AnimatedScale(
                  scale: revealDetails ? 1 : 0.84,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GymMapColors.mapLabel,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      shadows: [
                        Shadow(color: GymMapColors.textShadow, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: revealDetails && isLowCrowd ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
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
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: selected ? 12 : 6,
                          offset: const Offset(0, 3),
                          color: withUiOpacity(color, selected ? 0.30 : 0.16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/logo/pinGym.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    width: revealDetails ? 8 : 0,
                  ),
                  AnimatedOpacity(
                    opacity: revealDetails ? 1 : 0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    child: AnimatedScale(
                      scale: revealDetails ? 1 : 0.84,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: Text(
                        '$percent%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          shadows: const [
                            Shadow(
                              color: GymMapColors.textShadow,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
