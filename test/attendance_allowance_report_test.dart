import 'attendance_pdf_summary_test.dart' show pdfContents;
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_allowance_report.dart';
import 'package:hasani_payroll_portal/services/attendance_allowance_service.dart';
import 'package:hasani_payroll_portal/services/attendance_allowance_report_export.dart';
import 'package:excel_plus/excel_plus.dart' as xls;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final month = DateTime(2026, 10);
  const causes = [
    AttendanceAllowanceReason(
        category: 'Late',
        dates: ['2026-10-01'],
        count: 3,
        details: 'Late arrival: 2026-10-01'),
    AttendanceAllowanceReason(
        category: 'MC', dates: ['2026-10-02'], count: 1, details: ''),
    AttendanceAllowanceReason(
        category: 'UL-Unpaid', dates: ['2026-10-03'], count: 1, details: ''),
  ];
  AttendanceAllowanceReport report(
          {double? snapshot = 100,
          double paid = 0,
          double configured = 150,
          bool duplicate = false,
          String? branch}) =>
      AttendanceAllowanceReport.build(
        month: month,
        employees: [
          {
            'employee_id': 'E1',
            'name': 'Employee One',
            'branch_id': 'A',
            'is_active': true
          },
          {
            'employee_id': 'NO_PAYROLL',
            'name': 'No payroll',
            'branch_id': 'A',
            'is_active': true
          },
        ],
        payroll: [
          {
            'employee_id': 'E1',
            'period': '2026-10-01',
            'elaun_kedatangan': paid,
            if (snapshot != null) 'attendance_allowance_default': snapshot
          },
          if (duplicate)
            {
              'employee_id': 'E1',
              'period': '2026-10-15',
              'elaun_kedatangan': 0
            },
        ],
        defaults: [
          {'employee_id': 'E1', 'elaun_kedatangan': configured}
        ],
        reasons: {'E1': causes, 'NO_PAYROLL': causes},
        branches: {'A': 'Branch A', 'B': 'Branch B'},
        branchId: branch,
      );

  test('three reasons remove one full saved allowance, not three allowances',
      () {
    final data = report();
    expect(data.rows, hasLength(1));
    final row = data.rows.single;
    expect(row.reasonText, 'Late, MC, UL-Unpaid');
    expect(row.dateText, contains('2026-10-03'));
    expect(
        row.baseline, 100); // Saved baseline wins over today's RM150 default.
    expect(row.paid, 0);
    expect(row.deducted, 100);
    expect(row.status, 'Fully deducted');
    expect(data.confirmedTotal, 100);
    expect(data.estimatedTotal, 0);
    expect(data.reviewCount, 0);
  });

  test('historical comparison is marked estimated, not a confirmed deduction',
      () {
    final data = report(snapshot: null);
    expect(data.rows.single.snapshot, false);
    expect(data.rows.single.deducted, 150);
    expect(data.confirmedTotal, 0);
    expect(data.estimatedTotal, 150);
    expect(data.reviewCount, 1);
  });

  test('partial or missing reductions are flagged for payroll review', () {
    final partial = report(paid: 25);
    expect(partial.rows.single.deducted, 75);
    expect(partial.rows.single.status, 'Partially deducted — review');
    expect(partial.reviewCount, 1);
    final untouched = report(paid: 100);
    expect(untouched.rows.single.deducted, 0);
    expect(untouched.rows.single.status, 'Not deducted — review');
  });

  test('duplicate payroll and branch filters do not invent deducted amounts',
      () {
    final data = report(duplicate: true);
    expect(data.rows.single.deducted, isNull);
    expect(data.rows.single.status, 'Duplicate payroll — review');
    expect(data.confirmedTotal, 0);
    expect(report(branch: 'B').rows, isEmpty);
    expect(report(snapshot: 0).rows, isEmpty);
  });

  test('Excel retains reasons, baseline source and numeric deduction amount',
      () {
    final data = report();
    final book = xls.Excel.decodeBytes(
        AttendanceAllowanceReportExport.excel(data, data.rows));
    final sheet = book['Allowance deductions'];
    // Excel's reader normalizes whole-valued doubles (100.0) to integer cells.
    // Both are numeric; text or missing cells must still fail this assertion.
    final deduction = sheet.cell(xls.CellIndex.indexByString('I5')).value;
    final amount = switch (deduction) {
      xls.IntCellValue(value: final value) => value,
      xls.DoubleCellValue(value: final value) => value,
      _ => null,
    };
    expect(amount, 100);
    expect(sheet.cell(xls.CellIndex.indexByString('E5')).value.toString(),
        contains('Late, MC, UL-Unpaid'));
    expect(sheet.cell(xls.CellIndex.indexByString('J5')).value.toString(),
        contains('Saved payroll baseline'));
  });
  test(
      'Excel preserves fractional deduction amounts without rounding to integers',
      () {
    final data = report(snapshot: 100.25);
    final book = xls.Excel.decodeBytes(
        AttendanceAllowanceReportExport.excel(data, data.rows));
    final deduction = book['Allowance deductions']
        .cell(xls.CellIndex.indexByString('I5'))
        .value;
    expect(deduction, isA<xls.DoubleCellValue>());
    expect((deduction as xls.DoubleCellValue).value, 100.25);
  });
  test('PDF shows the same reasons and source distinction as Excel', () async {
    final data = report();
    final text =
        pdfContents(await AttendanceAllowanceReportExport.pdf(data, data.rows));
    expect(text, contains('Elaun Kedatangan Deduction Report'));
    expect(text, contains('Employee One'));
    expect(text, contains('Late, MC, UL-Unpaid'));
    expect(text, contains('Saved payroll baseline'));
  });
}
