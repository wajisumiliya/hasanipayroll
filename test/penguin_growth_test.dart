import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/penguin_growth.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';

void main() {
  test('newborn starts small and grows every day until adulthood', () {
    expect(penguinGrowthScale(0), closeTo(.30, .00001));
    expect(penguinGrowthScale(14), greaterThan(.5));
    expect(penguinGrowthScale(14), lessThan(.55));
    expect(penguinGrowthScale(42), closeTo(1, .00001));
    for (var day = 1; day <= 42; day++) {
      expect(penguinGrowthScale(day), greaterThan(penguinGrowthScale(day - 1)));
      expect(
          penguinGrowthScale(day) - penguinGrowthScale(day - 1), lessThan(.02));
    }
    expect(penguinGrowthScale(-10), penguinGrowthScale(0));
    expect(penguinGrowthScale(500), penguinGrowthScale(42));
  });

  testWidgets('rendered penguin grows smoothly as server age advances',
      (tester) async {
    Widget bird(int age, String stage) => MaterialApp(
        home: Center(
            child: PenguinIllustration(stage: stage, daysSinceHatch: age)));
    await tester.pumpWidget(bird(0, 'chick'));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale,
        closeTo(.30, .00001));
    await tester.pumpWidget(bird(7, 'chick'));
    await tester.pump(const Duration(seconds: 1));
    final weekOne =
        tester.widget<AnimatedScale>(find.byType(AnimatedScale).first);
    expect(weekOne.scale, greaterThan(.4));
    expect(weekOne.scale, lessThan(.45));
    expect(weekOne.duration, const Duration(milliseconds: 800));
    await tester.pumpWidget(bird(42, 'adult'));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale,
        closeTo(1, .00001));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
