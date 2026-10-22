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
    },
  );

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
    },
  );

  testWidgets('egg cracks render during the final hatch window',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PenguinIllustration(stage: 'egg', hatching: true),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('employee egg stage hides its age and previews a surprise',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EmployeePenguinPetCard()),
      ),
    );
    await tester.pump();

    expect(find.text('A LITTLE SURPRISE'), findsOneWidget);
    expect(
        find.text('Your surprise is growing. Come back soon!'), findsOneWidget);
    expect(find.textContaining('Day 0'), findsNothing);
    expect(find.text('EGG'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/penguin_habitat.png',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
