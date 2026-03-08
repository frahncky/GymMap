import 'package:flutter/material.dart';

import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

class QuickFilterChipData {
  const QuickFilterChipData({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool selected;
}

class GymPageHeader extends StatelessWidget {
  const GymPageHeader({
    super.key,
    required this.planLabel,
    required this.onOpenPlanSettings,
  });

  final String planLabel;
  final VoidCallback onOpenPlanSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: withUiOpacity(Colors.white, 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GymMap',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Lotacao em tempo real',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: withUiOpacity(Colors.white, 0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: withUiOpacity(Colors.white, 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              planLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Configuracoes de plano',
            onPressed: onOpenPlanSettings,
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class GymSearchField extends StatelessWidget {
  const GymSearchField({
    super.key,
    required this.controller,
    required this.searchTerm,
    required this.isResolvingSearchLocation,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onSearchTap,
  });

  final TextEditingController controller;
  final String searchTerm;
  final bool isResolvingSearchLocation;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'Campo de busca',
      hint: 'Digite academia, bairro ou cidade',
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar academia, bairro ou cidade',
          prefixIcon: IconButton(
            onPressed: onSearchTap,
            icon: const Icon(Icons.search),
            tooltip: 'Buscar localizacao',
          ),
          suffixIcon:
              searchTerm.isEmpty
                  ? null
                  : isResolvingSearchLocation
                  ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                  : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                    tooltip: 'Limpar busca',
                  ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class MapQuickFiltersBar extends StatelessWidget {
  const MapQuickFiltersBar({
    super.key,
    required this.filters,
    required this.onToggle,
  });

  final List<QuickFilterChipData> filters;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: withUiOpacity(Colors.white, 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: withUiOpacity(GymMapColors.northControl, 0.08),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < filters.length; index++)
            Expanded(
              flex: _chipFlex(filters[index]),
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == filters.length - 1 ? 0 : 6,
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: _QuickFilterToggleChip(
                    filter: filters[index],
                    onToggle: onToggle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _chipFlex(QuickFilterChipData filter) {
    if (filter.id == 'low') {
      return 3;
    }
    return 2;
  }
}

class _QuickFilterToggleChip extends StatelessWidget {
  const _QuickFilterToggleChip({required this.filter, required this.onToggle});

  final QuickFilterChipData filter;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: filter.selected,
      label: filter.label,
      hint:
          filter.selected
              ? 'Toque novamente para desativar'
              : 'Toque para ativar',
      child: FilterChip(
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        avatarBoxConstraints: const BoxConstraints.tightFor(
          width: 18,
          height: 18,
        ),
        avatar: Icon(
          filter.icon,
          size: 14,
          color:
              filter.selected
                  ? Theme.of(context).colorScheme.primary
                  : GymMapColors.textSecondary,
        ),
        selected: filter.selected,
        label: Text(filter.label, maxLines: 1),
        onSelected: (_) => onToggle(filter.id),
        selectedColor: withUiOpacity(
          Theme.of(context).colorScheme.primary,
          0.14,
        ),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: withUiOpacity(
            Theme.of(context).colorScheme.primary,
            filter.selected ? 0.38 : 0.12,
          ),
        ),
        labelStyle: TextStyle(
          color:
              filter.selected
                  ? Theme.of(context).colorScheme.primary
                  : GymMapColors.textStrong,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1.5),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class SelectionHintCard extends StatelessWidget {
  const SelectionHintCard({
    super.key,
    required this.hasNoResults,
    required this.hasNoNearbyGyms,
    this.hasActiveFilters = false,
  });

  final bool hasNoResults;
  final bool hasNoNearbyGyms;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    final message =
        hasNoResults && hasActiveFilters
            ? 'Nenhuma academia corresponde aos filtros ativos.'
            : hasNoResults
            ? 'Nenhum resultado encontrado para sua busca.'
            : hasNoNearbyGyms
            ? 'Nenhuma academia cadastrada proxima da sua localizacao.'
            : 'Toque no marcador para ver detalhes da lotacao.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class AdBannerCard extends StatelessWidget {
  const AdBannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [GymMapColors.adGradientStart, GymMapColors.adGradientEnd],
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.campaign, color: GymMapColors.adIcon),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Publicidade: faca upgrade para remover anuncios.',
              style: TextStyle(
                color: GymMapColors.adText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapStatusCard extends StatelessWidget {
  const MapStatusCard({super.key, required this.message, this.loading = false});

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
      ),
      child: Center(
        child:
            loading
                ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Localizando voce...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: GymMapColors.textStrong,
                      ),
                    ),
                  ],
                )
                : Text(message),
      ),
    );
  }
}

class MapTutorialOverlay extends StatelessWidget {
  const MapTutorialOverlay({
    super.key,
    required this.onDismiss,
    required this.onFocusNearestGym,
  });

  final VoidCallback onDismiss;
  final VoidCallback onFocusNearestGym;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: withUiOpacity(Colors.black, 0.26),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: withUiOpacity(GymMapColors.northControl, 0.10),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 14,
                        color: GymMapColors.cardShadow,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dicas rapidas do mapa',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: GymMapColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _TutorialHintRow(
                        icon: Icons.search_rounded,
                        text: 'Use a busca para academia, bairro ou cidade.',
                      ),
                      const SizedBox(height: 6),
                      const _TutorialHintRow(
                        icon: Icons.tune_rounded,
                        text: 'Ative os toggles para filtrar os resultados.',
                      ),
                      const SizedBox(height: 6),
                      const _TutorialHintRow(
                        icon: Icons.location_on_rounded,
                        text:
                            'Toque no pin para abrir detalhes e enviar relato.',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onDismiss,
                              child: const Text('Entendi'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onFocusNearestGym,
                              icon: const Icon(Icons.near_me_rounded, size: 18),
                              label: const Text('Ver proxima'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onDismiss,
                child: const Text('Pular tutorial'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialHintRow extends StatelessWidget {
  const _TutorialHintRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: GymMapColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: GymMapColors.textStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
