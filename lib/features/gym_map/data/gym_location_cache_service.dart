import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/gym_models.dart';

class CachedGymLocation {
  const CachedGymLocation({
    required this.id,
    required this.name,
    required this.position,
    required this.address,
    required this.updatedAtUtc,
  });

  final String id;
  final String name;
  final LatLng position;
  final String address;
  final DateTime updatedAtUtc;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'address': address,
      'lat': position.latitude,
      'lng': position.longitude,
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
    };
  }

  static CachedGymLocation? fromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final id = '${raw['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return null;
    }

    final lat = double.tryParse('${raw['lat'] ?? ''}');
    final lng = double.tryParse('${raw['lng'] ?? ''}');
    if (lat == null || lng == null) {
      return null;
    }

    final name = '${raw['name'] ?? kUnnamedGymName}'.trim();
    final address = '${raw['address'] ?? kMapGymAddress}'.trim();
    final updatedAtRaw = '${raw['updatedAtUtc'] ?? ''}'.trim();
    final updatedAt =
        DateTime.tryParse(updatedAtRaw)?.toUtc() ?? DateTime.now().toUtc();

    return CachedGymLocation(
      id: id,
      name: name.isEmpty ? kUnnamedGymName : name,
      position: LatLng(lat, lng),
      address: address.isEmpty ? kMapGymAddress : address,
      updatedAtUtc: updatedAt,
    );
  }
}

class GymLocationCacheService {
  GymLocationCacheService._({
    required SharedPreferences prefs,
    required Uri? backendBaseUri,
    http.Client? httpClient,
  }) : _prefs = prefs,
       _backendBaseUri = backendBaseUri,
       _httpClient = httpClient ?? http.Client();

  static const String _locationsKey = 'gym_map.cached_locations.v1';
  static const String _authUserIdKey = 'subscription.auth.user_id';
  static const String _authTokenKey = 'subscription.auth.token';
  static const int _maxLocations = 1400;
  static const Duration _requestTimeout = Duration(seconds: 8);

  final SharedPreferences _prefs;
  final Uri? _backendBaseUri;
  final http.Client _httpClient;

  static Future<GymLocationCacheService> create({
    String? backendBaseUrl,
    http.Client? httpClient,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fromEnv = const String.fromEnvironment('PLAN_BACKEND_BASE_URL');
    final rawBaseUrl = (backendBaseUrl ?? fromEnv).trim();
    final parsedBaseUrl = rawBaseUrl.isEmpty ? null : Uri.tryParse(rawBaseUrl);
    return GymLocationCacheService._(
      prefs: prefs,
      backendBaseUri: parsedBaseUrl,
      httpClient: httpClient,
    );
  }

  Future<List<CachedGymLocation>> loadLocations() async {
    final raw = _prefs.getString(_locationsKey);
    if (raw == null || raw.isEmpty) {
      return const <CachedGymLocation>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <CachedGymLocation>[];
      }

      final parsed = <CachedGymLocation>[];
      for (final item in decoded) {
        final location = CachedGymLocation.fromJson(item);
        if (location != null) {
          parsed.add(location);
        }
      }

      parsed.sort(
        (a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc),
      );
      return parsed;
    } catch (_) {
      return const <CachedGymLocation>[];
    }
  }

  Future<void> mergeAndSave(
    Iterable<CachedGymLocation> incoming, {
    bool syncRemote = true,
  }) async {
    final mergedById = <String, CachedGymLocation>{};
    final existing = await loadLocations();
    for (final location in existing) {
      mergedById[location.id] = location;
    }

    final now = DateTime.now().toUtc();
    final changedForRemote = <CachedGymLocation>[];
    for (final location in incoming) {
      final normalized = _normalizedLocation(location, updatedAtUtc: now);
      final current = mergedById[normalized.id];
      if (current != null && _sameLocationData(current, normalized)) {
        continue;
      }
      mergedById[normalized.id] = normalized;
      changedForRemote.add(normalized);
    }

    if (changedForRemote.isEmpty) {
      return;
    }

    final normalized = mergedById.values.toList(growable: false)
      ..sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    final limited = normalized.take(_maxLocations).toList(growable: false);
    await _saveLocationsSnapshot(limited);
    if (syncRemote) {
      await _syncRemoteLocations(changedForRemote);
    }
  }

  Future<int> pullRemoteToLocal() async {
    try {
      final baseUri = _backendBaseUri;
      if (baseUri == null) {
        return 0;
      }

      final userId = _effectiveUserId();
      if (userId.isEmpty) {
        return 0;
      }

      final uri = _buildRemoteUri(baseUri, <String>[
        'v1',
        'gyms',
        'locations',
        userId,
      ]);
      final response = await _httpClient
          .get(uri, headers: _remoteHeaders())
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 0;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return 0;
      }
      final rawLocations = decoded['locations'];
      if (rawLocations is! List) {
        return 0;
      }

      final incoming = <CachedGymLocation>[];
      for (final raw in rawLocations) {
        final location = CachedGymLocation.fromJson(raw);
        if (location != null) {
          incoming.add(location);
        }
      }
      if (incoming.isEmpty) {
        return 0;
      }

      final mergedById = <String, CachedGymLocation>{};
      final existing = await loadLocations();
      for (final location in existing) {
        mergedById[location.id] = location;
      }
      var changedCount = 0;
      for (final location in incoming) {
        final current = mergedById[location.id];
        if (current == null ||
            location.updatedAtUtc.isAfter(current.updatedAtUtc)) {
          mergedById[location.id] = location;
          changedCount++;
        }
      }
      if (changedCount == 0) {
        return 0;
      }

      final normalized = mergedById.values.toList(growable: false)
        ..sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
      final limited = normalized.take(_maxLocations).toList(growable: false);
      await _saveLocationsSnapshot(limited);
      return changedCount;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _saveLocationsSnapshot(List<CachedGymLocation> locations) async {
    final payload = jsonEncode(
      locations.map((location) => location.toJson()).toList(growable: false),
    );
    await _prefs.setString(_locationsKey, payload);
  }

  Future<void> _syncRemoteLocations(List<CachedGymLocation> locations) async {
    try {
      final baseUri = _backendBaseUri;
      if (baseUri == null || locations.isEmpty) {
        return;
      }

      final userId = _effectiveUserId();
      if (userId.isEmpty) {
        return;
      }

      final uri = _buildRemoteUri(baseUri, <String>[
        'v1',
        'gyms',
        'locations',
        'upsert',
      ]);
      final response = await _httpClient
          .post(
            uri,
            headers: _remoteHeaders(contentTypeJson: true),
            body: jsonEncode(<String, dynamic>{
              'userId': userId,
              'locations':
                  locations
                      .map((location) => location.toJson())
                      .toList(growable: false),
            }),
          )
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }
    } catch (_) {
      // Falha de rede remota não pode bloquear o cache local.
    }
  }

  String _effectiveUserId() {
    final fromStorage = (_prefs.getString(_authUserIdKey) ?? '').trim();
    if (fromStorage.isNotEmpty) {
      return fromStorage;
    }
    final fromEnv = const String.fromEnvironment(
      'PLAN_USER_ID',
      defaultValue: 'local-device-user',
    ).trim();
    return fromEnv.isEmpty ? 'local-device-user' : fromEnv;
  }

  Uri _buildRemoteUri(Uri baseUri, List<String> pathSegments) {
    final baseSegments =
        baseUri.pathSegments
            .where((segment) => segment.trim().isNotEmpty)
            .toList(growable: false);
    return baseUri.replace(
      pathSegments: <String>[...baseSegments, ...pathSegments],
      queryParameters: null,
    );
  }

  Map<String, String> _remoteHeaders({bool contentTypeJson = false}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (contentTypeJson) {
      headers['Content-Type'] = 'application/json';
    }
    final auth = _authorizationHeader();
    if (auth != null) {
      headers['Authorization'] = auth;
    }
    return headers;
  }

  String? _authorizationHeader() {
    final rawToken = (_prefs.getString(_authTokenKey) ?? '').trim();
    if (rawToken.isEmpty) {
      return null;
    }
    final lower = rawToken.toLowerCase();
    if (lower.startsWith('bearer ')) {
      return rawToken;
    }
    return 'Bearer $rawToken';
  }

  CachedGymLocation _normalizedLocation(
    CachedGymLocation source, {
    required DateTime updatedAtUtc,
  }) {
    final name = source.name.trim();
    final address = source.address.trim();
    return CachedGymLocation(
      id: source.id.trim(),
      name: name.isEmpty ? kUnnamedGymName : name,
      address: address.isEmpty ? kMapGymAddress : address,
      position: source.position,
      updatedAtUtc: updatedAtUtc,
    );
  }

  bool _sameLocationData(CachedGymLocation a, CachedGymLocation b) {
    return a.id == b.id &&
        a.name == b.name &&
        a.address == b.address &&
        a.position.latitude == b.position.latitude &&
        a.position.longitude == b.position.longitude;
  }
}
