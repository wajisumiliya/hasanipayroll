import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/admin_activity_cards.dart';

void main() {
  test('five-day service dates respect branch and completed years', () {
    final widget = AdminActivityCards(
      month: DateTime(2026, 9),
      referenceDate: DateTime(2026, 9, 1),
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
  test('eligibility uses maintained schedule before payroll generation', () {
    final widget = AdminActivityCards(
        month: DateTime(2026, 10),
        branch: 'A',
        employees: const [
          {
            'employee_id': 'E1',
            'branch_id': 'A',
            'is_active': true,
            'inc_details': 'OCT-26/100'
          },
          {
            'employee_id': 'E2',
            'branch_id': 'A',
            'is_active': true,
            'inc_details': 'SEP-26/100'
          },
          {
            'employee_id': 'E3',
            'branch_id': 'B',
            'is_active': true,
            'inc_details': 'OCT-26/100'
          },
          {
            'employee_id': 'E4',
            'branch_id': 'A',
            'is_active': false,
            'inc_details': 'OCT-26/100'
          },
          {
            'employee_id': 'E5',
            'branch_id': 'A',
            'is_active': true,
            'inc_details': 'OCT-26/125'
          },
        ],
        payroll: const [],
        activity: Future.value({}),
        onMonth: (_) {},
        onLate: () {},
        onPayroll: () {});
    expect(widget.increments().single['employee_id'], 'E1');
    expect(widget.increments().single['amount'], 100);
  });
  test('five-day window crosses New Year and excludes sixth day', () {
    final widget = AdminActivityCards(
        month: DateTime(2026, 12),
        branch: null,
        referenceDate: DateTime(2026, 12, 31),
        employees: const [
          {
            'employee_id': 'E1',
            'is_active': true,
            'birthday': '1990-01-05',
            'joining_date': '2020-01-05'
          },
          {
            'employee_id': 'E2',
            'is_active': true,
            'birthday': '1990-01-06',
            'joining_date': '2020-01-06'
          },
        ],
        payroll: const [],
        activity: Future.value({}),
        onMonth: (_) {},
        onLate: () {},
        onPayroll: () {});
    expect(widget.occasions(false).single['days'], 5);
    expect(widget.occasions(true).single['years'], 7);
    expect(
        AdminActivityCards.lateMinutes({
          'events': [
            {'type': 'arrival', 'minutes': 60},
            {'type': 'break', 'minutes': 120},
            {'type': 'arrival', 'minutes': 30}
          ]
        }),
        90);
  });
  testWidgets('late employee flash card opens arrival-only detail',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: AdminActivityCards(
                    month: DateTime(2026, 10),
                    branch: 'A',
                    employees: const [
                      {
                        'employee_id': 'E1',
                        'name': 'Aina',
                        'branch_id': 'A',
                        'is_active': true
                      }
                    ],
                    payroll: const [],
                    activity: Future.value({
                      'late': [
                        {
                          'employee_id': 'E1',
                          'name': 'Aina',
                          'branch_id': 'A',
                          'arrival_count': 3,
                          'events': [
                            {
                              'type': 'arrival',
                              'date': '2026-10-01',
                              'scheduled': '09:00',
                              'actual': '09:30',
                              'minutes': 30
                            },
                            {
                              'type': 'arrival',
                              'date': '2026-10-02',
                              'scheduled': '09:00',
                              'actual': '09:30',
                              'minutes': 30
                            },
                            {
                              'type': 'arrival',
                              'date': '2026-10-03',
                              'scheduled': '09:00',
                              'actual': '10:00',
                              'minutes': 60
                            },
                            {
                              'type': 'break',
                              'date': '2026-10-03',
                              'minutes': 90
                            },
                          ]
                        }
                      ]
                    }),
                    onMonth: (_) {},
                    onLate: () {},
                    onPayroll: () {})))));
    await tester.pumpAndSettle();
    expect(find.text('2.00 h'), findsOneWidget);
    await tester.ensureVisible(find.text('Aina'));
    await tester.tap(find.text('Aina'));
    await tester.pumpAndSettle();
    expect(find.text('Aina · 3 late days · 2.00 h'), findsOneWidget);
    expect(find.text('2026-10-01'), findsOneWidget);
    expect(find.text('90'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 768.0, 1100.0, 1440.0]) {
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
          find.text('No matching records for this month.'), findsNWidgets(2));
      expect(find.text('No events in the next 5 days.'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}
