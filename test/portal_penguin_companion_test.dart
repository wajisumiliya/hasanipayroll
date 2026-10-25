import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/widgets/portal_penguin_companion.dart';
import 'package:hasani_payroll_portal/widgets/penguin_companion_reaction.dart';
import 'package:hasani_payroll_portal/widgets/branch_penguin_crew.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';
import 'package:hasani_payroll_portal/widgets/mystery_egg_teaser.dart';

void main() {
  testWidgets('branch shows only Pingu with the same public login background',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var now = '2026-10-25T03:59:59Z';
    final branch = MysteryEggHatchController(
        load: () async => {
              'stage': 'chick',
              'hatchAt': '2026-10-23T08:39:11Z',
              'serverNow': now
            });
    final login = MysteryEggHatchController(
        load: () async => {
              'stage': 'chick',
              'hatchAt': '2026-10-23T07:39:11Z',
              'serverNow': now
            });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PortalPenguinCompanion(
                    controller: branch,
                    sceneController: login,
                    matchLoginScene: true,
                    title: 'LITTLE PINGU')))));
    await tester.pump();
    await tester.pump();
    expect(find.byType(EmployeePenguinPetCard), findsOneWidget);
    expect(find.byType(BranchPenguinCrew), findsNothing);
    expect(find.text('LITTLE PINGU'), findsOneWidget);
    Finder scene(String period) => find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName ==
            'assets/login_habitats/sunday_$period.png');
    expect(scene('morning'), findsOneWidget);
    await tester.ensureVisible(find.text('Rest'));
    await tester.tap(find.text('Rest'));
    await tester.pump();
    now = '2026-10-25T04:00:00Z';
    await login.refresh();
    await tester.pump();
    await tester.pump();
    expect(scene('afternoon'), findsOneWidget);
    expect(find.text('Wake'), findsOneWidget);
    final actor = tester.widget<Positioned>(
        find.byWidgetPredicate((w) => w is Positioned && w.width == 280).first);
    expect(actor.top!, greaterThan(0),
        reason:
            'Pingu must not be cropped off the ice arch ledge on a wide branch card');
    expect(find.byType(MysteryEggTeaser), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    branch.dispose();
    login.dispose();
  });

  testWidgets('a sealed branch shows one egg rather than the old family',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final clock = MysteryEggHatchController(
        load: () async => {
              'stage': 'egg',
              'hatchAt': '2026-10-26T07:39:11Z',
              'serverNow': '2026-10-25T02:00:00Z'
            });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PortalPenguinCompanion(
                    controller: clock,
                    sceneController: clock,
                    matchLoginScene: true,
                    title: 'LITTLE PINGU')))));
    await tester.pump();
    await tester.pump();
    expect(find.byType(BranchPenguinCrew), findsNothing);
    expect(find.byType(PenguinIllustration), findsOneWidget);
    expect(
        tester
            .widget<PenguinIllustration>(find.byType(PenguinIllustration))
            .stage,
        'egg');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
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
