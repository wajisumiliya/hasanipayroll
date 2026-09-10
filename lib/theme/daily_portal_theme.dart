import 'package:flutter/material.dart';

class DailyPortalTheme {
  const DailyPortalTheme({
    required this.day,
    required this.quote,
    required this.accent,
    required this.secondary,
    required this.background,
    required this.sidebar,
    required this.header,
    required this.surfaceTint,
  });

  final String day;
  final String quote;
  final Color accent;
  final Color secondary;
  final List<Color> background;
  final List<Color> sidebar;
  final List<Color> header;
  final Color surfaceTint;

  Color get glass => const Color(0xFF241334).withValues(alpha: .92);
  Color get glassStrong => const Color(0xFF12081F).withValues(alpha: .98);
  Color get glassBorder => accent.withValues(alpha: .52);

  static DailyPortalTheme today() => forWeekday(DateTime.now().weekday);

  static DailyPortalTheme forWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return const DailyPortalTheme(
          day: 'Monday',
          quote: 'A focused mind creates extraordinary days.',
          accent: Color(0xFFE8C778),
          secondary: Color(0xFF9C7AC2),
          background: [Color(0xFF10091D), Color(0xFF35204D)],
          sidebar: [Color(0xFF130B22), Color(0xFF2A173E)],
          header: [Color(0xFF1A0F2B), Color(0xFF45275C)],
          surfaceTint: Color(0xFFF7F0E6),
        );
      case DateTime.tuesday:
        return const DailyPortalTheme(
          day: 'Tuesday',
          quote: 'Small steps create great progress.',
          accent: Color(0xFFE2B96B),
          secondary: Color(0xFFA76D86),
          background: [Color(0xFF110A1D), Color(0xFF4B213E)],
          sidebar: [Color(0xFF150C23), Color(0xFF35162C)],
          header: [Color(0xFF20102E), Color(0xFF5B2947)],
          surfaceTint: Color(0xFFF8EEE9),
        );
      case DateTime.wednesday:
        return const DailyPortalTheme(
          day: 'Wednesday',
          quote: 'Halfway there. Keep moving forward.',
          accent: Color(0xFFE7C77E),
          secondary: Color(0xFF668A91),
          background: [Color(0xFF0C111D), Color(0xFF233D43)],
          sidebar: [Color(0xFF101522), Color(0xFF1E3338)],
          header: [Color(0xFF141C2C), Color(0xFF2D4B50)],
          surfaceTint: Color(0xFFF2F1E9),
        );
      case DateTime.thursday:
        return const DailyPortalTheme(
          day: 'Thursday',
          quote: 'Better days are built by consistent effort.',
          accent: Color(0xFFE8C778),
          secondary: Color(0xFF986FA9),
          background: [Color(0xFF10091D), Color(0xFF43254E)],
          sidebar: [Color(0xFF150C23), Color(0xFF321A3A)],
          header: [Color(0xFF21112F), Color(0xFF53305E)],
          surfaceTint: Color(0xFFF5EDF6),
        );
      case DateTime.friday:
        return const DailyPortalTheme(
          day: 'Friday',
          quote: 'Finish strong. You make it happen.',
          accent: Color(0xFFF0D28B),
          secondary: Color(0xFFB98A3D),
          background: [Color(0xFF0D0A12), Color(0xFF382C1D)],
          sidebar: [Color(0xFF110D17), Color(0xFF2B2116)],
          header: [Color(0xFF18121E), Color(0xFF49371F)],
          surfaceTint: Color(0xFFFFF7E7),
        );
      case DateTime.saturday:
        return const DailyPortalTheme(
          day: 'Saturday',
          quote: 'Good energy brings great opportunities.',
          accent: Color(0xFFE6C579),
          secondary: Color(0xFF687DA5),
          background: [Color(0xFF0B1020), Color(0xFF263858)],
          sidebar: [Color(0xFF0E1425), Color(0xFF1C2A45)],
          header: [Color(0xFF141C30), Color(0xFF304666)],
          surfaceTint: Color(0xFFEEF1F7),
        );
      default:
        return const DailyPortalTheme(
          day: 'Sunday',
          quote: 'A calm mind is a powerful mind.',
          accent: Color(0xFFEAD39A),
          secondary: Color(0xFF80739A),
          background: [Color(0xFF0E0B18), Color(0xFF2D2942)],
          sidebar: [Color(0xFF120E1D), Color(0xFF242035)],
          header: [Color(0xFF181324), Color(0xFF39344F)],
          surfaceTint: Color(0xFFF3F0F6),
        );
    }
  }
}

class PortalDayIndicator extends StatelessWidget {
  const PortalDayIndicator({
    super.key,
    required this.theme,
    this.compact = false,
    this.walkDistance = 28,
  });

  final DailyPortalTheme theme;
  final bool compact;
  final double walkDistance;

  @override
  Widget build(BuildContext context) {
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const colors = [
      Color(0xFFE8C778),
      Color(0xFFE2B96B),
      Color(0xFFE7C77E),
      Color(0xFFE8C778),
      Color(0xFFF0D28B),
      Color(0xFFE6C579),
      Color(0xFFEAD39A),
    ];
    final todayIndex = DateTime.now().weekday - 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < labels.length; index++)
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: index == todayIndex ? 9 : 6,
                  height: index == todayIndex ? 9 : 6,
                  decoration: BoxDecoration(
                    color: colors[index],
                    shape: BoxShape.circle,
                    boxShadow: index == todayIndex
                        ? [
                            BoxShadow(
                              color: colors[index].withValues(alpha: .7),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Text(
                    labels[index],
                    style: TextStyle(
                      color:
                          index == todayIndex ? Colors.white : Colors.white54,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class PortalAtmosphere extends StatelessWidget {
  const PortalAtmosphere({
    super.key,
    required this.theme,
  });

  final DailyPortalTheme theme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PortalAtmospherePainter(theme),
        size: Size.infinite,
      ),
    );
  }
}

class _PortalAtmospherePainter extends CustomPainter {
  const _PortalAtmospherePainter(this.theme);

  final DailyPortalTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = theme.accent.withValues(alpha: .16);
    final bright = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = theme.secondary.withValues(alpha: .22);

    for (var index = 0; index < 5; index++) {
      final inset = 28.0 + index * 24;
      canvas.drawArc(
        Rect.fromLTWH(
          size.width - 260 - inset,
          -100 + inset,
          330,
          270,
        ),
        .35,
        2.25,
        false,
        line,
      );
      canvas.drawArc(
        Rect.fromLTWH(
          -170 + inset,
          size.height - 240,
          300,
          250,
        ),
        3.8,
        2.0,
        false,
        line,
      );
    }

    final path = Path()
      ..moveTo(0, size.height * .10)
      ..quadraticBezierTo(
        size.width * .45,
        size.height * .02,
        size.width,
        size.height * .08,
      );
    canvas.drawPath(path, bright);

    // Fine gold diamond details give admin and branch portals a restrained
    // royal finish without reducing dashboard readability.
    final jewel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = theme.accent.withValues(alpha: .24);
    for (final center in <Offset>[
      Offset(size.width * .12, size.height * .16),
      Offset(size.width * .84, size.height * .72),
      Offset(size.width * .72, size.height * .22),
    ]) {
      const radius = 8.0;
      final diamond = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius, center.dy)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - radius, center.dy)
        ..close();
      canvas.drawPath(diamond, jewel);
    }
  }

  @override
  bool shouldRepaint(covariant _PortalAtmospherePainter oldDelegate) =>
      oldDelegate.theme.day != theme.day;
}
