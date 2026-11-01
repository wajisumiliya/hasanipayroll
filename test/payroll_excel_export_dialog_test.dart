import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/payroll_excel_export_dialog.dart';

void main() {
  testWidgets('selected period generates once and prevents duplicate actions',
      (tester) async {
    final done = Completer<bool>();
    var calls = 0;
    DateTime? selected;
    Set<String>? chosen;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showDialog<bool>(
                          context: context,
                          builder: (_) => PayrollExcelExportDialog(
                              initialMonth: DateTime(2026, 11),
                              onGenerate: (month, files) {
                                selected = month;
                                chosen = files;
                                calls++;
                                return done.future;
                              })),
                      child: const Text('Open export'),
                    )))));
    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
    expect(find.text('Generate Payroll Excel Files'), findsOneWidget);
    await tester.ensureVisible(find.text('Generate Selected Files'));
    await tester.tap(find.text('Generate Selected Files'));
    await tester.pump();
    expect(selected, DateTime(2026, 11));
    expect(calls, 1);
    expect(chosen,
        {'Branch Payroll', 'RHB Layout', 'EPF', 'SOCSO', 'EIS', 'HRDF'});
    expect(find.text('Generating...'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton))
            .onPressed,
        isNull);
    done.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(PayrollExcelExportDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed generation stays open with a retryable error',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PayrollExcelExportDialog(
            initialMonth: DateTime(2026, 11),
            onGenerate: (_, files) async => false)));
    await tester.tap(find.text('Generate Selected Files'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Export was not completed. Check the payroll data and try again.'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton))
            .onPressed,
        isNotNull);
  });
}
