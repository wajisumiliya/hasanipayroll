import 'dart:math' as math;
import 'package:flutter/painting.dart';

enum FamilyActivity { walking, swimming, feeding, playing, resting }

/// Coordinates use the habitat image's shoreline, never a random screen walk.
class FamilyPenguin {
  const FamilyPenguin(this.name, this.position, this.scale, this.activity,
      this.direction, this.phase,
      {this.baby = false});
  final String name;
  final Offset position;
  final double scale;
  final FamilyActivity activity;
  final int direction;
  final double phase;
  final bool baby;
  String get action => switch (activity) {
        FamilyActivity.swimming => 'swim',
        FamilyActivity.feeding => 'eat',
        _ => 'walk',
      };
}

/// An 80-second family routine: a fishing trip, feeding, and a gentle chase.
/// The downy baby stays on dry ice; only the adults enter the water.
List<FamilyPenguin> penguinFamilyAt(double seconds) {
  final t = seconds % 80;
  final phase = (seconds / .8) % 1;
  Offset lerp(Offset a, Offset b, double q) => Offset.lerp(a, b, q)!;
  const shore = Offset(.59, .77);
  const nest = Offset(.39, .91);
  late Offset adult;
  late FamilyActivity activity;
  var direction = 2;
  if (t < 12) {
    adult = lerp(shore, const Offset(.85, .73), t / 12);
    activity = FamilyActivity.swimming;
  } else if (t < 24) {
    adult = lerp(const Offset(.85, .73), shore, (t - 12) / 12);
    activity = FamilyActivity.swimming;
    direction = 6;
  } else if (t < 38) {
    adult = lerp(shore, nest, (t - 24) / 14);
    activity = FamilyActivity.walking;
    direction = 6;
  } else if (t < 54) {
    adult = nest;
    activity = FamilyActivity.feeding;
    direction = 2;
  } else if (t < 68) {
    adult = lerp(nest, shore, (t - 54) / 14);
    activity = FamilyActivity.walking;
  } else {
    adult = shore;
    activity = FamilyActivity.resting;
    direction = 6;
  }
  // Rounded, continuous out-and-back paths keep parent and youngster together.
  final play = (1 - math.cos(seconds * math.pi / 14)) / 2;
  final goRight = math.sin(seconds * math.pi / 14) >= 0;
  final paused = play < .025 || play > .975;
  return [
    FamilyPenguin('Adult fishing and feeding', adult, 1, activity, direction,
        activity == FamilyActivity.feeding ? (seconds / 2.2) % 1 : phase),
    FamilyPenguin(
        'Adult watching the youngsters',
        Offset(.14 + .15 * play, .84),
        .98,
        paused ? FamilyActivity.resting : FamilyActivity.playing,
        goRight ? 2 : 6,
        phase),
    FamilyPenguin(
        'Young penguin playing with a parent',
        Offset(.23 + .15 * play, .87),
        .70,
        paused ? FamilyActivity.resting : FamilyActivity.playing,
        goRight ? 2 : 6,
        (phase + .25) % 1),
    FamilyPenguin(
        'Baby waiting safely on the ice',
        Offset(
            t < 32
                ? .46
                : t < 38
                    ? .46 - .02 * (t - 32) / 6
                    : t < 54
                        ? .44
                        : t < 60
                            ? .44 + .02 * (t - 54) / 6
                            : .46,
            .92),
        .43,
        t >= 38 && t < 54
            ? FamilyActivity.feeding
            : (t >= 32 && t < 38) || (t >= 54 && t < 60)
                ? FamilyActivity.walking
                : FamilyActivity.resting,
        t >= 54 && t < 60 ? 2 : 6,
        0,
        baby: true),
  ];
}
