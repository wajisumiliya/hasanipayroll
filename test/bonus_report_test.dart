import 'dart:convert';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/bonus_report.dart';
import 'package:hasani_payroll_portal/services/bonus_report_export.dart';
import 'package:hasani_payroll_portal/widgets/bonus_report_dialog.dart';
import 'attendance_pdf_summary_test.dart' show pdfContents;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final month = DateTime(2026, 10);
  Map<String, dynamic> employee(String id, {String branch = 'A'}) => {
    'employee_id': id, 'name': 'Employee $id', 'branch_id': branch,
    'is_active': true, 'joining_date': '2026-01-01',
  };
  Map<String, dynamic> pay(String id, dynamic bonus, {String? remarks}) => {
    'employee_id': id, 'period': '2026-10-01', 'bonus': bonus, 'remarks': remarks,
  };
  BonusReport build(List<Map<String, dynamic>> payroll,
      {List<Map<String, dynamic>>? employees, String? branch}) => BonusReport.build(
    month: month, employees: employees ?? [employee('E1'), employee('E2')],
    payroll: payroll, branches: {'A': 'Branch A', 'B': 'Branch B'}, branchId: branch,
  );

  test('recipients and totals use saved positive bonus, not current entitlement', () {
    final report = build([
      pay('E1', '65.40', remarks: 'Local unused OFF bonus days: 1; amount: 65.4 (basic/26, normal rate).'),
      pay('E2', 20.25), pay('E3', 0), pay('E4', -1), pay('E5', null),
      {...pay('E6', 100), 'period': '2026-09-01'},
    ], employees: [for (var i = 1; i <= 6; i++) employee('E$i')]);
    expect(report.rows.map((row) => row.employeeId), ['E1', 'E2']);
    expect(report.total, 85.65);
    expect(report.rows.first.reason, contains('Unused fifth OFF bonus'));
    expect(report.rows.last.reason, contains('reason not recorded'));
    // The saved amount remains authoritative even if the old note differs.
    expect(build([pay('E1', 100, remarks: 'Local unused OFF bonus days: 1; amount: 65.4')]).total, 100);
  });

  test('month eligibility, historical resignation and payroll branch are respected', () {
    final employees = [
      {...employee('E1'), 'is_active': false, 'resigned_at': '2026-11-01'},
      {...employee('E2'), 'is_active': false, 'resigned_at': '2026-09-30'},
      {...employee('E3'), 'joining_date': '2026-11-01'},
      {...employee('E4'), 'payroll_branch_id': 'B'},
      employee('E5'),
    ];
    final payroll = [for (var i = 1; i <= 4; i++) pay('E$i', 10)];
    expect(build(payroll, employees: employees).rows.map((r) => r.employeeId), ['E1', 'E4']);
    final report = build(payroll, employees: employees, branch: 'B');
    expect(report.branchName, 'Branch B');
    expect(report.rows.single.employeeId, 'E4');
    expect(report.rows.single.branch, 'Branch B');
  });

  test('duplicates and invalid money cannot silently produce incorrect totals', () {
    expect(() => build([pay('E1', 10), pay('E1', 20)]), throwsStateError);
    for (final invalid in ['NaN', 'Infinity', 'invalid']) {
      expect(() => build([pay('E1', invalid)]), throwsStateError);
    }
    expect(build([]).rows, isEmpty);
  });

  test('Excel keeps bonus and total numeric including fractional cents', () {
    final report = build([pay('E1', 65.40), pay('E2', 20.25)]);
    final book = xls.Excel.decodeBytes(BonusReportExport.excel(report, report.rows));
    final sheet = book['Bonus recipients'];
    double number(String address) {
      final value = sheet.cell(xls.CellIndex.indexByString(address)).value;
      return switch (value) {
        xls.IntCellValue() => value.value.toDouble(),
        xls.DoubleCellValue() => value.value,
        _ => throw StateError('Expected numeric bonus at $address'),
      };
    }
    expect(number('E5'), 65.40);
    expect(number('E6'), 20.25);
    expect(number('E7'), 85.65);
    expect(sheet.cell(xls.CellIndex.indexByString('D5')).value.toString(), contains('reason not recorded'));
  });

  test('PDF includes recipients, saved reasons and total on one page', () async {
    final report = build([pay('E1', 65.4, remarks: 'Local unused OFF bonus days: 1; amount: 65.4'), pay('E2', 20.25)]);
    final bytes = await BonusReportExport.pdf(report, report.rows);
    final text = pdfContents(bytes);
    expect(text, contains('Bonus Recipients Report'));
    expect(text, contains('Employee E1'));
    expect(text, contains('Unused fifth OFF'));
    expect(text, contains('85.65'));
    expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length, 1);
  });

  testWidgets('report shows recipients, total and both export buttons', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BonusReportDialog(
      initialMonth: month, load: (_) async => build([pay('E1', 65.4)]),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Employee E1'), findsOneWidget);
    expect(find.text('Total bonus: RM 65.40'), findsOneWidget);
    expect(find.text('Print / Save PDF'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load failure displays retry and disables exports', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BonusReportDialog(
      initialMonth: month, load: (_) async => throw StateError('Payroll unavailable'),
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Payroll unavailable'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    for (final label in ['Print / Save PDF', 'Export Excel']) {
      final button = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label));
      expect(button.onPressed, isNull);
    }
    expect(tester.takeException(), isNull);
  });
}
