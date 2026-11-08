import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/salary_report_temporary_payroll.dart';

void main() {
  Map<String, dynamic> options() => {
    'employees': [{'employee_id': 'E1', 'name': 'Existing Employee', 'staff_scope': 'local'}],
    'branches': [{'id': 'G', 'name': 'GURUN'}], 'entries': [], 'staff_scope': null,
  };
  void screen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  Future<void> choose(WidgetTester tester, String label, String text) async {
    final field = find.byWidgetPredicate((w) => w is DropdownButtonFormField<String> &&
      w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('$label:'));
    await tester.ensureVisible(field); await tester.tap(field); await tester.pumpAndSettle();
    await tester.tap(find.text(text).last); await tester.pumpAndSettle();
  }
  Future<void> amount(WidgetTester tester, String field, String text) async {
    final finder = find.byKey(ValueKey('temporary-$field'));
    await tester.ensureVisible(finder); await tester.enterText(finder, text); await tester.pump();
  }
  testWidgets('historical employee entry calculates reconciliation amount without creating a live employee', (tester) async {
    screen(tester);
    Map<String, dynamic>? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SalaryReportTemporaryPayroll(
      startYear: 2025, load: (_) async => options(), save: (body, method) async {
        expect(method, 'POST'); saved = body;
      },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile)); await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('temporary-employee-id')), 'OLD1');
    await tester.enterText(find.byKey(const ValueKey('temporary-employee-name')), 'Historical Employee');
    await choose(tester, 'Reconciliation branch', 'GURUN');
    await amount(tester, 'basic_salary', '2000');
    await amount(tester, 'allowances', '250');
    await amount(tester, 'deductions', '50');
    expect(find.text('Salary Report amount per month: RM 2200.00'), findsOneWidget);
    await tester.tap(find.text('Save temporary payroll')); await tester.pumpAndSettle();
    expect(saved?['employee_id'], 'OLD1'); expect(saved?['employee_name'], 'Historical Employee');
    expect(saved?['branch_id'], 'G'); expect(saved?['from_month'], '2025-07');
    expect(saved?['through_month'], '2025-07'); expect(saved?['deductions'], '50');
    expect(find.text('Temporary reconciliation payroll saved. It will appear in the Salary Report only.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('existing employee selection and server duplicate failures preserve the draft', (tester) async {
    screen(tester);
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SalaryReportTemporaryPayroll(
      startYear: 2025, load: (_) async => options(), save: (body, method) async {
        attempts++; expect(body['employee_id'], 'E1'); expect(body['employee_name'], 'Existing Employee');
        throw StateError('Saved payroll already exists');
      },
    ))));
    await tester.pumpAndSettle();
    await choose(tester, 'Existing employee', 'E1 · Existing Employee');
    await choose(tester, 'Reconciliation branch', 'GURUN');
    await amount(tester, 'basic_salary', '2000');
    await tester.tap(find.text('Save temporary payroll')); await tester.pumpAndSettle();
    expect(attempts, 1); expect(find.textContaining('Saved payroll already exists'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('temporary-basic_salary'))).controller!.text, '2000');
    expect(tester.takeException(), isNull);
  });
}
