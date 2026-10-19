import 'dart:convert';

import 'package:http/http.dart' as http;

typedef StateMaps = Map<String, Map<String, Map<String, dynamic>>>;

/// Stores each entity separately and guards atomic diffs with a revision.
/// A stale instance cannot overwrite updates committed by another revision.
class FirestoreStateStore {
  FirestoreStateStore({required String projectId, required http.Client client})
    : _client = client,
      _database = 'projects/$projectId/databases/(default)';

  final http.Client _client;
  final String _database;
  String? _revision;
  bool _loaded = false;
  Map<String, Map<String, String>> _persisted = {};

  String get _documents => '$_database/documents';
  String get _meta => '$_documents/gymmap_meta/state';

  Future<http.Response> _request(
    String method,
    String resource, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(
      method,
      Uri.https('firestore.googleapis.com', '/v1/$resource', query),
    );
    request.headers['Content-Type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    return http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 20)),
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Never include response payloads, credentials, or account data in errors.
      throw StateError('firestore_http_${response.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>?> _metadata({String? transaction}) async {
    final response = await _request(
      'GET',
      _meta,
      query: transaction == null ? null : {'transaction': transaction},
    );
    if (response.statusCode == 404) return null;
    return _decode(response);
  }

  /// Null means the caller's in-memory state still matches persistent state.
  Future<StateMaps?> refresh() async {
    final metadata = await _metadata();
    final remoteRevision = metadata?['updateTime'] as String?;
    if (_loaded && remoteRevision == _revision) return null;

    final begin = _decode(
      await _request(
        'POST',
        '$_documents:beginTransaction',
        body: {
          'options': {'readOnly': <String, dynamic>{}},
        },
      ),
    );
    final transaction = begin['transaction'] as String;
    try {
      final snapshotMetadata = await _metadata(transaction: transaction);
      final state = <String, Map<String, Map<String, dynamic>>>{};
      final persisted = <String, Map<String, String>>{};
      String? nextPage;
      do {
        final page = _decode(
          await _request(
            'GET',
            '$_documents/gymmap_state',
            query: {
              'pageSize': '500',
              'transaction': transaction,
              if (nextPage != null) 'pageToken': nextPage,
            },
          ),
        );
        for (final document in (page['documents'] as List? ?? [])) {
          final fields = document['fields'] as Map;
          final kind = fields['kind']['stringValue'] as String;
          final id = fields['id']['stringValue'] as String;
          final payload = fields['payload']['stringValue'] as String;
          (state[kind] ??= {})[id] = Map<String, dynamic>.from(
            jsonDecode(payload) as Map,
          );
          persisted[document['name'] as String] = {
            'kind': kind,
            'id': id,
            'payload': payload,
          };
        }
        nextPage = page['nextPageToken'] as String?;
      } while (nextPage != null && nextPage.isNotEmpty);
      _revision = snapshotMetadata?['updateTime'] as String?;
      _persisted = persisted;
      _loaded = true;
      return state;
    } finally {
      // Read-only transactions have no writes; release the snapshot promptly.
      try {
        await _request(
          'POST',
          '$_documents:rollback',
          body: {'transaction': transaction},
        );
      } catch (_) {
        /* The server also expires read-only transactions. */
      }
    }
  }

  Future<void> persist(StateMaps state) async {
    if (!_loaded) throw StateError('firestore_state_not_loaded');
    final next = <String, Map<String, String>>{};
    final writes = <Map<String, dynamic>>[
      {
        'update': {
          'name': _meta,
          'fields': {
            'updatedAt': {
              'stringValue': DateTime.now().toUtc().toIso8601String(),
            },
          },
        },
        'currentDocument':
            _revision == null ? {'exists': false} : {'updateTime': _revision},
      },
    ];
    for (final kind in state.entries) {
      for (final row in kind.value.entries) {
        final encoded = base64Url
            .encode(utf8.encode('${kind.key}:${row.key}'))
            .replaceAll('=', '');
        final name = '$_documents/gymmap_state/$encoded';
        final payload = jsonEncode(row.value);
        next[name] = {'kind': kind.key, 'id': row.key, 'payload': payload};
        if (_persisted[name]?['payload'] != payload) {
          writes.add({
            'update': {
              'name': name,
              'fields': {
                'kind': {'stringValue': kind.key},
                'id': {'stringValue': row.key},
                'payload': {'stringValue': payload},
              },
            },
          });
        }
      }
    }
    for (final name in _persisted.keys) {
      if (!next.containsKey(name)) writes.add({'delete': name});
    }
    if (writes.length == 1) return;
    try {
      final result = _decode(
        await _request('POST', '$_documents:commit', body: {'writes': writes}),
      );
      _revision =
          (result['writeResults'] as List).first['updateTime'] as String;
      _persisted = next;
    } catch (_) {
      // Next request must reload; failed writes must never become a baseline.
      _loaded = false;
      rethrow;
    }
  }
}
