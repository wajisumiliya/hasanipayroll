import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/payroll_generation_dialog.dart';

void main() {
  testWidgets(
      'branch selection generates payroll without automatic file selection',
      (tester) async {
    PayrollGenerationChoice? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      selected = await showDialog<PayrollGenerationChoice>(
                          context: context,
                          builder: (_) => PayrollGenerationDialog(
                                  initialMonth: DateTime(2026, 11),
                                  branches: const {
                                    'A': 'ALOR SETAR',
                                    'B': 'AMANJAYA',
                                    'C': 'ASTANA'
                                  },
                                  employeeCounts: const {
                                    'A': 2,
                                    'B': 3,
                                    'C': 0
                                  }));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('AMANJAYA'));
    await tester.tap(find.text('AMANJAYA'));
    await tester.pumpAndSettle();
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('Select Files to Generate'), findsNothing);
    expect(find.textContaining('Export Excel manually from RHB Layout'),
        findsOneWidget);
    final generate = find.byWidgetPredicate((widget) => widget is FilledButton);
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(selected!.month, DateTime(2026, 11));
    expect(selected!.branchIds, {'A'});

    expect(tester.takeException(), isNull);
  });
  testWidgets('no branches selected disables generation', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PayrollGenerationDialog(
            initialMonth: DateTime(2026, 11),
            branches: const {'A': 'ALOR SETAR'},
            employeeCounts: const {'A': 2})));
    final selectAll = find.byType(Checkbox).first;
    await tester.ensureVisible(selectAll);
    await tester.tap(selectAll);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
}
