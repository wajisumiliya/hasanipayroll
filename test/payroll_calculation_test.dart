import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/models/payroll.dart';
import 'package:hasani_payroll_portal/services/payroll_calculation_service.dart';

void main() {
  group('PayrollCalculationService salary base', () {
    test('uses local basic salary when FW salary is zero', () {
      expect(
        PayrollCalculationService.salaryBase(
          basicSalary: 1700,
          fwSalary: 0,
        ),
        1700,
      );
    });

    test('does not double count duplicated foreign-worker salary', () {
      expect(
        PayrollCalculationService.salaryBase(
          basicSalary: 1700,
          fwSalary: 1700,
        ),
        1700,
      );
    });

    test('uses FW salary when it is the populated salary source', () {
      expect(
        PayrollCalculationService.salaryBase(
          basicSalary: 0,
          fwSalary: 1700,
        ),
        1700,
      );
    });
  });

  test('PayrollRecord gross and net use the centralized rules', () {
    final record = PayrollRecord(
      id: 'test',
      employeeId: 'FW001',
      period: DateTime(2026, 7),
      basicSalary: 1700,
      fwSalary: 1700,
      elaunKedatangan: 50,
      elaunPerkhidmatan: 100,
      elaunKerajinan: 25,
      overtime: 75,
      cutiUmum: 0,
      epfEmployee: 0,
      socsoEmployee: 10,
      eisEmployee: 3,
      pcb: 0,
      zakat: 0,
      lateDeduction: 2,
      epfEmployer: 0,
      socsoEmployer: 20,
      eisEmployer: 3,
    );

    expect(record.totalEarnings, 1950);
    expect(record.totalDeductions, 15);
    expect(record.netPay, 1935);
  });
}
