import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/increment_report_button.dart';

void main() {
  for (final comparison in [false, true]) {
    testWidgets(
        'increment $comparison report prints directly and blocks duplicate clicks',
        (tester) async {
      final load = Completer<Uint8List>();
      var loads = 0, prints = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: IncrementReportButton(
        month: DateTime(2026, 10),
        branch: 'A',
        comparison: comparison,
        pdfLoader: () {
          loads++;
          return load.future;
        },
        printAction: (bytes) async {
          prints++;
          expect(bytes, [1, 2, 3]);
        },
      ))));
      await tester.tap(find
          .text(comparison ? 'Payroll Comparison PDF' : 'Eligible List PDF'));
      await tester.pump();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Preparing PDF…'), findsOneWidget);
      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull);
      load.complete(Uint8List.fromList([1, 2, 3]));
      await tester.pumpAndSettle();
      expect(loads, 1);
      expect(prints, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed increment export shows an error and allows retry',
      (tester) async {
    var attempts = 0, prints = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: IncrementReportButton(
      month: DateTime(2026, 10),
      branch: null,
      comparison: false,
      pdfLoader: () async {
        attempts++;
        throw StateError('Unavailable');
      },
      printAction: (_) async {
        prints++;
      },
    ))));
    await tester.tap(find.text('Eligible List PDF'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to print increment report'),
        findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull);
    expect(attempts, 1);
    expect(prints, 0);
  });
}
