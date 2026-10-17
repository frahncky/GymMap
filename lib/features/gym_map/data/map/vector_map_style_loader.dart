import 'dart:async';
import 'http_vector_map_style_reader.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;

/// Lê um estilo de mapa vetorial (Mapbox/MapLibre Style JSON, ex.: o
/// "liberty" do OpenFreeMap) e o converte no tema e nas fontes de tiles que
/// a camada `VectorTileLayer` do `flutter_map` desenha em Dart puro — sem o
/// renderer nativo do MapLibre, que não desenhava no Android.
///
/// O estilo lido fica em memória por URL (todas as telas de mapa usam o
/// mesmo); uma falha não fica guardada, para "Tentar
/// novamente" buscar de novo.
///
/// As academias do próprio mapa base (POIs `fitness_centre` dos vector
/// tiles) continuam visíveis, para aparecerem mesmo sem a busca do Overpass.
class VectorMapStyleLoader {
  VectorMapStyleLoader({Future<vmt.Style> Function(String url)? reader})
    : _reader = reader ?? HttpVectorMapStyleReader().read;

  final Future<vmt.Style> Function(String url) _reader;

  static final Map<String, vmt.Style> _cache = <String, vmt.Style>{};
  static final Map<String, Future<vmt.Style?>> _inFlight = {};

  /// O estilo em [styleUrl], ou `null` quando a URL não é http(s), a rede
  /// falha ou o documento é inválido.
  Future<vmt.Style?> load(String styleUrl) async {
    final String url = styleUrl.trim();
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return null;
    }
    final vmt.Style? cached = _cache[url];
    if (cached != null) return cached;
    return _inFlight.putIfAbsent(url, () => _load(url));
  }

  Future<vmt.Style?> _load(String url) async {
    try {
      final vmt.Style style = await _reader(
        url,
      ).timeout(const Duration(seconds: 20));
      _cache[url] = style;
      return style;
    } catch (_) {
      return null;
    } finally {
      _inFlight.remove(url);
    }
  }
}
