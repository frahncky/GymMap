import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/gym_location_cache_service.dart';
import '../data/map_services_config.dart';
import '../domain/gym_models.dart';
import 'gym_map_logic.dart';

class GymMapPoiController {
  GymMapPoiController({
    GymLocationCacheService? cacheService,
    http.Client? httpClient,
  }) : _cacheService = cacheService,
       _httpClient = httpClient ?? http.Client();

  static const Duration _overpassTimeout = Duration(seconds: 16);
  static final Uri _overpassUri = MapServicesConfig.overpassUri;
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

  Future<List<MapGymPoi>?> fetchOverpassPoisAround({
    required LatLng center,
    required List<Gym> knownGyms,
    double knownGymExclusionMeters = 120,
  }) async {
    final query = _buildOverpassQuery(center);
    final response = await _httpClient
        .post(
          _overpassUri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'text/plain; charset=utf-8',
            'User-Agent': _overpassUserAgent,
          },
          body: query,
        )
        .timeout(_overpassTimeout);
    if (response.statusCode != 200) {
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
  nwr["name"~"(academia|fitness|gym|crossfit)",i](around:12000,${center.latitude},${center.longitude});
);
out body center;
''';
  }
}
