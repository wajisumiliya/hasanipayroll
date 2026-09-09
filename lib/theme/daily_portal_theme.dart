import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'realistic_cat_data.dart';

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

  Color get glass => const Color(0xFF102A43).withValues(alpha: .88);
  Color get glassStrong => const Color(0xFF0B2239).withValues(alpha: .96);
  Color get glassBorder => accent.withValues(alpha: .38);

  static DailyPortalTheme today() => forWeekday(DateTime.now().weekday);

  static DailyPortalTheme forWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return const DailyPortalTheme(
          day: 'Monday',
          quote: 'A focused mind creates extraordinary days.',
          accent: Color(0xFF6FFFD8),
          secondary: Color(0xFF7B74FF),
          background: [Color(0xFF041225), Color(0xFF063C47)],
          sidebar: [Color(0xFF061530), Color(0xFF102C55)],
          header: [Color(0xFF0A2148), Color(0xFF183B74)],
          surfaceTint: Color(0xFFE9F8F6),
        );
      case DateTime.tuesday:
        return const DailyPortalTheme(
          day: 'Tuesday',
          quote: 'Small steps create great progress.',
          accent: Color(0xFFFF8B83),
          secondary: Color(0xFF6BA8FF),
          background: [Color(0xFF07162F), Color(0xFF7A2F42)],
          sidebar: [Color(0xFF07162F), Color(0xFF3B2440)],
          header: [Color(0xFF102B52), Color(0xFF633044)],
          surfaceTint: Color(0xFFFFF0EF),
        );
      case DateTime.wednesday:
        return const DailyPortalTheme(
          day: 'Wednesday',
          quote: 'Halfway there. Keep moving forward.',
          accent: Color(0xFF5DFFD3),
          secondary: Color(0xFF20B8D8),
          background: [Color(0xFF041D32), Color(0xFF075A62)],
          sidebar: [Color(0xFF041D32), Color(0xFF064B53)],
          header: [Color(0xFF062842), Color(0xFF08616A)],
          surfaceTint: Color(0xFFE8F8F5),
        );
      case DateTime.thursday:
        return const DailyPortalTheme(
          day: 'Thursday',
          quote: 'Better days are built by consistent effort.',
          accent: Color(0xFFFFB39E),
          secondary: Color(0xFFB58AFF),
          background: [Color(0xFF17112F), Color(0xFF4B243A)],
          sidebar: [Color(0xFF17112F), Color(0xFF402553)],
          header: [Color(0xFF261948), Color(0xFF633451)],
          surfaceTint: Color(0xFFF8EEF7),
        );
      case DateTime.friday:
        return const DailyPortalTheme(
          day: 'Friday',
          quote: 'Finish strong. You make it happen.',
          accent: Color(0xFFFFD76A),
          secondary: Color(0xFFC99023),
          background: [Color(0xFF080B12), Color(0xFF242018)],
          sidebar: [Color(0xFF080B12), Color(0xFF252017)],
          header: [Color(0xFF11151D), Color(0xFF40341C)],
          surfaceTint: Color(0xFFFFF8E7),
        );
      case DateTime.saturday:
        return const DailyPortalTheme(
          day: 'Saturday',
          quote: 'Good energy brings great opportunities.',
          accent: Color(0xFFB8FF45),
          secondary: Color(0xFF38BEFF),
          background: [Color(0xFF061C54), Color(0xFF0757BD)],
          sidebar: [Color(0xFF061C54), Color(0xFF074583)],
          header: [Color(0xFF082769), Color(0xFF0865A2)],
          surfaceTint: Color(0xFFF1FBE6),
        );
      default:
        return const DailyPortalTheme(
          day: 'Sunday',
          quote: 'A calm mind is a powerful mind.',
          accent: Color(0xFFD8E7FF),
          secondary: Color(0xFF829BC4),
          background: [Color(0xFF071326), Color(0xFF172B4A)],
          sidebar: [Color(0xFF071326), Color(0xFF152541)],
          header: [Color(0xFF0A1930), Color(0xFF243B5D)],
          surfaceTint: Color(0xFFF0F4FA),
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
      Color(0xFF6FFFD8),
      Color(0xFFFF8B83),
      Color(0xFF5DFFD3),
      Color(0xFFFFB39E),
      Color(0xFFFFD76A),
      Color(0xFFB8FF45),
      Color(0xFFD8E7FF),
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
  }

  @override
  bool shouldRepaint(covariant _PortalAtmospherePainter oldDelegate) =>
      oldDelegate.theme.day != theme.day;
}

class PortalCatMascot extends StatefulWidget {
  const PortalCatMascot({
    super.key,
    this.width = 180,
    this.height = 220,
    this.compact = false,
    this.walkDistance = 28,
  });

  final double width;
  final double height;
  final bool compact;
  final double walkDistance;

  @override
  State<PortalCatMascot> createState() => _PortalCatMascotState();
}

class _PortalCatMascotState extends State<PortalCatMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6200),
  )..repeat();

  late final Animation<double> _float = CurvedAnimation(
    parent: _controller,
    curve: Curves.linear,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) {
        final phase = _float.value * math.pi * 2;
        final horizontal = math.sin(phase) * widget.walkDistance;
        final step = math.sin(phase * 4).abs();
        final facingLeft = math.cos(phase) < 0;
        final tilt = math.sin(phase * 4) * .012;

        return Transform.translate(
          offset: Offset(horizontal, -step * 5),
          child: Transform.rotate(
            angle: tilt,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                facingLeft ? -1 : 1,
                1,
                1,
              ),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.compact ? 16 : 24),
          boxShadow: [
            BoxShadow(
              color: DailyPortalTheme.today().accent.withValues(alpha: .22),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          base64Decode(realisticCatBase64),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFF0B2239),
            alignment: Alignment.center,
            child: const Icon(
              Icons.pets,
              color: Colors.white70,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
