// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class NotificationPresenter {
  static Future<void> initialize() async {
    if (html.Notification.supported &&
        html.Notification.permission != 'granted') {
      await html.Notification.requestPermission();
    }
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!html.Notification.supported) return;
    if (html.Notification.permission != 'granted') {
      final permission = await html.Notification.requestPermission();
      if (permission != 'granted') return;
    }
    html.Notification(
      title,
      body: body,
      icon: 'icons/Icon-192.png',
    );
  }
}
