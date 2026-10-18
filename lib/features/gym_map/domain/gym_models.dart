import 'package:latlong2/latlong.dart';

/// Nome gravado para academias sem nome no OpenStreetMap. É dado (cache e
/// servidor); na tela use `displayGymName`, que traduz.
const String kUnnamedGymName = 'Academia';

/// Endereço gravado para academias vindas do mapa, sem endereço conhecido.
/// É dado; na tela é traduzido.
const String kMapGymAddress = 'Academia encontrada no mapa';

// Comodidades gravadas (os filtros "Aulas", "Cardio" e "Com piscina" procuram
// por estes textos). Na tela, converta com [GymAmenity.fromStored].
const String kAmenityWeights = 'Musculação';
const String kAmenityCardio = 'Cardio';
const String kAmenityGroupClasses = 'Aulas coletivas';
const String kAmenityPool = 'Piscina';

/// Comodidades que a comunidade marca e valida. [key] é o nome no servidor.
enum GymAmenity {
  weights('weights'),
  cardio('cardio'),
  groupClasses('group_classes'),
  pool('pool'),
  crossfit('crossfit'),
  pilates('pilates'),
  martialArts('martial_arts'),
  functionalDance('functional_dance'),
  lockerRoom('locker_room'),
  airConditioning('air_conditioning'),
  parking('parking'),
  accessibility('accessibility'),
  open24h('open_24h'),
  personalTrainer('personal_trainer'),
  fitnessAssessment('fitness_assessment');

  const GymAmenity(this.key);

  final String key;

  static GymAmenity? fromKey(String key) {
    for (final amenity in values) {
      if (amenity.key == key) {
        return amenity;
      }
    }
    return null;
  }

  /// Comodidade equivalente aos textos gravados em [Gym.amenities].
  static GymAmenity? fromStored(String stored) => switch (stored) {
    kAmenityWeights => weights,
    kAmenityCardio => cardio,
    kAmenityGroupClasses => groupClasses,
    kAmenityPool => pool,
    _ => null,
  };
}

/// Situação de uma comodidade numa academia, segundo os votos.
enum AmenityVoteStatus { confirmed, pending, rejected }

/// Votos da comunidade numa comodidade de uma academia.
class GymAmenityVotes {
  const GymAmenityVotes({
    required this.amenity,
    required this.yes,
    required this.no,
    required this.status,
    this.userVote,
  });

  final GymAmenity amenity;
  final int yes;
  final int no;
  final AmenityVoteStatus status;

  /// Voto de quem está usando o app: `true` (tem), `false` (não tem) ou
  /// `null` (não votou).
  final bool? userVote;
}

/// Representa uma academia no mapa.
class Gym {
  const Gym({
    required this.id,
    required this.name,
    required this.address,
    required this.position,
    required this.amenities,
  });

  /// Identificador unico usado para relacionar relatos colaborativos.
  final String id;

  /// Nome exibido na interface.
  final String name;

  /// Endereço/bairro exibido ao usuário.
  final String address;

  /// Coordenada geografica da academia.
  final LatLng position;

  /// Comodidades disponiveis na academia.
  final List<String> amenities;
}

/// Relato colaborativo de lotação enviado por usuário.
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

  /// Lotação pelo consenso dos relatos, ou `null` (sem informação) quando
  /// ainda não há relatos suficientes. O app não inventa um número.
  final int? occupancyPercent;
  final int reportsCount;
  final int recentReportsCount;
  final DateTime? lastReportAt;
}

/// Base local removida: o app usa dados externos/tempo real.
class DemoGyms {
  static final List<Gym> all = <Gym>[];
}
