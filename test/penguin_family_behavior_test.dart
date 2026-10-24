import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/penguin_family_scene.dart';
import 'package:hasani_payroll_portal/services/penguin_feeding.dart';

void main() {
  test(
      'both adults share duties and youngsters stay near a parent through handovers',
      () {
    var pauses = 0, walks = 0, plays = 0;
    final swimmers = <int>{};
    for (var tick = 0; tick < 3200; tick++) {
      final t = tick / 10;
      final family = penguinFamilyAt(t);
      final parents = family.take(2).toList();
      final guardian = parents.singleWhere((p) => p.caregiver);
      if (guardian.activity == FamilyActivity.walking) {
        walks++;
      } else {
        pauses++;
      }
      for (var index = 0; index < 2; index++) {
        if (parents[index].immersion > 0) swimmers.add(index);
        if (parents[index].activity == FamilyActivity.swimming) {
          final dx = penguinFamilyAt(t + .001)[index].position.dx -
              parents[index].position.dx;
          expect(parents[index].direction, dx >= 0 ? 2 : 6);
        }
        expect(
            (parents[index].position -
                    penguinFamilyAt(t + .001)[index].position)
                .distance,
            lessThan(.001));
      }
      for (final child in family.skip(2)) {
        final closest = parents
            .map((p) => (child.position - p.position).distance)
            .reduce(math.min);
        expect(closest, lessThan(.17));
        expect(child.immersion, 0);
      }
      if (family[2].activity == FamilyActivity.playing) plays++;
      expect((parents[0].position - parents[1].position).distance,
          greaterThan(.10));
      expect(guardian.immersion, 0);
    }
    expect(swimmers, {0, 1});
    expect(pauses, greaterThan(walks * 2));
    expect(plays, greaterThan(0));
    expect(penguinCaregiverIndexAt(79.9), 1);
    expect(penguinCaregiverIndexAt(80), 0);
    expect(penguinCaregiverIndexAt(160), 1);
  });
  test('each caregiver holds position during its quiet intervals', () {
    for (final shift in [0.0, 80.0]) {
      final index = penguinCaregiverIndexAt(shift);
      for (final interval in [
        (0.0, 7.9),
        (16.1, 24.9),
        (49.1, 59.9),
        (66.1, 79.9)
      ]) {
        final first = penguinFamilyAt(shift + interval.$1)[index];
        final last = penguinFamilyAt(shift + interval.$2)[index];
        expect(first.position, last.position);
        expect(first.activity, isNot(FamilyActivity.walking));
      }
    }
    expect(penguinGroundScale(.94), greaterThan(penguinGroundScale(.73)));
  });
  test(
      'feeding selects the dry caregiver and does not interrupt other family members',
      () {
    for (final start in [
      0.0,
      15.0,
      40.0,
      58.0,
      78.0,
      79.9,
      80.0,
      95.0,
      120.0,
      159.9
    ]) {
      final feed =
          PenguinFeeding(startedAt: start, sceneWidth: 4096, adultHeight: 154);
      expect(feed.responderIndex, penguinCaregiverIndexAt(start));
      for (var sample = 0; sample <= 100; sample++) {
        final t = start + feed.duration * sample / 100;
        final family = feed.familyAt(t);
        final other = 1 - feed.responderIndex;
        expect(family[feed.responderIndex].immersion, 0);
        expect(
            (family[feed.responderIndex].position - family[other].position)
                .distance,
            greaterThan(.10));
        final child = family[3];
        expect(
            family
                .take(2)
                .map((p) => (p.position - child.position).distance)
                .reduce(math.min),
            lessThan(.18));
      }
    }
  });
  test('baby huddles, explores and returns without a jump through either shift',
      () {
    final near = penguinFamilyAt(12);
    expect((near[3].position - near[1].position).distance, lessThan(.13));
    expect(penguinFamilyAt(4)[3].activity, FamilyActivity.walking);
    expect(penguinFamilyAt(11)[3].activity, FamilyActivity.resting);
    expect(penguinFamilyAt(20)[3].activity, FamilyActivity.walking);
    for (var tick = 0; tick < 3200; tick++) {
      final t = tick / 10;
      expect(
          (penguinFamilyAt(t + .001)[3].position -
                  penguinFamilyAt(t)[3].position)
              .distance,
          lessThan(.001));
    }
  });
  test(
      'quiet poses are bounded and staggered while grooming has its own action',
      () {
    for (var tick = 0; tick < 320; tick++) {
      final t = tick / 10;
      for (final baby in [false, true]) {
        expect(penguinIdleFrameAt(t, baby: baby), inInclusiveRange(0, 15));
      }
    }
    for (var t = 5.1; t < 14; t += .1) {
      expect(penguinIdleFrameAt(t, baby: false), 0);
    }
    expect({
      penguinIdleFrameAt(1, baby: false),
      penguinIdleFrameAt(1, baby: false, caregiver: true),
      penguinIdleFrameAt(1, baby: true)
    }, hasLength(3));
    expect(penguinFamilyAt(46)[1].action, 'preen');
    expect(penguinFamilyAt(126)[0].action, 'preen');
  });
}
