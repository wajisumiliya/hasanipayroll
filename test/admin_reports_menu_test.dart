import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/admin_reports_menu.dart';

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets('Reports destinations navigate correctly at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final visited = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AdminReportsMenu(onNavigate: visited.add),
            ),
          ),
        ),
      );
      const labels = [
        'Employee Requests',
        'Leave Requests',
        'OT Requests',
        'Daily Reports',
      ];
      expect(find.byType(OutlinedButton), findsNWidgets(4));
      for (final label in labels) {
        await tester.tap(find.text(label));
        await tester.pump();
      }
      expect(visited, [10, 13, 11, 14]);
      expect(tester.takeException(), isNull);
    });
  }
}
