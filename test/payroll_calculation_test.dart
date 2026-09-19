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

    test('keeps a genuinely blank salary blank', () {
      expect(
        PayrollCalculationService.salaryBase(
          basicSalary: 0,
          fwSalary: 0,
        ),
        0,
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

  test('unpaid and late deductions reduce net pay exactly once', () {
    final gross = PayrollCalculationService.grossEarnings(
      basicSalary: 2000,
      fwSalary: 0,
      overtime: 100,
    );
    final deductions = PayrollCalculationService.totalDeductions(
      epfEmployee: 220,
      socsoEmployee: 10,
      eisEmployee: 4,
      unpaid: 125.50,
      late: 8.25,
    );

    expect(gross, 2100);
    expect(deductions, 367.75);
    expect(
      PayrollCalculationService.netPay(
        gross: gross,
        deductions: deductions,
      ),
      1732.25,
    );
  });

  test(
    'statutory deductions are included without affecting employer amounts',
    () {
      expect(
        PayrollCalculationService.totalDeductions(
          epfEmployee: 187,
          socsoEmployee: 9.75,
          eisEmployee: 3.40,
          pcb: 25,
          zakat: 15,
        ),
        240.15,
      );
    },
  );
}
