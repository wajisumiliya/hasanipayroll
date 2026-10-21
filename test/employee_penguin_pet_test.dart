import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';

void main() {
  testWidgets(
      'original penguin illustration renders every growth and care state',
      (tester) async {
    for (final stage in ['egg', 'chick', 'juvenile', 'adult']) {
      for (final action in ['idle', 'eating', 'playing', 'sleeping']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PenguinIllustration(stage: stage, action: action),
            ),
          ),
        );
        expect(find.byType(CustomPaint), findsWidgets);
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  });

  testWidgets(
      'penguin remains available with reduced motion and supports a nap tap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: PenguinIllustration(
              stage: 'adult',
              action: 'sleeping',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.tap(find.byType(GestureDetector).last);
    expect(tapped, isTrue);
  });
}
