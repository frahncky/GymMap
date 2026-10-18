import 'package:test/test.dart';

import '../server.dart';

void main() {
  // Centro de São Luís (MA).
  const lat = -2.53;
  const lng = -44.28;

  Map<String, dynamic> gym(
    String id,
    double gymLat,
    double gymLng, {
    String userId = 'user-a',
    String updatedAt = '2026-10-01T00:00:00.000Z',
    String name = 'Academia X',
  }) => <String, dynamic>{
    'id': id,
    'userId': userId,
    'name': name,
    'address': 'Rua 1',
    'lat': gymLat,
    'lng': gymLng,
    'updatedAtUtc': updatedAt,
  };

  test('keeps gyms inside the radius, nearest first, without userId', () {
    final result = nearbyGymLocations(
      [
        gym('far', -2.90, -44.28), // ~41 km
        gym('near', -2.531, -44.281),
        gym('mid', -2.60, -44.28), // ~7,8 km
      ],
      lat: lat,
      lng: lng,
      radiusKm: 25,
    );

    expect(result.map((g) => g['id']), ['near', 'mid']);
    expect(result.first.containsKey('userId'), isFalse);
  });

  test('merges the same gym sent by several users, keeping the newest', () {
    final result = nearbyGymLocations(
      [
        gym('node-1', lat, lng, userId: 'a', name: 'Antigo'),
        gym(
          'node-1',
          lat,
          lng,
          userId: 'b',
          name: 'Novo',
          updatedAt: '2026-10-10T00:00:00.000Z',
        ),
      ],
      lat: lat,
      lng: lng,
      radiusKm: 5,
    );

    expect(result, hasLength(1));
    expect(result.single['name'], 'Novo');
  });

  test('ignores entries without id or coordinates and respects the limit', () {
    final result = nearbyGymLocations(
      [
        <String, dynamic>{'id': '', 'lat': lat, 'lng': lng},
        <String, dynamic>{'id': 'no-coords'},
        for (var i = 0; i < 5; i++) gym('g$i', lat + i * 0.001, lng),
      ],
      lat: lat,
      lng: lng,
      radiusKm: 5,
      limit: 3,
    );

    expect(result.map((g) => g['id']), ['g0', 'g1', 'g2']);
  });

  test('gymDistanceKm matches a known distance', () {
    // 1 grau de latitude ≈ 111,2 km.
    expect(gymDistanceKm(0, 0, 1, 0), closeTo(111.2, 0.2));
  });
}
