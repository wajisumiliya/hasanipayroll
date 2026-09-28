import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../screens/supabase_service.dart';
import 'notification_presenter.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const String _sendFunctionName = 'send-notification';

  static Future<void> initialize({
    String? employeeId,
    String? branchId,
  }) async {
    try {
      await NotificationPresenter.initialize();
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

      // ============================================================
      // LISTEN FOR TOKEN CHANGES
      // ============================================================

      _messaging.onTokenRefresh.listen((newToken) async {
        await _registerToken(newToken, employeeId, branchId);
      });

      // ============================================================
      // FOREGROUND NOTIFICATION
      // ============================================================

      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          final title = message.notification?.title ??
              message.data['title']?.toString() ??
              'Hasani Payroll';
          final body = message.notification?.body ??
              message.data['body']?.toString() ??
              '';
          if (body.isNotEmpty) {
            await NotificationPresenter.show(title: title, body: body);
          }
        },
      );

      // ============================================================
      // NOTIFICATION CLICKED WHILE APP IS BACKGROUND
      // ============================================================

      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          // Do not log notification payloads or identifiers. They may contain
          // payroll or employee information.
        },
      );

      // ============================================================
      // APP OPENED FROM A TERMINATED STATE
      // ============================================================

      final initialMessage = await _messaging.getInitialMessage();

      if (initialMessage != null) {
        // The payload is intentionally not logged because notifications may
        // contain payroll or employee information.
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
      _sendFunctionName,
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

  static Future<void> sendPayslipAvailable({
    required String employeeId,
    required DateTime period,
  }) {
    return send(
      title: 'New Payslip Available',
      body:
          'Your ${DateFormat('MMMM yyyy').format(period)} payslip is ready to view.',
      audience: 'employee',
      employeeId: employeeId.trim(),
      type: 'payslip',
    );
  }

  static Future<void> sendEaFormsAvailable({
    required Iterable<String> employeeIds,
    required int taxYear,
  }) async {
    final ids = employeeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;

    final response = await SupabaseService.client.functions.invoke(
      _sendFunctionName,
      body: {
        'title': 'EA Form Available',
        'body': 'Your EA form for $taxYear is ready to view.',
        'type': 'ea_form',
        'audience': 'employee',
        'employee_ids': ids,
        'tax_year': taxYear,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Notification service returned ${response.status}.');
    }
  }
}
