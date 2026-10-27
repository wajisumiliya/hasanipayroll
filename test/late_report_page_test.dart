import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/screens/late_report_page.dart';
import 'package:hasani_payroll_portal/services/late_report_export_service.dart';

Map<String, dynamic> fixture() => {
      'missing_records': [
        {
          'branch_id': 'B',
          'employee_id': 'E2',
          'name': 'Employee B',
          'date': '2026-10-03',
          'issues': ['Missing roster']
        }
      ],
      'previous_missing_records': [
        {
          'branch_id': 'B',
          'employee_id': 'E2',
          'name': 'Employee B',
          'date': '2026-09-03',
          'issues': ['Incomplete break start/end']
        }
      ],
      'reports': [
        {
          'branch_id': 'A',
          'employee_id': 'E1',
          'name': 'Employee A',
          'count': 4,
          'arrival_count': 2,
          'break_count': 2,
          'total_minutes': 50,
          'previous_count': 7,
          'change': -3,
          'events': [
            {
              'date': '2026-10-01',
              'type': 'arrival',
              'scheduled': '09:00',
              'actual': '09:10',
              'minutes': 10,
              'fingerprint': 'f' * 64,
              'review_history': []
            },
            {
              'date': '2026-10-01',
              'type': 'break',
              'allocated_minutes': 60,
              'actual_minutes': 75,
              'minutes': 15,
              'fingerprint': 'd' * 64,
              'review_history': [],
            },
            {
              'date': '2026-10-02',
              'type': 'arrival',
              'scheduled': '09:00',
              'actual': '09:05',
              'minutes': 5,
              'fingerprint': 'c' * 64,
              'review_history': [],
            },
            {
              'date': '2026-10-02',
              'type': 'break',
              'allocated_minutes': 60,
              'actual_minutes': 80,
              'minutes': 20,
              'fingerprint': 'e' * 64,
              'review_history': []
            },
          ]
        },
        {
          'branch_id': 'B',
          'employee_id': 'E2',
          'name': 'Employee B',
          'count': 7,
          'arrival_count': 5,
          'break_count': 2,
          'total_minutes': 90,
          'previous_count': 3,
          'change': 4,
          'events': []
        },
      ],
    };
const branches = [
  {'id': 'A', 'name': 'ALOR SETAR'},
  {'id': 'B', 'name': 'ASTANA'}
];
Future<void> chooseBranch(WidgetTester tester) async {
  final field = find.byType(DropdownButtonFormField<String>).first;
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text('ALOR SETAR').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'shows summaries and details without incomplete sections even from older servers',
      (tester) async {
    final months = <DateTime>[];
    await tester.pumpWidget(MaterialApp(
        home: LateReportPage(
            month: DateTime(2026, 10),
            branches: branches,
            loader: (month) async {
              months.add(month);
              return fixture();
            })));
    await tester.pumpAndSettle();
    expect(find.text('Employees flagged'), findsOneWidget);
    expect(find.text('Late arrivals'), findsOneWidget);
    expect(find.text('Exceeded breaks'), findsOneWidget);
    expect(find.text('Excess minutes'), findsOneWidget);
    expect(find.textContaining('Incomplete current records'), findsNothing);
    expect(
        find.textContaining('Incomplete previous-month records'), findsNothing);
    await tester.ensureVisible(find.text('Employee A · E1'));
    expect(find.textContaining('2 late arrivals + 2 exceeded breaks = 4'),
        findsOneWidget);
    expect(find.text('Low severity'), findsOneWidget);
    expect(find.text('4 this month · 7 last month'), findsOneWidget);
    expect(find.text('3 fewer than last month'), findsOneWidget);
    expect(find.text('High severity'), findsOneWidget);
    await tester.tap(find.text('Employee A · E1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('+20 min'));
    expect(find.text('Allowed 60 min · used 80 min'), findsOneWidget);
    expect(find.text('+10 min'), findsOneWidget);
    await chooseBranch(tester);
    expect(find.text('Employee B · E2'), findsNothing);
    expect(find.textContaining('Incomplete current records'), findsNothing);
    expect(
        find.textContaining('Incomplete previous-month records'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Previous month'));
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(months.last, DateTime(2026, 9));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'review validates reason, retains failed input, saves selected status and reloads history',
      (tester) async {
    var loads = 0, saves = 0;
    Map<String, dynamic>? saved;
    await tester.pumpWidget(MaterialApp(
        home: LateReportPage(
            month: DateTime(2026, 10),
            branches: branches,
            loader: (_) async {
              loads++;
              return fixture();
            },
            reviewSaver: (body) async {
              saves++;
              if (saves == 1) throw StateError('offline');
              saved = body;
            })));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Employee A · E1'));
    await tester.tap(find.text('Employee A · E1'));
    await tester.pumpAndSettle();
    final button = find.text('Review event').first;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 3 characters.'), findsOneWidget);
    expect(saves, 0);
    final status = find
        .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(DropdownButtonFormField<String>))
        .first;
    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'Approved after transport delay');
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to save.'), findsOneWidget);
    expect(loads, 1);
    expect(find.text('Approved after transport delay'), findsOneWidget);
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(saved?['employee_id'], 'E1');
    expect(saved?['status'], 'approved');
    expect(saved?['fingerprint'], 'f' * 64);
    expect(saved?['reason'], 'Approved after transport delay');
    expect(loads, 2);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets(
      'exports use selected branch and month, with the same visible report rows',
      (tester) async {
    final exports = <LateReportExportData>[];
    final formats = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: LateReportPage(
            month: DateTime(2026, 10),
            branches: branches,
            loader: (_) async => fixture(),
            exporter: (format, payload) async {
              formats.add(format);
              exports.add(payload);
            })));
    await tester.pumpAndSettle();
    await chooseBranch(tester);
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Excel'));
    await tester.pumpAndSettle();
    expect(formats, ['pdf', 'xlsx']);
    expect(exports.first.branchLabel, 'ALOR SETAR');
    expect(exports.first.reports.length, 1);
    expect(exports.first.reports.single['employee_id'], 'E1');
    expect(exports.first.branchId, 'A');
    expect(exports.first.month, DateTime(2026, 10));
  });
  testWidgets(
      'mobile report fits narrow screen; old reviews are clearly marked stale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = fixture();
    final event = ((data['reports'] as List).first['events'] as List).first;
    event['review_outdated'] = true;
    event['review_history'] = [
      {
        'status': 'approved',
        'reason_code': 'transport',
        'reason': 'Train delayed',
        'reviewed_by': 'admin1',
        'reviewed_at': '2026-10-26T01:00:00Z',
        'event_fingerprint': 'old'
      }
    ];
    await tester.pumpWidget(MaterialApp(
        home: LateReportPage(
            month: DateTime(2026, 10),
            branches: branches,
            loader: (_) async => data)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Employee A · E1'));
    await tester.tap(find.text('Employee A · E1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Needs re-review'));
    expect(find.text('Needs re-review'), findsOneWidget);
    await tester.ensureVisible(find.text('Review history (1)'));
    await tester.tap(find.text('Review history (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Previous attendance timing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed request offers retry rather than empty success',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: LateReportPage(
            month: DateTime(2026, 10),
            branches: const [],
            loader: (_) async {
              if (calls++ == 0) throw StateError('offline');
              return {'reports': [], 'missing_records': []};
            })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No employees with 3'), findsOneWidget);
  });
  testWidgets(
      'pending export leaves page responsive and failure re-enables export controls',
      (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: LateReportPage(
            month: DateTime(2026, 10),
            branches: branches,
            loader: (_) async => fixture(),
            exporter: (_, __) => pending.future)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export PDF'));
    await tester.pump();
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Export Excel'))
            .onPressed,
        isNull);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pump();
    await tester.pump();
    expect(find.text('September 2026'), findsOneWidget);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to export report. Please retry.'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Export Excel'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'embedded report carries the dashboard branch and retains refresh',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LateReportPage(
            month: DateTime(2026, 10),
            branches: branches,
            embedded: true,
            initialBranchId: 'A',
            loader: (_) async => fixture())));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Refresh report'), findsOneWidget);
    expect(find.text('Employee A · E1'), findsOneWidget);
    expect(find.text('Employee B · E2'), findsNothing);
  });
}
