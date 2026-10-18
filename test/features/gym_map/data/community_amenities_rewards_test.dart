import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/features/gym_map/data/crowd_report_remote_service.dart';
import 'package:gymmap/features/gym_map/domain/gym_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'subscription.auth.user_id': 'anon_1',
      'subscription.auth.token': 'token-1',
    });
  });

  test('parses amenity votes and skips unknown amenities', () {
    final votes = CrowdReportRemoteService.parseAmenityVotes(<Object?>[
      <String, Object?>{
        'amenity': 'pool',
        'yes': 3,
        'no': 0,
        'status': 'confirmed',
        'userVote': true,
      },
      <String, Object?>{
        'amenity': 'group_classes',
        'yes': 1,
        'no': 1,
        'status': 'pending',
        'userVote': null,
      },
      <String, Object?>{'amenity': 'sauna', 'yes': 9, 'status': 'confirmed'},
    ]);

    expect(votes.map((v) => v.amenity), [
      GymAmenity.pool,
      GymAmenity.groupClasses,
    ]);
    expect(votes.first.status, AmenityVoteStatus.confirmed);
    expect(votes.first.userVote, isTrue);
    expect(votes.last.status, AmenityVoteStatus.pending);
    expect(votes.last.userVote, isNull);
  });

  test(
    'sends amenity votes with server keys, including withdrawn ones',
    () async {
      late Map<String, dynamic> sent;
      late Uri url;
      final service = await CrowdReportRemoteService.create(
        backendBaseUrl: 'http://backend.test',
        httpClient: MockClient((request) async {
          url = request.url;
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.headers['authorization'], 'Bearer token-1');
          return http.Response(
            jsonEncode(<String, Object?>{
              'amenities': <Object?>[
                <String, Object?>{
                  'amenity': 'cardio',
                  'yes': 1,
                  'no': 0,
                  'status': 'pending',
                  'userVote': true,
                },
              ],
              'pointsAwarded': 2,
              'pointsBalance': 12,
            }),
            200,
          );
        }),
      );

      final result = await service.submitAmenityVotes(
        gymId: 'node-1',
        votes: <GymAmenity, bool?>{
          GymAmenity.cardio: true,
          GymAmenity.open24h: null,
        },
      );

      expect(url.path, '/v1/gyms/amenities/votes');
      expect(sent['gymId'], 'node-1');
      expect(sent['votes'], <String, Object?>{
        'cardio': true,
        'open_24h': null,
      });
      expect(result.pointsAwarded, 2);
      expect(result.pointsBalance, 12);
      expect(result.amenities.single.amenity, GymAmenity.cardio);
    },
  );

  test('reads the rewards balance and reports why it cannot redeem', () async {
    final service = await CrowdReportRemoteService.create(
      backendBaseUrl: 'http://backend.test',
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          expect(request.url.path, '/v1/rewards/anon_1');
          return http.Response(
            jsonEncode(<String, Object?>{
              'balance': 40,
              'costPoints': 100,
              'planKey': 'smart',
              'planDays': 7,
              'canRedeem': false,
              'blockedReason': 'not_enough_points',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{'error': 'higher_plan_active'}),
          409,
        );
      }),
    );

    final rewards = await service.loadRewards();
    expect(rewards!.balance, 40);
    expect(rewards.canRedeem, isFalse);
    expect(rewards.blockedReason, 'not_enough_points');

    expect(
      service.redeemReward,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'higher_plan_active',
        ),
      ),
    );
  });
}
