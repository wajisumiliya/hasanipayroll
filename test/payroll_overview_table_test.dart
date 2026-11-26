import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/payroll_overview_table.dart';

void main() {
  for (final width in [360.0, 1400.0]) {
    testWidgets('payroll overview shows essential columns at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: PayrollOverviewTable(entries: [
        PayrollOverviewEntry(
            employeeId: 'EMP001',
            name: 'Sample Employee',
            basicSalary: 'RM 1,700.00',
            gross: 'RM 1,900.00',
            deductions: 'RM 160.00',
            net: 'RM 1,740.00',
            status: 'Published',
            onDetails: () => opened++),
      ]))));
      expect(tester.widget<DataTable>(find.byType(DataTable)).columns,
          hasLength(8));
      expect(find.text('Sample Employee'), findsOneWidget);
      expect(find.text('RM 1,740.00'), findsOneWidget);
      await tester.tap(find.text('EMP001'));
      await tester.pump();
      expect(opened, 1);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(-1800, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View details'));
      await tester.pump();
      expect(opened, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
