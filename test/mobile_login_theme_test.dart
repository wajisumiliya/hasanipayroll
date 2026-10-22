import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hasani_payroll_portal/screens/login_screen.dart';
import 'package:hasani_payroll_portal/widgets/mystery_egg_teaser.dart';

void main() {
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
              (widget.image as AssetImage).assetName ==
                  'assets/login_arctic/$day.png'),
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
      expect(find.byType(MysteryEggTeaser), findsOneWidget);
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
