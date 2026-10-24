import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/penguin_entry_geometry.dart';
import 'package:hasani_payroll_portal/widgets/employee_penguin_pet_card.dart';
import 'package:hasani_payroll_portal/widgets/penguin_companion_reaction.dart';

Map<String, dynamic> data(
        {String stage = 'chick', bool fed = false, bool played = false}) =>
    {
      'pet': {
        'stage': stage,
        'ageDays': stage == 'adult' ? 50 : 8,
        'nickname': 'Pingu',
        'serverNow': '2026-10-24T04:00:00Z',
        'hatchAt':
            stage == 'adult' ? '2026-09-07T04:00:00Z' : '2026-10-19T04:00:00Z',
        'fedToday': fed,
        'playedToday': played,
      }
    };
Future<void> mount(
    WidgetTester tester, Future<Map<String, dynamic>> Function(String?) request,
    {bool reduced = true}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
              body: SingleChildScrollView(
                  child: EmployeePenguinPetCard(request: request))))));
  await tester.pump();
}

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump();
}

void main() {
  testWidgets(
      'four silent interactions save daily care once and keep responding',
      (tester) async {
    final calls = <String?>[];
    var fed = false, played = false;
    await mount(tester, (kind) async {
      calls.add(kind);
      if (kind == 'feed') fed = true;
      if (kind == 'play') played = true;
      return data(fed: fed, played: played);
    });
    expect(find.text('Talk'), findsNothing);
    expect(find.byIcon(Icons.mic), findsNothing);
    await tap(tester, 'Feed');
    expect(find.text('Yum! Thank you for the fish!'), findsOneWidget);
    expect(
        tester
            .widget<PenguinCompanionReaction>(
                find.byType(PenguinCompanionReaction))
            .action,
        'eating');
    await tap(tester, 'Feed');
    expect(find.text('Another little fish? Yum!'), findsOneWidget);
    await tap(tester, 'Play');
    expect(find.text('A snowball! Let’s play!'), findsOneWidget);
    await tap(tester, 'Play');
    expect(find.text('Let’s play again!'), findsOneWidget);
    await tap(tester, 'Pet');
    expect(find.text('That feels lovely. Thank you!'), findsOneWidget);
    await tap(tester, 'Rest');
    expect(find.text('Wake'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(
        tester
            .widget<PenguinCompanionReaction>(
                find.byType(PenguinCompanionReaction))
            .action,
        'sleeping',
        reason: 'An old reaction timer cannot wake a resting pet');
    await tap(tester, 'Wake');
    expect(find.text('Hello again! Ready to play?'), findsOneWidget);
    expect(calls, [null, 'feed', 'play']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
  });
  testWidgets('care failure shows an error without a false successful reaction',
      (tester) async {
    await mount(tester, (kind) async {
      if (kind != null) throw StateError('offline');
      return data();
    });
    await tap(tester, 'Feed');
    expect(
        find.text('Penguin home is temporarily unavailable.'), findsOneWidget);
    expect(find.byType(PenguinCompanionReaction), findsNothing);
    expect(find.text('Yum! Thank you for the fish!'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('unhatched pet cannot be fed or played with', (tester) async {
    final calls = <String?>[];
    await mount(tester, (kind) async {
      calls.add(kind);
      return {
        'pet': {
          'stage': 'egg',
          'ageDays': 1,
          'serverNow': '2026-10-24T04:00:00Z',
          'hatchAt': '2026-10-26T04:00:00Z'
        }
      };
    });
    for (final label in ['Feed', 'Play', 'Pet', 'Rest']) {
      await tap(tester, label);
    }
    expect(calls, [null]);
    expect(find.byType(PenguinCompanionReaction), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('pending request prevents duplicate care writes', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    var writes = 0;
    await mount(tester, (kind) async {
      if (kind == null) return data();
      writes++;
      return pending.future;
    });
    await tap(tester, 'Feed');
    await tap(tester, 'Feed');
    await tap(tester, 'Play');
    expect(writes, 1);
    pending.complete(data(fed: true));
    await tester.pump();
    expect(find.text('Yum! Thank you for the fish!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
  });
  testWidgets(
      'expressions animate while reduced motion keeps a planted static pose',
      (tester) async {
    var reduced = false;
    final key = GlobalKey();
    Widget app() => MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Center(
                child: RepaintBoundary(
                    key: key,
                    child: const PenguinCompanionReaction(
                        stage: 'adult',
                        action: 'petting',
                        daysSinceHatch: 42)))));
    await tester.pumpWidget(app());
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();
    expect(find.byType(Image), findsNothing,
        reason:
            'The reaction atlas must decode instead of falling back to a still');
    Future<int> pixels() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await image.toByteData();
      image.dispose();
      return Object.hashAll(bytes!.buffer.asUint8List());
    }

    final before = await tester.runAsync(pixels);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(await tester.runAsync(pixels), isNot(before));
    reduced = true;
    await tester.pumpWidget(app());
    await tester.pump();
    final still = await tester.runAsync(pixels);
    await tester.pump(const Duration(seconds: 1));
    expect(await tester.runAsync(pixels), still);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
      'both original-colour reaction sheets contain sixteen isolated full-body poses',
      () async {
    for (final age in ['chick', 'adult']) {
      final bytes =
          await rootBundle.load('assets/penguins/${age}_reactions.png');
      final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      try {
        final rgba =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final poses = penguinEntryGeometry(image.width, image.height, rgba);
        expect(poses, hasLength(16));
        for (var i = 0; i < 16; i++) {
          expect(poses[i].footX, inInclusiveRange(.05, .95));
          if (i >= 4) {
            expect(poses[i - 4].source.bottom, lessThan(poses[i].source.top));
          }
        }
      } finally {
        image.dispose();
      }
    }
  });
}
