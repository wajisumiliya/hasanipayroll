import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/widgets/portal_penguin_companion.dart';
import 'package:hasani_payroll_portal/widgets/penguin_companion_reaction.dart';
import 'package:hasani_payroll_portal/widgets/branch_penguin_crew.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';
import 'package:hasani_payroll_portal/widgets/mystery_egg_teaser.dart';

void main() {
  testWidgets('joined mobile habitat fits all sealed eggs before confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final clock = MysteryEggHatchController(
        load: () async => {
              'stage': 'egg',
              'hatchAt': '2026-10-25T07:39:11Z',
              'serverNow': '2026-10-24T09:42:00Z'
            });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PortalPenguinCompanion(
                    controller: clock,
                    familyBranchName: 'SP-EDAR',
                    title: 'OUR BRANCH FAMILY')))));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MysteryEggTeaser), findsNWidgets(4));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    clock.dispose();
  });

  testWidgets('branch family and Pingu share one habitat and one care dock',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final clock = MysteryEggHatchController(
        load: () async => {
              'stage': 'chick',
              'hatchAt': '2026-10-23T07:39:11Z',
              'serverNow': '2026-10-24T09:42:00Z'
            });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PortalPenguinCompanion(
                    controller: clock,
                    familyBranchName: 'SP-EDAR',
                    title: 'OUR BRANCH FAMILY')))));
    await tester.pump();
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();
    expect(find.byType(EmployeePenguinPetCard), findsOneWidget);
    expect(find.byType(BranchPenguinCrew), findsOneWidget);
    expect(
        tester
            .widget<BranchPenguinCrew>(find.byType(BranchPenguinCrew))
            .companion,
        isNotNull);
    expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/penguins/family/coast.png'),
        findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Feed fish'), findsNothing,
        reason: 'A merged habitat has one feeding control');
    await tester.ensureVisible(find.text('Feed'));
    await tester.tap(find.text('Feed'));
    await tester.pump();
    expect(find.text('It noticed the fish'), findsOneWidget);
    await tester.ensureVisible(find.text('Rest'));
    await tester.tap(find.text('Rest'));
    await tester.pump();
    expect(find.text('Wake'), findsOneWidget);
    expect(find.byType(BranchPenguinCrew), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    clock.dispose();
  });

  testWidgets(
      'public companion waits for server confirmation and uses page-local care',
      (tester) async {
    var confirmed = false, calls = 0;
    final clock = MysteryEggHatchController(load: () async {
      calls++;
      return {
        'hatchAt': '2026-10-24T04:00:00Z',
        'serverNow': '2026-10-24T04:01:00Z',
        'stage': confirmed ? 'chick' : 'egg',
      };
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PortalPenguinCompanion(
                    controller: clock, compact: true)))));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Feed'));
    await tester.pump();
    expect(find.byType(PenguinCompanionReaction), findsNothing,
        reason: 'Device time cannot unseal the egg');
    confirmed = true;
    await clock.refresh();
    await tester.pump();
    await tester.pump();
    for (final label in ['Feed', 'Play', 'Pet', 'Rest']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(find.text('Wake'), findsOneWidget);
    expect(find.textContaining('Daily care:'), findsNothing);
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(calls, 2,
        reason:
            'Only initial public metadata and explicit confirmation refresh');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    clock.dispose();
  });
}
