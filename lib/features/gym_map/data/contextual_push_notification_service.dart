import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContextualPushNotificationService {
  static const String _pushNotificationsPrefKey = 'gymmap_pref_push_v1';
  static const String _locationAlertsPrefKey = 'gymmap_pref_location_alerts_v1';
  static const String _lastAlertAtPrefKey = 'gymmap_push_last_alert_at_v1';
  static const String _lastAlertGymIdPrefKey =
      'gymmap_push_last_alert_gym_id_v1';
  static const String _lastAlertGymAtPrefKey =
      'gymmap_push_last_alert_gym_at_v1';
  static const int _lowCrowdThresholdPercent = 35;
  static const double _maxDistanceMeters = 1800;
  static const Duration _globalCooldown = Duration(minutes: 30);
  static const Duration _sameGymCooldown = Duration(minutes: 90);
  static const String _channelId = 'gymmap_contextual_alerts_v1';
  static const String _channelName = 'Alertas contextuais';
  static const String _channelDescription =
      'Alertas quando houver academia com lotacao baixa proxima.';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    await _notificationsPlugin.initialize(settings);
    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macosImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> maybeNotifyLowCrowdNearby({
    required String gymId,
    required String gymName,
    required int occupancyPercent,
    required double distanceMeters,
  }) async {
    if (occupancyPercent > _lowCrowdThresholdPercent ||
        distanceMeters > _maxDistanceMeters) {
      return;
    }
    if (!_isInitialized) {
      await initialize();
    }
    await _requestPermissions();

    final prefs = await SharedPreferences.getInstance();
    final pushNotificationsEnabled =
        prefs.getBool(_pushNotificationsPrefKey) ?? true;
    final locationAlertsEnabled = prefs.getBool(_locationAlertsPrefKey) ?? true;
    if (!pushNotificationsEnabled || !locationAlertsEnabled) {
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    final lastAlertAt = _tryParseDate(prefs.getString(_lastAlertAtPrefKey));
    if (lastAlertAt != null && nowUtc.difference(lastAlertAt) < _globalCooldown) {
      return;
    }
    final lastAlertGymId = '${prefs.getString(_lastAlertGymIdPrefKey) ?? ''}'
        .trim();
    final lastAlertGymAt = _tryParseDate(
      prefs.getString(_lastAlertGymAtPrefKey),
    );
    if (lastAlertGymId == gymId &&
        lastAlertGymAt != null &&
        nowUtc.difference(lastAlertGymAt) < _sameGymCooldown) {
      return;
    }

    final normalizedGymName = gymName.trim();
    if (normalizedGymName.isEmpty) {
      return;
    }

    final clampedOccupancy = occupancyPercent.clamp(0, 100);
    final distanceLabel = _distanceLabel(distanceMeters);
    final title = 'Academia com lotacao baixa perto';
    final body =
        '$normalizedGymName com $clampedOccupancy% agora, a $distanceLabel de voce.';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.recommendation,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
    );

    final notificationId = _notificationIdForGym(gymId);
    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      details,
      payload: gymId,
    );

    await prefs.setString(_lastAlertAtPrefKey, nowUtc.toIso8601String());
    await prefs.setString(_lastAlertGymIdPrefKey, gymId);
    await prefs.setString(_lastAlertGymAtPrefKey, nowUtc.toIso8601String());
  }

  DateTime? _tryParseDate(String? raw) {
    final normalized = '${raw ?? ''}'.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return DateTime.tryParse(normalized)?.toUtc();
  }

  String _distanceLabel(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  int _notificationIdForGym(String gymId) {
    final hash = gymId.codeUnits.fold<int>(0, (value, code) {
      return (value * 31 + code) & 0x7fffffff;
    });
    return hash == 0 ? 1 : hash;
  }
}
