import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      // ============================================================
      // REQUEST NOTIFICATION PERMISSION
      // ============================================================

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        'Notification permission: '
            '${settings.authorizationStatus}',
      );

      // ============================================================
      // GET FCM TOKEN
      // ============================================================

      final token = await _messaging.getToken();

      debugPrint('');
      debugPrint(
        '========================================',
      );
      debugPrint('HASANI PAYROLL FCM TOKEN');
      debugPrint(token ?? 'FCM TOKEN NOT AVAILABLE');
      debugPrint(
        '========================================',
      );
      debugPrint('');

      // ============================================================
      // LISTEN FOR TOKEN CHANGES
      // ============================================================

      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('');
        debugPrint(
          '========================================',
        );
        debugPrint('FCM TOKEN REFRESHED');
        debugPrint(newToken);
        debugPrint(
          '========================================',
        );
        debugPrint('');
      });

      // ============================================================
      // FOREGROUND NOTIFICATION
      // ============================================================

      FirebaseMessaging.onMessage.listen(
            (RemoteMessage message) {
          debugPrint('');
          debugPrint(
            '========================================',
          );
          debugPrint('FCM MESSAGE RECEIVED');
          debugPrint(
            'Title: ${message.notification?.title ?? 'No title'}',
          );
          debugPrint(
            'Body: ${message.notification?.body ?? 'No body'}',
          );
          debugPrint(
            'Data: ${message.data}',
          );
          debugPrint(
            '========================================',
          );
          debugPrint('');
        },
      );

      // ============================================================
      // NOTIFICATION CLICKED WHILE APP IS BACKGROUND
      // ============================================================

      FirebaseMessaging.onMessageOpenedApp.listen(
            (RemoteMessage message) {
          debugPrint('');
          debugPrint(
            '========================================',
          );
          debugPrint('NOTIFICATION CLICKED');
          debugPrint(
            'Message ID: ${message.messageId}',
          );
          debugPrint(
            'Data: ${message.data}',
          );
          debugPrint(
            '========================================',
          );
          debugPrint('');
        },
      );

      // ============================================================
      // APP OPENED FROM A TERMINATED STATE
      // ============================================================

      final initialMessage =
      await _messaging.getInitialMessage();

      if (initialMessage != null) {
        debugPrint('');
        debugPrint(
          '========================================',
        );
        debugPrint('APP OPENED FROM NOTIFICATION');
        debugPrint(
          'Message ID: ${initialMessage.messageId}',
        );
        debugPrint(
          'Data: ${initialMessage.data}',
        );
        debugPrint(
          '========================================',
        );
        debugPrint('');
      }
    } catch (error) {
      debugPrint(
        'Notification initialization error: $error',
      );
    }
  }
}