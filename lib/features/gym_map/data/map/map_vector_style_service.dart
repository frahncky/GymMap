/// Resolve a URL do estilo do mapa vetorial (MapLibre Style JSON) desenhado
/// pela `VectorTileLayer` (ver `VectorMapStyleLoader`).
///
/// O padrão é o "liberty" do OpenFreeMap (dados do OpenStreetMap); outro
/// estilo pode ser passado no build com `--dart-define=MAPLIBRE_STYLE_URL=...`.
class MapVectorStyleService {
  const MapVectorStyleService._();

  static const String styleUrl = String.fromEnvironment(
    'MAPLIBRE_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );

  /// Rótulo de atribuição exigido pela licença ODbL do OpenStreetMap.
  static const String attributionLabel = 'OpenStreetMap contributors';
}
