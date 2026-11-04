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
    final employees = List.generate(12, (i) => person(i + 1));
    final records = {
      for (final employee in employees)
        employee.employeeId: [PayrollRecord.fromJson({
          'id': employee.employeeId,
          'employeeId': employee.employeeId,
          'period': '2026-11-01',
        })],
    };
    await tester.pumpWidget(directory(employees: employees, records: records));
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
  testWidgets('list hides missing payroll and staff inactive in the month',
      (tester) async {
    final employees = [
      person(1), person(2), person(3),
      person(4).copyWith(isActive: false, resignedAt: DateTime(2026, 10, 31)),
      person(5).copyWith(isActive: false, resignedAt: DateTime(2026, 12, 1)),
    ];
    final records = {
      for (final id in ['E1', 'E3', 'E4', 'E5'])
        id: [PayrollRecord.fromJson({
          'id': id, 'employeeId': id,
          'period': id == 'E3' ? '2026-10-01' : '2026-11-01',
        })],
    };
    await tester.pumpWidget(directory(employees: employees, records: records));
    await tester.pumpAndSettle();
    expect(find.text('Employee 1'), findsOneWidget);
    expect(find.text('Employee 2'), findsNothing);
    expect(find.text('Employee 3'), findsNothing);
    expect(find.text('Employee 4'), findsNothing);
    expect(find.text('Employee 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
