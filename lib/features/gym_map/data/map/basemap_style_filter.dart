/// Categorias dos pontos de interesse do mapa base, agrupando as classes
/// (`class`) da camada `poi` do esquema OpenMapTiles.
enum BasemapPoiCategory {
  transport(<String>[
    'bus',
    'railway',
    'aerialway',
    'ferry_terminal',
    'harbor',
    'entrance',
    'parking',
    'bicycle_parking',
    'bicycle_rental',
    'fuel',
  ]),
  food(<String>[
    'restaurant',
    'fast_food',
    'cafe',
    'bar',
    'beer',
    'ice_cream',
    'bakery',
  ]),
  shops(<String>[
    'shop',
    'grocery',
    'clothing_store',
    'alcohol_shop',
    'butcher',
    'florist',
    'furniture',
    'jewelry',
    'mobile_phone',
    'music',
    'hairdresser',
    'laundry',
    'car',
    'bicycle',
  ]),
  health(<String>['hospital', 'pharmacy', 'doctors', 'dentist', 'veterinary']),
  education(<String>['school', 'college', 'library', 'kindergarten']),
  services(<String>[
    'bank',
    'atm',
    'post',
    'police',
    'fire_station',
    'town_hall',
    'office',
    'information',
    'toilets',
    'drinking_water',
    'shelter',
    'recycling',
    'waste_basket',
    'telephone',
  ]),
  leisure(<String>[
    'lodging',
    'museum',
    'art_gallery',
    'theatre',
    'cinema',
    'attraction',
    'monument',
    'castle',
    'zoo',
    'park',
    'garden',
    'playground',
    'stadium',
    'pitch',
    'swimming_pool',
    'sports_centre',
  ]),
  religion(<String>['place_of_worship']),

  /// Tudo que não entra nas categorias acima.
  other(<String>[]);

  const BasemapPoiCategory(this.classes);

  final List<String> classes;

  static List<String> get knownClasses => <String>[
    for (final category in values) ...category.classes,
  ];
}

/// Ajustes aplicados ao documento de estilo do mapa base (MapLibre Style
/// JSON no esquema OpenMapTiles, como o "liberty" do OpenFreeMap) antes de
/// ele virar o tema da `VectorTileLayer`.
class BasemapStyleFilter {
  const BasemapStyleFilter._();

  /// `source-layer` dos pontos de interesse no esquema OpenMapTiles.
  static const String poiSourceLayer = 'poi';

  /// Cópia de [style] em que as camadas de pontos de interesse deixam de
  /// desenhar as categorias em [hidden]. Ruas, bairros, parques e água
  /// continuam. O documento original não é alterado; um estilo fora do
  /// esquema OpenMapTiles fica como está.
  static Map<String, dynamic> withoutPoiCategories(
    Map<String, dynamic> style,
    Set<BasemapPoiCategory> hidden,
  ) {
    final Object? rawLayers = style['layers'];
    if (rawLayers is! List || hidden.isEmpty) return style;

    final hideAll = hidden.length == BasemapPoiCategory.values.length;
    final hiddenClasses = <String>[
      for (final category in hidden) ...category.classes,
    ];
    final visibleFilters = <Object>[
      if (hiddenClasses.isNotEmpty)
        <Object>[
          'match',
          <Object>['get', 'class'],
          hiddenClasses,
          false,
          true,
        ],
      if (hidden.contains(BasemapPoiCategory.other))
        <Object>[
          'match',
          <Object>['get', 'class'],
          BasemapPoiCategory.knownClasses,
          true,
          false,
        ],
    ];

    var changed = false;
    final layers = <Object?>[];
    for (final Object? layer in rawLayers) {
      if (layer is! Map || layer['source-layer'] != poiSourceLayer) {
        layers.add(layer);
        continue;
      }
      changed = true;
      if (hideAll) continue;
      final Object? filter = layer['filter'];
      layers.add(<String, dynamic>{
        for (final MapEntry<Object?, Object?> entry in layer.entries)
          entry.key.toString(): entry.value,
        'filter': <Object>[
          'all',
          if (filter is List && filter.isNotEmpty) filter,
          ...visibleFilters,
        ],
      });
    }
    if (!changed) return style;

    final Object? id = style['id'];
    final suffix = (hidden.map((category) => category.name).toList()..sort())
        .join('-');
    return <String, dynamic>{
      ...style,
      // Id próprio para o tema filtrado não se confundir com o original em
      // caches que usam o id do tema como chave.
      'id': '${id is String && id.isNotEmpty ? id : 'style'}-hide-$suffix',
      'layers': layers,
    };
  }
}
