import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hasani_payroll_portal/screens/login_screen.dart';
import 'package:hasani_payroll_portal/services/login_habitat_scene.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/widgets/login_penguin_walker.dart';
import 'package:hasani_payroll_portal/widgets/portal_penguin_companion.dart';

void main() {
  testWidgets(
      'desktop and mobile login have a silent companion and usable fields',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    for (final size in [const Size(1600, 830), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      final controller = MysteryEggHatchController(
          load: () async => {
                'hatchAt': '2026-10-23T07:39:11Z',
                'serverNow': '2026-10-24T03:30:00Z',
                'stage': 'chick',
              });
      await tester.pumpWidget(MaterialApp(
          home: LoginScreen(
              hatchController: controller, showThemePreview: false)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(LoginPenguinWalker), findsNothing);
      expect(find.byType(PortalPenguinCompanion), findsOneWidget);
      await tester.ensureVisible(find.text('Feed'));
      await tester.tap(find.text('Feed'));
      await tester.pump();
      expect(find.text('Yum! Thank you for the fish!'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
      final username = find.byWidgetPredicate((w) =>
          w is TextField && w.decoration?.hintText == 'Username / Employee ID');
      final password =
          find.byWidgetPredicate((w) => w is TextField && w.obscureText);
      await tester.enterText(username, 'test-user');
      await tester.enterText(password, 'private-test-value');
      await tester.pump();
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('rapid scene changes and compact adult rendering dispose safely',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MysteryEggHatchController(
        load: () async => {
              'hatchAt': '2026-09-01T00:00:00Z',
              'serverNow': '2026-10-24T03:30:00Z',
              'stage': 'chick',
            });
    Widget app(LoginHabitatScene scene) => MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 354,
                height: 190,
                child: LoginPenguinWalker(
                    controller: controller, scene: scene, compact: true))));
    await tester.pumpWidget(app(const LoginHabitatScene(6, 'morning')));
    await tester.pump();
    await tester.pumpWidget(app(const LoginHabitatScene(6, 'evening')));
    await tester.pumpWidget(app(const LoginHabitatScene(7, 'night')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Your penguin is resting.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
