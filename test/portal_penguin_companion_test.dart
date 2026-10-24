import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/widgets/portal_penguin_companion.dart';
import 'package:hasani_payroll_portal/widgets/penguin_companion_reaction.dart';

void main() {
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
