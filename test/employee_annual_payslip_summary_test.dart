import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/models/payroll.dart';
import 'package:hasani_payroll_portal/widgets/employee_annual_payslip_summary.dart';
import 'annual_payslip_summary_test.dart' show saved;

void main() {
  testWidgets(
      'choose employee then year keeps selection and changes annual values',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final employee = Employee(
        employeeId: 'E1',
        name: 'Sample Employee',
        designation: '',
        department: '',
        email: '',
        newIcNo: '',
        bankCode: '',
        bankAccount: '',
        branchId: 'A');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: EmployeeAnnualPayslipSummary(employees: [
      employee
    ], records: [
      saved('E1', '2025-07-01', 1234),
      saved('E1', '2026-11-01', 2345)
    ], onRefresh: () {})))));
    expect(
        find.text(
            'Choose an employee and year to view the annual payslip summary.'),
        findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sample Employee (E1)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025').last);
    await tester.pumpAndSettle();
    expect(find.text('ANNUAL SALARY YEAR 2025'), findsOneWidget);
    expect(find.text('1,234.00'), findsWidgets);
    expect(find.text('2,345.00'), findsNothing);
    expect(find.text('NAME: Sample Employee   |   ID: E1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
