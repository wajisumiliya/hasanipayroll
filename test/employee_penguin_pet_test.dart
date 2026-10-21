import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll/widgets/employee_penguin_pet_card.dart';

void main() {
  testWidgets('penguin growth illustration renders at every stage', (tester) async {
    for (final stage in ['egg', 'chick', 'juvenile', 'adult']) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PenguinIllustration(stage: stage)),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
}
