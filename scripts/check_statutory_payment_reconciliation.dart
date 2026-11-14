import '../lib/services/statutory_payment_reconciliation.dart';

void expectEqual(Object actual, Object expected, String label) {
  if (actual != expected) {
    throw StateError('$label: expected $expected, got $actual');
  }
}

void main() {
  // Synthetic October 2026 fixture, in sen, including both EE and ER.
  final rows = [
    ({'employee_id': 'HED1179', 'address': 'LOCAL', 'epf_no': ''}, 24000),
    ({'employee_id': 'FOREIGN-MISSING', 'address': ' frn '}, 152000),
    ({'employee_id': 'OTHER-PAYABLE', 'address': 'LOCAL'}, 5647000),
  ];
  var total = 0;
  var excluded = 0;
  for (final (employee, contribution) in rows) {
    total += contribution;
    if (excludeMissingEpfFromPayment(employee)) excluded += contribution;
  }
  expectEqual(total, 5823000, 'October original EPF');
  expectEqual(excluded, 152000, 'October missing-number exclusion');
  expectEqual(total - excluded, 5671000, 'October EPF payable');
  expectEqual(
    excludeMissingEpfFromPayment(rows.first.$1),
    false,
    'HED1179 RM240 remains payable',
  );

  for (final missing in [null, '', '   ', '-', 'n/a', 'NA', 'null', '0']) {
    expectEqual(
      excludeMissingEpfFromPayment({'address': 'FRN', 'epf_no': missing}),
      true,
      'Foreign missing number $missing',
    );
    expectEqual(
      excludeMissingEpfFromPayment({'address': 'LOCAL', 'epf_no': missing}),
      false,
      'Local missing number $missing',
    );
  }
  for (final key in ['epf_no', 'epfNo', 'kwsp_no', 'kwspNo']) {
    expectEqual(
      excludeMissingEpfFromPayment({'address': 'FRN', key: ' 12345678 '}),
      false,
      'Foreign valid $key',
    );
  }
  expectEqual(
    excludeMissingEpfFromPayment({}),
    false,
    'Unknown employee is not assumed foreign',
  );
  for (final missing in [null, '', '   ', '-', 'n/a', 'NA', 'null', '0']) {
    expectEqual(
        excludeMissingSocsoFromPayment(
            {'address': ' frn ', 'socso_no': missing}),
        true,
        'Foreign missing SOCSO number $missing');
    expectEqual(
        excludeMissingSocsoFromPayment(
            {'address': 'LOCAL', 'socso_no': missing}),
        false,
        'Local missing SOCSO number $missing remains payable');
  }
  for (final key in ['socso_no', 'socsoNo', 'socso_number', 'SOCSO_NO']) {
    expectEqual(
        excludeMissingSocsoFromPayment({'address': 'FRN', key: ' 12345678 '}),
        false,
        'Foreign valid $key remains payable');
  }
  expectEqual(excludeMissingSocsoFromPayment({}), false,
      'Unknown employee is not assumed foreign for SOCSO');

  // Synthetic saved EE + ER contributions in sen, shared SOCSO/EIS exclusion.
  final statutoryRows = [
    ({'address': 'LOCAL', 'socso_no': ''}, 10000, 2000),
    ({'address': 'FRN', 'socso_no': '-'}, 3000, 600),
    ({'address': 'FRN', 'socsoNo': '12345678'}, 7000, 1400),
  ];
  var socsoTotal = 0;
  var socsoExcluded = 0;
  var eisTotal = 0;
  var eisExcluded = 0;
  for (final (employee, socso, eis) in statutoryRows) {
    socsoTotal += socso;
    eisTotal += eis;
    if (excludeMissingSocsoFromPayment(employee)) {
      socsoExcluded += socso;
      eisExcluded += eis;
    }
  }
  expectEqual(socsoTotal, 20000, 'SOCSO original total');
  expectEqual(socsoExcluded, 3000, 'SOCSO foreign-only exclusion');
  expectEqual(socsoTotal - socsoExcluded, 17000, 'SOCSO net payable');
  expectEqual(eisTotal, 4000, 'EIS original total');
  expectEqual(eisExcluded, 600, 'EIS foreign-only exclusion');
  expectEqual(eisTotal - eisExcluded, 3400, 'EIS net payable');
  final counts = <String, dynamic>{
    for (final key in statutoryEmployeeCountKeys) key: 0,
  };
  for (var i = 0; i < 170; i++) {
    countStatutoryEmployee(counts, 'epf', 240, i < 9);
  }
  expectEqual(counts['epfEmployees'], 170, 'Original contributing employees');
  expectEqual(
      counts['excludedEpfEmployees'], 9, 'Excluded contributing employees');
  expectEqual(statutoryAmountWithEmployees(58230, counts['epfEmployees']),
      '58230.00 / 170 emp', 'Amount and employee count, without average');
  expectEqual(
      statutoryAmountWithEmployees(
          56710, counts['epfEmployees'] - counts['excludedEpfEmployees']),
      '56710.00 / 161 emp',
      'Net payable contributing employees');
  countStatutoryEmployee(counts, 'socso', 20, false);
  countStatutoryEmployee(counts, 'socso', 10, true);
  countStatutoryEmployee(counts, 'socso', 0, true);
  expectEqual(
      counts['socsoEmployees'], 2, 'SOCSO includes employer-only amounts');
  expectEqual(counts['excludedSocsoEmployees'], 1, 'Zero SOCSO is not counted');
  countStatutoryEmployee(counts, 'eis', 0, true);
  expectEqual(
      counts['eisEmployees'], 0, 'No EIS contribution means no employee');
  Map<String, dynamic>? zero(String id, double ee, double er) =>
      zeroStatutoryContributor(
        employeeId: id,
        name: id == 'LOCAL' ? 'Local employee' : '',
        branch: 'Branch A',
        employeeAmount: ee,
        employerAmount: er,
      );
  expectEqual(zero('LOCAL', 0, 0)!['name'], 'Local employee',
      'Local zero contributions listed');
  expectEqual(zero('FOREIGN', 0, 0)!['name'], 'FOREIGN',
      'Foreign zero contributions listed with fallback name');
  expectEqual(zero('EMPLOYER-ONLY', 0, 20) == null, true,
      'Employer-only contribution is not a zero contribution');
  expectEqual(zero('EMPLOYEE-ONLY', 10, 0) == null, true,
      'Employee-only contribution is not a zero contribution');
  expectEqual(zero('FOREIGN-MISSING-NUMBER', 10, 10) == null, true,
      'Missing number exclusion does not put nonzero payroll in the zero list');
  final zeroList = statutoryZeroContributorList([
    {
      'branch': 'Branch A',
      'zeroEpfEmployees': [zero('LOCAL', 0, 0)]
    },
    {
      'branch': 'Branch A',
      'zeroEpfEmployees': [zero('LOCAL', 0, 0)]
    },
    {
      'branch': 'GRAND TOTAL',
      'zeroEpfEmployees': [zero('TOTAL', 0, 0)]
    },
  ], 'zeroEpfEmployees');
  expectEqual(
      zeroList.length, 1, 'List deduplicates staff and ignores grand total');
  expectEqual(statutoryZeroContributorList([], 'zeroSocsoEmployees').length, 0,
      'Empty SOCSO list');
  print('Statutory EPF/SOCSO/EIS reconciliation regression checks passed.');
}
