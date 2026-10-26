import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/late_report_page.dart';

void main() {
  testWidgets(
      'admin report shows combined count, dates and minutes; filters branches and changes month',
      (tester) async {
    final months = <DateTime>[];
    await tester.pumpWidget(MaterialApp(
        home: LateReportPage(
      month: DateTime(2026, 10),
      branches: const [
        {'id': 'A', 'name': 'ALOR SETAR'},
        {'id': 'B', 'name': 'ASTANA'}
      ],
      loader: (month) async {
        months.add(month);
        return {
          'missing_schedules': 1,
          'missing_schedules_by_branch': {'B': 1},
          'reports': [
            {
              'branch_id': 'A',
              'employee_id': 'E1',
              'name': 'Employee A',
              'count': 4,
              'arrival_count': 2,
              'break_count': 2,
              'total_minutes': 50,
              'events': [
                {
                  'date': '2026-10-01',
                  'type': 'arrival',
                  'scheduled': '09:00',
                  'actual': '09:10',
                  'minutes': 10
                },
                {
                  'date': '2026-10-02',
                  'type': 'break',
                  'allocated_minutes': 60,
                  'actual_minutes': 80,
                  'minutes': 20
                }
              ]
            },
            {
              'branch_id': 'B',
              'employee_id': 'E2',
              'name': 'Employee B',
              'count': 3,
              'arrival_count': 3,
              'break_count': 0,
              'total_minutes': 30,
              'events': []
            },
          ]
        };
      },
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 late arrivals + 2 exceeded breaks = 4'),
        findsOneWidget);
    await tester.tap(find.text('Employee A · E1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('+20 min'), 100);
    expect(find.text('Allowed 60 min · used 80 min'), findsOneWidget);
    expect(find.text('+10 min'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALOR SETAR').last);
    await tester.pumpAndSettle();
    expect(find.text('Employee B · E2'), findsNothing);
    expect(find.textContaining('could not be assessed'), findsNothing);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(months.last, DateTime(2026, 9));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'failed request offers retry rather than an empty successful report',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: LateReportPage(
            month: DateTime(2026, 10),
            branches: const [],
            loader: (_) async {
              if (calls++ == 0) throw StateError('offline');
              return {'reports': [], 'missing_schedules': 0};
            })));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No employees with 3'), findsOneWidget);
  });
}
