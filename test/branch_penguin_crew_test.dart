import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/branch_penguin_crew.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';
import 'package:hasani_payroll_portal/widgets/mystery_egg_teaser.dart';

void main() {
  testWidgets('branch dashboard keeps every crew member a mystery',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BranchPenguinCrew(branchName: 'ALOR SETAR'),
        ),
      ),
    );

    expect(find.text('A LITTLE SURPRISE'), findsOneWidget);
    expect(
        find.text('ALOR SETAR · Something special is growing'), findsOneWidget);
    expect(find.byType(PenguinIllustration), findsNWidgets(6));
    expect(find.byType(MysteryEggTeaser), findsNWidgets(6));
    expect(find.bySemanticsLabel('A little surprise is waiting'),
        findsNWidgets(6));
    for (final name in ['Pip', 'Poppy', 'Pebble', 'Nori', 'Skipper']) {
      expect(find.text(name), findsNothing);
    }
    for (final label in [
      'THE PENGUIN CREW',
      'Grown-up',
      'Little one',
      'Youngster'
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PenguinIllustration && widget.stage != 'egg',
      ),
      findsNothing,
    );
  });
}
