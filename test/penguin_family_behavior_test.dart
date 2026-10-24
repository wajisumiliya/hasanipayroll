import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/penguin_family_scene.dart';
import 'package:hasani_payroll_portal/services/penguin_feeding.dart';

void main() {
  test('caregiver pauses and baby stays close while youngster explores', () {
    var pauseSamples = 0;
    var walks = 0;
    var play = 0;
    for (var tick = 0; tick < 1600; tick++) {
      final t = tick / 10;
      final family = penguinFamilyAt(t);
      final parent = family[1];
      final young = family[2];
      final baby = family[3];
      if (parent.activity == FamilyActivity.walking) {
        walks++;
      } else {
        pauseSamples++;
      }
      if (young.activity == FamilyActivity.playing) {
        play++;
      }
      expect((baby.position - parent.position).distance, lessThan(.15));
      expect((young.position - parent.position).distance, lessThan(.15));
      expect(baby.position.dx, greaterThan(parent.position.dx));
      expect(young.position.dx, lessThan(parent.position.dx));
      expect((family[0].position - parent.position).distance, greaterThan(.15));
    }
    expect(pauseSamples, greaterThan(walks * 2));
    expect(walks, greaterThan(0));
    expect(play, greaterThan(0));
  });
  test('feet stay stationary throughout resting and observing intervals', () {
    for (final interval in [
      (0.0, 7.9),
      (16.1, 24.9),
      (49.1, 59.9),
      (66.1, 79.9)
    ]) {
      final start = penguinFamilyAt(interval.$1)[1];
      final end = penguinFamilyAt(interval.$2)[1];
      expect(start.position, end.position);
      expect(start.activity, isNot(FamilyActivity.walking));
      expect(end.activity, isNot(FamilyActivity.walking));
    }
    expect(penguinGroundScale(.94), greaterThan(penguinGroundScale(.73)));
  });
  test(
      'offered fish keeps the responding parent near the baby and clear of the other adult',
      () {
    for (final start in [0.0, 15.0, 40.0, 58.0, 78.0]) {
      final feed =
          PenguinFeeding(startedAt: start, sceneWidth: 1280, adultHeight: 154);
      for (var sample = 0; sample <= 100; sample++) {
        final family = feed.familyAt(start + feed.duration * sample / 100);
        expect(
            (family[1].position - family[3].position).distance, lessThan(.17));
        expect((family[1].position - family[0].position).distance,
            greaterThan(.14));
      }
    }
  });
  test('baby takes real steps into a huddle, rests, explores, and returns', () {
    double gap(double t) {
      final family = penguinFamilyAt(t);
      return family[3].position.dx - family[1].position.dx;
    }

    expect(gap(8), lessThan(gap(0) * .65));
    expect(penguinFamilyAt(4)[3].activity, FamilyActivity.walking);
    expect(penguinFamilyAt(8)[3].activity, FamilyActivity.resting);
    expect(penguinFamilyAt(20)[3].activity, FamilyActivity.walking);
    expect(penguinFamilyAt(8)[3].position, penguinFamilyAt(11)[3].position);
    expect(penguinIdleFrameAt(8, baby: true),
        isNot(penguinIdleFrameAt(11, baby: true)));
    expect(gap(24), greaterThan(gap(8)));
    expect(gap(35), lessThan(gap(24)));
    for (var tick = 0; tick < 1600; tick++) {
      final t = tick / 10;
      final before = penguinFamilyAt(t)[3].position;
      final after = penguinFamilyAt(t + .001)[3].position;
      expect((after - before).distance, lessThan(.001));
    }
  });
  test('quiet pose loops pause between gestures and do not synchronize', () {
    for (var tick = 0; tick < 280; tick++) {
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
      penguinIdleFrameAt(1, baby: false, identity: .98),
      penguinIdleFrameAt(1, baby: true)
    }, hasLength(3));
  });
}
