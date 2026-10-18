import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/gym_models.dart';
import 'gym_map_colors.dart';

/// Compatibilidade entre versoes do Flutter sem depender de withValues/withOpacity.
Color withUiOpacity(Color color, double opacity) {
  final alpha = (opacity * 255).round().clamp(0, 255).toInt();
  return color.withAlpha(alpha);
}

/// Define a cor usada para lotação por faixa percentual.
Color occupancyColor(int percent) {
  if (percent <= 35) {
    return GymMapColors.occupancyLow;
  }
  if (percent <= 65) {
    return GymMapColors.occupancyMedium;
  }
  if (percent <= 85) {
    return GymMapColors.occupancyHigh;
  }
  return GymMapColors.occupancyCritical;
}

/// Variante contínua para transição suave de cores conforme o percentual muda.
Color occupancyColorForValue(double percent) {
  final value = percent.clamp(0, 100).toDouble();
  if (value <= 35) {
    return GymMapColors.occupancyLow;
  }
  if (value <= 65) {
    final t = (value - 35) / 30;
    return Color.lerp(
          GymMapColors.occupancyLow,
          GymMapColors.occupancyMedium,
          t,
        ) ??
        GymMapColors.occupancyMedium;
  }
  if (value <= 85) {
    final t = (value - 65) / 20;
    return Color.lerp(
          GymMapColors.occupancyMedium,
          GymMapColors.occupancyHigh,
          t,
        ) ??
        GymMapColors.occupancyHigh;
  }
  final t = (value - 85) / 15;
  return Color.lerp(
        GymMapColors.occupancyHigh,
        GymMapColors.occupancyCritical,
        t,
      ) ??
      GymMapColors.occupancyCritical;
}

/// Converte percentual em descricao de status.
/// Nome da academia para exibir: o nome genérico gravado para academias sem
/// nome no OpenStreetMap ([kUnnamedGymName]) aparece traduzido.
String displayGymName(String name) =>
    name == kUnnamedGymName ? AppL10n.current.gymUnnamed : name;

/// Nome da comodidade no idioma em uso.
String amenityLabel(GymAmenity amenity) {
  final t = AppL10n.current;
  return switch (amenity) {
    GymAmenity.weights => t.amenityWeights,
    GymAmenity.cardio => t.amenityCardio,
    GymAmenity.groupClasses => t.amenityGroupClasses,
    GymAmenity.pool => t.amenityPool,
    GymAmenity.crossfit => t.amenityCrossfit,
    GymAmenity.pilates => t.amenityPilates,
    GymAmenity.martialArts => t.amenityMartialArts,
    GymAmenity.functionalDance => t.amenityFunctionalDance,
    GymAmenity.lockerRoom => t.amenityLockerRoom,
    GymAmenity.airConditioning => t.amenityAirConditioning,
    GymAmenity.parking => t.amenityParking,
    GymAmenity.accessibility => t.amenityAccessibility,
    GymAmenity.open24h => t.amenityOpen24h,
    GymAmenity.personalTrainer => t.amenityPersonalTrainer,
    GymAmenity.fitnessAssessment => t.amenityFitnessAssessment,
  };
}

/// Ícone da marca para a comodidade (gerado por tool/brand/gerar_marca.ps1).
String amenityIconAsset(GymAmenity amenity) =>
    'assets/brand/amenity_${amenity.key}.png';

String occupancyLabel(int percent) {
  if (percent <= 35) {
    return AppL10n.current.occupancyLevelLow;
  }
  if (percent <= 65) {
    return AppL10n.current.occupancyLevelModerate;
  }
  if (percent <= 85) {
    return AppL10n.current.occupancyLevelHigh;
  }
  return AppL10n.current.occupancyLevelVeryHigh;
}

/// Formata tempo relativo do ultimo relato para leitura humana.
String formatRelativeTime(DateTime? timestamp) {
  if (timestamp == null) {
    return AppL10n.current.timeNoInfo;
  }

  final now = DateTime.now();
  final diff = now.difference(timestamp);

  if (diff.inMinutes < 1) {
    return AppL10n.current.timeNow;
  }
  if (diff.inHours < 1) {
    return AppL10n.current.timeMinutesAgo('${diff.inMinutes}');
  }
  if (diff.inDays < 1) {
    return AppL10n.current.timeHoursAgo('${diff.inHours}');
  }

  final day = timestamp.day.toString().padLeft(2, '0');
  final month = timestamp.month.toString().padLeft(2, '0');
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}
