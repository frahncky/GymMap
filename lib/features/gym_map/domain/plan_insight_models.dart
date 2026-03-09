/// Ponto de lotação para uma hora específica.
class HourlyOccupancyPoint {
  const HourlyOccupancyPoint({
    required this.time,
    required this.occupancyPercent,
  });

  final DateTime time;
  final int occupancyPercent;
}

/// Janela de pico detectada para o dia atual.
class PeakWindowInsight {
  const PeakWindowInsight({required this.hour, required this.occupancyPercent});

  final int hour;
  final int occupancyPercent;
}

/// Linha comparativa entre academias (lotação e diferença).
class GymComparisonInsight {
  const GymComparisonInsight({
    required this.gymName,
    required this.occupancyPercent,
    required this.deltaFromSelected,
  });

  final String gymName;
  final int occupancyPercent;
  final int deltaFromSelected;
}

/// Ponto de previsão para as próximas horas.
class ForecastInsightPoint {
  const ForecastInsightPoint({
    required this.time,
    required this.occupancyPercent,
  });

  final DateTime time;
  final int occupancyPercent;
}

