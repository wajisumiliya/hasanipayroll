import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/payroll_editor_summary.dart';

void main() {
  testWidgets('payroll summary shows current values and updates on rebuild',
      (tester) async {
    Widget summary(double earnings, double deductions) => MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 285,
                child: PayrollEditorSummary(
                    earnings: earnings,
                    deductions: deductions,
                    net: earnings - deductions))));
    await tester.pumpWidget(summary(2000, 250));
    expect(find.text('Total Earnings'), findsOneWidget);
    expect(find.text('Total Deductions'), findsOneWidget);
    expect(find.text('Net Payroll'), findsOneWidget);
    expect(find.text('RM 1,750.00'), findsOneWidget);
    await tester.pumpWidget(summary(2200, 300));
    expect(find.text('RM 1,900.00'), findsOneWidget);
    expect(find.text('RM 1,750.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
