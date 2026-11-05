import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/models/payroll.dart';
import 'package:hasani_payroll_portal/services/payroll_calculation_service.dart';
import 'package:hasani_payroll_portal/services/pdf_service.dart';
import 'package:hasani_payroll_portal/services/saved_payroll_amounts.dart';

import 'attendance_pdf_summary_test.dart' show pdfContents;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('final net rounds every sen boundary, including carry and negatives',
      () {
    const expectedSen = [0, 0, 0, 5, 5, 5, 5, 5, 10, 10];
    for (var cents = 0; cents < 100; cents++) {
      final input = 1700 + cents / 100;
      final expected =
          1700 + (cents ~/ 10 * 10 + expectedSen[cents % 10]) / 100;
      expect(PayrollCalculationService.roundNetPay(input), expected);
      expect(PayrollCalculationService.roundNetPay(-input), -expected);
      expect(PayrollCalculationService.roundNetPay(expected), expected);
    }
    expect(PayrollCalculationService.roundNetPay(999.98), 1000);
    expect(() => PayrollCalculationService.roundNetPay(double.nan),
        throwsArgumentError);
    expect(() => PayrollCalculationService.roundNetPay(double.infinity),
        throwsArgumentError);
    // The separate FRN daily-rate rule remains nearest ten sen.
    expect(
        PayrollCalculationService.unpaidDailyRate(
            basicSalary: 1700,
            month: DateTime(2026, 10),
            isForeignEmployee: true),
        60.70);
  });

  test('Branch Payroll and RHB retain all five-sen amounts supplied for review',
      () {
    const amounts = <double>[
      2500,
      7970,
      3000,
      5377.60,
      3204.70,
      2366.85,
      1989.10,
      2201.80,
      1500,
      2372.95,
      3289.50,
      2816.10,
      1989.10,
      2089.10,
      2376.60,
      2146.30,
      1450.80,
      1789.10,
      789.10,
      2174,
      2506.05,
      1939.10,
      1789.10,
      2357.60,
      2135.05,
      1639.10,
      1889.10,
      1868.20,
      1687.15,
      1639.10,
      1441.80,
      1638.25,
      1589.10,
      1538.25,
      1489.10,
      1391.80,
      1645.40,
    ];
    final book = xls.Excel.createExcel();
    for (var index = 0; index < amounts.length; index++) {
      final expected = amounts[index];
      final savedRow = <String, dynamic>{'basic_salary': expected};
      final reportAmount = SavedPayrollAmounts.finalNetPay(savedRow);
      final payslip = PayrollRecord.fromJson({
        'id': 'P$index',
        'employeeId': 'E$index',
        'period': '2026-10-01',
        'basicSalary': expected,
      });
      expect(reportAmount, expected, reason: 'Report employee E$index');
      expect(payslip.netPay, expected, reason: 'Payslip employee E$index');
      expect(SavedPayrollAmounts.finalNetPay({'net_pay': expected}), expected);
      final cell = book['Payments'].cell(
          xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: index));
      cell.value = xls.DoubleCellValue(reportAmount);
      cell.cellStyle = xls.CellStyle(
          numberFormat: xls.NumFormat.custom(formatCode: '#,##0.00'));
    }
    final decoded = xls.Excel.decodeBytes(book.encode()!);
    for (var index = 0; index < amounts.length; index++) {
      final value = decoded['Payments']
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: index))
          .value;
      final number = switch (value) {
        xls.DoubleCellValue(value: final amount) => amount,
        xls.IntCellValue(value: final amount) => amount.toDouble(),
        _ => throw StateError('Payment must remain numeric: $value'),
      };
      expect(number, amounts[index], reason: 'Excel employee E$index');
    }
  });

  test('saved net is authoritative, including zero; totals sum rounded people',
      () {
    final saved = SavedPayrollAmounts.fromRow({
      'net_pay': 'RM 2,200.03',
      'net_salary': 9999,
      'basic_salary': 9999,
      'epf_employee': 100,
    });
    expect(saved.net, 2200.05);
    expect(
        SavedPayrollAmounts.fromRow({'net_pay': 0, 'basic_salary': 9999}).net,
        0);
    final rows = [
      {'net_pay': 0.02},
      {'net_pay': 0.02}
    ];
    expect(
        rows.fold<double>(
            0, (sum, row) => sum + SavedPayrollAmounts.fromRow(row).net),
        0);
  });

  test('component fallback counts aliases once and includes every deduction',
      () {
    final amounts = SavedPayrollAmounts.fromRow({
      'basic_salary': 2000,
      'fw_salary': 2000,
      'elaun_kedatangan': 100,
      'elaun_perkhidmatan': 150,
      'other_allowance': 150,
      'elaun_kerajinan': 50,
      'elaun_makanan': 300,
      'food_allowance': 300,
      'housing_allowance': 80,
      'travel_allowance': 20,
      'overtime': 40,
      'bonus': 30,
      'commission': 10,
      'other_earnings': 5,
      'otherEarnings': 5,
      'cuti_umum': 15,
      'epf_employee': 220,
      'epfEmployee': 220,
      'socso_employee': 20,
      'eis_employee': 4,
      'pcb': 15,
      'zakat': 6,
      'advance': 50,
      'loan_deduction': 70,
      'unpaid_deduction': 60,
      'late_deduction': 12,
      'other_deduction': 3.97,
      'net_pay': '',
    });
    expect(amounts.gross, 2800);
    expect(amounts.deductions, closeTo(460.97, 1e-9));
    expect(amounts.net, 2339.05);
    expect(() => SavedPayrollAmounts.fromRow({'net_pay': 'invalid'}),
        throwsStateError);
  });

  test('editing saved components refreshes existing totals without new columns',
      () {
    final row = <String, dynamic>{
      'basic_salary': 2000,
      'loan_deduction': 50.02,
      'net_pay': 9999,
      'gross_salary': 9999,
      'total_deductions': 0,
    };
    SavedPayrollAmounts.refreshExistingTotals(row);
    expect(row['gross_salary'], 2000);
    expect(row['total_deductions'], 50.02);
    expect(row['net_pay'], 1950);
    final components = <String, dynamic>{'basic_salary': 2000};
    SavedPayrollAmounts.refreshExistingTotals(components);
    expect(components, {'basic_salary': 2000});
  });

  PayrollRecord record() => PayrollRecord.fromJson({
        'id': 'PAY-HED1001-2026-10',
        'employeeId': 'HED1001',
        'period': '2026-10-01',
        'basicSalary': 2000,
        'housingAllowance': 80,
        'travelAllowance': 20,
        'advance': 50,
        'loanDeduction': 70,
        'unpaidLeave': 60,
        'otherDeduction': 3.97,
      });

  test('model cache and metadata edits preserve components and payment', () {
    final original = record();
    expect(original.netPay, 1916.05);
    final restored = PayrollRecord.fromJson(original.toJson());
    expect(restored.netPay, original.netPay);
    expect(restored.copyWith(isPublished: true).netPay, original.netPay);
    expect(restored.copyWith(isPublished: true).loanDeduction, 70);
    final snapshot = PayrollRecord.fromJson({
      ...original.toJson(),
      'netSalary': 1800.03,
      'grossSalary': 2100,
      'totalDeductions': 299.97,
    });
    expect(snapshot.copyWith(isPublished: true).netPay, 1800.05);
    expect(snapshot.copyWith(basicSalary: 2100).storedNetSalary, isNull);
    expect(snapshot.copyWith(basicSalary: 2100).netPay, 2016.05);
  });

  test('payslip prints the rounded saved net and a rounding adjustment',
      () async {
    const employee = Employee(
        employeeId: 'HED1001',
        name: 'Test Employee',
        designation: '',
        department: '',
        email: '',
        newIcNo: '',
        bankCode: '',
        bankAccount: '');
    final payroll = record();
    expect(payroll.basicSalary, 2000);
    final content = pdfContents(
        await PdfService.buildPayslip(employee: employee, p: payroll));
    expect(content, contains('1916.05'));
    expect(content, contains('Rounding RM +0.02'));
  });
}
