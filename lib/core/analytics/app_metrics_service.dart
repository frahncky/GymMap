import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppMetricsService {
  AppMetricsService._();

  static final AppMetricsService instance = AppMetricsService._();

  static const String _installAtPrefKey = 'gymmap_metrics_install_at_utc_v1';
  static const String _retentionD7TrackedPrefKey =
      'gymmap_metrics_retention_d7_tracked_v1';
  static const String _eventCountersPrefKey =
      'gymmap_metrics_event_counters_json_v1';
  static const String _recentEventsPrefKey =
      'gymmap_metrics_recent_events_json_v1';
  static const String _sessionCountPrefKey = 'gymmap_metrics_session_count_v1';
  static const String _sessionSecondsPrefKey =
      'gymmap_metrics_session_seconds_v1';
  static const int _maxRecentEvents = 200;

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  DateTime? _sessionStartAtUtc;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _isInitialized = true;

    final existingInstallAt = prefs.getString(_installAtPrefKey);
    if ((existingInstallAt ?? '').trim().isEmpty) {
      await prefs.setString(_installAtPrefKey, DateTime.now().toUtc().toIso8601String());
      await trackEvent('app_install');
    }
  }

  Future<void> startSession({String source = 'unknown'}) async {
    await initialize();
    if (_sessionStartAtUtc != null) {
      return;
    }
    _sessionStartAtUtc = DateTime.now().toUtc();
    await _trackRetentionD7IfEligible(_sessionStartAtUtc!);
    await trackEvent('session_start', params: <String, Object?>{'source': source});
  }

  Future<void> endSession({String reason = 'unknown'}) async {
    await initialize();
    final startAt = _sessionStartAtUtc;
    if (startAt == null) {
      return;
    }
    _sessionStartAtUtc = null;
    final durationSec = DateTime.now()
        .toUtc()
        .difference(startAt)
        .inSeconds
        .clamp(1, 86400);
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final sessionCount = prefs.getInt(_sessionCountPrefKey) ?? 0;
    final totalSeconds = prefs.getInt(_sessionSecondsPrefKey) ?? 0;
    await prefs.setInt(_sessionCountPrefKey, sessionCount + 1);
    await prefs.setInt(_sessionSecondsPrefKey, totalSeconds + durationSec);
    await trackEvent(
      'session_end',
      params: <String, Object?>{'reason': reason, 'durationSec': durationSec},
    );
  }

  Future<void> trackScreen(String screenName) async {
    final normalized = screenName.trim();
    if (normalized.isEmpty) {
      return;
    }
    await trackEvent(
      'screen_view',
      params: <String, Object?>{'screen': normalized},
    );
  }

  Future<void> trackEvent(
    String eventName, {
    Map<String, Object?> params = const <String, Object?>{},
  }) async {
    final normalizedEventName = eventName.trim();
    if (normalizedEventName.isEmpty) {
      return;
    }
    await initialize();
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final nowUtc = DateTime.now().toUtc();
    final sanitizedParams = _sanitizeParams(params);
    final event = <String, Object?>{
      'name': normalizedEventName,
      'atUtc': nowUtc.toIso8601String(),
      'params': sanitizedParams,
    };

    final counters = _loadEventCounters(prefs);
    counters[normalizedEventName] = (counters[normalizedEventName] ?? 0) + 1;
    await prefs.setString(_eventCountersPrefKey, jsonEncode(counters));

    final recentEvents = _loadRecentEvents(prefs);
    recentEvents.add(event);
    if (recentEvents.length > _maxRecentEvents) {
      recentEvents.removeRange(0, recentEvents.length - _maxRecentEvents);
    }
    await prefs.setString(_recentEventsPrefKey, jsonEncode(recentEvents));
  }

  Future<void> _trackRetentionD7IfEligible(DateTime nowUtc) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final alreadyTracked = prefs.getBool(_retentionD7TrackedPrefKey) ?? false;
    if (alreadyTracked) {
      return;
    }
    final installAtRaw = prefs.getString(_installAtPrefKey);
    final installAt = DateTime.tryParse(installAtRaw ?? '')?.toUtc();
    if (installAt == null) {
      return;
    }
    final daysSinceInstall = nowUtc.difference(installAt).inDays;
    if (daysSinceInstall < 6) {
      return;
    }
    await trackEvent(
      'retention_d7_hit',
      params: <String, Object?>{'daysSinceInstall': daysSinceInstall},
    );
    await prefs.setBool(_retentionD7TrackedPrefKey, true);
  }

  Map<String, int> _loadEventCounters(SharedPreferences prefs) {
    final raw = prefs.getString(_eventCountersPrefKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, int>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, int>{};
    }
    final counters = <String, int>{};
    for (final entry in decoded.entries) {
      final key = '${entry.key}'.trim();
      if (key.isEmpty) {
        continue;
      }
      final valueRaw = entry.value;
      final value =
          valueRaw is num ? valueRaw.toInt() : int.tryParse('$valueRaw');
      if (value == null) {
        continue;
      }
      counters[key] = value;
    }
    return counters;
  }

  List<Map<String, Object?>> _loadRecentEvents(SharedPreferences prefs) {
    final raw = prefs.getString(_recentEventsPrefKey);
    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, Object?>>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <Map<String, Object?>>[];
    }
    final events = <Map<String, Object?>>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final mapped = <String, Object?>{};
      for (final entry in item.entries) {
        mapped['${entry.key}'] = entry.value;
      }
      events.add(mapped);
    }
    return events;
  }

  Map<String, Object?> _sanitizeParams(Map<String, Object?> params) {
    final sanitized = <String, Object?>{};
    for (final entry in params.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      final value = entry.value;
      if (value == null ||
          value is String ||
          value is num ||
          value is bool) {
        sanitized[key] = value;
        continue;
      }
      sanitized[key] = value.toString();
    }
    return sanitized;
  }
}
