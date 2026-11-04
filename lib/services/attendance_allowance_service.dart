class AttendanceAllowanceReason {
  const AttendanceAllowanceReason({required this.category, required this.dates,
    required this.count, required this.details});
  final String category;
  final List<String> dates;
  final int count;
  final String details;
}

/// Uses the same monthly report membership for deduction and explanation.
class AttendanceAllowanceService {
  static Future<Map<String, List<AttendanceAllowanceReason>>> reasons({
    required List<String> employeeIds,
    required Future<Map<String, dynamic>> Function() loadLate,
    required Future<Map<String, dynamic>> Function(String, List<String>) loadStatus,
  }) async {
    final selected = employeeIds.map((id) => id.trim().toUpperCase())
        .where((id) => id.isNotEmpty).toSet();
    if (selected.isEmpty) return {};
    final ids = selected.toList();
    final categories = ['Late'];
    final requests = <Future<Map<String, dynamic>>>[loadLate()];
    for (var offset = 0; offset < ids.length; offset += 500) {
      final batch = ids.sublist(offset, (offset + 500).clamp(0, ids.length));
      for (final status in ['MC', 'UNPAID']) {
        categories.add(status == 'MC' ? 'MC' : 'UL-Unpaid');
        requests.add(loadStatus(status, batch));
      }
    }
    final results = await Future.wait(requests);
    final output = <String, List<AttendanceAllowanceReason>>{};
    for (var index = 0; index < results.length; index++) {
      final reports = results[index]['reports'];
      if (reports is! List) throw StateError('Attendance report unavailable.');
      for (final raw in reports) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = '${row['employee_id']}'.trim().toUpperCase();
        if (!selected.contains(id)) continue;
        final events = (row['events'] as List? ?? const [])
            .map((event) => Map<String, dynamic>.from(event as Map)).toList();
        final dates = <String>{
          for (final date in row['dates'] as List? ?? const []) '$date',
          for (final event in events)
            if (event['date'] != null) '${event['date']}',
        }.toList()..sort();
        final details = events.map((event) {
          final type = event['type'] == 'break' ? 'Excess break' : 'Late arrival';
          return '$type: ${event['date']}';
        }).toSet().join('; ');
        output.putIfAbsent(id, () => []).add(AttendanceAllowanceReason(
          category: categories[index], dates: dates,
          count: int.tryParse('${row['count']}') ?? dates.length,
          details: details,
        ));
      }
    }
    return output;
  }

  static Future<Set<String>> disqualifiedEmployees({
    required List<String> employeeIds,
    required Future<Map<String, dynamic>> Function() loadLate,
    required Future<Map<String, dynamic>> Function(String, List<String>) loadStatus,
  }) async => (await reasons(employeeIds: employeeIds, loadLate: loadLate,
      loadStatus: loadStatus)).keys.toSet();
}
