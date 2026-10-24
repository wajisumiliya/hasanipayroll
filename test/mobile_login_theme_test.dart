import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/screens/login_screen.dart';
import 'package:hasani_payroll_portal/widgets/mystery_egg_teaser.dart';

void main() {
  for (final width in [390.0, 1600.0]) {
    testWidgets(
        'login at width $width follows reveal and night without reopening',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final hatch = DateTime.parse('2026-10-23T07:39:11Z');
      var now = hatch.subtract(const Duration(seconds: 5));
      final controller = MysteryEggHatchController(
          load: () async => {
                'hatchAt': hatch.toIso8601String(),
                'serverNow': now.toIso8601String(),
                'stage': now.isBefore(hatch) ? 'egg' : 'chick',
              });
      Finder image(String asset) => find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == asset);
      await tester.pumpWidget(
          MaterialApp(home: LoginScreen(hatchController: controller)));
      await tester.pump(const Duration(seconds: 1));
      expect(
          image('assets/login_habitats/friday_afternoon.png'), findsOneWidget);
      now = hatch;
      await controller.refresh();
      await tester.pump();
      expect(image('assets/login_habitats/friday_evening.png'), findsOneWidget);
      now = DateTime.parse('2026-10-23T12:00:00Z');
      await controller.refresh();
      await tester.pump();
      expect(image('assets/login_habitats/friday_night.png'), findsOneWidget);
      now = DateTime.parse('2026-10-24T02:00:00Z');
      await controller.refresh();
      await tester.pump();
      expect(
          image('assets/login_habitats/saturday_morning.png'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets('portrait login cycles seven scenes and keeps logo above fields',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump(const Duration(seconds: 2));

    const days = [
      ('Mon', 'monday'),
      ('Tue', 'tuesday'),
      ('Wed', 'wednesday'),
      ('Thu', 'thursday'),
      ('Fri', 'friday'),
      ('Sat', 'saturday'),
      ('Sun', 'sunday'),
    ];
    for (final (label, day) in days) {
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      expect(
          find.byWidgetPredicate((widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage)
                  .assetName
                  .startsWith('assets/login_habitats/${day}_')),
          findsOneWidget);
      final logo = find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is ResizeImage &&
          ((widget.image as ResizeImage).imageProvider as AssetImage)
                  .assetName ==
              'assets/hasani_books_logo.jpg');
      expect(logo, findsOneWidget);
      expect(tester.getCenter(logo).dy,
          lessThan(tester.getCenter(find.byType(TextField).first).dy));
      expect(tester.getCenter(logo).dx,
          closeTo(tester.getCenter(find.byType(TextField).first).dx, 1));
      expect(find.byType(MysteryEggTeaser), findsNothing);
      expect(tester.takeException(), isNull);
    }
    // The keyboard must leave the form scrollable instead of hiding sign in.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.ensureVisible(find.text('SIGN IN'));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
