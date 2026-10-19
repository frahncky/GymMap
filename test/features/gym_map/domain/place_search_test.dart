import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/features/gym_map/domain/place_search.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const saoLuisMa = LatLng(-2.5307, -44.3068);

  test('prefers the result closest to the reference point', () {
    final results = <dynamic>[
      {'lat': '-28.4', 'lon': '-54.9'}, // outro São Luís, no RS
      {'lat': '-2.505', 'lon': '-44.290'}, // Renascença, São Luís (MA)
      {'lat': '-23.5', 'lon': '-46.6'},
    ];

    final picked = PlaceSearch.pickPosition(results, near: saoLuisMa);

    expect(picked, const LatLng(-2.505, -44.290));
  });

  test('without a reference uses the first valid result', () {
    final results = <dynamic>[
      {'lat': 'x', 'lon': '1'},
      {'lat': '-23.5', 'lon': '-46.6'},
      {'lat': '-2.5', 'lon': '-44.3'},
    ];

    expect(PlaceSearch.pickPosition(results), const LatLng(-23.5, -46.6));
    expect(PlaceSearch.pickPosition(const <dynamic>[]), isNull);
  });

  test('asks for several results in Brazil, biased around the reference', () {
    final params = PlaceSearch.queryParameters(
      'Renascença',
      near: saoLuisMa,
      language: 'pt-BR',
    );

    expect(params['limit'], '10');
    expect(params['countrycodes'], 'br');
    expect(params['bounded'], '0');
    expect(params['viewbox'], '-44.90680,-1.93070,-43.70680,-3.13070');
    expect(
      PlaceSearch.queryParameters('x', language: 'en').containsKey('viewbox'),
      isFalse,
    );
  });
}
