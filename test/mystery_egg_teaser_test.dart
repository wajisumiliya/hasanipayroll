import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';
import 'package:hasani_payroll_portal/widgets/mystery_egg_teaser.dart';

void main() {
  testWidgets('unavailable hatch service keeps the golden surprise sealed',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: MysteryEggTeaser(size: 200)),
      ),
    ));
    expect(
        find.bySemanticsLabel('A little surprise is waiting'), findsOneWidget);
    expect(find.byType(PenguinIllustration), findsNothing);
    await tester.tap(find.byType(MysteryEggTeaser));
    await tester.pump(const Duration(days: 7));
    expect(find.byType(PenguinIllustration), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('golden surprise respects reduced motion', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Center(child: MysteryEggTeaser()),
      ),
    ));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
