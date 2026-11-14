/// Edit the saved row without replaying insert-only validation or rewriting its
/// identity. Omit unchanged columns so unrelated UPDATE OF triggers do not run.
Map<String, dynamic> payrollEditUpdatePayload(
    Map<String, dynamic> saved, Map<String, dynamic> edited) {
  const immutable = {
    'id',
    'employee_id',
    'period',
    'created_at',
    'branch_id',
    'branch_name',
  };
  return {
    for (final entry in edited.entries)
      if (!immutable.contains(entry.key) &&
          !_samePayrollValue(saved[entry.key], entry.value))
        entry.key: entry.value,
  };
}

bool _samePayrollValue(dynamic saved, dynamic edited) {
  if (edited is num) {
    final previous = saved is num ? saved : double.tryParse('$saved');
    return previous == edited;
  }
  return saved == edited;
}
