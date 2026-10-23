import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/penguin_walk_path.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/widgets/login_penguin_walker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the marked route loops smoothly and stays clear of the login card', () {
    const size = Size(1595, 827);
    final route = PenguinWalkPath(size);
    expect(route.length, greaterThan(2500));
    for (var i = 0; i < 1000; i++) {
      final point = route.at(route.length * i / 1000).position;
      expect(point.dx, inInclusiveRange(size.width * .025, size.width * .60));
      expect(point.dy, inInclusiveRange(size.height * .34, size.height));
    }
    expect(
        (route.at(0).position - route.at(route.length - .001).position)
            .distance,
        lessThan(.01));
    expect(PenguinWalkPath.direction(const Offset(1, 0)), 2);
    expect(PenguinWalkPath.direction(const Offset(0, -1)), 4);
    expect(PenguinWalkPath.direction(const Offset(-1, 0)), 6);
    expect(PenguinWalkPath.direction(const Offset(0, 1)), 0);
  });

  test('all eight 3D walk atlases are packaged as 16-pose grids', () async {
    for (var d = 0; d < 8; d++) {
      final data = await rootBundle.load('assets/penguins/walk/walk_$d.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1024);
      expect(frame.image.height, 1024);
      if (d == 2) {
        final pixels = (await frame.image.toByteData())!.buffer.asUint8List();
        final poses = <int>{};
        for (var pose = 0; pose < 16; pose++) {
          final row = pose ~/ 4, col = pose % 4;
          poses.add(Object.hashAll(List.generate(256, (y) {
            final start = ((row * 256 + y) * 1024 + col * 256) * 4;
            return Object.hashAll(pixels.sublist(start, start + 256 * 4));
          })));
        }
        expect(poses.length, 16,
            reason:
                'A walk must contain changing articulated poses, not repeated stills.');
      }
      frame.image.dispose();
      codec.dispose();
    }
  });

  testWidgets(
      'rendered pose frames move; reduced motion freezes the 3D penguin',
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

    final first = await tester.runAsync(pixels);
    await tester.pump(const Duration(milliseconds: 100));
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
