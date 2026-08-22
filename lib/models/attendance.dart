class BreakRecord {
  final String morningCheckIn;
  final String morningCheckOut;

  final String afternoonCheckIn;
  final String afternoonCheckOut;

  final String eveningCheckIn;
  final String eveningCheckOut;

  const BreakRecord({
    required this.morningCheckIn,
    required this.morningCheckOut,
    required this.afternoonCheckIn,
    required this.afternoonCheckOut,
    required this.eveningCheckIn,
    required this.eveningCheckOut,
  });
}

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String branchId;
  final DateTime date;
  final String status;

  // Working card
  final String workingCheckIn;
  final String workingCheckOut;

  // Break card
  final BreakRecord breakRecord;

  final String remarks;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.branchId,
    required this.date,
    required this.status,
    required this.workingCheckIn,
    required this.workingCheckOut,
    required this.breakRecord,
    required this.remarks,
  });
}