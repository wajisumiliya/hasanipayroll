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
      {this.baby = false, this.immersion = 0, this.caregiver = false});
  final String name;
  final Offset position;
  final double scale;
  final FamilyActivity activity;
  final int direction;
  final double phase;
  final bool baby;
  final bool caregiver;
  final double immersion;
  String get action => switch (activity) {
        FamilyActivity.swimming => 'swim',
        FamilyActivity.feeding => 'eat',
        FamilyActivity.preening => 'preen',
        _ => 'walk',
      };
}

double _ease(double a, double b, double t) => a + (b - a) * t * t * (3 - 2 * t);
Offset _between(Offset a, Offset b, double t) =>
    Offset.lerp(a, b, _ease(0, 1, t))!;

Offset _guardianSteps(double seconds) {
  final t = seconds % 80;
  final x = t < 10
      ? .29
      : t < 16
          ? _ease(.29, .32, (t - 10) / 6)
          : t < 34
              ? .32
              : t < 42
                  ? _ease(.32, .28, (t - 34) / 8)
                  : t < 60
                      ? .28
                      : t < 66
                          ? _ease(.28, .29, (t - 60) / 6)
                          : .29;
  return Offset(x, .86);
}

/// Stable adult identities exchange duties every eighty seconds. Each adult
/// remains at its own home position between its fishing and caregiving shifts.
int penguinCaregiverIndexAt(double seconds) => seconds % 160 < 80 ? 1 : 0;
Offset _guardianPosition(double seconds, int index) =>
    _guardianSteps(seconds) +
    (index == 0 ? const Offset(.22, .03) : Offset.zero);

/// The young and baby walk between parents during reunions. They never jump to
/// the new caregiver when a shift changes; both adults are home at that time.
Offset _familyGuideAt(double seconds) {
  final t = seconds % 160;
  const left = Offset(.29, .86);
  const right = Offset(.51, .89);
  if (t < 8) return _between(right, left, (t + 8) / 16);
  if (t < 72) return _guardianPosition(t, 1);
  if (t < 88) return _between(left, right, (t - 72) / 16);
  if (t < 152) return _guardianPosition(t - 80, 0);
  return _between(right, left, (t - 152) / 16);
}

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
    Offset(_familyGuideAt(seconds - 2).dx + _babyOffsetAt(seconds), .94);

int penguinIdleFrameAt(double seconds,
    {required bool baby,
    double identity = 1,
    bool? caregiver,
    bool juvenile = false}) {
  final local = seconds % 80;
  final guarding = caregiver ?? identity < 1;
  final starts = baby
      ? const [0.0, 10.0, 22.0, 32.0, 44.0, 72.0]
      : juvenile
          ? const [0.0, 11.0, 19.0, 28.0, 45.0, 69.0]
          : guarding
              ? const [0.0, 16.0, 42.0, 49.0, 66.0]
              : const [0.0, 61.0, 74.0];
  final start = starts.lastWhere((value) => value <= local);
  final offset = baby
      ? .3
      : juvenile
          ? 1.3
          : guarding
              ? .8
              : 0.0;
  final t = (local - start + offset) % 14;
  return t < 5 ? (t / 5 * 16).floor().clamp(0, 15) : 0;
}

double penguinGroundScale(double y) =>
    .86 + .14 * ((y - .72) / .22).clamp(0.0, 1.0);
double penguinImmersionAt(double seconds, {int adultIndex = 0}) {
  if (adultIndex == penguinCaregiverIndexAt(seconds)) return 0;
  final t = seconds % 80;
  if (t < 18 || t >= 42) return 0;
  if (t < 20) return _ease(0, 1, (t - 18) / 2);
  if (t > 40) return _ease(1, 0, (t - 40) / 2);
  return 1;
}

FamilyPenguin _fishingAdult(double seconds, int index) {
  final t = seconds % 80;
  final home = index == 0 ? const Offset(.51, .89) : const Offset(.29, .86);
  const shore = Offset(.59, .77),
      water = Offset(.85, .73),
      waypoint = Offset(.40, .70);
  late Offset position;
  late FamilyActivity activity;
  var direction = index == 0 ? 6 : 2;
  var phase = (seconds / .9) % 1;
  if (t < 8) {
    position = home;
    activity = FamilyActivity.observing;
  } else if (t < 18) {
    if (index == 0) {
      position = _between(home, shore, (t - 8) / 10);
    } else if (t < 13) {
      position = _between(home, waypoint, (t - 8) / 5);
    } else {
      position = _between(waypoint, shore, (t - 13) / 5);
    }
    activity = FamilyActivity.walking;
    direction = 2;
  } else if (t < 30) {
    position = Offset.lerp(shore, water, (t - 18) / 12)!;
    activity = FamilyActivity.swimming;
    direction = 2;
  } else if (t < 42) {
    position = Offset.lerp(water, shore, (t - 30) / 12)!;
    activity = FamilyActivity.swimming;
    direction = 6;
  } else if (t < 56) {
    if (index == 0) {
      position = _between(shore, home, (t - 42) / 14);
    } else if (t < 49) {
      position = _between(shore, waypoint, (t - 42) / 7);
    } else {
      position = _between(waypoint, home, (t - 49) / 7);
    }
    activity = FamilyActivity.walking;
    direction = 6;
  } else if (t < 61) {
    position = home;
    activity = FamilyActivity.feeding;
    phase = (t - 56) / 5;
  } else if (t >= 70 && t < 74) {
    position = home;
    activity = FamilyActivity.preening;
    phase = (t - 70) / 4;
  } else {
    position = home;
    activity = FamilyActivity.resting;
  }
  return FamilyPenguin(index == 0 ? 'Adult A' : 'Adult B', position,
      index == 0 ? 1 : .98, activity, direction, phase,
      immersion: penguinImmersionAt(seconds, adultIndex: index));
}

FamilyPenguin _watchingAdult(double seconds, int index) {
  final t = seconds % 80;
  final p = _guardianPosition(seconds, index);
  final next = _guardianPosition(seconds + .01, index);
  final moving = (p - next).distance > .00000001;
  final activity = moving
      ? FamilyActivity.walking
      : t >= 45 && t < 49
          ? FamilyActivity.preening
          : t >= 16 && t < 25
              ? FamilyActivity.observing
              : FamilyActivity.resting;
  return FamilyPenguin(
      index == 0 ? 'Adult A' : 'Adult B',
      p,
      index == 0 ? 1 : .98,
      activity,
      moving ? (next.dx >= p.dx ? 2 : 6) : 2,
      activity == FamilyActivity.preening ? (t - 45) / 4 : (seconds / .9) % 1,
      caregiver: true);
}

/// A continuous 160-second family routine: adults take turns fishing and
/// watching while the youngsters gradually move between the reunited parents.
List<FamilyPenguin> penguinFamilyAt(double seconds) {
  final t = seconds % 80;
  final guardian = penguinCaregiverIndexAt(seconds);
  final youngBase = _familyGuideAt(seconds - 3);
  final youngNext = _familyGuideAt(seconds - 2.99);
  final baby = _babyAt(seconds), babyNext = _babyAt(seconds + .01);
  final play = t >= 20 && t < 28
      ? -.025 * math.pow(math.sin((t - 20) / 8 * math.pi), 2).toDouble()
      : 0.0;
  final youngMoving = (youngBase - youngNext).distance > .00000001;
  final babyMoving = (baby - babyNext).distance > .00000001;
  return [
    guardian == 0 ? _watchingAdult(seconds, 0) : _fishingAdult(seconds, 0),
    guardian == 1 ? _watchingAdult(seconds, 1) : _fishingAdult(seconds, 1),
    FamilyPenguin(
        'Young penguin',
        Offset(youngBase.dx - .10 + play, .90),
        .70,
        play < 0
            ? FamilyActivity.playing
            : youngMoving
                ? FamilyActivity.walking
                : FamilyActivity.observing,
        play < 0
            ? (t < 24 ? 6 : 2)
            : youngNext.dx >= youngBase.dx
                ? 2
                : 6,
        (seconds / .9) % 1),
    FamilyPenguin(
        'Baby penguin',
        baby,
        .43,
        babyMoving ? FamilyActivity.walking : FamilyActivity.resting,
        babyMoving ? (babyNext.dx >= baby.dx ? 2 : 6) : 6,
        (seconds / .9) % 1,
        baby: true),
  ];
}
