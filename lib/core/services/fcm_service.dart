// apps/patient-app/lib/core/services/fcm_service.dart
//
// Phase 11B — Viva's FCM + local notification glue.
//
// The patient app counterpart to Sara's FcmService. Same three
// responsibilities: Firebase init, device token registration with
// the backend (via the /patient-app scoped route), and foreground
// message rendering.
//
// Two differences from Sara:
//   1. Registers against the patient-app auth surface
//      (/api/v1/patient-app/fcm/register-device) because Viva uses
//      its own patient-login JWT, not the staff-login JWT.
//   2. Deep links go through Viva's Navigator key (supplied by the
//      caller via onNotificationTap) because Viva has a simpler
//      navigation surface than Sara's multi-tab workspace.
//
// Coexistence rule: does NOT replace the existing
// sync_settings_screen.dart manual sync UI in lib/features/sync/.
// That screen stays as the user-facing "sync now" control; this
// service handles the push side of the pipeline.
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

final vivaFcmServiceProvider = Provider<VivaFcmService>((ref) => VivaFcmService._());

@pragma('vm:entry-point')
Future<void> vivaBackgroundMessageHandler(RemoteMessage message) async {
  // Background isolate — Firebase is re-initialised automatically.
  // The notification row is durable on the backend, so this handler
  // only needs to not crash. The Phase 11B foreground sync loop
  // picks up the row on next app resume.
  debugPrint('[Viva FCM] background message: ${message.messageId}');
}

class VivaFcmService {
  VivaFcmService._();

  bool _initialised = false;
  String? _currentToken;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'viva-alerts';
  static const _channelName = 'Viva alerts';

  Future<void> initialise({
    void Function(String? actionUrl)? onNotificationTap,
    void Function()? onSyncTrigger,
  }) async {
    if (_initialised) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[Viva FCM] Firebase init failed (continuing without push): $e');
      _initialised = true;
      return;
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[Viva FCM] permission request failed: $e');
    }

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null) return;
        try {
          final map = json.decode(payload) as Map<String, dynamic>;
          final url = map['deep_link'] as String? ?? map['action_url'] as String?;
          onNotificationTap?.call(url);
        } catch (_) { /* ignore malformed payload */ }
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Appointment reminders, messages and clinical updates from your Signacare clinic',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    FirebaseMessaging.onBackgroundMessage(vivaBackgroundMessageHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      onSyncTrigger?.call();
      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? '';
      final payload = json.encode(message.data);
      _localNotifications.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onSyncTrigger?.call();
      final url = message.data['deep_link'] as String? ?? message.data['action_url'] as String?;
      onNotificationTap?.call(url);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      onSyncTrigger?.call();
      final url = initial.data['deep_link'] as String? ?? initial.data['action_url'] as String?;
      onNotificationTap?.call(url);
    }

    _initialised = true;
  }

  Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _currentToken = token;
      await _postRegisterToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        await _postRegisterToken(newToken);
      });
    } catch (e) {
      debugPrint('[Viva FCM] registerToken failed: $e');
    }
  }

  Future<void> unregisterToken() async {
    if (_currentToken == null) return;
    try {
      await pApi.delete('/patient-app/fcm/register-device/${Uri.encodeComponent(_currentToken!)}');
    } catch (e) {
      debugPrint('[Viva FCM] unregisterToken failed: $e');
    }
    _currentToken = null;
  }

  Future<void> _postRegisterToken(String token) async {
    final platform = !kIsWeb && Platform.isIOS ? 'ios' : 'android';
    await pApi.post('/patient-app/fcm/register-device', data: {
      'deviceToken': token,
      'platform': platform,
    });
  }
}
