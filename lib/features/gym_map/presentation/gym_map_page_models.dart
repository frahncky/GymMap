part of 'gym_map_page.dart';

enum AppPlanTier { free, smart, pro, elite }

enum MapQuickFilter {
  openNow,
  lowCrowd,
  withClasses,
  withCardio,
  withPool,
  favorites,
}

class PlanInfo {
  const PlanInfo({
    required this.label,
    required this.monthlyPrice,
    required this.insights,
  });

  final String label;
  final String monthlyPrice;
  final List<String> insights;
}

class _CommunityLeaderboardEntry {
  const _CommunityLeaderboardEntry({
    required this.name,
    required this.points,
    required this.isCurrentUser,
  });

  final String name;
  final int points;
  final bool isCurrentUser;
}

class _CommunityLeaderboardSheetData {
  const _CommunityLeaderboardSheetData({
    required this.entries,
    required this.userRank,
    required this.userPoints,
    required this.regionLabel,
    required this.isRegional,
  });

  final List<_CommunityLeaderboardEntry> entries;
  final int userRank;
  final int userPoints;
  final String regionLabel;
  final bool isRegional;
}

class _MapDerivedData {
  const _MapDerivedData({
    required this.snapshotsByGymId,
    required this.filteredGyms,
    required this.filteredMapPois,
  });

  final Map<String, GymCrowdSnapshot> snapshotsByGymId;
  final List<Gym> filteredGyms;
  final List<MapGymPoi> filteredMapPois;
}

const Map<AppPlanTier, PlanInfo> kPlanCatalog = {
  AppPlanTier.free: PlanInfo(
    label: 'Grátis',
    monthlyPrice: 'R\$ 0/mês',
    insights: ['Lotação atual'],
  ),
  AppPlanTier.smart: PlanInfo(
    label: 'Essencial',
    monthlyPrice: 'R\$ 4,90/mês',
    insights: ['Lotação atual', 'Histórico das últimas 24h'],
  ),
  AppPlanTier.pro: PlanInfo(
    label: 'Pro',
    monthlyPrice: 'R\$ 19,90/mês',
    insights: [
      'Lotação atual',
      'Histórico das últimas 24h',
      'Horários de pico por dia',
      'Comparativo entre academias',
    ],
  ),
  AppPlanTier.elite: PlanInfo(
    label: 'Elite',
    monthlyPrice: 'R\$ 34,90/mês',
    insights: [
      'Lotação atual',
      'Histórico das últimas 24h',
      'Horários de pico por dia',
      'Comparativo entre academias',
      'Previsão de lotação para próximas horas',
      'Cobertura em qualquer lugar do país',
      'Alertas personalizados',
    ],
  ),
};

class PlanThemePalette {
  const PlanThemePalette._();

  static const Map<AppPlanTier, Color> tierColors = <AppPlanTier, Color>{
    AppPlanTier.free: Color(0xFF8E949C),
    AppPlanTier.smart: Color(0xFF0D8B6E),
    AppPlanTier.pro: Color(0xFF153A73),
    AppPlanTier.elite: Color(0xFFC79A22),
  };

  static Color colorFor(AppPlanTier tier) {
    return tierColors[tier] ?? tierColors[AppPlanTier.free]!;
  }

  static Color onColorFor(AppPlanTier tier) {
    final brightness = ThemeData.estimateBrightnessForColor(colorFor(tier));
    return brightness == Brightness.dark ? Colors.white : Colors.black87;
  }
}
