import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/penguin_walk_path.dart';
import 'package:hasani_payroll_portal/services/login_penguin_terrain.dart';
import 'package:hasani_payroll_portal/services/login_habitat_scene.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/widgets/login_penguin_walker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all 28 terrain trails stay visible and clear of the login card', () {
    final trails = <String>{};
    for (var day = 1; day <= 7; day++) {
      for (final period in ['morning', 'afternoon', 'evening', 'night']) {
        final scene = LoginHabitatScene(day, period);
        trails.add(LoginPenguinTerrain.forScene(scene)
            .points
            .map((p) => '${p.dx},${p.dy}')
            .join(';'));
        for (final size in [
          const Size(1599, 827),
          const Size(1000, 700),
          const Size(1920, 1080)
        ]) {
          final route = PenguinWalkPath(size, scene: scene);
          expect(route.length, greaterThan(10));
          expect(
              (route.at(0).position - route.at(route.length).position).distance,
              greaterThan(10));
          for (var i = 0; i <= 100; i++) {
            final point = route.at(route.length * i / 100).position;
            expect(point.dx, inInclusiveRange(109.9, size.width * .55 - 109.9));
            expect(point.dy, inInclusiveRange(0, size.height));
          }
        }
      }
    }
    expect(trails.length, 28);
    final compact = PenguinWalkPath(const Size(354, 190), compact: true);
    expect(compact.at(0).position.dy, greaterThan(150));
  });

  test('cover projection retains the photographed foreground and growth ages',
      () {
    final projection =
        LoginPhotoProjection(const Size(1672, 941), const Size(1000, 700));
    expect(projection.project(const Offset(0, 1)), const Offset(0, 700));
    expect(projection.project(const Offset(1, 0)).dx, greaterThan(1000));
    expect(loginPenguinVariant(0), 'baby');
    expect(loginPenguinVariant(11), 'baby');
    expect(loginPenguinVariant(12), 'young');
    expect(loginPenguinVariant(41), 'young');
    expect(loginPenguinVariant(42), 'adult');
  });

  testWidgets('natural poses move; reduced motion freezes the penguin',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hatch = DateTime.utc(2026, 10, 23, 7, 39, 11);
    final controller = MysteryEggHatchController(
        load: () async => {
              'serverNow': hatch.toIso8601String(),
              'hatchAt': hatch.toIso8601String(),
              'stage': 'chick',
            });
    var reduce = false;
    final capture = GlobalKey();
    Widget app() => MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(
                size: const Size(1000, 700), disableAnimations: reduce),
            child: Scaffold(
                body: RepaintBoundary(
                    key: capture,
                    child: LoginPenguinWalker(controller: controller)))));
    await tester.pumpWidget(app());
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();
    Future<int> pixels() async {
      final image = await (capture.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage();
      final data = await image.toByteData();
      image.dispose();
      return Object.hashAll(data!.buffer.asUint8List());
    }

    await tester.pump(const Duration(milliseconds: 100));
    final first = await tester.runAsync(pixels);
    await tester.pump(const Duration(milliseconds: 200));
    final next = await tester.runAsync(pixels);
    expect(next, isNot(first));
    reduce = true;
    await tester.pumpWidget(app());
    await tester.pump();
    final still = await tester.runAsync(pixels);
    await tester.pump(const Duration(seconds: 1));
    expect(await tester.runAsync(pixels), still);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
