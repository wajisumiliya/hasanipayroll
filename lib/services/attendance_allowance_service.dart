/// Uses report membership rather than shortage amounts or inferred late times.
class AttendanceAllowanceService {
  static Future<Set<String>> disqualifiedEmployees({
    required List<String> employeeIds,
    required Future<Map<String, dynamic>> Function() loadLate,
    required Future<Map<String, dynamic>> Function(String, List<String>)
        loadStatus,
  }) async {
    final selected = employeeIds.map((id) => id.trim().toUpperCase()).toSet();
    if (selected.isEmpty) return {};
    final results = await Future.wait<Map<String, dynamic>>([
      loadLate(),
      for (var offset = 0; offset < employeeIds.length; offset += 500)
        for (final status in ['MC', 'UNPAID'])
          loadStatus(
              status,
              employeeIds.sublist(
                  offset, (offset + 500).clamp(0, employeeIds.length))),
    ]);
    final disqualified = <String>{};
    for (final result in results) {
      for (final row in result['reports'] as List) {
        final id = row['employee_id'].toString().trim().toUpperCase();
        if (selected.contains(id)) disqualified.add(id);
      }
    }
    return disqualified;
  }
}
