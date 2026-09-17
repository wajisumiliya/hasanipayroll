import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_pdf_service.dart';

void main() {
  testWidgets('renders attendance PDF watermark', (tester) async {
    final days = List.generate(
      30,
      (index) => AttendancePrintDay(
        day: index + 1,
        workingIn: index < 12 ? '09:00' : '',
        workingOut: index < 12 ? '18:00' : '',
        morningIn: index < 12 ? '13:00' : '',
        morningOut: index < 12 ? '13:30' : '',
        afternoonIn: '',
        afternoonOut: '',
        eveningIn: '',
        eveningOut: '',
        status: index < 12 ? 'Present' : '-',
        workMinutes: index < 12 ? 540 : 0,
        breakMinutes: index < 12 ? 30 : 0,
        netMinutes: index < 12 ? 510 : 0,
        overtimeMinutes: 0,
        lateMinutes: 0,
      ),
    );
    final bytes = await AttendancePdfService.build(
      employeeId: 'HB-001',
      employeeName: 'Sample Employee',
      department: 'Operations',
      section: 'Retail',
      branchId: 'SUNGAI PETANI',
      month: DateTime(2026, 9),
      days: days,
    );
    final output = File('tmp/pdfs/attendance_watermark_sample.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes);
    expect(bytes, isNotEmpty);
 