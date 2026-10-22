import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/branch_penguin_crew.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';
import 'package:hasani_payroll_portal/widgets/mystery_egg_teaser.dart';

void main() {
  testWidgets('branch dashboard displays its crew and a mystery teaser',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BranchPenguinCrew(branchName: 'ALOR SETAR'),
        ),
      ),
    );

    expect(find.text('THE PENGUIN CREW'), findsOneWidget);
    expect(find.text('ALOR SETAR · Five branch penguins'), findsOneWidget);
    expect(find.byType(PenguinIllustration), findsNWidgets(6));
    expect(find.byType(MysteryEggTeaser), findsOneWidget);
    expect(
        find.bySemanticsLabel('A little surprise is waiting'), findsOneWidget);
    expect(find.text('Pip'), findsOneWidget);
    expect(find.text('Poppy'), findsOneWidget);
    expect(find.text('Pebble'), findsOneWidget);
    expect(find.text('Nori'), findsOneWidget);
    expect(find.text('Skipper'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PenguinIllustration && widget.action == 'eating',
      ),
      findsOneWidget,
    );
  });
}
