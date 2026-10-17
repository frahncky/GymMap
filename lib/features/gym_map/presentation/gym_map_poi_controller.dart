import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/gym_location_cache_service.dart';
import '../domain/gym_models.dart';
import 'gym_map_logic.dart';

class GymMapPoiController {
  GymMapPoiController({
    GymLocationCacheService? cacheService,
    http.Client? httpClient,
  }) : _cacheService = cacheService,
       _httpClient = httpClient ?? http.Client();

  static const Duration _overpassTimeout = Duration(seconds: 30);
  static const Duration _nominatimTimeout = Duration(seconds: 10);
  // Meia-largura da caixa de busca do Nominatim (~11 km).
  static const double _nominatimHalfSpanDegrees = 0.1;
  // Servidor principal e espelhos públicos, tentados em ordem.
  static final List<Uri> _overpassUris = <Uri>[
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://overpass.private.coffee/api/interpreter'),
    Uri.parse('https://overpass.kumi.systems/api/interpreter'),
  ];
  static const String _overpassUserAgent = 'gymmap/1.0';

  GymLocationCacheService? _cacheService;
  final http.Client _httpClient;

  void dispose() {
    _httpClient.close();
  }

  Future<List<MapGymPoi>> loadCachedPois() async {
    final cacheService = await _ensureCacheService();
    final cachedLocations = await cacheService.loadLocations();
    return cachedLocations
        .map(
          (location) => MapGymPoi(
            id: location.id,
            position: location.position,
            name: location.name,
          ),
        )
        .toList(growable: false);
  }

  Future<int> pullRemoteToLocal() async {
    final cacheService = await _ensureCacheService();
    return cacheService.pullRemoteToLocal();
  }

  Future<void> persistPois(List<MapGymPoi> pois) async {
    if (pois.isEmpty) {
      return;
    }
    final cacheService = await _ensureCacheService();
    final now = DateTime.now().toUtc();
    final locations = pois
        .map(
          (poi) => CachedGymLocation(
            id: poi.id,
            name: poi.name,
            address: 'Academia encontrada no mapa',
            position: poi.position,
            updatedAtUtc: now,
          ),
        )
        .toList(growable: false);
    await cacheService.mergeAndSave(locations);
  }

  Future<List<MapGymPoi>> loadCachedPoisNear({
    required LatLng center,
    required double radiusMeters,
    required int limit,
  }) async {
    final cachedPois = await loadCachedPois();
    final nearby =
        cachedPois
            .where(
              (poi) => GymMapLogic.isWithinDistanceMeters(
                center,
                poi.position,
                radiusMeters,
              ),
            )
            .toList();
    if (nearby.isEmpty) {
      return const <MapGymPoi>[];
    }

    nearby.sort(
      (a, b) => GymMapLogic.distanceSquaredMeters(
        center,
        a.position,
      ).compareTo(GymMapLogic.distanceSquaredMeters(center, b.position)),
    );
    return nearby.take(limit).toList(growable: false);
  }

  /// Academias perto de [center]: tenta o Overpass e, se ele falhar ou
  /// estiver sobrecarregado (o servidor público vive no limite), usa a busca
  /// do Nominatim como alternativa. `null` só quando as duas falham.
  Future<List<MapGymPoi>?> fetchOverpassPoisAround({
    required LatLng center,
    required List<Gym> knownGyms,
    double knownGymExclusionMeters = 120,
  }) async {
    List<MapGymPoi>? pois;
    try {
      pois = await _fetchOverpassPois(
        center: center,
        knownGyms: knownGyms,
        knownGymExclusionMeters: knownGymExclusionMeters,
      );
    } catch (_) {
      pois = null;
    }
    if (pois != null) {
      return pois;
    }
    try {
      return await _fetchNominatimPois(
        center: center,
        knownGyms: knownGyms,
        knownGymExclusionMeters: knownGymExclusionMeters,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<MapGymPoi>?> _fetchOverpassPois({
    required LatLng center,
    required List<Gym> knownGyms,
    required double knownGymExclusionMeters,
  }) async {
    final query = _buildOverpassQuery(center);
    http.Response? response;
    for (final uri in _overpassUris) {
      try {
        // A consulta vai como formulário (`data=`): o Overpass público
        // recusa o corpo em texto puro com 502 ("at capacity").
        final attempt = await _httpClient
            .post(
              uri,
              headers: const {
                'Accept': 'application/json',
                'User-Agent': _overpassUserAgent,
              },
              body: <String, String>{'data': query},
            )
            .timeout(_overpassTimeout);
        if (attempt.statusCode == 200) {
          response = attempt;
          break;
        }
      } catch (_) {
        // Tenta o próximo espelho.
      }
    }
    if (response == null) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return null;
    }
    final elements = decoded['elements'];
    if (elements is! List) {
      return null;
    }

    final poiList = <MapGymPoi>[];
    final seenIds = <String>{};
    for (final element in elements) {
      if (element is! Map) {
        continue;
      }
      final type = element['type'];
      final idRaw = element['id'];
      if (type is! String || idRaw is! num) {
        continue;
      }

      double? lat;
      double? lon;
      if (element['lat'] is num && element['lon'] is num) {
        lat = (element['lat'] as num).toDouble();
        lon = (element['lon'] as num).toDouble();
      } else if (element['center'] is Map) {
        final centerMap = element['center'] as Map;
        if (centerMap['lat'] is num && centerMap['lon'] is num) {
          lat = (centerMap['lat'] as num).toDouble();
          lon = (centerMap['lon'] as num).toDouble();
        }
      }
      if (lat == null || lon == null) {
        continue;
      }

      final position = LatLng(lat, lon);
      if (GymMapLogic.isNearAnyKnownGym(
        point: position,
        gyms: knownGyms,
        maxMeters: knownGymExclusionMeters,
      )) {
        continue;
      }

      final key = '$type-$idRaw';
      if (!seenIds.add(key)) {
        continue;
      }

      final tags = element['tags'];
      if (tags is! Map) {
        continue;
      }
      if (!_looksLikeGym(tags)) {
        continue;
      }

      String name = 'Academia';
      if (tags['name'] is String) {
        name = (tags['name'] as String).trim();
        if (name.isEmpty) {
          name = 'Academia';
        }
      }

      poiList.add(MapGymPoi(id: key, position: position, name: name));
    }

    return List<MapGymPoi>.unmodifiable(poiList);
  }

  /// Busca "academia" e "gym" na caixa em volta de [center] e mantém só os
  /// resultados que o OpenStreetMap classifica como academia. As duas buscas
  /// são sequenciais, respeitando o limite de 1 req/s do Nominatim público.
  Future<List<MapGymPoi>?> _fetchNominatimPois({
    required LatLng center,
    required List<Gym> knownGyms,
    required double knownGymExclusionMeters,
  }) async {
    const span = _nominatimHalfSpanDegrees;
    final viewbox = [
      center.longitude - span,
      center.latitude + span,
      center.longitude + span,
      center.latitude - span,
    ].map((value) => value.toStringAsFixed(5)).join(',');

    final poiList = <MapGymPoi>[];
    final seenIds = <String>{};
    var anySucceeded = false;
    for (final term in const <String>['academia', 'gym']) {
      if (anySucceeded) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': term,
        'format': 'jsonv2',
        'limit': '50',
        'bounded': '1',
        'viewbox': viewbox,
      });
      final http.Response response;
      try {
        response = await _httpClient
            .get(
              uri,
              headers: const {
                'Accept': 'application/json',
                'User-Agent': _overpassUserAgent,
              },
            )
            .timeout(_nominatimTimeout);
      } catch (_) {
        continue;
      }
      if (response.statusCode != 200) {
        continue;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        continue;
      }
      anySucceeded = true;

      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final category = '${item['category'] ?? ''}';
        final type = '${item['type'] ?? ''}';
        final isGym =
            (category == 'leisure' && type == 'fitness_centre') ||
            (category == 'amenity' && type == 'gym');
        if (!isGym) {
          continue;
        }
        final lat = double.tryParse('${item['lat']}');
        final lon = double.tryParse('${item['lon']}');
        final osmType = item['osm_type'];
        final osmId = item['osm_id'];
        if (lat == null || lon == null || osmType is! String || osmId == null) {
          continue;
        }
        // Mesmo formato de id do Overpass (`node-123`), para o cache e os
        // relatos de lotação reconhecerem a mesma academia.
        final key = '$osmType-$osmId';
        if (!seenIds.add(key)) {
          continue;
        }
        final position = LatLng(lat, lon);
        if (GymMapLogic.isNearAnyKnownGym(
          point: position,
          gyms: knownGyms,
          maxMeters: knownGymExclusionMeters,
        )) {
          continue;
        }
        var name = '${item['name'] ?? ''}'.trim();
        if (name.isEmpty) {
          name = 'Academia';
        }
        poiList.add(MapGymPoi(id: key, position: position, name: name));
      }
    }
    if (!anySucceeded) {
      return null;
    }
    return List<MapGymPoi>.unmodifiable(poiList);
  }

  bool _looksLikeGym(Map tags) {
    final amenity = '${tags['amenity'] ?? ''}'.toLowerCase();
    final leisure = '${tags['leisure'] ?? ''}'.toLowerCase();
    final sport = '${tags['sport'] ?? ''}'.toLowerCase();
    final name = '${tags['name'] ?? ''}'.toLowerCase();
    return amenity == 'gym' ||
        leisure == 'fitness_centre' ||
        sport.contains('fitness') ||
        sport.contains('bodybuilding') ||
        name.contains('academia') ||
        name.contains('fitness') ||
        name.contains('gym') ||
        name.contains('crossfit');
  }

  Future<GymLocationCacheService> _ensureCacheService() async {
    final cached = _cacheService;
    if (cached != null) {
      return cached;
    }
    final created = await GymLocationCacheService.create();
    _cacheService = created;
    return created;
  }

  String _buildOverpassQuery(LatLng center) {
    return '''
[out:json][timeout:18];
(
  nwr["amenity"="gym"](around:25000,${center.latitude},${center.longitude});
  nwr["leisure"="fitness_centre"](around:25000,${center.latitude},${center.longitude});
  nwr["sport"~"^(fitness|bodybuilding)\$",i](around:25000,${center.latitude},${center.longitude});
);
out body center;
''';
  }
}
