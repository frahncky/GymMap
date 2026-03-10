import 'package:flutter/material.dart';

import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

/// Botão que corrige apenas a orientação do mapa para o norte.
class NorthResetButton extends StatelessWidget {
  const NorthResetButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: 'Reorientar mapa para norte',
      hint: 'Toque para voltar a orientação para zero grau',
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
                  color: primary,
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
              child: Center(
                child: Text(
                  'N',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: primary,
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

/// Botão para centralizar o mapa na localização atual do aparelho.
class MyLocationButton extends StatelessWidget {
  const MyLocationButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: 'Centralizar no meu local',
      hint: 'Toque para mover o mapa para a sua posição atual',
      child: Tooltip(
        message: 'Minha localização',
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
                  color: primary,
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
              child: Center(
                child: Icon(
                  Icons.my_location,
                  size: 20,
                  color: primary,
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
    final primary = Theme.of(context).colorScheme.primary;
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
              color: withUiOpacity(primary, 0.18),
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, 2),
                color: GymMapColors.floatingControlShadow,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: primary,
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

/// Marcador visual da posição atual do usuário no mapa.
class UserLocationMarkerDot extends StatelessWidget {
  const UserLocationMarkerDot({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Sua localização no mapa',
      readOnly: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: withUiOpacity(primary, 0.20),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: primary.withValues(alpha: 0.42),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.location_on_rounded,
                size: 16,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
