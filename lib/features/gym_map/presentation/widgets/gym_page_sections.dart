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
    required this.onClearAll,
  });

  final List<QuickFilterChipData> filters;
  final ValueChanged<String> onToggle;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final hasAnySelected = filters.any((filter) => filter.selected);

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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Semantics(
                        button: true,
                        selected: filter.selected,
                        label: filter.label,
                        hint:
                            filter.selected
                                ? 'Toque para remover filtro'
                                : 'Toque para aplicar filtro',
                        child: FilterChip(
                          showCheckmark: false,
                          avatar: Icon(
                            filter.icon,
                            size: 16,
                            color:
                                filter.selected
                                    ? Theme.of(context).colorScheme.primary
                                    : GymMapColors.textSecondary,
                          ),
                          selected: filter.selected,
                          label: Text(filter.label),
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
                          visualDensity: const VisualDensity(
                            horizontal: -1,
                            vertical: -1.5,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (hasAnySelected)
            TextButton.icon(
              onPressed: onClearAll,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Limpar'),
            ),
        ],
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
