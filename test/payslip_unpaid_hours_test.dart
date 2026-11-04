import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/models/payroll.dart';
import 'package:hasani_payroll_portal/services/pdf_service.dart';
import 'attendance_pdf_summary_test.dart' show pdfContents;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const employee = Employee(employeeId: 'HED1031', name: 'Test Employee',
    designation: '', department: '', email: '', newIcNo: '', bankCode: '', bankAccount: '');
  PayrollRecord payroll({double unpaid = 0, double late = 0, String? remarks}) =>
      PayrollRecord.fromJson({'id': 'P1', 'employeeId': 'HED1031',
        'period': '2026-10-01', 'basicSalary': 1700,
        'unpaidLeave': unpaid, 'lateDeduction': late, 'remarks': remarks});
  AttendanceRecord day(int day, {String status = 'Present', bool unpaid = false,
      String out = '10:00', String id = 'HED1031', int month = 10}) => AttendanceRecord(
    id: 'A$day', employeeId: id, date: DateTime(2026, month, day),
    checkIn: '09:00', checkOut: out, status: status, isUnpaid: unpaid);
  Future<String> print(PayrollRecord p, List<AttendanceRecord> attendance,
      {bool foreign = false}) async => pdfContents(await PdfService.buildPayslip(
        employee: foreign ? employee.copyWith(address: 'FRN') : employee,
        p: p, attendance: attendance));

  test('HED1031 45.17 hours of ordinary shortages never become unpaid leave', () async {
    // Six shortages of 390 minutes plus one of 370 = 2710 minutes = 45.17h.
    // The old footer incorrectly labelled that total as UNPAID.
    final attendance = [for (var d = 1; d <= 6; d++) day(d), day(7, out: '10:20')];
    final text = await print(payroll(), attendance);
    expect(text, contains('UNPAID 0.00 HRS'));
    expect(text, isNot(contains('UNPAID 45.17 HRS')));
  });

  test('late money and stale unpaid-day notes cannot create phantom unpaid hours', () async {
    final text = await print(payroll(late: 20,
      remarks: 'Unpaid days: 6. Unpaid deduction: 0.00.'), [day(1)]);
    expect(text, contains('UNPAID 0.00 HRS'));
  });

  test('paid leave, ordinary OFF and ambiguous time off are not unpaid leave', () async {
    final text = await print(payroll(), [
      for (final status in ['MC', 'AL', 'PH-OFF', 'OFF', 'Time Off', 'Absent'])
        day(1, status: status),
    ]);
    expect(text, contains('UNPAID 0.00 HRS'));
  });

  test('explicit unpaid statuses and flags are counted using assigned day length', () async {
    final attendance = [day(1, status: 'UL'), day(2, status: 'UL-UNPAID'),
      day(3, status: 'UNPAID'), day(4, status: 'UNPAID LEAVE'), day(5, unpaid: true)];
    expect(await print(payroll(), attendance), contains('UNPAID 37.50 HRS'));
    expect(await print(payroll(), attendance, foreign: true), contains('UNPAID 52.50 HRS'));
  });

  test('other employees and months cannot contribute unpaid leave', () async {
    final text = await print(payroll(), [day(1, status: 'UL', id: 'OTHER'),
      day(2, status: 'UL', month: 9), day(3)]);
    expect(text, contains('UNPAID 0.00 HRS'));
  });

  test('saved unpaid deduction remains usable when attendance is unavailable', () async {
    expect(await print(payroll(unpaid: 109.68, remarks: 'Unpaid days: 2.'), []),
      contains('UNPAID 15.00 HRS'));
    expect(await print(payroll(unpaid: 121.4, remarks: 'Unpaid days: 2.'), [], foreign: true),
      contains('UNPAID 21.00 HRS'));
  });

  test('explicit unpaid flag survives database parsing, copy and cache roundtrip', () {
    final parsed = AttendanceRecord.fromJson({'id': 'A1', 'employee_id': 'HED1031',
      'attendance_date': '2026-10-01', 'status': 'Present', 'is_unpaid': true});
    expect(parsed.isUnpaid, true);
    expect(AttendanceRecord.fromJson(parsed.copyWith().toJson()).isUnpaid, true);
    expect(parsed.copyWith(isUnpaid: false).isUnpaid, false);
    expect(day(1).isUnpaid, false);
  });
}
