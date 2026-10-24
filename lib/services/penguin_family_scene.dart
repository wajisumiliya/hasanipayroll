import 'dart:math' as math;
import 'package:flutter/painting.dart';

enum FamilyActivity {
  walking,
  swimming,
  feeding,
  playing,
  resting,
  observing,
  preening
}

class FamilyPenguin {
  const FamilyPenguin(this.name, this.position, this.scale, this.activity,
      this.direction, this.phase,
      {this.baby = false, this.immersion = 0});
  final String name;
  final Offset position;
  final double scale;
  final FamilyActivity activity;
  final int direction;
  final double phase;
  final bool baby;

  /// Water entry/exit progresses continuously from standing (0) to floating (1).
  final double immersion;
  String get action => switch (activity) {
        FamilyActivity.swimming => 'swim',
        FamilyActivity.feeding || FamilyActivity.preening => 'eat',
        _ => 'walk',
      };
}

/// A short walk with a gentle start/stop, followed by a long real pause.
/// The family members use different timings rather than a synchronized chase.
Offset _caregiverAt(double seconds) {
  final t = seconds % 80;
  double x;
  if (t < 10) {
    x = .29;
  } else if (t < 16) {
    x = _ease(.29, .32, (t - 10) / 6);
  } else if (t < 34) {
    x = .32;
  } else if (t < 42) {
    x = _ease(.32, .28, (t - 34) / 8);
  } else if (t < 60) {
    x = .28;
  } else if (t < 66) {
    x = _ease(.28, .29, (t - 60) / 6);
  } else {
    x = .29;
  }
  return Offset(x, .86);
}

double _ease(double a, double b, double t) =>
    a + (b - a) * (t * t * (3 - 2 * t));

double _babyOffsetAt(double seconds) {
  final t = seconds % 80;
  if (t < 2) return .10;
  if (t < 7) return _ease(.10, .055, (t - 2) / 5);
  if (t < 18) return .055;
  if (t < 22) return _ease(.055, .085, (t - 18) / 4);
  if (t < 26) return .085;
  if (t < 32) return _ease(.085, .055, (t - 26) / 6);
  if (t < 66) return .055;
  if (t < 72) return _ease(.055, .10, (t - 66) / 6);
  return .10;
}

Offset _babyAt(double seconds) =>
    Offset(_caregiverAt(seconds - 2).dx + _babyOffsetAt(seconds), .94);

/// Brief, staggered head/eyelid loops followed by an extended still pause.
int penguinIdleFrameAt(double seconds,
    {required bool baby, double identity = 1}) {
  final local = seconds % 80;
  final starts = baby
      ? const [0.0, 7.0, 22.0, 32.0, 44.0, 72.0]
      : identity < 1
          ? const [0.0, 16.0, 42.0, 49.0, 66.0]
          : const [0.0, 61.0, 74.0];
  final start = starts.lastWhere((value) => value <= local);
  final offset = baby
      ? .3
      : identity < 1
          ? .8
          : 0.0;
  final t = (local - start + offset) % 14;
  return t < 5 ? (t / 5 * 16).floor().clamp(0, 15) : 0;
}

/// Perspective belongs to the ground plane, not the age of the animal.
double penguinGroundScale(double y) =>
    .86 + .14 * ((y - .72) / .22).clamp(0.0, 1.0);

double penguinImmersionAt(double seconds) {
  final t = seconds % 80;
  if (t < 18 || t >= 42) return 0;
  if (t < 20) return _ease(0, 1, (t - 18) / 2);
  if (t > 40) return _ease(1, 0, (t - 40) / 2);
  return 1;
}

/// An 80-second routine with long observation/rest stops, a fishing trip,
/// a chick following its nearby caregiver, and a youngster's short playful walk.
List<FamilyPenguin> penguinFamilyAt(double seconds) {
  final t = seconds % 80;
  final gait = (seconds / .9) % 1;
  const nest = Offset(.51, .89);
  const shore = Offset(.59, .77);
  const water = Offset(.85, .73);
  late Offset adult;
  late FamilyActivity activity;
  var direction = 6;
  var phase = gait;
  if (t < 8) {
    adult = nest;
    activity = FamilyActivity.observing;
  } else if (t < 18) {
    adult = Offset.lerp(nest, shore, _ease(0, 1, (t - 8) / 10))!;
    activity = FamilyActivity.walking;
    direction = 2;
  } else if (t < 30) {
    adult = Offset.lerp(shore, water, (t - 18) / 12)!;
    activity = FamilyActivity.swimming;
    direction = 2;
  } else if (t < 42) {
    adult = Offset.lerp(water, shore, (t - 30) / 12)!;
    activity = FamilyActivity.swimming;
  } else if (t < 56) {
    adult = Offset.lerp(shore, nest, _ease(0, 1, (t - 42) / 14))!;
    activity = FamilyActivity.walking;
  } else if (t < 61) {
    adult = nest;
    activity = FamilyActivity.feeding;
    phase = (t - 56) / 5;
  } else if (t < 70) {
    adult = nest;
    activity = FamilyActivity.resting;
  } else if (t < 74) {
    adult = nest;
    activity = FamilyActivity.preening;
    phase = .04 + .12 * math.sin((t - 70) / 4 * math.pi);
  } else {
    adult = nest;
    activity = FamilyActivity.resting;
  }
  final parent = _caregiverAt(seconds);
  final parentMoving =
      (parent - _caregiverAt(seconds + .01)).distance > .00000001;
  final parentRight = _caregiverAt(seconds + .01).dx >= parent.dx;
  final youngBase = _caregiverAt(seconds - 3);
  final baby = _babyAt(seconds);
  final babyNext = _babyAt(seconds + .01);
  final youngMoving =
      (youngBase - _caregiverAt(seconds - 2.99)).distance > .00000001;
  final babyMoving = (baby - babyNext).distance > .00000001;
  // A youngster explores a few steps, then returns to its parent's side.
  final playOffset = t >= 20 && t < 28
      ? -.025 * math.pow(math.sin((t - 20) / 8 * math.pi), 2).toDouble()
      : 0.0;
  final young = Offset(youngBase.dx - .10 + playOffset, .90);
  final parentActivity = parentMoving
      ? FamilyActivity.walking
      : t >= 45 && t < 49
          ? FamilyActivity.preening
          : t >= 16 && t < 25
              ? FamilyActivity.observing
              : FamilyActivity.resting;
  return [
    FamilyPenguin('Adult fishing and watching the family', adult, 1, activity,
        direction, phase,
        immersion: penguinImmersionAt(seconds)),
    FamilyPenguin(
        'Adult staying close to the baby',
        parent,
        .98,
        parentActivity,
        parentMoving ? (parentRight ? 2 : 6) : 2,
        parentActivity == FamilyActivity.preening
            ? .04 + .12 * math.sin((t - 45) / 4 * math.pi)
            : gait),
    FamilyPenguin(
        'Young penguin exploring near its parent',
        young,
        .70,
        playOffset < 0
            ? FamilyActivity.playing
            : youngMoving
                ? FamilyActivity.walking
                : FamilyActivity.observing,
        playOffset < 0
            ? (t < 24 ? 6 : 2)
            : _caregiverAt(seconds - 2.99).dx >= youngBase.dx
                ? 2
                : 6,
        gait),
    FamilyPenguin(
        'Baby staying beside its parent',
        baby,
        .43,
        babyMoving ? FamilyActivity.walking : FamilyActivity.resting,
        babyMoving ? (babyNext.dx >= baby.dx ? 2 : 6) : 6,
        gait,
        baby: true),
  ];
}
