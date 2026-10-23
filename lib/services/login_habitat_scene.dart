/// Malaysia has a fixed UTC+8 offset and does not observe daylight saving time.
DateTime malaysiaTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));

class LoginHabitatScene {
  const LoginHabitatScene(this.weekday, this.period);
  final int weekday;
  final String period;
  static const days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  String get asset => 'assets/login_habitats/${days[weekday - 1]}_$period.png';
}

LoginHabitatScene loginHabitatScene({
  required DateTime instant,
  DateTime? hatchAt,
  bool hatchConfirmed = false,
  int? previewWeekday,
}) {
  final local = malaysiaTime(instant);
  var period = local.hour < 6 || local.hour >= 20
      ? 'night'
      : local.hour < 12
          ? 'morning'
          : local.hour < 17
              ? 'afternoon'
              : 'evening';
  if (hatchConfirmed && hatchAt != null && !instant.isBefore(hatchAt)) {
    final revealDay = malaysiaTime(hatchAt);
    if (local.year == revealDay.year &&
        local.month == revealDay.month &&
        local.day == revealDay.day &&
        local.hour < 20) {
      period = 'evening';
    }
  }
  return LoginHabitatScene(previewWeekday ?? local.weekday, period);
}
