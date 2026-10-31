import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/increment_eligibility_service.dart';

void main() {
  test('January last increment becomes eligible in July, not January or June',
      () {
    for (final month in [1, 6]) {
      expect(
          IncrementEligibilityService.dueForMonth(
              'Jan-26/50', DateTime(2026, month)),
          isNull);
    }
    final july = IncrementEligibilityService.dueForMonth(
        'Jan-26/50', DateTime(2026, 7))!;
    expect(july.lastMonth, DateTime(2026, 1));
    expect(july.dueMonth, DateTime(2026, 7));
    expect(july.lastAmount, 50);
    expect(
        IncrementEligibilityService.dueForMonth(
                'Jan-26/50', DateTime(2026, 10))!
            .dueMonth,
        DateTime(2026, 7));
    expect(
        IncrementEligibilityService.dueForMonth(
            'Jul-26/50', DateTime(2026, 10)),
        isNull);
  });

  test('year rollover and long month names use six calendar months', () {
    expect(
        IncrementEligibilityService.dueForMonth(
            'SEPT-2026/125', DateTime(2027, 2)),
        isNull);
    final due = IncrementEligibilityService.dueForMonth(
        'SEPT-2026/125', DateTime(2027, 3))!;
    expect(due.dueMonth, DateTime(2027, 3));
    expect(due.lastAmount, 125);
  });

  test('eligibility depends on last date, not an arbitrary amount step', () {
    for (final amount in ['25', '125', '1050', 'unknown']) {
      expect(
          IncrementEligibilityService.dueForMonth(
              'JAN-26/$amount', DateTime(2026, 7)),
          isNotNull);
    }
    expect(
        IncrementEligibilityService.dueForMonth(
                'JAN-26/unknown', DateTime(2026, 7))!
            .lastAmount,
        isNull);
    for (final value in ['', 'bad', 'BAD-26/50', 'JAN-27/50']) {
      expect(IncrementEligibilityService.dueForMonth(value, DateTime(2026, 7)),
          isNull);
    }
  });
}
