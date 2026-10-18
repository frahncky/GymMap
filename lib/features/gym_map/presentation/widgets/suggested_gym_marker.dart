import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

/// Pino de uma academia sugerida que ainda não foi confirmada: pino da marca
/// mais claro, com um "?" laranja e a etiqueta "A confirmar". A ponta do pino
/// fica no pé do widget (use com `Alignment.topCenter` no Marker).
class SuggestedGymMarker extends StatelessWidget {
  const SuggestedGymMarker({
    super.key,
    required this.name,
    required this.onTap,
  });

  final String name;
  final VoidCallback onTap;

  static const double width = 140;
  static const double height = 96;

  @override
  Widget build(BuildContext context) {
    final label = AppL10n.current.suggestionPendingLabel;
    return Semantics(
      button: true,
      label: '$name, $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GymMapColors.mapLabel,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  shadows: [
                    Shadow(color: GymMapColors.textShadow, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppBrand.orangeDeep),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppBrand.orangeDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 36,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: 0.7,
                      child: Image.asset(
                        'assets/brand/pin.png',
                        width: 36,
                        height: 46,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppBrand.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.4),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 4,
                              color: withUiOpacity(AppBrand.orange, 0.4),
                            ),
                          ],
                        ),
                        child: const Text(
                          '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
