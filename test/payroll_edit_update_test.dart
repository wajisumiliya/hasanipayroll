import 'package:flutter_test/flutter_test.dart';

import '../lib/services/payroll_edit_update.dart';
import '../lib/services/saved_payroll_amounts.dart';

void main() {
  test(
      'Locked payroll correction includes financial changes and preserves status',
      () {
    final saved = <String, dynamic>{
      'id': 'LOCKED',
      'employee_id': 'BLK011',
      'period': '2026-10-01',
      'basic_salary': 2500,
      'epf_employee': 0,
      'epf_employer': 100,
      'net_salary': 2500,
      'is_published': true,
      'is_paid': true,
      'remarks': 'Original',
    };
    final edited = <String, dynamic>{
      ...saved,
      'basic_salary': 3000,
      'epf_employee': 50,
      'remarks': 'Reviewed correction',
    };
    SavedPayrollAmounts.refreshExistingTotals(edited);
    expect(payrollEditUpdatePayload(saved, edited, preserveUnsetZero: true), {
      'basic_salary': 3000,
      'epf_employee': 50,
      'net_salary': 2950,
      'remarks': 'Reviewed correction',
    });
    expect(edited['is_published'], true);
    expect(edited['is_paid'], true);
  });
  test('All published, paid and finalized markers identify locked payroll', () {
    for (final key in ['is_published', 'is_paid', 'isPaid', 'is_finalized']) {
      expect(payrollIsLocked({key: true}), isTrue);
      expect(payrollIsLocked({key: 'true'}), isTrue);
    }
    for (final key in ['paid_at', 'paidAt', 'finalized_at']) {
      expect(payrollIsLocked({key: '2026-11-01'}), isTrue);
    }
    for (final status in ['paid', 'finalized', 'finalised', 'locked', 'PAID']) {
      expect(payrollIsLocked({'status': status}), isTrue);
    }
    expect(payrollIsLocked({'is_published': false}), isFalse);
  });
  test('Locked adjustment preserves unset component values displayed as zero',
      () {
    expect(
        payrollEditUpdatePayload(
          {'epf_employer': 0, 'fw_salary': null, 'is_published': true},
          {'epf_employer': 100, 'fw_salary': 0, 'is_published': true},
          preserveUnsetZero: true,
        ),
        {'epf_employer': 100});
  });
  test(
      'Employer EPF edit updates only changed values, preserving the saved row',
      () {
    final saved = <String, dynamic>{
      'id': 'SAVED-ID',
      'employee_id': 'BLK011',
      'period': '2026-10-01',
      'created_at': '2026-10-20',
      'branch_id': 'A',
      'branch_name': 'Branch A',
      'basic_salary': '2500.00',
      'epf_employee': '0.00',
      'epf_employer': '0.00',
      'net_salary': '2500.00',
      'is_published': false,
    };
    final edited = <String, dynamic>{
      ...saved,
      'id': 'DO-NOT-REPLACE',
      'period': '2026-11-01',
      'basic_salary': 2500.0,
      'epf_employee': 0.0,
      'epf_employer': 100.0,
    };
    SavedPayrollAmounts.refreshExistingTotals(edited);
    expect(payrollEditUpdatePayload(saved, edited), {'epf_employer': 100.0});
    expect(saved['epf_employer'], '0.00');
  });

  test('Financial edits refresh existing snapshots and withdraw publication',
      () {
    final saved = <String, dynamic>{
      'basic_salary': 2500,
      'epf_employee': 0,
      'epf_employer': 0,
      'net_salary': 2500,
      'is_published': true,
      'published_at': '2026-11-01',
    };
    final edited = <String, dynamic>{
      ...saved,
      'epf_employee': 50,
      'is_published': false,
      'published_at': null,
    };
    SavedPayrollAmounts.refreshExistingTotals(edited);
    expect(payrollEditUpdatePayload(saved, edited), {
      'epf_employee': 50,
      'net_salary': 2450,
      'is_published': false,
      'published_at': null,
    });
  });
}
