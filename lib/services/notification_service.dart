import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../screens/supabase_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize({
    String? employeeId,
    String? branchId,
  }) async {
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

      if (token != null && token.isNotEmpty) {
        await _registerToken(token, employeeId, branchId);
      }

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

      _messaging.onTokenRefresh.listen((newToken) async {
        await _registerToken(newToken, employeeId, branchId);
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

      final initialMessage = await _messaging.getInitialMessage();

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

  static Future<void> _registerToken(
    String token,
    String? employeeId,
    String? branchId,
  ) async {
    await SupabaseService.client.rpc(
      'register_notification_device',
      params: {
        'p_token': token,
        'p_employee_id': employeeId?.trim(),
        'p_branch_id': branchId?.trim(),
        'p_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      },
    );
  }

  static Future<void> registerCurrentDevice({
    String? employeeId,
    String? branchId,
  }) async {
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerToken(token, employeeId, branchId);
    }
  }

  static Future<void> send({
    required String title,
    required String body,
    required String audience,
    String type = 'information',
    String? branchId,
    String? employeeId,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'send-notification',
      body: {
        'title': title.trim(),
        'body': body.trim(),
        'type': type,
        'audience': audience,
        'branch_id': branchId,
        'employee_id': employeeId,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Notification service returned ${response.status}.');
    }
  }
}
