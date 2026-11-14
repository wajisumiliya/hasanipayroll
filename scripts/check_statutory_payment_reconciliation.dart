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
  print('Statutory EPF reconciliation regression checks passed.');
}
