import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../firestore_state_store.dart';

class FakeFirestore {
  String? revision;
  final documents = <String, dynamic>{};
  final commits = <List<dynamic>>[];
  var sequence = 0;
  late final client = MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith(':beginTransaction')) {
      return http.Response('{"transaction":"snapshot"}', 200);
    }
    if (path.endsWith(':rollback')) return http.Response('{}', 200);
    if (path.endsWith('/gymmap_meta/state')) {
      return revision == null
          ? http.Response('{}', 404)
          : http.Response(jsonEncode({'updateTime': revision}), 200);
    }
    if (path.endsWith('/gymmap_state')) {
      expect(request.url.queryParameters['transaction'], 'snapshot');
      return http.Response(
        jsonEncode({'documents': documents.values.toList()}),
        200,
      );
    }
    if (path.endsWith(':commit')) {
      final writes = jsonDecode(request.body)['writes'] as List;
      final condition = writes.first['currentDocument'] as Map;
      if ((condition['exists'] == false && revision != null) ||
          (condition['updateTime'] != null &&
              condition['updateTime'] != revision)) {
        return http.Response('{}', 412);
      }
      commits.add(writes);
      for (final write in writes.skip(1)) {
        if (write['delete'] != null) {
          documents.remove(write['delete']);
        } else {
          documents[write['update']['name']] = write['update'];
        }
      }
      revision =
          '2026-10-18T12:00:00.${(++sequence).toString().padLeft(6, '0')}Z';
      return http.Response(
        jsonEncode({
          'writeResults': [
            for (final _ in writes) {'updateTime': revision},
          ],
        }),
        200,
      );
    }
    throw StateError('Unexpected Firestore request: ${request.method} $path');
  });

  FirestoreStateStore create() =>
      FirestoreStateStore(projectId: 'test-project', client: client);
}

void main() {
  test(
    'stores entities individually, only writes changes and persists deletions',
    () async {
      final remote = FakeFirestore();
      final store = remote.create();
      final state = (await store.refresh())!;
      state['account'] = {
        'user/a': {'userId': 'user/a'},
      };
      state['point_ledger'] = {
        'user/a': {'earned': 10},
      };
      await store.persist(state);
      expect(remote.commits.single, hasLength(3));
      expect(remote.commits.single.first['currentDocument'], {'exists': false});
      await store.persist(state);
      expect(remote.commits, hasLength(1));
      expect(await store.refresh(), isNull);
      final another = remote.create();
      expect(await another.refresh(), state);
      state['account']!.clear();
      state['point_ledger']!['user/a']!['earned'] = 11;
      await store.persist(state);
      expect(
        remote.commits.last.where((write) => write['delete'] != null),
        hasLength(1),
      );
      final reloaded = (await another.refresh())!;
      expect(reloaded['account'] ?? {}, isEmpty);
      expect(reloaded['point_ledger']!['user/a']!['earned'], 11);
    },
  );

  test(
    'rejects stale writes and reloads the winning persistent state',
    () async {
      final remote = FakeFirestore();
      final first = remote.create();
      final original = (await first.refresh())!;
      original['account'] = {
        'a': {'userId': 'a'},
      };
      await first.persist(original);
      final second = remote.create();
      final concurrent = (await second.refresh())!;
      concurrent['account']!['b'] = {'userId': 'b'};
      await second.persist(concurrent);
      original['account']!['c'] = {'userId': 'c'};
      await expectLater(first.persist(original), throwsStateError);
      final fresh = (await first.refresh())!;
      expect(fresh['account']!.keys, containsAll(['a', 'b']));
      expect(fresh['account']!.containsKey('c'), isFalse);
      expect(remote.commits, hasLength(2));
    },
  );
}
