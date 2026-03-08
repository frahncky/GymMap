import 'package:flutter/material.dart';

import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

/// Botao que corrige apenas a orientacao do mapa para o norte.
class NorthResetButton extends StatelessWidget {
  const NorthResetButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reorientar mapa para norte',
      hint: 'Toque para voltar a orientacao para zero grau',
      child: Tooltip(
        message: 'Reorientar para norte',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: withUiOpacity(Colors.white, 0.96),
                shape: BoxShape.circle,
                border: Border.all(
                  color: GymMapColors.northControl,
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
                child: Text(
                  'N',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: GymMapColors.northControl,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botao para centralizar o mapa na localizacao atual do aparelho.
class MyLocationButton extends StatelessWidget {
  const MyLocationButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Centralizar no meu local',
      hint: 'Toque para mover o mapa para a sua posicao atual',
      child: Tooltip(
        message: 'Minha localizacao',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              width: 48,
              height: 48,
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
                  size: 20,
                  color: GymMapColors.myLocationAccent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge de carregamento exibido enquanto os POIs do mapa sao atualizados.
class MapPoiLoadingBadge extends StatelessWidget {
  const MapPoiLoadingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Atualizando academias no mapa',
        readOnly: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: withUiOpacity(Colors.white, 0.95),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: withUiOpacity(GymMapColors.northControl, 0.18),
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 2),
                color: GymMapColors.floatingControlShadow,
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: GymMapColors.northControl,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Atualizando academias...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GymMapColors.textStrong,
                  ),
                ),
              ],
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
    return Semantics(
      label: 'Sua localizacao no mapa',
      readOnly: true,
      child: Stack(
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
      ),
    );
  }
}
