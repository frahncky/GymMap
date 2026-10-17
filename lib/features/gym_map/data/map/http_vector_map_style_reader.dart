import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

/// Lê estilos HTTP com uma única busca por documento e recursos em paralelo.
/// O cache de metadados é transversal às contas e não contém dados pessoais.
class HttpVectorMapStyleReader {
  HttpVectorMapStyleReader({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  static const _timeout = Duration(seconds: 10);
  static const _cacheTtl = Duration(days: 1);

  /// Documento de cada estilo já lido, por URL, para montar variações do
  /// tema (ex.: sem pontos de interesse) sem buscar de novo.
  static final Map<String, Map<String, dynamic>> documents =
      <String, Map<String, dynamic>>{};

  Future<Map<String, dynamic>> _document(http.Client client, Uri uri) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'vector_map_document:$uri';
    Map<String, dynamic>? cached;
    try {
      final raw = prefs.getString(key);
      if (raw != null) cached = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Um cache inválido é substituído pela resposta da rede.
    }
    final savedAt = cached?['savedAt'] as int? ?? 0;
    final document = cached?['document'];
    if (document is Map<String, dynamic> &&
        DateTime.now().millisecondsSinceEpoch - savedAt <
            _cacheTtl.inMilliseconds) {
      return document;
    }
    try {
      final response = await client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw StateError('map_style_read_failed');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      try {
        await prefs.setString(
          key,
          jsonEncode(<String, Object>{
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'document': decoded,
          }),
        );
      } catch (_) {
        // Falha de cache não impede exibir o documento já recebido.
      }
      return decoded;
    } catch (_) {
      if (document is Map<String, dynamic>) return document;
      rethrow;
    }
  }

  Uri _httpUri(Uri base, String reference) {
    final uri = base.resolve(reference);
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const FormatException('Fonte de mapa com protocolo específico.');
    }
    return uri;
  }

  Future<vmt.Style> read(String url) async {
    final client = _clientFactory();
    try {
      final uri = Uri.parse(url);
      final json = await _document(client, uri);
      documents[url] = json;
      final sources = json['sources'] as Map<String, dynamic>;
      // Preserva a leitura da biblioteca para protocolos específicos,
      // como mapbox://, sem acoplar o domínio a esse fornecedor.
      for (final source in sources.values.cast<Map<String, dynamic>>()) {
        final reference = source['url'] as String?;
        if (reference != null) _httpUri(uri, reference);
      }
      final sprite = json['sprite'] as String?;
      if (sprite != null && sprite.isNotEmpty) _httpUri(uri, sprite);

      final resources = await Future.wait<Object?>(<Future<Object?>>[
        _providers(client, uri, sources),
        _sprites(client, uri, sprite),
      ]);
      final center = json['center'];
      final zoom = (json['zoom'] as num?)?.toDouble();
      return vmt.Style(
        name: json['name'] as String?,
        theme: _theme(json),
        providers: resources[0] as vmt.TileProviders,
        sprites: resources[1] as vmt.SpriteStyle?,
        center:
            center is List && center.length == 2 && (zoom == null || zoom >= 2)
                ? LatLng(
                  (center[1] as num).toDouble(),
                  (center[0] as num).toDouble(),
                )
                : null,
        zoom: zoom != null && zoom >= 2 ? zoom : null,
      );
    } on FormatException {
      return vmt.StyleReader(uri: url).read();
    } finally {
      client.close();
    }
  }

  vtr.Theme _theme(Map<String, dynamic> json) => vtr.ThemeReader().read(json);

  Future<vmt.TileProviders> _providers(
    http.Client client,
    Uri uri,
    Map<String, dynamic> sources,
  ) async {
    final entries = await Future.wait(
      sources.entries.map((entry) async {
        final source = entry.value as Map<String, dynamic>;
        final type =
            vmt.TileProviderType.values
                .where(
                  (type) => type.name.replaceAll('_', '-') == source['type'],
                )
                .firstOrNull;
        if (type == null) return null;
        final reference = source['url'] as String?;
        final sourceUri = reference == null ? uri : _httpUri(uri, reference);
        final metadata =
            reference == null ? source : await _document(client, sourceUri);
        final tiles = metadata['tiles'];
        if (tiles is! List || tiles.isEmpty) return null;
        // Mantém os placeholders {z}/{x}/{y} sem codificá-los como %7B.
        final template = sourceUri
            .resolve(tiles.first as String)
            .toString()
            .replaceAll('%7B', '{')
            .replaceAll('%7D', '}');
        return MapEntry<String, vmt.VectorTileProvider>(
          entry.key,
          vmt.NetworkVectorTileProvider(
            type: type,
            urlTemplate: template,
            minimumZoom: (metadata['minzoom'] as num?)?.toInt() ?? 1,
            maximumZoom: (metadata['maxzoom'] as num?)?.toInt() ?? 14,
          ),
        );
      }),
    );
    final providers = Map<String, vmt.VectorTileProvider>.fromEntries(
      entries.whereType<MapEntry<String, vmt.VectorTileProvider>>(),
    );
    if (providers.isEmpty) throw StateError('Mapa sem fontes de tiles.');
    return vmt.TileProviders(providers);
  }

  Future<vmt.SpriteStyle?> _sprites(
    http.Client client,
    Uri base,
    String? reference,
  ) async {
    if (reference == null || reference.isEmpty) return null;
    final uri = _httpUri(base, reference);
    for (final suffix in <String>['@2x', '']) {
      final indexUri = uri.replace(path: '${uri.path}$suffix.json');
      final imageUri = uri.replace(path: '${uri.path}$suffix.png');
      try {
        final resources = await Future.wait<Object>(<Future<Object>>[
          _document(client, indexUri),
          client.get(imageUri).timeout(_timeout),
        ]);
        final image = resources[1] as http.Response;
        if (image.statusCode != 200) continue;
        final bytes = image.bodyBytes;
        return vmt.SpriteStyle(
          index: vtr.SpriteIndexReader().read(
            resources[0] as Map<String, dynamic>,
          ),
          atlasProvider: () async => bytes,
        );
      } catch (_) {
        // Ícones opcionais: tenta a resolução normal e preserva as ruas.
      }
    }
    return null;
  }
}
