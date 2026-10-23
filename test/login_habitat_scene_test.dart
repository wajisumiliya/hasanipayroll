import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hasani_payroll_portal/services/mystery_egg_hatch_controller.dart';
import 'package:hasani_payroll_portal/widgets/mystery_egg_teaser.dart';
import 'package:hasani_payroll_portal/services/login_habitat_scene.dart';

void main() {
  test('all 28 habitat images are included in the application asset bundle',
      () async {
    for (var weekday = 1; weekday <= 7; weekday++) {
      for (final period in ['morning', 'afternoon', 'evening', 'night']) {
        final data =
            await rootBundle.load(LoginHabitatScene(weekday, period).asset);
        expect(data.lengthInBytes, greaterThan(8));
        expect(data.getUint32(0), 0x89504e47); // PNG signature
      }
    }
  });

  testWidgets(
      'server hatch confirmation changes the background selection immediately',
      (tester) async {
    final hatch = DateTime.parse('2026-10-23T07:39:11Z');
    var now = hatch.subtract(const Duration(seconds: 5));
    final controller = MysteryEggHatchController(
        load: () async => {
              'hatchAt': hatch.toIso8601String(),
              'serverNow': now.toIso8601String(),
              'stage': now.isBefore(hatch) ? 'egg' : 'chick',
            });
    await tester.pumpWidget(
        MaterialApp(home: MysteryEggTeaser(controller: controller)));
    await tester.pump();
    LoginHabitatScene scene() => loginHabitatScene(
          instant: controller.serverNow!,
          hatchAt: controller.hatchAt,
          hatchConfirmed: controller.stage != 'egg',
        );
    expect(scene().asset, 'assets/login_habitats/friday_afternoon.png');
    now = hatch;
    await controller.refresh();
    expect(scene().asset, 'assets/login_habitats/friday_evening.png');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  test(
      'Malaysia weekday and all four daily boundaries are independent of device timezone',
      () {
    final cases = {
      '2026-10-22T21:59:59Z': 'night', // Friday 05:59:59 MYT
      '2026-10-22T22:00:00Z': 'morning',
      '2026-10-23T03:59:59Z': 'morning',
      '2026-10-23T04:00:00Z': 'afternoon',
      '2026-10-23T08:59:59Z': 'afternoon',
      '2026-10-23T09:00:00Z': 'evening',
      '2026-10-23T11:59:59Z': 'evening',
      '2026-10-23T12:00:00Z': 'night',
    };
    for (final entry in cases.entries) {
      final scene = loginHabitatScene(instant: DateTime.parse(entry.key));
      expect(scene.period, entry.value);
      expect(scene.weekday, DateTime.friday);
    }
    expect(
        loginHabitatScene(instant: DateTime.parse('2026-10-23T16:00:00Z'))
            .weekday,
        DateTime.saturday);
  });

  test(
      'reveal day starts evening only when the hatch is confirmed; night starts at 8 PM',
      () {
    final hatch = DateTime.parse('2026-10-23T07:39:11Z');
    LoginHabitatScene at(String utc, {bool confirmed = true}) =>
        loginHabitatScene(
          instant: DateTime.parse(utc),
          hatchAt: hatch,
          hatchConfirmed: confirmed,
        );
    expect(at('2026-10-23T07:39:10Z').period, 'afternoon');
    expect(at('2026-10-23T07:39:11Z', confirmed: false).period, 'afternoon');
    expect(at('2026-10-23T07:39:11Z').period, 'evening');
    expect(at('2026-10-23T11:59:59Z').period, 'evening');
    expect(at('2026-10-23T12:00:00Z').period, 'night');
    expect(at('2026-10-24T02:00:00Z').period, 'morning');
    expect(at('2026-10-24T07:39:11Z').period, 'afternoon');
  });

  test('the seven days and four periods select 28 distinct assets', () {
    final assets = <String>{};
    for (var day = 0; day < 7; day++) {
      for (final utcHour in [0, 5, 10, 13]) {
        final scene = loginHabitatScene(
            instant: DateTime.utc(2026, 10, 19 + day, utcHour));
        assets.add(scene.asset);
      }
    }
    expect(assets.length, 28);
    expect(assets, contains('assets/login_habitats/friday_evening.png'));
    expect(assets, contains('assets/login_habitats/sunday_night.png'));
  });
}
