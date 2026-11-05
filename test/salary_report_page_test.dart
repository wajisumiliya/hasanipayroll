import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/salary_report_page.dart';

void main() {
  Map<String, dynamic> report({bool empty = false}) => {
        'start_year': 2025,
        'months': [
          for (var i = 0; i < 12; i++) {'label': 'Month $i'}
        ],
        'note': 'EPF, EIS and SOCSO excluded',
        'branch_note': 'Saved payroll branch',
        'branches': empty
            ? []
            : [
                for (final id in ['A', 'B'])
                  {
                    'id': id,
                    'name': 'Branch $id',
                    'rows': [
                      {
                        'employee_id': 'E$id',
                        'name': 'Employee $id',
                        'values': [2200, ...List<double?>.filled(11, null)],
                      }
                    ],
                    'totals': [2200, ...List<double>.filled(11, 0)],
                  }
              ],
      };
  void screen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<Uint8List> noExport(int year, String format, String? branch) async =>
      throw StateError('Export not requested');

  testWidgets(
      'new report page shows branch tables and separate PDF/Excel actions',
      (tester) async {
    screen(tester);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SalaryReportPage(
      load: (year) async {
        expect(year, 2025);
        return report();
      },
      export: noExport,
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Salary Report'), findsOneWidget);
    expect(find.text('Jul 2025 - Jun 2026'), findsOneWidget);
    expect(find.text('Employee A'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);
    expect(find.text('Print / Save PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'empty results and loading failures disable downloads and allow retry',
      (tester) async {
    screen(tester);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SalaryReportPage(
      load: (_) async => report(empty: true),
      export: noExport,
    ))));
    await tester.pumpAndSettle();
    expect(find.text('No eligible saved payroll records in this period.'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Export Excel'))
            .onPressed,
        isNull);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SalaryReportPage(
      key: const ValueKey('failed'),
      load: (_) async => throw StateError('Payroll unavailable'),
      export: noExport,
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Payroll unavailable'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Refresh'))
            .onPressed,
        isNotNull);
  });
  testWidgets(
      'export uses the selected branch and shows errors without discarding report',
      (tester) async {
    screen(tester);
    int? exportedYear;
    String? exportedFormat, exportedBranch;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SalaryReportPage(
      load: (_) async => report(),
      export: (year, format, branch) async {
        exportedYear = year;
        exportedFormat = format;
        exportedBranch = branch;
        throw StateError('Export unavailable');
      },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Branch B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Excel'));
    await tester.pumpAndSettle();
    expect(exportedYear, 2025);
    expect(exportedFormat, 'xlsx');
    expect(exportedBranch, 'B');
    expect(find.textContaining('Export unavailable'), findsOneWidget);
    expect(find.text('Employee B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
