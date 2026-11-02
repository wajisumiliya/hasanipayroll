import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/screens/early_out_page.dart';

void main() {
  testWidgets(
      'Early Out filters, search, refresh and pagination request current records',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Map<String, dynamic>>[];
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: EarlyOutPage(loader: (filters) async {
      requests.add(filters);
      return {'records': [], 'total': 25};
    }))));
    await tester.pumpAndSettle();
    expect(find.text('Early Out Approvals'), findsOneWidget);
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(requests.last['page'], 2);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search name / ID / branch'), 'E1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(requests.last['search'], 'E1');
    expect(requests.last['page'], 1);
    final count = requests.length;
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(requests.length, count + 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'approval validates duration and sends exact event revision without modifying payroll',
      (tester) async {
    tester.view.physicalSize = const Size(3000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? saved;
    final event = {
      'employee_id': 'E1',
      'name': 'Employee',
      'branch_id': 'A',
      'attendance_date': '2026-10-01',
      'shift_end': '18:00',
      'check_out': '16:00',
      'required_minutes': 480,
      'worked_minutes': 360,
      'shortage_minutes': 105,
      'eligible_early_minutes': 105,
      'approval_status': 'PENDING',
      'approved_minutes': 0,
      'revision': '0',
      'fingerprint': 'f' * 64,
      'is_submitted': true
    };
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EarlyOutPage(
                loader: (_) async => {
                      'records': [event],
                      'total': 1
                    },
                decisionSaver: (value) async {
                  saved = value;
                }))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review'));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(
        find.text(
            'Enter a valid duration and remarks (at least 3 characters).'),
        findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Approved duration (minutes)'), '45');
    await tester.enterText(find.widgetWithText(TextField, 'Remarks / reason'),
        'Approved appointment');
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(saved!['approved_minutes'], 45);
    expect(saved!['employee_id'], 'E1');
    expect(saved!['expected_revision'], '0');
    expect(saved!['fingerprint'], 'f' * 64);
    expect(saved!.containsKey('late_deduction'), false);
    expect(tester.takeException(), isNull);
  });
}
