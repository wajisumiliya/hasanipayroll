import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/attendance_status_report_button.dart';

void main() {
  for (final status in ['MC', 'UNPAID']) {
    testWidgets('$status prints directly with no report dialog',
        (tester) async {
      final load = Completer<Uint8List>();
      var prints = 0, loads = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: AttendanceStatusReportButton(
                  month: DateTime(2026, 10),
                  branch: null,
                  status: status,
                  employeeIds: const ['E1'],
                  pdfLoader: () {
                    loads++;
                    return load.future;
                  },
                  printAction: (bytes) async {
                    prints++;
                    expect(bytes, [1, 2, 3]);
                  }))));
      await tester.tap(find.text(status == 'MC' ? 'MC Print' : 'Unpaid Print'));
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
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
