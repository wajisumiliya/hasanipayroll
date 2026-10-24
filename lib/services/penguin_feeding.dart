import 'package:flutter/painting.dart';
import 'penguin_family_scene.dart';

enum PenguinFeedPhase { noticing, approaching, eating, returning, complete }

/// A local habitat interaction. The adult on dry ice responds; the downy baby
/// is never sent swimming or given a whole fish. Feeding does not change pets.
class PenguinFeeding {
  factory PenguinFeeding(
      {required double startedAt,
      required double sceneWidth,
      required double adultHeight}) {
    final family = penguinFamilyAt(startedAt);
    final index = family.indexWhere((member) => member.caregiver);
    final origin = family[index].position;
    final spot = index == 0 ? const Offset(.72, .95) : destination;
    final approach =
        ((origin - spot).distance * sceneWidth / (adultHeight * .18 / .8))
            .clamp(2.0, 6.0);
    return PenguinFeeding._(
        startedAt, origin, spot, approach, index, spot.dx >= origin.dx ? 2 : 6);
  }
  PenguinFeeding._(this.startedAt, this.origin, this.feedingSpot,
      this.approachSeconds, this.responderIndex, this.direction);
  final double startedAt;
  final Offset origin;
  final Offset feedingSpot;
  final double approachSeconds;
  final int responderIndex;
  final int direction;
  String get responderName => responderIndex == 0 ? 'Adult A' : 'Adult B';

  /// Use actual ground travel, including depth movement, to animate the feet.
  double walkingPhase(double time, Size viewport, double bodyHeight) {
    double pixels(Offset offset) =>
        Offset(offset.dx * viewport.width, offset.dy * viewport.height)
            .distance;
    final elapsed = time - startedAt - noticeSeconds;
    final approach = pixels(feedingSpot - origin);
    double distance;
    if (elapsed <= approachSeconds) {
      distance = approach * (elapsed / approachSeconds).clamp(0.0, 1.0);
    } else if (elapsed < approachSeconds + mealSeconds) {
      distance = approach;
    } else {
      distance = approach +
          pixels(familyAt(time)[responderIndex].position - feedingSpot);
    }
    return (distance / (bodyHeight * .18)) % 1;
  }

  static const destination = Offset(.34, .83);
  static const noticeSeconds = 1.2;
  static const mealSeconds = 2.4;
  double get duration => noticeSeconds + approachSeconds * 2 + mealSeconds;
  PenguinFeedPhase phaseAt(double sceneTime) {
    final t = sceneTime - startedAt - noticeSeconds;
    if (t < 0) return PenguinFeedPhase.noticing;
    if (t < approachSeconds) return PenguinFeedPhase.approaching;
    if (t < approachSeconds + mealSeconds) return PenguinFeedPhase.eating;
    if (t < duration - noticeSeconds) return PenguinFeedPhase.returning;
    return PenguinFeedPhase.complete;
  }

  double mealProgress(double time) =>
      ((time - startedAt - noticeSeconds - approachSeconds) / mealSeconds)
          .clamp(0.0, 1.0)
          .toDouble();
  List<FamilyPenguin> familyAt(double time) {
    final family = penguinFamilyAt(time);
    final phase = phaseAt(time);
    if (phase == PenguinFeedPhase.complete) return family;
    final base = family[responderIndex];
    final t = time - startedAt - noticeSeconds;
    final Offset position;
    final FamilyActivity activity;
    final int direction;
    if (phase == PenguinFeedPhase.noticing) {
      position = origin;
      activity = FamilyActivity.observing;
      direction = this.direction;
    } else if (phase == PenguinFeedPhase.approaching) {
      position = Offset.lerp(origin, feedingSpot,
          (t / approachSeconds).clamp(0.0, 1.0).toDouble())!;
      activity = FamilyActivity.walking;
      direction = this.direction;
    } else if (phase == PenguinFeedPhase.eating) {
      position = feedingSpot;
      activity = FamilyActivity.feeding;
      direction = this.direction;
    } else {
      final p = ((t - approachSeconds - mealSeconds) / approachSeconds)
          .clamp(0.0, 1.0)
          .toDouble();
      position = Offset.lerp(feedingSpot, base.position, p)!;
      activity = FamilyActivity.walking;
      direction = base.position.dx >= feedingSpot.dx ? 2 : 6;
    }
    family[responderIndex] = FamilyPenguin(
        base.name,
        position,
        base.scale,
        activity,
        direction,
        phase == PenguinFeedPhase.eating ? mealProgress(time) : base.phase,
        caregiver: base.caregiver);
    return family;
  }

  /// The thrown fish lands on the ice, is lifted to the bill, then disappears
  /// as the mandible closes. Never show another fish during the return walk.
  Offset fishPosition(double time) {
    final t = (time - startedAt).clamp(0, duration);
    if (t < .7) {
      final p = t / .7;
      return Offset.lerp(const Offset(.90, .15),
              (feedingSpot + Offset(direction == 2 ? .05 : -.05, .01)), p)! +
          Offset(0, -.18 * 4 * p * (1 - p));
    }
    final p = (mealProgress(time) * 3).clamp(0.0, 1.0);
    return Offset.lerp((feedingSpot + Offset(direction == 2 ? .05 : -.05, .01)),
        (feedingSpot + Offset(direction == 2 ? .06 : -.06, -.09)), p)!;
  }

  double fishScale(double time) =>
      (1 - ((mealProgress(time) - .6) / .25).clamp(0.0, 1.0).toDouble());
  bool fishVisible(double time) =>
      phaseAt(time) == PenguinFeedPhase.noticing ||
      phaseAt(time) == PenguinFeedPhase.approaching ||
      (phaseAt(time) == PenguinFeedPhase.eating && mealProgress(time) < .85);
}
