import 'dart:math';
import 'neon_api.dart';

class QrAttendanceService {
  static final Random _random = Random.secure();
  static String requestId() {
    final bytes = List.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static Future<Map<String, dynamic>> get(String path,
          [Map<String, String> query = const {}]) =>
      NeonApi.jsonRequest(
          Uri.parse('/api/qr-attendance$path')
              .replace(queryParameters: query.isEmpty ? null : query)
              .toString(),
          method: 'GET');
  static Future<Map<String, dynamic>> post(
          String path, Map<String, dynamic> body) =>
      NeonApi.jsonRequest('/api/qr-attendance$path', body: body);
  static String malaysiaTime(dynamic value) {
    final date = DateTime.tryParse('$value');
    if (date == null) return '—';
    final my = date.toUtc().add(const Duration(hours: 8));
    final hour = my.hour % 12 == 0 ? 12 : my.hour % 12;
    return '${my.day.toString().padLeft(2, '0')}/${my.month.toString().padLeft(2, '0')}/${my.year} '
        '$hour:${my.minute.toString().padLeft(2, '0')}:${my.second.toString().padLeft(2, '0')} ${my.hour >= 12 ? 'PM' : 'AM'}';
  }
}

/// Small transport seam for scanner recovery tests; production uses JWT APIs.
class QrAttendanceGateway {
  const QrAttendanceGateway();
  Future<Map<String, dynamic>> get(String path,
          [Map<String, String> query = const {}]) =>
      QrAttendanceService.get(path, query);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      QrAttendanceService.post(path, body);
}
