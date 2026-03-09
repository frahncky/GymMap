import 'package:flutter/material.dart';

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

/// Converte percentual em descricao de status.
String occupancyLabel(int percent) {
  if (percent <= 35) {
    return 'Baixa';
  }
  if (percent <= 65) {
    return 'Moderada';
  }
  if (percent <= 85) {
    return 'Alta';
  }
  return 'Muito alta';
}

/// Formata tempo relativo do ultimo relato para leitura humana.
String formatRelativeTime(DateTime? timestamp) {
  if (timestamp == null) {
    return 'sem informações';
  }

  final now = DateTime.now();
  final diff = now.difference(timestamp);

  if (diff.inMinutes < 1) {
    return 'agora';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes} min atrás';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours} h atrás';
  }

  final day = timestamp.day.toString().padLeft(2, '0');
  final month = timestamp.month.toString().padLeft(2, '0');
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

