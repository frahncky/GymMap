import 'package:flutter/material.dart';

import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

/// Botao que corrige apenas a orientacao do mapa para o norte.
class NorthResetButton extends StatelessWidget {
  const NorthResetButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: withUiOpacity(Colors.white, 0.96),
            shape: BoxShape.circle,
            border: Border.all(color: GymMapColors.northControl, width: 1.6),
            boxShadow: const [
              BoxShadow(
                blurRadius: 8,
                color: GymMapColors.floatingControlShadow,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'N',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: GymMapColors.northControl,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botao para centralizar o mapa na localização atual do aparelho.
class MyLocationButton extends StatelessWidget {
  const MyLocationButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: withUiOpacity(Colors.white, 0.96),
            shape: BoxShape.circle,
            border: Border.all(
              color: GymMapColors.myLocationAccent,
              width: 1.6,
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 8,
                color: GymMapColors.floatingControlShadow,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.my_location,
              size: 18,
              color: GymMapColors.myLocationAccent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Marcador visual da posicao atual do usuario no mapa.
class UserLocationMarkerDot extends StatelessWidget {
  const UserLocationMarkerDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: withUiOpacity(GymMapColors.myLocationAccent, 0.20),
          ),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: GymMapColors.myLocationGlow,
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.location_on_rounded,
              size: 16,
              color: GymMapColors.myLocationAccent,
            ),
          ),
        ),
      ],
    );
  }
}
