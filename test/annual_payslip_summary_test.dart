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
}
