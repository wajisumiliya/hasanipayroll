import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/models/payroll.dart';
import 'package:hasani_payroll_portal/widgets/annual_leave_balance_card.dart';

void main() {
  test('employee AL supports decimal, missing and zero balances', () {
    final employee =
        Employee.fromJson({'employeeId': 'E1', 'annual_leave_balance': '10.5'});
    expect(employee.annualLeaveBalance, 10.5);
    expect(employee.copyWith(name: 'Updated').annualLeaveBalance, 10.5);
    expect(Employee.fromJson(employee.toJson()).annualLeaveBalance, 10.5);
    expect(Employee.fromJson({'employeeId': 'E1'}).annualLeaveBalance, isNull);
    expect(
        Employee.fromJson({'employeeId': 'E1', 'annual_leave_balance': 0})
            .annualLeaveBalance,
        0);
    expect(employee.toJson().containsKey('medical_leave_balance'), isFalse);
  });
  for (final balance in <double?>[null, 0, 10.5]) {
    testWidgets('employee dashboard AL card shows $balance without MC',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: AnnualLeaveBalanceCard(balance: balance))));
      expect(find.text('Annual Leave (AL)'), findsOneWidget);
      expect(
          find.text(balance == null
              ? 'Not set'
              : balance == 0
                  ? '0 days'
                  : '10.5 days'),
          findsOneWidget);
      expect(find.textContaining('MC'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
