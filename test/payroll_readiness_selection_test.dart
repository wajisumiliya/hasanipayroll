import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/payroll_readiness_selection.dart';

void main() {
  const employees = <Map<String, dynamic>>[
    {'employee_id': 'MG1', 'name': 'Management'},
    {'employee_id': 'E1', 'name': 'Complete'},
    {'employee_id': 'E2', 'name': 'Partial attendance'},
    {'employee_id': 'E3', 'name': 'Not submitted'},
  ];
  const ready = {'MG1', 'E1'}, submitted = {'E1', 'E2'};
  test('submitted filter cannot make partial attendance selectable', () {
    final rows = PayrollReadinessSelection.visible(employees,
        readyIds: ready,
        submittedIds: submitted,
        filter: 'submitted',
        search: '');
    expect(rows.map(PayrollReadinessSelection.id), ['E1', 'E2']);
    expect(PayrollReadinessSelection.selectable(rows, ready), {'E1'});
  });
  test(
      'visible selection preserves hidden choices and never adds follow-up employees',
      () {
    final followup = PayrollReadinessSelection.visible(employees,
        readyIds: ready,
        submittedIds: submitted,
        filter: 'followup',
        search: '');
    final choices = PayrollReadinessSelection.selectable(followup, ready);
    expect(choices, isEmpty);
    expect(PayrollReadinessSelection.toggleVisible({'MG1'}, choices, true),
        {'MG1'});
    expect(
        PayrollReadinessSelection.toggleVisible({'MG1', 'E1'}, {'E1'}, false),
        {'MG1'});
  });
  test('search matches ID/name within selected readiness filter', () {
    final rows = PayrollReadinessSelection.visible(employees,
        readyIds: ready,
        submittedIds: submitted,
        filter: 'ready',
        search: 'management');
    expect(rows.map(PayrollReadinessSelection.id), ['MG1']);
  });
}
