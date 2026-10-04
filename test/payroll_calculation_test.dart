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

    test('historical FW salary takes precedence when both values differ', () {
      expect(
        PayrollCalculationService.salaryBase(
          basicSalary: 1800,
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

  group('Attendance payroll regression rules', () {
    test('public holiday pay is basic / 26 x 1 per worked day', () {
      expect(
        PayrollCalculationService.publicHolidayPay(
          basicSalary: 1700,
          workedDays: 1,
        ),
        65.38,
      );
    });

    test('public holiday pay supports multiple worked days', () {
      expect(
        PayrollCalculationService.publicHolidayPay(
          basicSalary: 2600,
          workedDays: 2,
        ),
        200,
      );
    });

    test('public holiday pay is zero for invalid or non-worked inputs', () {
      expect(
        PayrollCalculationService.publicHolidayPay(
          basicSalary: 1700,
          workedDays: 0,
        ),
        0,
      );
      expect(
        PayrollCalculationService.publicHolidayPay(
          basicSalary: 0,
          workedDays: 1,
        ),
        0,
      );
    });

    test('PH worked pays basic / 26 x 1', () {
      expect(
        PayrollCalculationService.publicHolidayPayForStatus(
          basicSalary: 2600,
          status: 'PH',
          worked: true,
        ),
        100,
      );
    });

    test('PH-OFF has no additional pay', () {
      expect(
        PayrollCalculationService.publicHolidayPayForStatus(
          basicSalary: 2600,
          status: 'PH-OFF',
          worked: false,
        ),
        0,
      );
    });

    test('PH-SPL worked pays basic / 26 x 2', () {
      expect(
        PayrollCalculationService.publicHolidayPayForStatus(
          basicSalary: 2600,
          status: 'PH-SPL',
          worked: true,
        ),
        200,
      );
    });

    test('PH-GUNTI worked gives replacement OFF and no additional pay', () {
      expect(
        PayrollCalculationService.publicHolidayPayForStatus(
          basicSalary: 2600,
          status: 'PH-GUNTI',
          worked: true,
        ),
        0,
      );
      expect(
        PayrollCalculationService.replacementOffDaysForStatus(
          status: 'PH-GUNTI',
          worked: true,
        ),
        1,
      );
      expect(
        PayrollCalculationService.replacementOffDaysForStatus(
          status: 'PH-GUNTI',
          worked: false,
        ),
        0,
      );
    });

    test('PH categories require the matching working-time condition', () {
      expect(
        PayrollCalculationService.publicHolidayPayForStatus(
          basicSalary: 2600,
          status: 'PH',
          worked: false,
        ),
        0,
      );
      expect(
        PayrollCalculationService.publicHolidayPayForStatus(
          basicSalary: 2600,
          status: 'PH-OFF',
          worked: true,
        ),
        0,
      );
      expect(
        PayrollCalculationService.publicHolidayPayForStatus(
          basicSalary: 2600,
          status: 'PH-SPL',
          worked: false,
        ),
        0,
      );
    });

    test('OT without approved minutes is not payable', () {
      expect(PayrollCalculationService.approvedOvertimeHours(null), 0);
      expect(PayrollCalculationService.approvedOvertimeHours(0), 0);
    });

    test('approved OT pays only the approved duration', () {
      expect(PayrollCalculationService.approvedOvertimeHours(75), 1.25);
      expect(PayrollCalculationService.approvedOvertimeHours(83),
          closeTo(83 / 60, 1e-12));
    });

    test('Admin direct OT hours convert to approved minutes', () {
      expect(PayrollCalculationService.directOvertimeMinutes('1.5'), 90);
      expect(PayrollCalculationService.directOvertimeMinutes('2.25'), 135);
      expect(PayrollCalculationService.directOvertimeMinutes(''), 0);
      expect(PayrollCalculationService.directOvertimeMinutes('-1'), isNull);
      expect(PayrollCalculationService.directOvertimeMinutes('24.1'), isNull);
      expect(PayrollCalculationService.directOvertimeMinutes('abc'), isNull);
    });

    test('negative approved OT minutes are never payable', () {
      expect(PayrollCalculationService.approvedOvertimeHours(-15), 0);
    });

    test('unpaid day cannot also create shortage deduction', () {
      expect(
        PayrollCalculationService.shouldApplyShortageDeduction(
          isUnpaid: true,
          isPublicHoliday: false,
          worked: true,
        ),
        isFalse,
      );
    });

    test('public holiday cannot create normal shortage deduction', () {
      expect(
        PayrollCalculationService.shouldApplyShortageDeduction(
          isUnpaid: false,
          isPublicHoliday: true,
          worked: true,
        ),
        isFalse,
      );
    });

    test('day without work cannot create normal shortage deduction', () {
      expect(
        PayrollCalculationService.shouldApplyShortageDeduction(
          isUnpaid: false,
          isPublicHoliday: false,
          worked: false,
        ),
        isFalse,
      );
    });

    test('normal worked day can create shortage deduction', () {
      expect(
        PayrollCalculationService.shouldApplyShortageDeduction(
          isUnpaid: false,
          isPublicHoliday: false,
          worked: true,
        ),
        isTrue,
      );
    });

    test('foreign employee late arrival cannot create shortage deduction', () {
      expect(
        PayrollCalculationService.shouldApplyShortageDeduction(
          isUnpaid: false,
          isPublicHoliday: false,
          worked: true,
          isForeignEmployee: true,
        ),
        isFalse,
      );
    });
  });

  group('Historical payroll edge cases', () {
    test('local employee unpaid daily rate uses basic salary divided by 26',
        () {
      expect(
        PayrollCalculationService.unpaidDailyRate(
          basicSalary: 2600,
          isForeignEmployee: false,
        ),
        100,
      );
    });

    test('foreign employee unpaid daily rate uses basic salary divided by 28',
        () {
      expect(
        PayrollCalculationService.unpaidDailyRate(
          basicSalary: 2800,
          isForeignEmployee: true,
        ),
        100,
      );
    });

    test('FW salary is not double counted with allowances and PH pay', () {
      final gross = PayrollCalculationService.grossEarnings(
        basicSalary: 1700,
        fwSalary: 1700,
        elaunKedatangan: 50,
        elaunPerkhidmatan: 100,
        cutiUmum: 130.77,
      );
      expect(gross, 1980.77);
    });

    test('EPF SOCSO EIS and PCB employee amounts each deduct once', () {
      expect(
        PayrollCalculationService.totalDeductions(
          epfEmployee: 34,
          socsoEmployee: 8.25,
          eisEmployee: 3.30,
          pcb: 12,
        ),
        57.55,
      );
    });

    test('EIS-disabled payroll can represent zero EIS without changing others',
        () {
      expect(
        PayrollCalculationService.totalDeductions(
          epfEmployee: 34,
          socsoEmployee: 8.25,
          eisEmployee: 0,
        ),
        42.25,
      );
    });

    test('UNPAID and late remain independent stored deduction components', () {
      expect(
        PayrollCalculationService.totalDeductions(
          unpaid: 65.38,
          late: 5,
        ),
        70.38,
      );
    });

    test('net pay preserves cents for historical imported payroll', () {
      expect(
        PayrollCalculationService.netPay(
          gross: 1980.77,
          deductions: 57.55,
        ),
        closeTo(1923.22, 1e-9),
      );
    });
  });

  group('Late deduction payroll rule', () {
    test('waives a total below RM10', () {
      expect(PayrollCalculationService.payableLateDeduction(9.99), 0);
    });

    test('keeps RM10 chargeable', () {
      expect(PayrollCalculationService.payableLateDeduction(10), 10);
    });

    test('rounds a chargeable total to the nearest ten sen', () {
      expect(PayrollCalculationService.payableLateDeduction(130.74), 130.7);
      expect(PayrollCalculationService.payableLateDeduction(130.75), 130.8);
      expect(PayrollCalculationService.payableLateDeduction(130.77), 130.8);
    });
  });

  group('Payroll earning rounding', () {
    test('rounds OT and public-holiday amounts to the nearest ten sen', () {
      expect(PayrollCalculationService.roundPayrollAmount(130.74), 130.7);
      expect(PayrollCalculationService.roundPayrollAmount(130.75), 130.8);
      expect(PayrollCalculationService.roundPayrollAmount(130.77), 130.8);
    });
  });

  group('Automatic local attendance OT', () {
    test('counts only net minutes above allocated working time', () {
      expect(
        PayrollCalculationService.automaticLocalOvertimeMinutes(
          isLocalStaff: true,
          netWorkingMinutes: 510,
          allocatedWorkingMinutes: 450,
        ),
        60,
      );
    });

    test('does not count OT when breaks reduce net time below allocation', () {
      expect(
        PayrollCalculationService.automaticLocalOvertimeMinutes(
          isLocalStaff: true,
          netWorkingMinutes: 420,
          allocatedWorkingMinutes: 450,
        ),
        0,
      );
    });

    test('does not automatically calculate OT for foreign staff', () {
      expect(
        PayrollCalculationService.automaticLocalOvertimeMinutes(
          isLocalStaff: false,
          netWorkingMinutes: 600,
          allocatedWorkingMinutes: 450,
        ),
        0,
      );
    });
  });

  group('OT payment minimum', () {
    test('does not pay a daily OT amount of RM5 or less', () {
      expect(PayrollCalculationService.isPayableOvertimeAmount(2), isFalse);
      expect(PayrollCalculationService.isPayableOvertimeAmount(5), isFalse);
    });

    test('pays a daily OT amount above RM5', () {
      expect(
        PayrollCalculationService.isPayableOvertimeAmount(5.01),
        isTrue,
      );
      expect(PayrollCalculationService.isPayableOvertimeAmount(13), isTrue);
    });
  });
}
