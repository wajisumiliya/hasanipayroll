import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Completed 24-hour days since the server-confirmed hatch, never device dates.
int penguinDaysSinceHatch(DateTime hatchAt, DateTime serverNow) =>
    math.max(0, serverNow.difference(hatchAt).inDays);

String penguinStageForAge(int days) => days < 12
    ? 'chick'
    : days < 42
        ? 'juvenile'
        : 'adult';

/// Three days in the egg, then 42 days of gradual growth.
double penguinGrowthScale(int daysSinceHatch) {
  final days = daysSinceHatch.clamp(0, 42);
  return .30 + .70 * days / 42;
}

/// Continues already-confirmed growth using server time plus monotonic elapsed
/// time. This clock can grow a hatched pet, but can never hatch a sealed egg.
class PenguinGrowthClock extends ChangeNotifier {
  DateTime? _hatchAt, _serverNow;
  final _elapsed = Stopwatch();
  Timer? _dayTimer;
  bool _confirmed = false, _active = true;
  int _days = 0;
  bool get confirmed => _confirmed;
  int get daysSinceHatch => _days;
  String get stage => _confirmed ? penguinStageForAge(_days) : 'egg';
  DateTime? get _now => _serverNow?.add(_elapsed.elapsed);

  void update(
      {required DateTime hatchAt,
      required DateTime serverNow,
      required bool hatched}) {
    final sameHatch = _hatchAt == hatchAt && _confirmed && hatched;
    _hatchAt = hatchAt;
    _serverNow = serverNow;
    _confirmed = hatched && !serverNow.isBefore(hatchAt);
    final age = _confirmed ? penguinDaysSinceHatch(hatchAt, serverNow) : 0;
    _days = sameHatch && _confirmed ? math.max(_days, age) : age;
    _elapsed
      ..reset()
      ..start();
    _schedule();
    notifyListeners();
  }

  void _schedule() {
    _dayTimer?.cancel();
    if (!_active || !_confirmed || _hatchAt == null || _now == null) return;
    final nextAge = _days + 1;
    final until = _hatchAt!.add(Duration(days: nextAge)).difference(_now!);
    // A delayed callback catches up from the monotonic server anchor. Capping
    // the next wait also prevents stale server snapshots delaying daily growth.
    final micros = until.inMicroseconds
        .clamp(1000, const Duration(days: 1).inMicroseconds);
    _dayTimer = Timer(Duration(microseconds: micros), () {
      if (!_active || !_confirmed) return;
      _days = math.max(nextAge, penguinDaysSinceHatch(_hatchAt!, _now!));
      notifyListeners();
      _schedule();
    });
  }

  void suspend() {
    _active = false;
    _dayTimer?.cancel();
  }

  void resume() {
    _active = true;
    if (_confirmed && _now != null) {
      final age = penguinDaysSinceHatch(_hatchAt!, _now!);
      if (age > _days) {
        _days = age;
        notifyListeners();
      }
    }
    _schedule();
  }

  @override
  void dispose() {
    _active = false;
    _dayTimer?.cancel();
    _elapsed.stop();
    super.dispose();
  }
}
