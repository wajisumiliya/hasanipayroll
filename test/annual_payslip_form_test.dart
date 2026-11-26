import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/annual_payslip_summary.dart';
import 'package:hasani_payroll_portal/widgets/annual_payslip_form.dart';
import 'annual_payslip_summary_test.dart' show saved;

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets(
        'annual form keeps twelve compact rows and welfare together at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final summary =
          AnnualPayslipSummary(employeeId: 'E1', year: 2024, records: [
        saved('E1', '2024-02-01', 1900, allowance: 800),
        saved('E1', '2024-03-01', 1900, allowance: 900),
      ]);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: AnnualPayslipForm(
                      summary: summary, name: 'Sample Employee')))));
      await tester.pumpAndSettle();
      expect(find.text('JANUARY'), findsOneWidget);
      expect(find.text('DECEMBER'), findsOneWidget);
      expect(find.text('WELFARE/GIFT/BONUS YEAR 2024'), findsOneWidget);
      expect(find.byType(Table), findsNWidgets(2));
      expect(tester.widget<Table>(find.byType(Table).first).children,
          hasLength(13));
      final salaryRect = tester.getRect(find.byType(Table).first);
      final welfareRect = tester.getRect(find.byType(Table).last);
      expect(welfareRect.top, greaterThan(salaryRect.bottom));
      expect(welfareRect.bottom, lessThan(width == 360 ? 560 : 1100));
      expect(salaryRect.width, greaterThan(width == 360 ? 300 : 650));
      expect(tester.takeException(), isNull);
    });
  }
}
