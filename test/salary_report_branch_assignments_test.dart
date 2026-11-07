import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/salary_report_branch_assignments.dart';

void main() {
  Map<String, dynamic> choices({bool assigned = false}) => {
        'employees': [
          {'employee_id': 'BAS025', 'name': 'Test Employee'}
        ],
        'branches': [
          {'id': 'G', 'name': 'GURUN'}
        ],
        'assignments': assigned
            ? [
                {'employee_id': 'BAS025', 'branch_id': 'G', 'month': '2025-07'}
              ]
            : [],
      };
  Future<void> select(WidgetTester tester, String label, String text) async {
    final field = find.byWidgetPredicate((widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('$label:'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'select employee, branch and range; save and reload persisted assignments',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? saved;
    var loads = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SalaryReportBranchAssignments(
      startYear: 2025,
      load: (year) async {
        expect(year, 2025);
        loads++;
        return choices(assigned: saved != null);
      },
      save: (body, remove) async {
        expect(remove, isFalse);
        saved = body;
      },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save assignment'));
    await tester.pump();
    expect(find.text('Select an employee and branch first.'), findsOneWidget);
    await select(tester, 'Employee', 'BAS025 · Test Employee');
    await select(tester, 'Payroll branch for report', 'GURUN');
    await tester.tap(find.text('Save assignment'));
    await tester.pumpAndSettle();
    expect(saved, {
      'employee_id': 'BAS025',
      'branch_id': 'G',
      'from_month': '2025-07',
      'through_month': '2026-06'
    });
    expect(loads, 2);
    expect(find.text('Assignments saved. Excel and PDF will use this branch.'),
        findsOneWidget);
    expect(find.text('Jul 2025 — GURUN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'overlap failures remain visible and removal requires confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var removes = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SalaryReportBranchAssignments(
      startYear: 2025,
      load: (_) async => choices(assigned: true),
      save: (_, remove) async {
        if (remove) {
          removes++;
        } else {
          throw StateError('Assignment overlaps');
        }
      },
    ))));
    await tester.pumpAndSettle();
    await select(tester, 'Employee', 'BAS025 · Test Employee');
    await select(tester, 'Payroll branch for report', 'GURUN');
    await tester.tap(find.text('Save assignment'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Assignment overlaps'), findsOneWidget);
    await tester.tap(find.text('Remove selected range'));
    await tester.pumpAndSettle();
    expect(removes, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(removes, 0);
    await tester.tap(find.text('Remove selected range'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(removes, 1);
    expect(tester.takeException(), isNull);
  });
}
