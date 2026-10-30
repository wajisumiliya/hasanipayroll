import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/admin_activity_cards.dart';

void main() {
  test('month and branch scope service dates; only completed years count', () {
    final widget = AdminActivityCards(
      month: DateTime(2026, 9),
      branch: 'A',
      employees: const [
        {
          'employee_id': 'A1',
          'branch_id': 'A',
          'is_active': true,
          'birthday': '1995-09-05',
          'joining_date': '2020-09-01'
        },
        {
          'employee_id': 'A2',
          'branch_id': 'A',
          'is_active': true,
          'birthday': '1995-08-05',
          'joining_date': '2026-09-01'
        },
        {
          'employee_id': 'B1',
          'branch_id': 'B',
          'is_active': true,
          'birthday': '1995-09-05',
          'joining_date': '2020-09-01'
        },
        {
          'employee_id': 'A3',
          'branch_id': 'A',
          'is_active': false,
          'birthday': '1995-09-05',
          'joining_date': '2020-09-01'
        },
      ],
      payroll: const [],
      activity: Future.value({}),
      onMonth: (_) {},
      onLate: () {},
      onPayroll: () {},
    );
    expect(widget.occasions(false).single['employee_id'], 'A1');
    expect(widget.occasions(true).single['years'], 6);
    expect(widget.increments(), isEmpty);
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets('activity cards fit $width with honest empty states',
        (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: AdminActivityCards(
                      month: DateTime(2026, 9),
                      branch: null,
                      employees: const [],
                      payroll: const [],
                      activity: Future.value({'late': []}),
                      onMonth: (_) {},
                      onLate: () {},
                      onPayroll: () {})))));
      await tester.pumpAndSettle();
      expect(find.text('Attendance Late (3 and above)'), findsOneWidget);
      expect(find.text('Increment List'), findsOneWidget);
      expect(find.text('Upcoming Birthdays'), findsOneWidget);
      expect(find.text('Work Anniversary'), findsOneWidget);
      expect(
          find.text('No matching records for this month.'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  }
}
