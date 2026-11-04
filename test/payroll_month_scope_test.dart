import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/models/payroll.dart';
import 'package:hasani_payroll_portal/services/payroll_month_scope.dart';

void main() {
  final july = DateTime(2026, 7);
  Map<String, dynamic> employee(String id, {
    bool active = true, String? joined, String? resigned,
  }) => {
    'employee_id': id, 'is_active': active,
    if (joined != null) 'joining_date': joined,
    if (resigned != null) 'resigned_at': resigned,
  };
  Map<String, dynamic> payroll(String id, String period) =>
      {'employee_id': id, 'period': period};

  test('selected month requires both employment eligibility and saved payroll', () {
    final result = PayrollMonthScope.employeesWithPayroll(
      month: july,
      employees: [
        employee('JULY'), employee('NO_PAYSLIP'), employee('JUNE_ONLY'),
        employee('RESIGNED', active: false, resigned: '2026-06-30'),
        employee('LATER', active: false, resigned: '2026-08-15'),
        employee('NOT_JOINED', joined: '2026-08-01'),
      ],
      payroll: [
        payroll('JULY', '2026-07-01'), payroll('JUNE_ONLY', '2026-06-01'),
        payroll('RESIGNED', '2026-07-01'), payroll('LATER', '2026-07-01'),
        payroll('NOT_JOINED', '2026-07-01'),
      ],
    );
    expect(result.map((row) => row['employee_id']), ['JULY', 'LATER']);
  });

  test('employment overlapping any part of the month remains eligible', () {
    expect(PayrollMonthScope.activeInMonth(
        employee('JOIN', joined: '2026-07-31'), july), true);
    expect(PayrollMonthScope.activeInMonth(
        employee('LEAVE', active: false, resigned: '2026-07-01'), july), true);
    expect(PayrollMonthScope.activeInMonth(
        employee('UNKNOWN', active: false), july), false);
  });

  test('changing month rebuilds membership instead of reusing the old list', () {
    final employees = [employee('JULY'), employee('AUGUST')];
    final records = [
      payroll('JULY', '2026-07-01'), payroll('AUGUST', '2026-08-01'),
    ];
    List<dynamic> ids(DateTime month) => PayrollMonthScope.employeesWithPayroll(
        employees: employees, payroll: records, month: month)
        .map((row) => row['employee_id']).toList();
    expect(ids(july), ['JULY']);
    expect(ids(DateTime(2026, 8)), ['AUGUST']);
    expect(ids(DateTime(2026, 9)), isEmpty);
  });

  test('month matching keeps legacy period formats and normalizes IDs', () {
    for (final period in ['2026-07-01', 'July 2026', '2026/7', '07/2026']) {
      expect(PayrollMonthScope.matchesMonth(period, july), true);
    }
    expect(PayrollMonthScope.matchesMonth('2025-07-01', july), false);
    expect(PayrollMonthScope.matchesMonth(null, july), false);
    expect(PayrollMonthScope.employeesWithPayroll(
      employees: [employee(' abc ')],
      payroll: [payroll('ABC', '2026-07-01')], month: july,
    ), hasLength(1));
  });

  test('resignation timestamp uses Malaysia calendar date at month boundary', () {
    final person = employee('BOUNDARY', active: false,
        resigned: '2026-06-30T17:00:00Z');
    expect(PayrollMonthScope.activeInMonth(person, july), true);
    expect(PayrollMonthScope.activeInMonth(
        employee('EARLIER', active: false,
            resigned: '2026-06-30T15:00:00Z'), july), false);
  });

  test('resignation date survives employee caching and unrelated profile edits', () {
    final person = Employee.fromJson({
      'employeeId': 'FORMER', 'isActive': false,
      'joiningDate': '2026-01-01', 'resigned_at': '2026-08-15T00:00:00Z',
    });
    final restored = Employee.fromJson(person.copyWith(name: 'Updated').toJson());
    expect(restored.resignedAt, person.resignedAt);
    expect(PayrollMonthScope.activeInMonth(restored.toJson(), july), true);
    expect(PayrollMonthScope.activeInMonth(
        restored.toJson(), DateTime(2026, 9)), false);
  });
}
