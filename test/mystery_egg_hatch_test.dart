import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';
import 'package:hasani_payroll_portal/widgets/mystery_egg_teaser.dart';

Map<String, dynamic> snapshot(DateTime now, DateTime hatchAt) => {
      'serverNow': now.toIso8601String(),
      'hatchAt': hatchAt.toIso8601String(),
      'stage': now.isBefore(hatchAt) ? 'egg' : 'chick',
    };

void main() {
  testWidgets(
      'golden egg cracks in final five minutes and hatches without a reload',
      (tester) async {
    final start = DateTime.utc(2026, 10, 22);
    var now = start;
    final hatchAt = start.add(const Duration(minutes: 6));
    final controller =
        MysteryEggHatchController(load: () async => snapshot(now, hatchAt));
    await tester.pumpWidget(MaterialApp(
        home: Center(child: MysteryEggTeaser(controller: controller))));
    await tester.pump();
    expect(controller.hatching, isFalse);
    expect(find.byType(PenguinIllustration), findsNothing);
    await tester.tap(find.byType(MysteryEggTeaser));
    expect(controller.stage, 'egg');

    now = start.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(controller.hatching, isTrue);
    expect(find.bySemanticsLabel('Something is stirring inside the golden egg'),
        findsOneWidget);
    expect(find.byType(PenguinIllustration), findsNothing);

    now = start.add(const Duration(minutes: 5));
    await tester.pump(const Duration(minutes: 4));
    await tester.pump();
    expect(controller.stage, 'egg');
    now = hatchAt;
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PenguinIllustration), findsOneWidget);
    expect(
        tester
            .widget<PenguinIllustration>(find.byType(PenguinIllustration))
            .stage,
        'chick');
    expect(find.bySemanticsLabel('Surprise! Your penguin has hatched'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('six eggs share one request and keep their hatch on reopening',
      (tester) async {
    final hatchAt = DateTime.utc(2026, 10, 25);
    var calls = 0;
    final controller = MysteryEggHatchController(load: () async {
      calls++;
      return snapshot(hatchAt, hatchAt);
    });
    Widget scene() => MaterialApp(
            home: Wrap(children: [
          for (var i = 0; i < 6; i++)
            MysteryEggTeaser(size: 90, controller: controller),
        ]));
    await tester.pumpWidget(scene());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    expect(find.byType(PenguinIllustration), findsNWidgets(6));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(scene());
    await tester.pump();
    expect(calls, 2);
    expect(find.byType(PenguinIllustration), findsNWidgets(6));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('outage at hatch keeps egg sealed until server confirms recovery',
      (tester) async {
    final start = DateTime.utc(2026, 10, 22);
    final hatchAt = start.add(const Duration(seconds: 2));
    var fail = false;
    var now = start;
    final controller = MysteryEggHatchController(load: () async {
      if (fail) throw StateError('offline');
      return snapshot(now, hatchAt);
    });
    await tester.pumpWidget(MaterialApp(
        home: Center(child: MysteryEggTeaser(controller: controller))));
    await tester.pump();
    fail = true;
    now = hatchAt;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byType(PenguinIllustration), findsNothing);
    fail = false;
    await controller.refresh();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PenguinIllustration), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('malformed premature reveal cannot expose a penguin',
      (tester) async {
    final now = DateTime.utc(2026, 10, 22);
    final controller = MysteryEggHatchController(
        load: () async => {
              ...snapshot(now, now.add(const Duration(days: 3))),
              'stage': 'chick',
            });
    await tester.pumpWidget(MaterialApp(
        home: Center(child: MysteryEggTeaser(controller: controller))));
    await tester.pump();
    expect(find.byType(PenguinIllustration), findsNothing);
    expect(controller.stage, 'egg');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
