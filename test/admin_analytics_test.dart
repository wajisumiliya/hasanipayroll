import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/admin_analytics.dart';

AdminAnalytics fixture({String? branch}) => AdminAnalytics(
      month: DateTime(2026, 1),
      branch: branch,
      branches: const {'A': 'Branch A', 'B': 'Branch B'},
      employees: const [
        {
          'employee_id': 'E1',
          'name': 'Aina',
          'branch_id': 'A',
          'is_active': true
        },
        {
          'employee_id': 'E2',
          'name': 'Other branch',
          'branch_id': 'B',
          'is_active': true
        },
      ],
      payroll: const [
        {
          'employee_id': 'E1',
          'period': '2026-01-01',
          'basic_salary': 3000,
          'epf_employee': 330
        },
        {'employee_id': 'E1', 'period': '2025-12-01', 'basic_salary': 2800},
        {
          'employee_id': 'E2',
          'branch_id': 'B',
          'period': '2026-01-01',
          'basic_salary': 9000
        },
      ],
      activity: Future.value(<String, dynamic>{}),
      grossOf: (r) => AdminAnalytics.number(r['basic_salary']),
      baseOf: (r) => AdminAnalytics.number(r['basic_salary']),
    );

void main() {
  test('uses payroll branch with employee fallback and handles year boundary',
      () {
    final widget = fixture(branch: 'a');
    expect(widget.rows(DateTime(2026, 1)).length, 1);
    expect(widget.rows(DateTime(2025, 12)).single['basic_salary'], 2800);
    expect(widget.rows(DateTime(2025, 11)), isEmpty);
    expect(widget.branchOf({'employee_id': 'E1', 'branch_id': 'B'}), 'B');
    expect(
        AdminAnalytics.deductionsOf(
            {'epf_employee': '330', 'pcb': '12.50', 'advance': 100}),
        442.5);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('analytics fit width $width and show real detail',
        (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(child: fixture(branch: 'A')))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('RM 3,000.00'), findsWidgets);
      expect(find.text('No saved payroll'), findsWidgets);
      for (final title in [
        'Salary analytics',
        'Attendance monitoring',
        'Branch monitoring',
        'Branch distribution'
      ]) {
        expect(find.text(title), findsNothing);
      }
      await tester.ensureVisible(find.text('View employee breakdown'));
      await tester.tap(find.text('View employee breakdown'));
      await tester.pumpAndSettle();
      expect(find.text('Aina'), findsWidgets);
      expect(find.text('RM 2,670.00'), findsWidgets);
      expect(find.text('Other branch'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
