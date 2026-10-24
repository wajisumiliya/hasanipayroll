import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/services/penguin_family_scene.dart';
import 'package:hasani_payroll_portal/widgets/branch_penguin_crew.dart';
import 'package:hasani_payroll_portal/widgets/mystery_egg_teaser.dart';

MysteryEggHatchController clock(String stage) => MysteryEggHatchController(
    load: () async => {
          'hatchAt': '2026-10-23T08:39:11Z',
          'serverNow':
              stage == 'egg' ? '2026-10-23T07:39:11Z' : '2026-10-23T08:39:11Z',
          'stage': stage
        });

void main() {
  test('four family members stay on their terrain throughout the routine', () {
    final activities = <FamilyActivity>{};
    for (var tick = 0; tick < 1600; tick++) {
      final family = penguinFamilyAt(tick / 10);
      expect(family, hasLength(4));
      expect(family.where((p) => p.scale > .9), hasLength(2));
      expect(family.where((p) => p.baby), hasLength(1));
      for (final p in family) {
        activities.add(p.activity);
        expect(p.position.dx, inInclusiveRange(.1, .9));
        expect(p.position.dy, inInclusiveRange(.7, .95));
        if (p.activity == FamilyActivity.swimming) {
          expect(p.scale, greaterThan(.9));
          expect(p.position.dx, greaterThanOrEqualTo(.59));
        } else if (p.baby || p.scale < .9) {
          expect(p.position.dx, lessThan(.70));
          expect(p.position.dy, greaterThan(.8));
        }
      }
      final next = penguinFamilyAt(tick / 10 + .001);
      for (var i = 0; i < 4; i++) {
        expect(
            (family[i].position - next[i].position).distance, lessThan(.001));
      }
    }
    expect(activities, containsAll(FamilyActivity.values));
  });

  testWidgets('four eggs use the branch clock before hatch', (tester) async {
    final controller = clock('egg');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BranchPenguinCrew(
                branchName: 'ALOR SETAR', controller: controller))));
    await tester.pump();
    expect(find.text('A LITTLE SURPRISE IS GROWING.'), findsOneWidget);
    expect(find.byType(MysteryEggTeaser), findsNWidgets(4));
    expect(find.textContaining('Reveal in'), findsNWidgets(4));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
      'hatched family replaces eggs and fits mobile with reduced motion',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    final controller = clock('chick');
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
                body: BranchPenguinCrew(
                    branchName: 'SP-EDAR', controller: controller)))));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    expect(find.byType(MysteryEggTeaser), findsNothing);
    expect(find.text('A LITTLE FAMILY. A LIVING WORLD.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Penguin family: two adults')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(find.text('Feed fish'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('1 fish eaten · Thank you!'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('Feed fish is exclusive until the meal and return are complete',
      (tester) async {
    final controller = clock('chick');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BranchPenguinCrew(
                branchName: 'SP-EDAR', controller: controller))));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester.tap(find.text('Feed fish'));
    await tester.pump();
    expect(find.text('Feeding…'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    for (var frame = 0; frame < 250; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('1 fish eaten · Thank you!'), findsOneWidget);
    expect(find.text('Feed fish'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
  testWidgets('feeding remains available after adults exchange duties',
      (tester) async {
    final controller = clock('chick');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BranchPenguinCrew(
                branchName: 'SP-EDAR', controller: controller))));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    for (var frame = 0; frame < 900; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Feed fish'));
    await tester.pump();
    expect(find.text('It noticed the fish'), findsOneWidget);
    for (var frame = 0; frame < 250; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('1 fish eaten · Thank you!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
