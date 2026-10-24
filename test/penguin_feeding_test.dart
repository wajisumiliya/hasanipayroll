import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/penguin_feeding.dart';
import 'package:hasani_payroll_portal/services/penguin_family_scene.dart';

void main() {
  test(
      'feed keeps the four-member family on terrain and rejoins without a jump',
      () {
    for (final width in [360.0, 1280.0, 4096.0]) {
      for (final started in [0.0, 23.0, 40.0, 79.9, 80.0, 110.0, 159.9]) {
        final feed = PenguinFeeding(
            startedAt: started, sceneWidth: width, adultHeight: 154);
        expect(feed.familyAt(started)[feed.responderIndex].position,
            penguinFamilyAt(started)[feed.responderIndex].position);
        for (var step = 0; step < 300; step++) {
          final time = started + feed.duration * step / 299;
          final family = feed.familyAt(time);
          expect(family, hasLength(4));
          expect(family[feed.responderIndex].activity,
              isNot(FamilyActivity.swimming));
          expect(
              family[feed.responderIndex].position.dx, lessThanOrEqualTo(.75));
          for (final index in [1 - feed.responderIndex, 2, 3]) {
            expect(
                family[index].position, penguinFamilyAt(time)[index].position);
          }
          final next = feed.familyAt(time + .0001)[feed.responderIndex];
          expect(
              (next.position - family[feed.responderIndex].position).distance,
              lessThan(.001));
        }
        final end = started + feed.duration;
        expect(feed.phaseAt(end + .001), PenguinFeedPhase.complete);
        expect(feed.familyAt(end + .001)[feed.responderIndex].position,
            penguinFamilyAt(end + .001)[feed.responderIndex].position);
        expect(feed.fishVisible(end), isFalse);
      }
    }
  });
  test('one fish lands, reaches the open bill and disappears during swallowing',
      () {
    final feed =
        PenguinFeeding(startedAt: 10, sceneWidth: 1280, adultHeight: 154);
    expect(feed.fishPosition(10), const Offset(.9, .15));
    expect(feed.fishPosition(11),
        PenguinFeeding.destination + const Offset(.05, .01));
    final eat = 10 + PenguinFeeding.noticeSeconds + feed.approachSeconds;
    expect(feed.phaseAt(eat + .01), PenguinFeedPhase.eating);
    expect(feed.fishVisible(eat + .5), isTrue);
    expect(feed.fishVisible(eat + PenguinFeeding.mealSeconds * .9), isFalse);
    expect(feed.fishScale(eat + PenguinFeeding.mealSeconds), 0);
  });
  test('approach footsteps include depth travel, not just horizontal movement',
      () {
    final feed =
        PenguinFeeding(startedAt: 80, sceneWidth: 1280, adultHeight: 154);
    expect(feed.responderIndex, 0);
    final start = 80 + PenguinFeeding.noticeSeconds;
    expect(feed.walkingPhase(start, const Size(1280, 360), 154),
        closeTo(0, .000000001));
    final time = start + feed.approachSeconds / 3;
    expect(
        feed.walkingPhase(time, const Size(1280, 360), 154),
        isNot(closeTo(
            feed.walkingPhase(time, const Size(1280, 720), 154), .000001)));
  });
}
