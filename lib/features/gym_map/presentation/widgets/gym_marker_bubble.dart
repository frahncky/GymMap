import 'package:flutter/material.dart';

import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

/// Marcador de academia exibindo lotação e estado de selecao.
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                  style: TextStyle(
                    color: GymMapColors.mapLabel,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    shadows: const [
                      Shadow(color: GymMapColors.textShadow, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/logo/pinGym.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
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
                          Shadow(color: GymMapColors.textShadow, blurRadius: 4),
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
    );
  }
}
