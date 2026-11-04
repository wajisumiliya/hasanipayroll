import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_allowance_report.dart';
import 'package:hasani_payroll_portal/services/attendance_allowance_service.dart';
import 'package:hasani_payroll_portal/widgets/attendance_allowance_report_dialog.dart';

void main() {
  testWidgets('separate report shows reasons, deducted amount and export actions', (tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = AttendanceAllowanceReport(month: DateTime(2026, 10),
      branchName: 'Branch A', rows: const [AttendanceAllowanceDeduction(
        employeeId: 'E1', name: 'Employee One', branch: 'Branch A',
        reasons: [AttendanceAllowanceReason(category: 'MC', dates: ['2026-10-01'],
          count: 1, details: '')],
        baseline: 100, paid: 0, deducted: 100, snapshot: true, status: 'Fully deducted',
      )]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      AttendanceAllowanceReportDialog(initialMonth: DateTime(2026, 10),
        load: (_) async => data))));
    await tester.pumpAndSettle();
    expect(find.text('Employee One'), findsOneWidget);
    expect(find.text('MC'), findsOneWidget);
    expect(find.text('Fully deducted'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);
    expect(find.text('Print / Save PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report failure remains visible with a retry option', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      AttendanceAllowanceReportDialog(initialMonth: DateTime(2026, 10),
        load: (_) async => throw StateError('Attendance unavailable')))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Attendance unavailable'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
