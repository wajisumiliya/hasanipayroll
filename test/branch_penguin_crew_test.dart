import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/branch_penguin_crew.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';

void main() {
  testWidgets('branch dashboard displays three animated penguins',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BranchPenguinCrew(branchName: 'ALOR SETAR'),
        ),
      ),
    );

    expect(find.text('THE PENGUIN CREW'), findsOneWidget);
    expect(find.text('ALOR SETAR · Three branch penguins'), findsOneWidget);
    expect(find.byType(PenguinIllustration), findsNWidgets(3));
    expect(find.text('Pip'), findsOneWidget);
    expect(find.text('Poppy'), findsOneWidget);
    expect(find.text('Pebble'), findsOneWidget);
  });
}
