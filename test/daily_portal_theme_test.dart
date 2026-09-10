import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/theme/daily_portal_theme.dart';

void main() {
  test('each weekday has a distinct royal palette with a gold accent', () {
    final themes = [
      for (var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++)
        DailyPortalTheme.forWeekday(weekday),
    ];

    expect(themes.map((theme) => theme.day).toSet(), hasLength(7));
    expect(themes.map((theme) => theme.background).toSet(), hasLength(7));

    for (final theme in themes) {
      expect(theme.accent.computeLuminance(), greaterThan(.45));
      expect(theme.background.first.computeLuminance(), lessThan(.02));
      expect(theme.glassBorder.a, greaterThan(0));
    }
  });

  testWidgets('royal atmosphere and day indicator render', (tester) async {
    final theme = DailyPortalTheme.forWeekday(DateTime.monday);

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            PortalAtmosphere(theme: theme),
            PortalDayIndicator(theme: theme),
          ],
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('SUN'), findsOneWidget);
  });
}
