import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'map_services_config.dart';

/// Meio de transporte do trajeto até a academia.
enum GymRouteMode {
  walking('foot'),
  cycling('bike'),
  driving('car');

  const GymRouteMode(this.profile);

  /// Perfil do servidor de rotas (`routed-foot`, `routed-bike`, `routed-car`).
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
/// alemão (FOSSGIS), que tem rotas reais a pé, de bicicleta e de carro; o
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

  /// Lê a resposta do OSRM (`geometries=geojson`). Pública para testes.
  static GymRoute? parseRoute(Object? decoded, GymRouteMode mode) {
    if (decoded is! Map || decoded['code'] != 'Ok') {
      return null;
    }
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      return null;
    }
    final route = routes.first as Map;
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

  // OSRM usa longitude,latitude.
  static String _coordinate(LatLng point) =>
      '${point.longitude.toStringAsFixed(6)},'
      '${point.latitude.toStringAsFixed(6)}';
}
