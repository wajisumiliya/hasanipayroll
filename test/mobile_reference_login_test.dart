import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hasani_payroll_portal/widgets/mobile_reference_login.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(360, 800),
    const Size(430, 932)
  ]) {
    testWidgets('approved mobile composition and controls at ${size.width}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final username = TextEditingController(),
          password = TextEditingController();
      final capture = GlobalKey();
      var signIns = 0, recoveries = 0;
      var obscure = true;
      await tester.pumpWidget(MaterialApp(
          home: StatefulBuilder(
              builder: (context, update) => RepaintBoundary(
                  key: capture,
                  child: MobileReferenceLogin(
                      usernameController: username,
                      passwordController: password,
                      obscurePassword: obscure,
                      loading: false,
                      onTogglePassword: () => update(() => obscure = !obscure),
                      onSignIn: () => signIns++,
                      onForgotPassword: () => recoveries++)))));
      await tester.runAsync(() async {
        final context = capture.currentContext!;
        await precacheImage(
            const AssetImage('assets/mobile_login_reference.png'), context);
        final font = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await font.load();
      });
      await tester.pumpAndSettle();
      final pictureDirectory =
          Platform.environment['MOBILE_LOGIN_SCREENSHOT_DIR'];
      if (pictureDirectory != null) {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory(pictureDirectory)
            ..createSync(recursive: true);
          File('${directory.path}/mobile-login-${size.width.toInt()}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final identifier = find.byKey(const ValueKey('mobile-login-identifier'));
      final secret = find.byKey(const ValueKey('mobile-login-password'));
      await tester.enterText(identifier, 'HED2073');
      await tester.enterText(secret, 'private-value');
      expect(tester.widget<TextField>(secret).obscureText, isTrue);
      await tester.ensureVisible(find.bySemanticsLabel('Show password'));
      await tester.tap(find.bySemanticsLabel('Show password'));
      await tester.pump();
      expect(tester.widget<TextField>(secret).obscureText, isFalse);
      await tester.ensureVisible(find.bySemanticsLabel('Forgot password?'));
      await tester.tap(find.bySemanticsLabel('Forgot password?'));
      expect(recoveries, 1);
      await tester.ensureVisible(find.bySemanticsLabel('Sign In'));
      await tester.tap(find.bySemanticsLabel('Sign In'));
      await tester.pumpAndSettle();
      expect(signIns, 1);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('mobile_login_identifier'), 'HED2073');
      expect(preferences.getKeys().any((key) => key.contains('password')),
          isFalse);
      await tester.ensureVisible(find.bySemanticsLabel('Remember me'));
      await tester.tap(find.bySemanticsLabel('Remember me'));
      await tester.pumpAndSettle();
      expect(preferences.getString('mobile_login_identifier'), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      username.dispose();
      password.dispose();
    });
  }

  testWidgets(
      'keyboard scroll, loading lock and authentication error remain usable',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    SharedPreferences.setMockInitialValues({});
    final username = TextEditingController(),
        password = TextEditingController();
    await tester.pumpWidget(MaterialApp(
        home: MobileReferenceLogin(
            usernameController: username,
            passwordController: password,
            obscurePassword: true,
            loading: true,
            errorMessage: 'Invalid credentials.',
            onTogglePassword: () => fail('Loading must lock visibility'),
            onSignIn: () => fail('Loading must lock login'),
            onForgotPassword: () => fail('Loading must lock recovery'))));
    await tester.pump();
    await tester.ensureVisible(find.text('Invalid credentials.'));
    await tester.pump();
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('mobile-login-password')))
            .enabled,
        isFalse);
    expect(find.text('Invalid credentials.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    username.dispose();
    password.dispose();
  });
}
