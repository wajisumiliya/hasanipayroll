import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/salary_transfer.dart';
import 'package:hasani_payroll_portal/models/payroll.dart';

void main() {
  test('existing bank accounts default to RHB irrespective of bank code', () {
    expect(SalaryTransfer.resolve(null, '0012345'), 'rhb');
    expect(SalaryTransfer.footerKey('', '0012345'), 'payroll');
    expect(SalaryTransfer.resolve(null, '   '), '');
    expect(SalaryTransfer.footerKey('', ''), '');
  });

  test('Instant and Cash are explicit choices with or without bank accounts',
      () {
    for (final account in ['', '0012345']) {
      for (final method in ['instant', 'cash']) {
        expect(SalaryTransfer.resolve(method, account), method);
        expect(SalaryTransfer.footerKey(method, account), method);
      }
    }
    expect(SalaryTransfer.resolve('RHB', '0012345'), 'rhb');
    expect(SalaryTransfer.resolve('rhb', ''), '');
  });

  test('employee payment method survives serialization and unrelated edits',
      () {
    final employee = Employee.fromJson({
      'employeeId': 'FIX',
      'bankAccount': '00123',
      'salaryTransferMethod': 'cash',
    });
    final updated = employee.copyWith(name: 'Updated');
    expect(Employee.fromJson(updated.toJson()).salaryTransferMethod, 'cash');
    expect(
        updated.copyWith(salaryTransferMethod: 'instant').salaryTransferMethod,
        'instant');
  });

  test('Excel footers sum each net salary once and reference its employee row',
      () {
    final summary = SalaryTransferSummary();
    summary.add(
        method: null,
        bankAccount: '00123',
        net: 1800.25,
        row: 5,
        employeeId: 'A');
    summary.add(
        method: 'instant',
        bankAccount: '',
        net: 1000.50,
        row: 6,
        employeeId: 'B');
    summary.add(
        method: 'cash', bankAccount: '', net: 750, row: 7, employeeId: 'C');
    summary.add(
        method: 'cash',
        bankAccount: '00987',
        net: 250,
        row: 8,
        employeeId: 'D');
    expect(summary.totals,
        {'payroll': 1800.25, 'instant': 1000.50, 'cash': 1000.0});
    expect(summary.totals.values.reduce((a, b) => a + b), 3800.75);
    expect(summary.formula('payroll', 'T'), 'SUM(T5)');
    expect(summary.formula('instant', 'U'), 'SUM(U6)');
    expect(summary.formula('cash', 'T'), 'SUM(T7,T8)');
    expect(SalaryTransferSummary().formula('cash', 'T'), isNull);
    expect(summary.hasUnassigned, false);
    summary.add(
        method: null, bankAccount: '', net: 500, row: 9, employeeId: 'BLK062');
    expect(summary.hasUnassigned, true);
    expect(summary.totals['unassigned'], 500);
    expect(summary.formula('unassigned', 'T'), 'SUM(T9)');
    expect(summary.totals['cash'], 1000);
    expect(summary.totals['payroll'], 1800.25);
    expect(summary.totals['instant'], 1000.50);
    expect(summary.totals.values.reduce((a, b) => a + b), 4300.75);
  });

  test('unassigned salaries keep zero and negative amounts in the footer', () {
    final summary = SalaryTransferSummary();
    summary.add(
        method: '', bankAccount: '', net: 0, row: 5, employeeId: 'BLANK');
    summary.add(
        method: 'rhb',
        bankAccount: '',
        net: -50,
        row: 6,
        employeeId: 'NO_BANK');
    expect(summary.hasUnassigned, true);
    expect(summary.formula('unassigned', 'U'), 'SUM(U5,U6)');
    expect(summary.totals['unassigned'], -50);
    expect(summary.totals['payroll'], 0);
    expect(summary.totals['instant'], 0);
    expect(summary.totals['cash'], 0);
  });
}
