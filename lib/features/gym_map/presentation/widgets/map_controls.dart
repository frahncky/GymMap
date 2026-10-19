import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
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
      label: _t.controlsNorthLabel,
      hint: _t.controlsNorthHint,
      child: Tooltip(
        message: _t.controlsNorthTooltip,
        child: _MapRoundButton(
          onTap: onTap,
          color: withUiOpacity(Colors.white, 0.96),
          borderColor: primary,
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
      label: _t.controlsMyLocationLabel,
      hint: _t.controlsMyLocationHint,
      child: Tooltip(
        message: _t.controlsMyLocationTooltip,
        child: _MapRoundButton(
          onTap: onTap,
          color: withUiOpacity(Colors.white, 0.96),
          borderColor: primary,
          child: Center(
            child: Icon(Icons.my_location, size: 20, color: primary),
          ),
        ),
      ),
    );
  }
}

/// Botão para sugerir uma academia que não está no mapa.
class AddGymButton extends StatelessWidget {
  const AddGymButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: _t.suggestAddTooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: _t.suggestAddTooltip,
        child: _MapRoundButton(
          onTap: onTap,
          color: withUiOpacity(Colors.white, 0.96),
          borderColor: primary,
          child: Center(
            child: Icon(
              Icons.add_location_alt_rounded,
              size: 22,
              color: primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão que abre a escolha dos locais do mapa base (paradas de ônibus,
/// lojas, restaurantes etc.). Fica destacado quando há categorias ocultas.
class BasemapPoiToggleButton extends StatelessWidget {
  const BasemapPoiToggleButton({
    super.key,
    required this.hidden,
    required this.onTap,
  });

  /// `true` quando alguma categoria de locais está oculta.
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final label = _t.controlsPlaces;
    return Semantics(
      button: true,
      toggled: hidden,
      label: label,
      child: Tooltip(
        message: label,
        child: _MapRoundButton(
          onTap: onTap,
          color: hidden ? primary : withUiOpacity(Colors.white, 0.96),
          borderColor: primary,
          child: Center(
            child: Icon(
              hidden ? Icons.layers_clear_rounded : Icons.layers_rounded,
              size: 20,
              color: hidden ? Colors.white : primary,
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
        label: _t.controlsUpdatingGymsLabel,
        readOnly: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: withUiOpacity(Colors.white, 0.95),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: withUiOpacity(primary, 0.18)),
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
                  _t.controlsUpdatingGyms,
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
      label: _t.controlsYourLocation,
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
              child: Icon(Icons.location_on_rounded, size: 16, color: primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão redondo dos controles do mapa. A sombra fica fora do Material:
/// dentro dele ela é cortada no quadrado do botão e aparece como um fundo
/// quadrado claro.
class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    required this.onTap,
    required this.color,
    required this.borderColor,
    required this.child,
  });

  final VoidCallback onTap;
  final Color color;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: GymMapColors.floatingControlShadow,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: color,
        shape: CircleBorder(side: BorderSide(color: borderColor, width: 1.6)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 48, height: 48, child: child),
        ),
      ),
    );
  }
}

/// Traduções do idioma em uso.
AppLocalizations get _t => AppL10n.current;
