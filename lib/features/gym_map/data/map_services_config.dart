/// Endereços dos serviços de mapa, configuráveis via `--dart-define`.
///
/// Os padrões apontam para os servidores públicos do OpenStreetMap, que
/// servem para desenvolvimento mas não aceitam tráfego de app em produção
/// (veja https://operations.osmfoundation.org/policies/). Em produção use um
/// provedor de tiles (MapTiler, Stadia, Thunderforest...) e instâncias
/// próprias ou pagas de Overpass/Nominatim.
class MapServicesConfig {
  const MapServicesConfig._();

  /// Crédito exibido no mapa. Os dados são do OpenStreetMap em qualquer
  /// provedor, então o padrão continua obrigatório; acrescente o do provedor
  /// separado por `|` (ex.: `MapTiler|OpenStreetMap contributors`).
  static const String tileAttribution = String.fromEnvironment(
    'MAP_TILE_ATTRIBUTION',
    defaultValue: 'OpenStreetMap contributors',
  );

  static const String _overpassApiUrl = String.fromEnvironment(
    'OVERPASS_API_URL',
    defaultValue: 'https://overpass-api.de/api/interpreter',
  );

  static const String _nominatimBaseUrl = String.fromEnvironment(
    'NOMINATIM_BASE_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );

  static Uri get overpassUri => Uri.parse(_overpassApiUrl);

  static Uri nominatimSearchUri(Map<String, String> queryParameters) {
    final base = Uri.parse(_nominatimBaseUrl);
    final baseSegments = base.pathSegments.where((s) => s.isNotEmpty);
    return base.replace(
      pathSegments: <String>[...baseSegments, 'search'],
      queryParameters: queryParameters,
    );
  }

  static List<String> get attributionLines => tileAttribution
      .split('|')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}
