import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/penguin_growth.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';
import 'package:hasani_payroll_portal/widgets/portal_penguin_companion.dart';

void main() {
  testWidgets(
      'public daily growth preserves resting state instead of recreating the companion',
      (tester) async {
    final clock = MysteryEggHatchController(
        load: () async => {
              'hatchAt': '2026-10-23T07:39:11Z',
              'serverNow': '2026-10-24T07:39:10Z',
              'stage': 'chick'
            });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PortalPenguinCompanion(
                    controller: clock, compact: true)))));
    await tester.pump();
    await tester.pump();
    final before = tester.state(find.byType(EmployeePenguinPetCard));
    await tester.ensureVisible(find.text('Rest'));
    await tester.tap(find.text('Rest'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(tester.state(find.byType(EmployeePenguinPetCard)), same(before));
    expect(find.text('Wake'), findsOneWidget);
    expect(find.text('Pingu • Day 1 • CHICK'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    clock.dispose();
  });

  testWidgets(
      'confirmed age advances daily at hatch anniversary through adult size',
      (tester) async {
    final hatch = DateTime.utc(2026, 10, 23, 7, 39, 11);
    final clock = PenguinGrowthClock();
    clock.update(
        hatchAt: hatch,
        serverNow:
            hatch.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
        hatched: true);
    expect(clock.daysSinceHatch, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(clock.daysSinceHatch, 1);
    await tester.pump(const Duration(days: 11));
    expect(clock.daysSinceHatch, 12);
    expect(clock.stage, 'juvenile');
    await tester.pump(const Duration(days: 30));
    expect(clock.daysSinceHatch, 42);
    expect(clock.stage, 'adult');
    expect(penguinGrowthScale(clock.daysSinceHatch), 1);
    await tester.pump(const Duration(days: 10));
    expect(clock.daysSinceHatch, 52);
    expect(penguinGrowthScale(clock.daysSinceHatch), 1);
    clock.dispose();
  });
  testWidgets(
      'an unconfirmed egg cannot grow; stale snapshots cannot shrink a confirmed pet',
      (tester) async {
    final hatch = DateTime.utc(2026, 10, 23);
    final clock = PenguinGrowthClock();
    clock.update(
        hatchAt: hatch,
        serverNow: hatch.add(const Duration(days: 3)),
        hatched: false);
    await tester.pump(const Duration(days: 50));
    expect(clock.stage, 'egg');
    expect(clock.daysSinceHatch, 0);
    clock.update(
        hatchAt: hatch,
        serverNow: hatch.add(const Duration(days: 42)),
        hatched: true);
    clock.update(
        hatchAt: hatch,
        serverNow: hatch.add(const Duration(days: 1)),
        hatched: true);
    expect(clock.daysSinceHatch, 42);
    expect(clock.stage, 'adult');
    clock.update(
        hatchAt: hatch.add(const Duration(days: 41)),
        serverNow: hatch.add(const Duration(days: 41, hours: 1)),
        hatched: true);
    expect(clock.daysSinceHatch, 0);
    expect(clock.stage, 'chick');
    clock.dispose();
  });
  testWidgets(
      'login and branch clocks grow on the day boundary during an outage',
      (tester) async {
    for (final scope in ['login', 'branch']) {
      var failed = false;
      final clock = MysteryEggHatchController(load: () async {
        if (failed) throw StateError('offline');
        return {
          'hatchAt': '2026-10-23T07:39:11Z',
          'serverNow': '2026-10-24T07:39:10Z',
          'stage': 'chick'
        };
      });
      clock.attach();
      await tester.pump();
      expect(clock.daysSinceHatch, 0, reason: scope);
      failed = true;
      await clock.refresh();
      await tester.pump(const Duration(seconds: 2));
      expect(clock.daysSinceHatch, 1, reason: scope);
      expect(clock.stage, 'chick');
      clock.detach();
      clock.dispose();
    }
  });
  testWidgets(
      'employee grows while open even if its daily refresh fails, and catches up on resume',
      (tester) async {
    var requests = 0;
    var resumed = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        SingleChildScrollView(
            child: EmployeePenguinPetCard(request: (kind) async {
      requests++;
      if (requests > 1 && !resumed) throw StateError('offline');
      return {
        'pet': {
          'stage': 'chick',
          'ageDays': resumed ? 11 : 3,
          'nickname': 'Pingu',
          'hatchAt': '2026-10-23T07:39:11Z',
          'serverNow':
              resumed ? '2026-10-31T07:39:11Z' : '2026-10-24T07:39:10Z',
          'fedToday': false,
          'playedToday': false
        }
      };
    })))));
    await tester.pump();
    expect(find.text('Pingu • Day 0 • CHICK'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Pingu • Day 1 • CHICK'), findsOneWidget);
    await tester.pump(const Duration(days: 1));
    await tester.pump();
    expect(find.text('Pingu • Day 2 • CHICK'), findsOneWidget);
    resumed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text('Pingu • Day 8 • CHICK'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
