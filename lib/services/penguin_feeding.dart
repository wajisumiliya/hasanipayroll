import 'package:flutter/painting.dart';
import 'penguin_family_scene.dart';

enum PenguinFeedPhase { approaching, eating, returning, complete }

/// A local habitat interaction. The adult on dry ice responds; the downy baby
/// is never sent swimming or given a whole fish. Feeding does not change pets.
class PenguinFeeding {
  PenguinFeeding(
      {required this.startedAt,
      required double sceneWidth,
      required double adultHeight})
      : origin = penguinFamilyAt(startedAt)[1].position,
        approachSeconds =
            ((penguinFamilyAt(startedAt)[1].position - destination).distance *
                    sceneWidth /
                    (adultHeight * .18 / .8))
                .clamp(2.0, 9.0);
  final double startedAt;
  final Offset origin;
  final double approachSeconds;
  static const destination = Offset(.49, .88);
  static const mealSeconds = 2.4;
  double get duration => approachSeconds * 2 + mealSeconds;
  PenguinFeedPhase phaseAt(double sceneTime) {
    final t = sceneTime - startedAt;
    if (t < approachSeconds) return PenguinFeedPhase.approaching;
    if (t < approachSeconds + mealSeconds) return PenguinFeedPhase.eating;
    if (t < duration) return PenguinFeedPhase.returning;
    return PenguinFeedPhase.complete;
  }

  double mealProgress(double time) =>
      ((time - startedAt - approachSeconds) / mealSeconds)
          .clamp(0.0, 1.0)
          .toDouble();
  List<FamilyPenguin> familyAt(double time) {
    final family = penguinFamilyAt(time);
    final phase = phaseAt(time);
    if (phase == PenguinFeedPhase.complete) return family;
    final base = family[1];
    final t = time - startedAt;
    final Offset position;
    final FamilyActivity activity;
    final int direction;
    if (phase == PenguinFeedPhase.approaching) {
      position = Offset.lerp(origin, destination,
          (t / approachSeconds).clamp(0.0, 1.0).toDouble())!;
      activity = FamilyActivity.walking;
      direction = 2;
    } else if (phase == PenguinFeedPhase.eating) {
      position = destination;
      activity = FamilyActivity.feeding;
      direction = 2;
    } else {
      final p = ((t - approachSeconds - mealSeconds) / approachSeconds)
          .clamp(0.0, 1.0)
          .toDouble();
      position = Offset.lerp(destination, base.position, p)!;
      activity = FamilyActivity.walking;
      direction = 6;
    }
    family[1] = FamilyPenguin(
        base.name,
        position,
        base.scale,
        activity,
        direction,
        phase == PenguinFeedPhase.eating ? mealProgress(time) : base.phase);
    return family;
  }

  /// The thrown fish lands on the ice, is lifted to the bill, then disappears
  /// as the mandible closes. Never show another fish during the return walk.
  Offset fishPosition(double time) {
    final t = (time - startedAt).clamp(0, duration);
    if (t < .7) {
      final p = t / .7;
      return Offset.lerp(const Offset(.90, .15), const Offset(.54, .89), p)! +
          Offset(0, -.18 * 4 * p * (1 - p));
    }
    final p = (mealProgress(time) * 3).clamp(0.0, 1.0);
    return Offset.lerp(const Offset(.54, .89), const Offset(.55, .79), p)!;
  }

  double fishScale(double time) =>
      (1 - ((mealProgress(time) - .6) / .25).clamp(0.0, 1.0).toDouble());
  bool fishVisible(double time) =>
      phaseAt(time) == PenguinFeedPhase.approaching ||
      (phaseAt(time) == PenguinFeedPhase.eating && mealProgress(time) < .85);
}
