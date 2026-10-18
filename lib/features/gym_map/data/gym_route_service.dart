import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'map_services_config.dart';

/// Meio de transporte do trajeto até a academia.
enum GymRouteMode {
  walking('foot'),
  driving('car');

  const GymRouteMode(this.profile);

  /// Perfil do servidor de rotas (`routed-foot` ou `routed-car`).
  final String profile;
}

/// Trajeto calculado: o desenho no mapa, a distância e o tempo estimado.
class GymRoute {
  const GymRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.mode,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final GymRouteMode mode;
}

/// Calcula trajetos com um servidor OSRM. O padrão é o do OpenStreetMap
/// alemão (FOSSGIS), que tem rotas reais a pé e de carro; o
/// servidor de demonstração do OSRM só calcula rotas de carro.
class GymRouteService {
  GymRouteService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxCachedRoutes = 30;
  static const String _userAgent = 'gymmap/1.0';

  final http.Client _httpClient;
  final Map<String, GymRoute> _cache = <String, GymRoute>{};

  void dispose() {
    _httpClient.close();
  }

  /// Trajeto de [origin] até [destination], ou `null` se o servidor falhar ou
  /// não encontrar caminho.
  Future<GymRoute?> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    required GymRouteMode mode,
  }) async {
    final key =
        '${mode.name}|${_coordinate(origin)}|${_coordinate(destination)}';
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    try {
      final response = await _httpClient
          .get(
            MapServicesConfig.routeUri(
              profile: mode.profile,
              coordinates: '${_coordinate(origin)};${_coordinate(destination)}',
            ),
            headers: const {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
            },
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return null;
      }
      final route = parseRoute(jsonDecode(response.body), mode);
      if (route != null) {
        if (_cache.length >= _maxCachedRoutes) {
          _cache.remove(_cache.keys.first);
        }
        _cache[key] = route;
      }
      return route;
    } catch (_) {
      return null;
    }
  }

  /// Lê a resposta do OSRM (`geometries=geojson`) e fica com a rota mais
  /// rápida. O servidor ordena as rotas pelo próprio critério (a pé, evita
  /// avenidas mesmo quando passar por elas é mais curto), então a primeira
  /// nem sempre é a melhor. Pública para testes.
  static GymRoute? parseRoute(Object? decoded, GymRouteMode mode) {
    if (decoded is! Map || decoded['code'] != 'Ok') {
      return null;
    }
    final routes = decoded['routes'];
    if (routes is! List) {
      return null;
    }
    GymRoute? fastest;
    for (final route in routes) {
      final parsed = route is Map ? _parseSingleRoute(route, mode) : null;
      if (parsed != null &&
          (fastest == null ||
              parsed.durationSeconds < fastest.durationSeconds)) {
        fastest = parsed;
      }
    }
    return fastest;
  }

  static GymRoute? _parseSingleRoute(Map route, GymRouteMode mode) {
    final geometry = route['geometry'];
    final coordinates = geometry is Map ? geometry['coordinates'] : null;
    if (coordinates is! List) {
      return null;
    }
    final points = <LatLng>[
      for (final pair in coordinates)
        if (pair is List &&
            pair.length >= 2 &&
            pair[0] is num &&
            pair[1] is num)
          LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
    ];
    final distance = route['distance'];
    final duration = route['duration'];
    if (points.length < 2 || distance is! num || duration is! num) {
      return null;
    }
    return GymRoute(
      points: List<LatLng>.unmodifiable(points),
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
      mode: mode,
    );
  }

  /// Menor distância, em metros, de [point] até a linha do trajeto. Usa uma
  /// projeção plana local, precisa o bastante para detectar desvios de
  /// dezenas de metros.
  static double distanceToRouteMeters(LatLng point, List<LatLng> route) {
    if (route.isEmpty) {
      return double.infinity;
    }
    const metersPerDegreeLat = 110540.0;
    final metersPerDegreeLng =
        111320.0 * math.cos(point.latitude * math.pi / 180);
    (double, double) project(LatLng p) => (
      (p.longitude - point.longitude) * metersPerDegreeLng,
      (p.latitude - point.latitude) * metersPerDegreeLat,
    );
    var best = double.infinity;
    var previous = project(route.first);
    best = math.sqrt(previous.$1 * previous.$1 + previous.$2 * previous.$2);
    for (final next in route.skip(1).map(project)) {
      // Distância da origem (o ponto) ao segmento previous–next.
      final dx = next.$1 - previous.$1;
      final dy = next.$2 - previous.$2;
      final lengthSquared = dx * dx + dy * dy;
      final t =
          lengthSquared == 0
              ? 0.0
              : ((-previous.$1 * dx - previous.$2 * dy) / lengthSquared).clamp(
                0.0,
                1.0,
              );
      final x = previous.$1 + t * dx;
      final y = previous.$2 + t * dy;
      best = math.min(best, math.sqrt(x * x + y * y));
      previous = next;
    }
    return best;
  }

  // OSRM usa longitude,latitude.
  static String _coordinate(LatLng point) =>
      '${point.longitude.toStringAsFixed(6)},'
      '${point.latitude.toStringAsFixed(6)}';
}
