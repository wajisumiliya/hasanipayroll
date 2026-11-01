/// Selection is always restricted to employees already verified as ready.
class PayrollReadinessSelection {
  static String id(Map<String, dynamic> row) =>
      '${row['employee_id'] ?? ''}'.trim().toUpperCase();
  static List<Map<String, dynamic>> visible(
      List<Map<String, dynamic>> employees,
      {required Set<String> readyIds,
      required Set<String> submittedIds,
      required String filter,
      required String search}) {
    final query = search.trim().toLowerCase();
    return employees.where((employee) {
      final employeeId = id(employee);
      final included = filter == 'all' ||
          filter == 'ready' && readyIds.contains(employeeId) ||
          filter == 'followup' && !readyIds.contains(employeeId) ||
          filter == 'submitted' && submittedIds.contains(employeeId);
      return included &&
          (query.isEmpty ||
              '$employeeId ${employee['name'] ?? ''}'
                  .toLowerCase()
                  .contains(query));
    }).toList();
  }

  static Set<String> selectable(
          List<Map<String, dynamic>> visible, Set<String> ready) =>
      visible.map(id).where(ready.contains).toSet();
  static Set<String> toggleVisible(
      Set<String> selected, Set<String> visibleReady, bool checked) {
    final next = Set<String>.from(selected);
    if (checked) {
      next.addAll(visibleReady);
    } else {
      next.removeAll(visibleReady);
    }
    return next;
  }
}
