import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/penguin_family_scene.dart';
import 'package:hasani_payroll_portal/services/penguin_feeding.dart';
import 'package:hasani_payroll_portal/widgets/penguin_habitat_effects.dart';

void main() {
  test('immersion stays continuous at the shore, only for the fishing adult',
      () {
    for (var index = 0; index <= 16000; index++) {
      final t = index / 100;
      final family = penguinFamilyAt(t);
      for (var adult = 0; adult < 2; adult++) {
        final water = family[adult].immersion;
        expect(water, inInclusiveRange(0, 1));
        expect((water - penguinImmersionAt(t + .001, adultIndex: adult)).abs(),
            lessThan(.001));
        if (water > 0) expect(family[adult].activity, FamilyActivity.swimming);
      }
      for (final child in family.skip(2)) {
        expect(child.immersion, 0);
      }
    }
    expect(penguinImmersionAt(18), 0);
    expect(penguinImmersionAt(19), closeTo(.5, .00001));
    expect(penguinImmersionAt(20), 1);
    expect(penguinImmersionAt(41), closeTo(.5, .00001));
    expect(penguinImmersionAt(42), 0);
  });
  test(
      'reflection mask stays off family ice and covers the open bay at all sizes',
      () {
    for (final size in [const Size(390, 310), const Size(1280, 360)]) {
      final path = penguinWaterMask(size);
      expect(
          path.contains(Offset(size.width * .90, size.height * .60)), isTrue);
      for (var tick = 0; tick < 800; tick++) {
        for (final p
            in penguinFamilyAt(tick / 10).where((p) => p.immersion == 0)) {
          expect(
              path.contains(Offset(
                  p.position.dx * size.width, p.position.dy * size.height)),
              isFalse);
        }
      }
    }
  });
  test(
      'adult notices the landed fish before walking, without delaying meal completion',
      () {
    final feed =
        PenguinFeeding(startedAt: 10, sceneWidth: 1280, adultHeight: 154);
    expect(feed.phaseAt(10), PenguinFeedPhase.noticing);
    expect(feed.phaseAt(10.8), PenguinFeedPhase.noticing);
    expect(feed.fishVisible(10.8), isTrue);
    expect(feed.familyAt(10.8)[1].position, feed.origin);
    expect(feed.familyAt(10.8)[1].activity, FamilyActivity.observing);
    expect(feed.phaseAt(10 + PenguinFeeding.noticeSeconds + .001),
        PenguinFeedPhase.approaching);
    expect(feed.phaseAt(10 + feed.duration + .001), PenguinFeedPhase.complete);
  });
  test('light snow has a bounded gentle fade and long clear intervals', () {
    expect(penguinSnowStrength(0), 0);
    expect(penguinSnowStrength(39.99), 0);
    expect(penguinSnowStrength(52.5), closeTo(1, .0001));
    expect(penguinSnowStrength(65), 0);
    for (var tick = 0; tick < 3600; tick++) {
      final t = tick / 10;
      expect(penguinSnowStrength(t), inInclusiveRange(0, 1));
      expect((penguinSnowStrength(t + .001) - penguinSnowStrength(t)).abs(),
          lessThan(.001));
    }
  });
}
