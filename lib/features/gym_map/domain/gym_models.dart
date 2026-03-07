import 'package:latlong2/latlong.dart';

/// Representa uma academia no mapa.
class Gym {
  const Gym({
    required this.id,
    required this.name,
    required this.address,
    required this.position,
    required this.capacity,
    required this.baseOccupancyPercent,
    required this.amenities,
  });

  /// Identificador unico usado para relacionar relatos colaborativos.
  final String id;

  /// Nome exibido na interface.
  final String name;

  /// Endereco/bairro exibido ao usuario.
  final String address;

  /// Coordenada geografica da academia.
  final LatLng position;

  /// Capacidade total estimada da unidade.
  final int capacity;

  /// Valor de fallback quando ainda nao ha relatos.
  final int baseOccupancyPercent;

  /// Comodidades disponiveis na academia.
  final List<String> amenities;
}

/// Relato colaborativo de lotação enviado por usuario.
class CrowdReport {
  const CrowdReport({
    required this.gymId,
    required this.occupancyPercent,
    required this.createdAt,
    this.reporterId = 'anonymous',
    this.reliabilityWeight = 1.0,
  });

  final String gymId;
  final int occupancyPercent;
  final DateTime createdAt;
  final String reporterId;
  final double reliabilityWeight;
}

/// Resultado agregado para exibir lotação e metadados no app.
class GymCrowdSnapshot {
  const GymCrowdSnapshot({
    required this.occupancyPercent,
    required this.reportsCount,
    required this.recentReportsCount,
    required this.lastReportAt,
  });

  final int occupancyPercent;
  final int reportsCount;
  final int recentReportsCount;
  final DateTime? lastReportAt;
}

/// Base local removida: o app usa dados externos/tempo real.
class DemoGyms {
  static final List<Gym> all = <Gym>[];
}
