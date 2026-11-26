import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:hasani_payroll_portal/models/payroll.dart';
import 'package:hasani_payroll_portal/services/annual_payslip_summary.dart';
import 'package:hasani_payroll_portal/services/annual_payslip_export.dart';
import 'attendance_pdf_summary_test.dart' show pdfContents;

PayrollRecord saved(String employee, String period, double salary,
        {double allowance = 0, double bonus = 0, double fw = 0}) =>
    PayrollRecord.fromJson({
      'employeeId': employee,
      'period': period,
      'basicSalary': salary,
      'fwSalary': fw,
      'elaunKedatangan': allowance,
      'bonus': bonus,
    });
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'annual values filter employee and year, compare previous year and avoid double increment',
      () {
    final result = AnnualPayslipSummary(employeeId: 'E1', year: 2026, records: [
      saved('E1', '2025-12-01', 2000, allowance: 100),
      saved('E1', '2026-01-01', 2100, allowance: 100, bonus: 50),
      saved('E1', '2026-03-01', 0),
      saved('E2', '2026-01-01', 9999),
      saved('E1', '2027-01-01', 9000),
    ]);
    expect(result.months, hasLength(12));
    expect(result.months.first.salary, 2100);
    expect(result.months.first.allowance, 100);
    expect(result.months.first.increment, 100);
    expect(result.months.first.total, 2200);
    expect(result.months[1].total, isNull);
    expect(result.months[2].total, 0);
    expect(result.bonuses.single.bonus, 50);
  });
  test('foreign pay replaces basic and duplicate saved months fail closed', () {
    expect(
        AnnualPayslipSummary(
                employeeId: 'E1',
                year: 2026,
                records: [saved('E1', '2026-01-01', 1000, fw: 2500)])
            .months
            .first
            .total,
        2500);
    expect(
        () => AnnualPayslipSummary(employeeId: 'E1', year: 2026, records: [
              saved('E1', '2026-01-01', 1),
              saved('E1', '2026-01-02', 2)
            ]),
        throwsStateError);
  });
  test(
      'PDF and numeric Excel contain twelve months and only selected-year bonuses',
      () async {
    final summary =
        AnnualPayslipSummary(employeeId: 'E1', year: 2026, records: [
      saved('E1', '2025-01-01', 400, bonus: 999),
      saved('E1', '2026-01-01', 2100, allowance: 100, bonus: 50)
    ]);
    final bytes = await AnnualPayslipExport.pdf(summary, 'Sample Employee');
    expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)),
        hasLength(1));
    final text = pdfContents(bytes);
    expect(text, contains('ANNUAL SALARY YEAR 2026'));
    expect(text, contains('WELFARE/GIFT/BONUS YEAR 2026'));
    expect(text, contains('DECEMBER'));
    expect(text, contains('50.00'));
    expect(text, isNot(contains('999.00')));
    final book = xls.Excel.decodeBytes(
        AnnualPayslipExport.excel(summary, 'Sample Employee'));
    final sheet = book['Annual Summary'];
    expect(sheet.cell(xls.CellIndex.indexByString('C6')).value,
        anyOf(xls.IntCellValue(2100), xls.DoubleCellValue(2100)));
    expect(sheet.cell(xls.CellIndex.indexByString('F6')).value,
        anyOf(xls.IntCellValue(2200), xls.DoubleCellValue(2200)));
    expect(sheet.cell(xls.CellIndex.indexByString('C7')).value,
        anyOf(isNull, xls.TextCellValue('')));
    expect(sheet.cell(xls.CellIndex.indexByString('F23')).value,
        anyOf(xls.IntCellValue(50), xls.DoubleCellValue(50)));
    final output = Platform.environment['ANNUAL_SUMMARY_PDF'];
    if (output != null) {
      await File(output).writeAsBytes(bytes);
    }
  });
  test(
      'welfare keeps full dates, employee and year; PDF and Excel include gifts with bonuses',
      () async {
    final summary =
        AnnualPayslipSummary(employeeId: 'E1', year: 2026, records: [
      saved('E1', '2026-03-01', 2000, bonus: 50)
    ], welfare: [
      {
        'employee_id': 'E1',
        'payment_date': '2026-03-15',
        'particulars': 'Wedding gift',
        'amount': 1234.55
      },
      {
        'employee_id': 'E1',
        'payment_date': '2025-03-15',
        'particulars': 'Prior-year welfare',
        'amount': 999
      },
      {
        'employee_id': 'E2',
        'payment_date': '2026-03-15',
        'particulars': 'Other employee',
        'amount': 888
      },
    ]);
    final rows = AnnualPayslipExport.bonusRows(summary);
    expect(summary.benefits, hasLength(2));
    expect(rows[1], ['2', '15/03/2026', 'Wedding gift', '1,234.55']);
    final bytes = await AnnualPayslipExport.pdf(summary, 'Sample Employee');
    final contents = pdfContents(bytes);
    expect(contents, contains('15/03/2026'));
    expect(contents, contains('Wedding gift'));
    expect(contents, isNot(contains('Prior-year welfare')));
    expect(contents, isNot(contains('Other employee')));
    final book = xls.Excel.decodeBytes(
        AnnualPayslipExport.excel(summary, 'Sample Employee'));
    final sheet = book['Annual Summary'];
    expect(sheet.cell(xls.CellIndex.indexByString('B24')).value,
        xls.TextCellValue('15/03/2026'));
    expect(sheet.cell(xls.CellIndex.indexByString('F24')).value,
        xls.DoubleCellValue(1234.55));
  });
  test('increment displays only exact RM50 steps between RM50 and RM1000', () {
    for (var amount = 50; amount <= 1000; amount += 50) {
      expect(
          AnnualPayslipSummary.qualifyingIncrement(amount.toDouble()), amount);
    }
    for (final amount in [
      -100.0,
      0.0,
      40.0,
      49.99,
      50.01,
      75.0,
      99.99,
      100.01,
      999.99,
      1000.01,
      1050.0,
      2700.0,
      double.nan,
      double.infinity
    ]) {
      expect(AnnualPayslipSummary.qualifyingIncrement(amount), isNull,
          reason: '$amount must remain blank');
    }
    expect(AnnualPayslipSummary.qualifyingIncrement(100.00000000001), 100);
  });
  test(
      'irregular increment is blank in preview PDF rows and Excel without changing totals',
      () {
    final summary =
        AnnualPayslipSummary(employeeId: 'E1', year: 2026, records: [
      saved('E1', '2025-12-01', 1900, allowance: 800),
      saved('E1', '2026-01-01', 1900, allowance: 840),
      saved('E1', '2026-02-01', 1900, allowance: 940),
      saved('E1', '2026-03-01', 1900, allowance: 940),
    ]);
    expect(summary.months[0].increment, isNull);
    expect(summary.months[1].increment, 100);
    expect(summary.months[2].increment, isNull);
    expect(summary.months[0].total, 2740);
    expect(AnnualPayslipExport.salaryRows(summary)[0][4], '');
    final sheet = xls.Excel.decodeBytes(
        AnnualPayslipExport.excel(summary, 'Sample'))['Annual Summary'];
    expect(sheet.cell(xls.CellIndex.indexByString('E6')).value,
        anyOf(isNull, xls.TextCellValue('')));
    expect(sheet.cell(xls.CellIndex.indexByString('E7')).value,
        anyOf(xls.IntCellValue(100), xls.DoubleCellValue(100)));
  });
}
