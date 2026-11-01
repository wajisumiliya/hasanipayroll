import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/models/payroll.dart';
import 'package:hasani_payroll_portal/widgets/employee_payslip_directory.dart';

Employee person(int n) => Employee(
    employeeId: 'E$n',
    name: 'Employee $n',
    designation: '',
    department: 'Operations',
    email: '',
    newIcNo: '',
    bankCode: '',
    bankAccount: '',
    branchId: 'A');
Widget directory(
        {required List<Employee> employees,
        Map<String, List<PayrollRecord>> records = const {},
        String tab = 'list'}) =>
    MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: EmployeePayslipDirectory(
      employees: employees,
      records: records,
      totalEmployees: employees.length,
      activeEmployees: employees.length,
      totalPayslips: records.values.fold(0, (sum, rows) => sum + rows.length),
      period: DateTime(2026, 11),
      branches: const {'A': 'ALOR SETAR'},
      branch: null,
      active: true,
      searchController: TextEditingController(),
      tab: tab,
      onPeriod: (_) {},
      onBranch: (_) {},
      onActive: (_) {},
      onSearch: (_) {},
      onTab: (_) {},
      onView: (_) {},
      onPayslips: (_) {},
      onRefresh: () {},
      onExport: (_) {},
    ))));
void main() {
  testWidgets('employee table paginates at ten rows', (tester) async {
    await tester.pumpWidget(
        directory(employees: List.generate(12, (i) => person(i + 1))));
    await tester.pumpAndSettle();
    expect(find.text('Employee 1'), findsOneWidget);
    expect(find.text('Employee 11'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Next employees'));
    await tester.tap(find.byTooltip('Next employees'));
    await tester.pumpAndSettle();
    expect(find.text('Employee 11'), findsOneWidget);
    expect(find.text('Employee 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('summary uses selected month without including earlier payroll',
      (tester) async {
    final rows = {
      'E1': [
        PayrollRecord.fromJson({
          'id': 'p1',
          'employeeId': 'E1',
          'period': '2026-11-01',
          'basicSalary': 2000
        })
      ],
      'E2': [
        PayrollRecord.fromJson({
          'id': 'p2',
          'employeeId': 'E2',
          'period': '2026-10-01',
          'basicSalary': 1000
        })
      ]
    };
    await tester.pumpWidget(directory(
        employees: [person(1), person(2)], records: rows, tab: 'summary'));
    await tester.pumpAndSettle();
    expect(find.text('Employee 1'), findsOneWidget);
    expect(find.text('Employee 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
