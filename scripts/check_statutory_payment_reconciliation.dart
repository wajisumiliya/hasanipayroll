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
  print('Statutory EPF/SOCSO/EIS reconciliation regression checks passed.');
}
