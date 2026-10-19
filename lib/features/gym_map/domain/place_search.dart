import 'package:latlong2/latlong.dart';

/// Busca de lugares (bairro, rua, cidade) no Nominatim, preferindo o que
/// fica perto de quem busca: "Renascença São Luís" deve levar ao bairro da
/// cidade da pessoa, não a outro lugar do país com nome parecido.
class PlaceSearch {
  const PlaceSearch._();

  /// Quantos resultados pedir para poder escolher o mais próximo.
  static const int resultLimit = 10;

  /// Meia largura, em graus, da área preferida em volta de [near]
  /// (cerca de 65 km). Resultados de fora continuam valendo.
  static const double biasHalfSpanDegrees = 0.6;

  static Map<String, String> queryParameters(
    String query, {
    LatLng? near,
    required String language,
  }) {
    return <String, String>{
      'q': query,
      'format': 'jsonv2',
      'limit': '$resultLimit',
      'countrycodes': 'br',
      'accept-language': language,
      if (near != null) ...<String, String>{
        // left, top, right, bottom; bounded=0 só dá preferência.
        'viewbox': <double>[
          near.longitude - biasHalfSpanDegrees,
          near.latitude + biasHalfSpanDegrees,
          near.longitude + biasHalfSpanDegrees,
          near.latitude - biasHalfSpanDegrees,
        ].map((value) => value.toStringAsFixed(5)).join(','),
        'bounded': '0',
      },
    };
  }

  /// Posição do resultado mais próximo de [near] (ou do primeiro, sem
  /// referência). Null quando nenhum resultado tem coordenadas válidas.
  static LatLng? pickPosition(List<dynamic> results, {LatLng? near}) {
    const distance = Distance();
    LatLng? best;
    var bestMeters = double.infinity;
    for (final result in results) {
      if (result is! Map) {
        continue;
      }
      final lat = double.tryParse('${result['lat'] ?? ''}');
      final lon = double.tryParse('${result['lon'] ?? ''}');
      if (lat == null || lon == null) {
        continue;
      }
      final position = LatLng(lat, lon);
      if (near == null) {
        return position;
      }
      final meters = distance(near, position);
      if (meters < bestMeters) {
        bestMeters = meters;
        best = position;
      }
    }
    return best;
  }
}
