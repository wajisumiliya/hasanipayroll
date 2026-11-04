import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../screens/supabase_service.dart';
import 'neon_api.dart';
import 'notification_presenter.dart';
import 'app_service.dart';
import 'notification_delivery.dart';
export 'notification_delivery.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static bool _listenersInstalled = false;
  static const _webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  static void _installListeners() {
    if (_listenersInstalled) return;
    _messaging.onTokenRefresh.listen((token) async {
      final user = AppService.instance.currentUser;
      if (user == null || user.isRequestAdmin) return;
      try {
        await _registerToken(token, user.employeeId, user.branchId);
      } catch (_) {
        debugPrint(
            'Notification device refresh failed; sign in again to retry.');
      }
    });
    FirebaseMessaging.onMessage.listen((message) async {
      final title = message.notification?.title ??
          message.data['title']?.toString() ??
          'Hasani Payroll';
      final body =
          message.notification?.body ?? message.data['body']?.toString() ?? '';
      if (body.isEmpty) return;
      try {
        await NotificationPresenter.show(title: title, body: body);
      } catch (_) {
        debugPrint('Unable to display foreground notification.');
      }
    });
    _listenersInstalled = true;
  }

  static Future<void> initialize({
    String? employeeId,
    String? branchId,
  }) async {
    // Install listeners before any operation that can fail (permission, token,
    // or authenticated registration). A logged-out startup must not disable them.
    try {
      _installListeners();
    } catch (_) {
      debugPrint('Firebase notification listeners unavailable.');
    }
    try {
      await NotificationPresenter.initialize();
    } catch (_) {
      debugPrint('Local notification setup unavailable.');
    }
    if (AppService.instance.currentUser == null) return;
    try {
      await registerCurrentDevice(employeeId: employeeId, branchId: branchId);
    } catch (_) {
      debugPrint(
          'Notification device registration failed; sign in again to retry.');
    }
  }

  static Future<void> _registerToken(
    String token,
    String? employeeId,
    String? branchId,
  ) async {
    await SupabaseService.database.rpc(
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
    _installListeners();
    final user = AppService.instance.currentUser;
    if (user == null || user.isRequestAdmin) {
      throw StateError(
          'Sign in to an employee or branch account to enable notifications.');
    }
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError(
          'Notifications are blocked. Allow notifications in your device or browser settings, then try again.');
    }
    final token = await _messaging.getToken(
      vapidKey: kIsWeb && _webVapidKey.isNotEmpty ? _webVapidKey : null,
    );
    if (token == null || token.isEmpty) {
      throw StateError(
          'A notification token is not available. Check your connection and try again.');
    }
    await _registerToken(token, user.employeeId, user.branchId);
  }

  static Future<String> enableDeviceNotifications() async {
    try {
      await NotificationPresenter.initialize();
      await registerCurrentDevice();
      return 'Device registered for notifications. Eligible recent payslip notifications will be retried.';
    } on StateError catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not register notifications. Check your connection and notification permission, then try again.';
    }
  }

  static Future<String> deliveryStatus(String employeeId) async {
    final data = await NeonApi.jsonRequest(
      '/api/notifications/status?employee_id=${Uri.encodeQueryComponent(employeeId)}',
      method: 'GET',
    );
    final config = data['firebase'] as Map? ?? {};
    final devices = data['devices'] as Map? ?? {};
    final firebase = switch (config['status']) {
      'configured' => 'Firebase server configuration is present.',
      'not_configured' =>
        'Firebase server credentials are missing on the backend.',
      'project_mismatch' =>
        'Backend Firebase credentials belong to a different project.',
      _ => 'Firebase server configuration is invalid.',
    };
    final lines = <String>[
      data['publication_notifications_ready'] == true
          ? 'Publication notifications are installed on the backend.'
          : 'Publication notifications are not enabled on the backend. Deploy the latest backend update.',
      firebase,
      'Registered devices: ${devices['total'] ?? 0} (Android: ${devices['android'] ?? 0}, web: ${devices['web'] ?? 0}).',
    ];
    if (devices['total'] == 0) {
      lines.add('Ask the employee to sign in and select Enable notifications.');
    }
    final payroll = data['payroll'] as List? ?? [];
    if (payroll.isEmpty)
      lines.add('No saved payroll records for this employee.');
    for (final row in payroll) {
      lines.add(
          '${row['payroll_month']}: ${row['available'] == true ? 'released' : 'not released'}, '
          'inbox: ${row['inbox_saved'] == true ? 'saved' : 'missing'}, '
          'push queue: ${row['push_queued'] == true ? 'present' : 'missing'}.');
    }
    final recent = data['recent'] as List? ?? [];
    if (recent.isEmpty)
      lines.add('No payslip push delivery has been queued for this employee.');
    for (final row in recent) {
      final status = row['last_status'] ?? 'queued';
      final errors = (row['last_error_codes'] as List? ?? []).join(', ');
      lines.add(
          '${row['payroll_month']}: $status, attempts: ${row['attempts']}${errors.isEmpty ? '' : ' ($errors)'}.');
    }
    lines.add(
        'A sent status means Firebase accepted the push; it does not confirm display on the device.');
    return lines.join('\n');
  }

  static Future<void> send({
    required String title,
    required String body,
    required String audience,
    String type = 'information',
    String? branchId,
    String? employeeId,
  }) async {
    await sendWithResult(
        title: title,
        body: body,
        audience: audience,
        type: type,
        branchId: branchId,
        employeeId: employeeId);
  }

  static Future<NotificationDelivery> sendWithResult({
    required String title,
    required String body,
    required String audience,
    String type = 'information',
    String? branchId,
    String? employeeId,
  }) async {
    final response = await NeonApi.jsonRequest(
      '/api/notifications/send',
      body: {
        'title': title.trim(),
        'body': body.trim(),
        'type': type,
        'audience': audience,
        'branch_id': branchId,
        'employee_id': employeeId,
      },
    );
    if (response['ok'] != true) {
      throw StateError('Unable to send notification.');
    }
    return NotificationDelivery.fromJson(response);
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

    final response = await NeonApi.jsonRequest(
      '/api/notifications/send',
      body: {
        'title': 'EA Form Available',
        'body': 'Your EA form for $taxYear is ready to view.',
        'type': 'ea_form',
        'audience': 'employee',
        'employee_ids': ids,
        'tax_year': taxYear,
      },
    );
    if (response['ok'] != true) {
      throw StateError('Unable to send notification.');
    }
  }
}
