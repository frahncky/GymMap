import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/features/gym_map/data/map/basemap_style_filter.dart';

void main() {
  Map<String, dynamic> style() => <String, dynamic>{
    'id': 'liberty',
    'layers': <Object>[
      <String, Object>{'id': 'road', 'source-layer': 'transportation'},
      <String, Object>{
        'id': 'poi_r1',
        'source-layer': 'poi',
        'filter': <Object>['==', 'rank', 1],
      },
      <String, Object>{'id': 'place', 'source-layer': 'place'},
    ],
  };

  group('BasemapStyleFilter.withoutPoiCategories', () {
    test('keeps the style unchanged when nothing is hidden', () {
      final original = style();
      expect(
        identical(
          BasemapStyleFilter.withoutPoiCategories(original, const {}),
          original,
        ),
        isTrue,
      );
    });

    test('drops the poi layers when every category is hidden', () {
      final filtered = BasemapStyleFilter.withoutPoiCategories(
        style(),
        BasemapPoiCategory.values.toSet(),
      );

      expect(
        (filtered['layers'] as List).map((layer) => (layer as Map)['id']),
        <String>['road', 'place'],
      );
    });

    test('filters only the hidden classes and keeps the original filter', () {
      final filtered = BasemapStyleFilter.withoutPoiCategories(style(), {
        BasemapPoiCategory.transport,
      });

      final poi = (filtered['layers'] as List)[1] as Map;
      final filter = poi['filter'] as List;
      expect(filter.first, 'all');
      expect(filter[1], <Object>['==', 'rank', 1]);
      final match = filter[2] as List;
      expect(match.first, 'match');
      expect(match[2], contains('bus'));
      expect(match[2], isNot(contains('restaurant')));
      expect(filtered['id'], 'liberty-hide-transport');
    });

    test('hiding "other" hides every class outside the known categories', () {
      final filtered = BasemapStyleFilter.withoutPoiCategories(style(), {
        BasemapPoiCategory.other,
      });

      final filter =
          ((filtered['layers'] as List)[1] as Map)['filter'] as List;
      final match = filter.last as List;
      expect(match[2], containsAll(<String>['bus', 'restaurant', 'school']));
      expect(match[3], isTrue);
      expect(match[4], isFalse);
    });
  });
}
