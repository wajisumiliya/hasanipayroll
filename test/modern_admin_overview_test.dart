import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/modern_admin_overview.dart';

List<Map<String, dynamic>> overviewPeople() => [
      for (var i = 1; i <= 5; i++)
        {
          'employee_id': 'A$i',
          'name': 'Employee $i',
          'branch_id': 'A',
          'is_active': true
        },
      {'employee_id': 'A6', 'branch_id': 'A', 'is_active': false},
      {'employee_id': 'B1', 'branch_id': 'B', 'is_active': true},
    ];
Map<String, dynamic> overviewActivity() => {
      'attendance': [
        {
          'employee_id': 'A4',
          'branch_id': 'A',
          'check_in': '99:99',
          'status': 'Present'
        },
        {
          'employee_id': 'A1',
          'branch_id': 'A',
          'check_in': '09:00',
          'status': 'Present'
        },
        {
          'employee_id': 'A1',
          'branch_id': 'A',
          'check_in': '09:00',
          'status': 'Present'
        },
        {
          'employee_id': 'A2',
          'branch_id': 'A',
          'check_in': '09:20',
          'status': 'Late'
        },
        {
          'employee_id': 'A3',
          'branch_id': 'A',
          'check_in': '-',
          'status': 'OFF'
        },
        {
          'employee_id': 'B1',
          'branch_id': 'B',
          'check_in': '09:00',
          'status': 'Present'
        },
      ],
      'late': [
        {
          'employee_id': 'A2',
          'name': 'Aina Rahman',
          'branch_id': 'A',
          'arrival_count': 2,
          'break_count': 2,
          'count': 4
        },
        {
          'employee_id': 'B1',
          'name': 'Daniel Tan',
          'branch_id': 'B',
          'arrival_count': 4,
          'break_count': 3,
          'count': 7
        },
        {
          'employee_id': 'X1',
          'name': 'Outside scope',
          'branch_id': 'A',
          'arrival_count': 4,
          'break_count': 3,
          'count': 7
        },
      ],
      'leave': [
        {'employee_id': 'A1', 'branch_id': 'A', 'status': 'pending_admin'},
        {'employee_id': 'A2', 'branch_id': 'A', 'status': 'pending_branch'}
      ],
      'ot': [
        {'employee_id': 'A2', 'branch_id': 'A', 'status': 'pending_admin'}
      ],
      'employee': [
        {'branch_id': 'A', 'status': 'PENDING'},
        {'branch_id': 'B', 'status': 'PENDING'}
      ],
    };
ModernAdminOverview overviewWidget(
        {ValueChanged<int>? navigate,
        VoidCallback? late,
        ValueChanged<DateTime>? month,
        ValueChanged<String?>? branch,
        Map<String, dynamic>? data,
        Widget? tools}) =>
    ModernAdminOverview(
      month: DateTime(2026, 10),
      branch: null,
      branches: const {'A': 'Alor Setar', 'B': 'Astana'},
      employees: overviewPeople(),
      gross: 10000,
      deductions: 1000,
      net: 9000,
      activity: Future.value(data ?? overviewActivity()),
      onMonth: month ?? (_) {},
      onBranch: branch ?? (_) {},
      onNavigate: navigate ?? (_) {},
      onRefresh: () async {},
      onLateReport: late ?? () {},
      onGross: () {},
      onNet: () {},
      birthdays: const [],
      anniversaries: const [],
      onCelebrate: (_, __) {},
      breakdown: const Text('Existing payroll details'),
      reports: AdminDashboardReportCards(
          itemBuilder: (width, report) => IvoryAdminReportCard(
              width: width,
              title: report,
              icon: Icons.description_outlined,
              value: const {
                'Payroll': 'RM 9,000.00',
                'EPF': 'RM 2,300.00',
                'SOCSO': 'RM 120.00',
                'EIS': 'RM 50.00',
                'HRDF': '1% levy',
                'Payroll Summary': 'RM 10,000.00'
              }[report]!,
              caption: report == 'HRDF'
                  ? 'Eligibility & levy report'
                  : 'Selected month',
              onTap: () {})),
      tools: tools ?? const Text('Existing import and notification tools'),
    );
void main() {
  test(
      'live counts deduplicate check-ins, exclude off days, respect branch and admin scope',
      () {
    final m = AdminOverviewMetrics(
        employees: overviewPeople(), activity: overviewActivity(), branch: 'a');
    expect(m.people.length, 6);
    expect(m.activeIds.length, 5);
    expect(m.present, 1);
    expect(m.lateIds!.length, 1);
    expect(m.offIds!.length, 1);
    expect(m.notChecked, 2);
    expect(m.lateRows!.single['name'], 'Aina Rahman');
    expect(m.pending('leave'), 1);
    expect(m.pending('ot'), 1);
    expect(m.pending('employee'), 1);
    final scoped = AdminOverviewMetrics(
        employees:
            overviewPeople().where((e) => e['branch_id'] == 'A').toList(),
        activity: overviewActivity());
    expect(scoped.lateRows!.length, 1);
    expect(scoped.checkedIn, {'A1', 'A2'});
  });
  test(
      'failed activity is unavailable, rather than a false zero; local requests are scoped',
      () {
    final m = AdminOverviewMetrics(employees: overviewPeople(), activity: {});
    expect(m.present, isNull);
    expect(m.lateRows, isNull);
    expect(m.pending('leave'), isNull);
    final scoped = AdminOverviewMetrics(employees: overviewPeople(), activity: {
      'staff_scope': 'local',
      'employee': [
        {'status': 'PENDING', 'address': 'FRN worker'},
        {'status': 'PENDING', 'address': 'Local'}
      ]
    });
    expect(scoped.pending('employee'), 1);
  });
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets(
        'approved overview fits width $width and retains report and payroll actions',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final routes = <int>[];
      var late = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: overviewWidget(navigate: routes.add, late: () => late++))));
      await tester.pumpAndSettle();
      expect(find.text('Total employees'), findsOneWidget);
      expect(find.text('Active employees'), findsOneWidget);
      expect(find.text('RM 9,000.00'), findsWidgets);
      final payrollAction = width < 650
          ? find.byTooltip('View payroll')
          : find.text('View payroll');
      await tester.ensureVisible(payrollAction);
      await tester.tap(payrollAction);
      expect(routes.last, 2);
      final lateAction = width < 650
          ? find.byTooltip('View report')
          : find.text('View report');
      await tester.ensureVisible(lateAction);
      await tester.tap(lateAction);
      expect(late, 1);
      expect(find.text('Outside scope'), findsNothing);
      expect(find.textContaining('Incomplete current'), findsNothing);
      await tester.ensureVisible(find.text('Detailed payroll breakdown'));
      await tester.tap(find.text('Detailed payroll breakdown'));
      await tester.pumpAndSettle();
      expect(find.text('Existing payroll details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('month and branch selectors dispatch real filter changes',
      (tester) async {
    DateTime? month;
    String? branch;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: overviewWidget(
                month: (v) => month = v, branch: (v) => branch = v))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('October 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('September').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(month, DateTime(2026, 9));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Astana').last);
    await tester.pumpAndSettle();
    expect(branch, 'B');
  });
  testWidgets(
      'all six separate payroll reports stay visible and clickable on mobile',
      (tester) async {
    final selected = <String>[];
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: AdminDashboardReportCards(
                    itemBuilder: (width, report) => SizedBox(
                        width: width,
                        child: OutlinedButton(
                            onPressed: () => selected.add(report),
                            child: Text(report))))))));
    for (final report in [
      'Payroll',
      'EPF',
      'SOCSO',
      'EIS',
      'HRDF',
      'Payroll Summary'
    ]) {
      expect(find.text(report), findsOneWidget);
      await tester.tap(find.text(report));
    }
    expect(selected,
        ['Payroll', 'EPF', 'SOCSO', 'EIS', 'HRDF', 'Payroll Summary']);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Ivory library uses three columns and keeps all report actions independent',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminDashboardReportCards(
                itemBuilder: (width, report) => IvoryAdminReportCard(
                    width: width,
                    title: report,
                    icon: Icons.description_outlined,
                    value: 'RM 12,345.67',
                    caption: 'Selected month',
                    onTap: () => opened.add(report))))));
    final first = tester.getTopLeft(find.text('Payroll'));
    expect(tester.getTopLeft(find.text('SOCSO')).dy, first.dy);
    expect(tester.getTopLeft(find.text('EIS')).dy, greaterThan(first.dy));
    expect(tester.getTopLeft(find.text('Payroll Summary')).dy,
        tester.getTopLeft(find.text('EIS')).dy);
    for (final title in AdminDashboardReportCards.reports) {
      await tester.tap(find.text(title));
    }
    expect(opened, AdminDashboardReportCards.reports);
    expect(tester.takeException(), isNull);
  });
}
