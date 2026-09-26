import 'dart:math' as math;
import 'package:flutter/material.dart';

class EmployeeAquariumCard extends StatefulWidget {
  const EmployeeAquariumCard(
      {super.key,
      required this.employeeId,
      required this.fishCount,
      required this.totalFeed,
      required this.availableFood,
      required this.weeklyLogins,
      required this.loginsUntilNextFish,
      required this.deadFishCount,
      required this.fishBirthDates,
      required this.onFeed,
      required this.onClean,
      this.loading = false});
  final String employeeId;
  final int fishCount,
      totalFeed,
      availableFood,
      weeklyLogins,
      loginsUntilNextFish,
      deadFishCount;
  final List<DateTime> fishBirthDates;
  final Future<bool> Function() onFeed;
  final Future<bool> Function() onClean;
  final bool loading;
  @override
  State<EmployeeAquariumCard> createState() => _EmployeeAquariumCardState();
}

class _EmployeeAquariumCardState extends State<EmployeeAquariumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _feeding = false;
  bool _thanking = false;
  bool _cleaning = false;
  bool _nightMode = true;
  double _feedStart = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 7))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _feed() async {
    if (_feeding || widget.availableFood < 1) return;
    setState(() {
      _feeding = true;
      _feedStart = _controller.value;
    });
    final fed = await widget.onFeed();
    if (!mounted) return;
    if (!fed) {
      setState(() => _feeding = false);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    if (mounted) setState(() => _thanking = true);
    await Future<void>.delayed(const Duration(milliseconds: 1250));
    if (mounted) {
      setState(() {
        _feeding = false;
        _thanking = false;
      });
    }
  }

  Future<void> _clean() async {
    if (_cleaning || widget.deadFishCount < 1) return;
    setState(() => _cleaning = true);
    await widget.onClean();
    if (mounted) setState(() => _cleaning = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 550),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _nightMode
                  ? const [
                      Color(0xFF03070D),
                      Color(0xFF071C2A),
                      Color(0xFF06394A),
                    ]
                  : const [
                      Color(0xFF073B72),
                      Color(0xFF087DB5),
                      Color(0xFF20B7C9),
                    ]),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFD7B65D), width: 2.2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x99000612),
                blurRadius: 34,
                offset: Offset(0, 18)),
            BoxShadow(
                color: Color(0x66E8C86D),
                blurRadius: 16,
                offset: Offset(0, -2)),
          ],
        ),
        child: LayoutBuilder(builder: (_, constraints) {
          final compact = constraints.maxWidth < 520;
          return Stack(children: [
            Positioned.fill(
                child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) => CustomPaint(
                        painter: _AquariumPainter(
                            employeeId: widget.employeeId,
                            fishCount: widget.fishCount.clamp(2, 10),
                            fishBirthDates: widget.fishBirthDates,
                            deadFishCount: widget.deadFishCount,
                            nightMode: _nightMode,
                            growth:
                                math.min(1.25, .78 + widget.totalFeed * .018),
                            progress: _controller.value,
                            feeding: _feeding,
                            feedStart: _feedStart)))),
            Padding(
                padding: EdgeInsets.all(compact ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _badge(Icons.water_rounded),
                      const SizedBox(width: 11),
                      const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('THE GRAND AQUARIUM',
                                style: TextStyle(
                                    color: Color(0xFFFFE9A9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5)),
                            Text('A living collection shaped by every login',
                                style: TextStyle(
                                    color: Color(0xCCFFFFFF), fontSize: 11)),
                          ])),
                      IconButton.filledTonal(
                        tooltip: _nightMode ? 'Day view' : 'Night view',
                        onPressed: () =>
                            setState(() => _nightMode = !_nightMode),
                        icon: Icon(_nightMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded),
                      ),
                      const SizedBox(width: 6),
                      if (widget.deadFishCount > 0) ...[
                        FilledButton.icon(
                          onPressed: _cleaning ? null : _clean,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE8A3),
                            foregroundColor: const Color(0xFF302000),
                          ),
                          icon: _cleaning
                              ? const SizedBox.square(
                                  dimension: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cleaning_services_rounded,
                                  size: 17),
                          label: Text('CLEAN ${widget.deadFishCount}'),
                        ),
                        const SizedBox(width: 6),
                      ],
                      FilledButton.icon(
                        onPressed: widget.availableFood > 0 && !_feeding
                            ? _feed
                            : null,
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE1BD5B),
                            foregroundColor: const Color(0xFF211600),
                            disabledBackgroundColor: Colors.white24,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10)),
                        icon: _feeding
                            ? const SizedBox.square(
                                dimension: 15,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.restaurant_rounded, size: 18),
                        label: Text(widget.availableFood > 0
                            ? 'FEED  ${widget.availableFood}'
                            : 'NO FOOD'),
                      ),
                    ]),
                    SizedBox(height: compact ? 128 : 148),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _stat(Icons.set_meal_rounded, '${widget.fishCount}',
                          'Fish'),
                      _stat(Icons.restaurant_rounded, '${widget.totalFeed}',
                          'Eaten'),
                      _stat(Icons.inventory_2_rounded,
                          '${widget.availableFood}', 'Food ready'),
                      _stat(
                          Icons.login_rounded,
                          widget.fishCount >= 10
                              ? 'MAX'
                              : '${widget.weeklyLogins % 4} / 4',
                          'Login cycle'),
                    ]),
                    const SizedBox(height: 13),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                            value: widget.fishCount >= 10
                                ? 1
                                : (widget.weeklyLogins % 4) / 4,
                            minHeight: 7,
                            color: const Color(0xFFFFD95A),
                            backgroundColor: Colors.white24)),
                    const SizedBox(height: 7),
                    Text(
                        widget.fishCount >= 10
                            ? 'Aquarium complete — maximum 10 fish reached!'
                            : '${widget.loginsUntilNextFish} more login${widget.loginsUntilNextFish == 1 ? '' : 's'} to welcome a new fish',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                )),
            Positioned(
              top: compact ? 88 : 96,
              right: compact ? 20 : 34,
              child: AnimatedScale(
                scale: _thanking ? 1 : .75,
                duration: const Duration(milliseconds: 280),
                curve: Curves.elasticOut,
                child: AnimatedOpacity(
                  opacity: _thanking ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 10)
                      ],
                    ),
                    child: const Text('Yum! Thank you!  ❤',
                        style: TextStyle(
                            color: Color(0xFF075485),
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ),
          ]);
        }),
      );

  Widget _badge(IconData icon) => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE4C668), Color(0xFF7B5B17)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE9A9)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x44002040), blurRadius: 7, offset: Offset(0, 4)),
          ]),
      child: Icon(icon, color: const Color(0xFF151006)));

  Widget _stat(IconData icon, String value, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF0152029), Color(0xF0030A11)],
          ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0x99D7B65D)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x55001832), blurRadius: 6, offset: Offset(0, 4)),
          ]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: const Color(0xFFFFD95A)),
        const SizedBox(width: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]));
}

class _AquariumPainter extends CustomPainter {
  const _AquariumPainter(
      {required this.employeeId,
      required this.fishCount,
      required this.fishBirthDates,
      required this.deadFishCount,
      required this.nightMode,
      required this.growth,
      required this.progress,
      required this.feeding,
      required this.feedStart});
  final int fishCount;
  final int deadFishCount;
  final List<DateTime> fishBirthDates;
  final bool nightMode;
  final String employeeId;
  final double growth, progress, feedStart;
  final bool feeding;

  @override
  void paint(Canvas canvas, Size size) {
    // Polished metal canopy and base turn the tank into a display piece.
    final gold = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6F5014), Color(0xFFFFE7A0), Color(0xFF9A7428)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 10));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 7), gold);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 7, size.width, 7),
      gold,
    );
    canvas.drawRect(
      Rect.fromLTWH(10, 7, 2, size.height - 14),
      Paint()..color = const Color(0x66FFE7A0),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - 12, 7, 2, size.height - 14),
      Paint()..color = const Color(0x66FFE7A0),
    );

    if (nightMode) {
      for (var i = 0; i < 5; i++) {
        final lightX = size.width * (.14 + i * .18);
        canvas.drawPath(
          Path()
            ..moveTo(lightX - 13, 0)
            ..lineTo(lightX + 13, 0)
            ..lineTo(lightX + 58, size.height * .72)
            ..lineTo(lightX - 58, size.height * .72)
            ..close(),
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0x554DEBFF), Color(0x004DEBFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(lightX, 4), width: 26, height: 7),
            const Radius.circular(4),
          ),
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFFFF3BA), Color(0xFF63E9FF)],
            ).createShader(Rect.fromCenter(
              center: Offset(lightX, 4),
              width: 26,
              height: 7,
            )),
        );
      }

      // Animated RGB spotlights sweep slowly across the luxury display.
      for (var i = 0; i < 4; i++) {
        final phase = progress * math.pi * 2 + i * math.pi / 2;
        final lampX = size.width * (.22 + i * .19);
        final targetX = lampX + math.sin(phase) * size.width * .18;
        final color = HSVColor.fromAHSV(
          1,
          (progress * 360 + i * 92) % 360,
          .78,
          1,
        ).toColor();
        canvas.drawPath(
          Path()
            ..moveTo(lampX - 7, 7)
            ..lineTo(lampX + 7, 7)
            ..lineTo(targetX + 46, size.height * .82)
            ..lineTo(targetX - 46, size.height * .82)
            ..close(),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: .25),
                color.withValues(alpha: .03),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
        );
        canvas.drawCircle(
          Offset(lampX, 9),
          5.5,
          Paint()
            ..color = color
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
        canvas.drawCircle(
          Offset(lampX, 9),
          2.6,
          Paint()..color = Colors.white,
        );
      }
    }
    // Soft glass highlights and light rays make the water feel dimensional.
    final rayPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x22FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .08, 0)
        ..lineTo(size.width * .30, 0)
        ..lineTo(size.width * .48, size.height)
        ..lineTo(size.width * .31, size.height)
        ..close(),
      rayPaint,
    );

    // Moving surface reflections and suspended particles keep the water from
    // looking like a flat background.
    final surfaceLight = Paint()
      ..color = Colors.white.withValues(alpha: nightMode ? .18 : .12)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 7; i++) {
      final phase = progress * math.pi * 2 + i * .9;
      final x = size.width * (.07 + i * .145) + math.sin(phase) * 10;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(x, 13 + (i % 2) * 5),
          width: 34,
          height: 8,
        ),
        0,
        math.pi,
        false,
        surfaceLight,
      );
    }
    final particlePaint = Paint()
      ..color = const Color(0xFFC8F7F4).withValues(alpha: .16);
    for (var i = 0; i < 22; i++) {
      final drift = (progress * (.05 + (i % 4) * .012) + i * .071) % 1;
      canvas.drawCircle(
        Offset(
          size.width * ((i * .137 + drift * .08) % 1),
          size.height * (.16 + ((i * .113 + drift) % .58)),
        ),
        .7 + (i % 3) * .45,
        particlePaint,
      );
    }

    // A faint panoramic reflection across the curved glass.
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .03, size.height * .12)
        ..quadraticBezierTo(
          size.width * .48,
          size.height * .03,
          size.width * .84,
          size.height * .15,
        ),
      Paint()
        ..color = Colors.white.withValues(alpha: .10)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );

    final floorY = size.height * .69;
    canvas.drawRect(Rect.fromLTRB(0, floorY, size.width, size.height),
        Paint()..color = const Color(0xFF075B78).withValues(alpha: .30));
    final sand = Paint()
      ..color = const Color(0xFFD9B868).withValues(alpha: .46);
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height * .82)
          ..quadraticBezierTo(size.width * .25, size.height * .75,
              size.width * .48, size.height * .84)
          ..quadraticBezierTo(size.width * .72, size.height * .91, size.width,
              size.height * .78)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        sand);

    if (nightMode) {
      // Colored caustics glide over the sand with the moving spotlights.
      for (var i = 0; i < 5; i++) {
        final phase = progress * math.pi * 2 + i * 1.25;
        final color = HSVColor.fromAHSV(
          1,
          (progress * 360 + i * 74) % 360,
          .72,
          1,
        ).toColor();
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              size.width * (.13 + i * .19) + math.sin(phase) * 18,
              size.height * (.84 + math.cos(phase) * .015),
            ),
            width: 58,
            height: 10,
          ),
          Paint()
            ..color = color.withValues(alpha: .20)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }

    final gravelColors = [
      const Color(0xFFC9A35E),
      const Color(0xFF8E7757),
      const Color(0xFFE0C77C),
      const Color(0xFF718B7B),
    ];
    for (var i = 0; i < 34; i++) {
      final gx = size.width * ((i * .083 + .017) % 1);
      final gy = size.height * (.84 + (i % 4) * .035);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(gx, gy),
          width: 7 + (i % 4).toDouble(),
          height: 4 + (i % 3).toDouble(),
        ),
        Paint()
          ..color =
              gravelColors[i % gravelColors.length].withValues(alpha: .80),
      );
    }

    final caveRect = Rect.fromLTWH(size.width * .69, size.height * .69,
        size.width * .14, size.height * .18);
    canvas.drawOval(caveRect, Paint()..color = const Color(0xFF415D63));
    canvas.drawOval(
      Rect.fromLTWH(size.width * .725, size.height * .745, size.width * .07,
          size.height * .12),
      Paint()..color = const Color(0xFF062F43),
    );

    // Layered river stones and driftwood create a more natural habitat.
    for (var i = 0; i < 5; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * (.24 + i * .045),
              size.height * (.82 + (i % 2) * .025)),
          width: 29 - i * 2,
          height: 13 + (i % 2) * 3,
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF314A4B),
            const Color(0xFF8C7658),
            i / 5,
          )!,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .30, size.height * .83)
        ..cubicTo(size.width * .39, size.height * .72, size.width * .49,
            size.height * .78, size.width * .58, size.height * .70)
        ..cubicTo(size.width * .50, size.height * .84, size.width * .39,
            size.height * .88, size.width * .30, size.height * .86),
      Paint()
        ..color = const Color(0xFF694A31)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Small floor creatures make the habitat feel alive without competing
    // with the Betta fish. Crabs scuttle sideways while the starfish and
    // seashells remain settled into the sand.
    for (var i = 0; i < 2; i++) {
      final crabPhase = progress * math.pi * 2 * (.55 + i * .08) + i * 2.4;
      canvas.save();
      canvas.translate(
        size.width * (i == 0 ? .18 : .78) + math.sin(crabPhase) * 17,
        size.height * (i == 0 ? .84 : .88),
      );
      canvas.scale(i == 0 ? .78 : .62);
      _drawCrab(canvas, crabPhase, i);
      canvas.restore();
    }

    canvas.save();
    canvas.translate(size.width * .63, size.height * .865);
    canvas.rotate(-.24 + math.sin(progress * math.pi * 2) * .025);
    _drawStarfish(canvas, 12.0, const Color(0xFFFF8A55));
    canvas.restore();

    _drawSeashell(
      canvas,
      Offset(size.width * .39, size.height * .89),
      12,
      const Color(0xFFFFD6B2),
    );
    _drawSeashell(
      canvas,
      Offset(size.width * .55, size.height * .91),
      9,
      const Color(0xFFD9B8FF),
    );
    _drawSeashell(
      canvas,
      Offset(size.width * .91, size.height * .88),
      10,
      const Color(0xFFFFE49A),
    );

    final filterX = size.width * .94;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(filterX, size.height * .17, 11, size.height * .27),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0x88445F6D),
    );
    canvas.drawLine(
      Offset(filterX + 5, size.height * .17),
      Offset(filterX - 14, size.height * .17),
      Paint()
        ..color = const Color(0xAA5F7C88)
        ..strokeWidth = 4,
    );
    // Oxygen motor, hose and diffuser stone.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .88, size.height * .10, 34, 25),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xCC263946),
    );
    canvas.drawCircle(Offset(size.width * .905, size.height * .145), 5,
        Paint()..color = const Color(0xFF70E6EC));
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .90, size.height * .20)
        ..cubicTo(size.width * .84, size.height * .34, size.width * .91,
            size.height * .64, size.width * .86, size.height * .82),
      Paint()
        ..color = const Color(0xAA9AE8EA)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * .86, size.height * .83),
          width: 25,
          height: 7),
      Paint()..color = const Color(0xFF566F75),
    );
    final plant = Paint()
      ..color = const Color(0xFF28B982).withValues(alpha: .78)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final x in [
      size.width * .07,
      size.width * .12,
      size.width * .18,
      size.width * .87,
      size.width * .92,
    ]) {
      final sway = math.sin(progress * math.pi * 2 + x * .03) * 9;
      canvas.drawPath(
          Path()
            ..moveTo(x, size.height * .88)
            ..quadraticBezierTo(x - 12 + sway * .35, size.height * .68,
                x + 3 + sway, size.height * .56),
          plant);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - 5 + sway * .45, size.height * .67),
          width: 15,
          height: 6,
        ),
        Paint()..color = const Color(0xAA35C98D),
      );
    }

    final bubble = Paint()..color = Colors.white.withValues(alpha: .18);
    for (var i = 0; i < 10; i++) {
      final phase = (progress + i * .13) % 1;
      canvas.drawCircle(
          Offset(size.width * (.06 + (i * .117) % .88),
              size.height * (.76 - phase * .58)),
          2.0 + (i % 3) * 1.3,
          bubble);
    }
    for (var i = 0; i < 8; i++) {
      final phase = (progress * 1.35 + i * .105) % 1;
      canvas.drawCircle(
        Offset(filterX - 10 + math.sin(phase * math.pi * 5) * 4,
            size.height * (.66 - phase * .48)),
        1.8 + (i % 3),
        Paint()
          ..color = Colors.white.withValues(alpha: .28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    if (feeding) {
      final elapsed = math.min(1.0, ((progress - feedStart + 1) % 1) / .33);
      final foodPaint = Paint()..color = const Color(0xFFFFC928);
      for (var i = 0; i < 7; i++) {
        final fall = (elapsed * 1.25 - i * .08).clamp(0.0, 1.0);
        if (fall >= 1) continue;
        canvas.drawCircle(
            Offset(size.width * (.67 + (i % 4) * .025),
                58 + fall * size.height * .34),
            2.5,
            foodPaint);
      }
    }
    final identitySeed = employeeId.codeUnits.fold<int>(
        0, (value, character) => (value * 31 + character) & 0x7fffffff);
    final baseHue = (identitySeed % 360).toDouble();
    final colors = List<Color>.generate(
      5,
      (index) => HSLColor.fromAHSL(
        1,
        (baseHue + index * 71 + (identitySeed % 29)) % 360,
        .76 - (index.isOdd ? .08 : 0),
        .57 + (index % 3) * .035,
      ).toColor(),
    );
    for (var i = 0; i < fishCount; i++) {
      final phase = (progress * (.52 + i * .037) + i * .173) % 1;
      // Cosine easing slows the fish at each glass wall before it turns.
      final pingPong = .5 - .5 * math.cos(phase * math.pi * 2);
      final movingRight = math.sin(phase * math.pi * 2) > 0;
      final margin = 34.0 + (i % 3) * 5;
      var x = margin + pingPong * math.max(0, size.width - margin * 2);
      var y = size.height * (.32 + (i % 4) * .085) +
          math.sin(progress * math.pi * 2 * (.7 + i * .04) + i * 1.7) * 10;

      var feedApproach = 0.0;
      if (feeding) {
        final elapsed = math.min(1.0, ((progress - feedStart + 1) % 1) / .33);
        feedApproach = Curves.easeInOut.transform(math.sin(elapsed * math.pi));
        final targetX = size.width * .70;
        final targetY = 58 + size.height * .34;
        x = x + (targetX - x) * feedApproach;
        y = y + (targetY - y) * feedApproach;
      }

      final verticalSlope =
          math.cos(progress * math.pi * 2 * (.7 + i * .04) + i * 1.7) * .15;
      final angle = verticalSlope * (movingRight ? 1 : -1);
      final ageDays = i < fishBirthDates.length
          ? DateTime.now().difference(fishBirthDates[i]).inDays.clamp(0, 90)
          : (i < 3 ? 45 : (i == 3 ? 18 : 1));
      final naturalGrowth = .43 + (ageDays / 45).clamp(0.0, 1.0) * .72;
      final scale = growth * naturalGrowth;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.scale((movingRight ? 1.0 : -1.0) * scale, scale);
      canvas.drawOval(
        const Rect.fromLTWH(-15, 7, 31, 6),
        Paint()..color = Colors.black.withValues(alpha: .10),
      );
      _drawBettaFish(
        canvas,
        colors[i % colors.length],
        progress * math.pi * 2,
        i,
      );
      canvas.restore();
    }

    // Dead fish stay visible on the floor until the employee cleans the tank.
    for (var i = 0; i < deadFishCount; i++) {
      canvas.save();
      canvas.translate(size.width * (.42 + i * .075), size.height * .82);
      canvas.rotate(math.pi + .10 * math.sin(progress * math.pi * 2 + i));
      canvas.scale(.62, .62);
      _drawBettaFish(canvas, const Color(0xFF7B8588), 0, i);
      canvas.drawLine(
          const Offset(5, -5),
          const Offset(10, 0),
          Paint()
            ..color = const Color(0xFF243238)
            ..strokeWidth = 1.5);
      canvas.drawLine(
          const Offset(10, -5),
          const Offset(5, 0),
          Paint()
            ..color = const Color(0xFF243238)
            ..strokeWidth = 1.5);
      canvas.restore();
    }
  }

  void _drawCrab(Canvas canvas, double phase, int index) {
    final bodyColor =
        index.isEven ? const Color(0xFFFF695E) : const Color(0xFFFFA052);
    final dark = Color.lerp(bodyColor, const Color(0xFF6F2630), .38)!;
    final legPaint = Paint()
      ..color = dark
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final step = math.sin(phase * 3) * 2.4;
    for (var side = -1; side <= 1; side += 2) {
      for (var leg = 0; leg < 3; leg++) {
        final y = -1.0 + leg * 4;
        canvas.drawPath(
          Path()
            ..moveTo(side * 8, y)
            ..lineTo(side * (14 + leg * 2), y + 3 + step * side)
            ..lineTo(side * (18 + leg * 2), y + 7),
          legPaint,
        );
      }
    }
    canvas.drawOval(
      const Rect.fromLTWH(-11, -7, 22, 15),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bodyColor, dark],
        ).createShader(const Rect.fromLTWH(-11, -7, 22, 15)),
    );
    for (final side in const [-1.0, 1.0]) {
      canvas.drawLine(const Offset(0, -5), Offset(side * 6, -12), legPaint);
      canvas.drawCircle(
        Offset(side * 6, -13),
        2.3,
        Paint()..color = const Color(0xFFF8F3DF),
      );
      canvas.drawCircle(
        Offset(side * 6, -13),
        .9,
        Paint()..color = const Color(0xFF101419),
      );
      final clawLift = math.sin(phase * 2 + side) * 2;
      canvas.drawLine(
        Offset(side * 9, -3),
        Offset(side * 17, -10 - clawLift),
        legPaint,
      );
      canvas.drawCircle(
        Offset(side * 19, -11 - clawLift),
        4.4,
        Paint()..color = bodyColor,
      );
      canvas.drawLine(
        Offset(side * 19, -15 - clawLift),
        Offset(side * 19, -8 - clawLift),
        Paint()
          ..color = dark
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawStarfish(Canvas canvas, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final length = i.isEven ? radius : radius * .42;
      final point = Offset(math.cos(angle) * length, math.sin(angle) * length);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(color, Colors.white, .28)!, color],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      canvas.drawCircle(
        Offset(math.cos(angle) * radius * .36, math.sin(angle) * radius * .36),
        1,
        Paint()..color = Colors.white.withValues(alpha: .45),
      );
    }
  }

  void _drawSeashell(Canvas canvas, Offset center, double radius, Color color) {
    final shellRect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 1.45,
    );
    canvas.drawArc(
      shellRect,
      math.pi,
      math.pi,
      true,
      Paint()
        ..shader = LinearGradient(
          colors: [color, Color.lerp(color, const Color(0xFF8D5B58), .34)!],
        ).createShader(shellRect),
    );
    final ridge = Paint()
      ..color = Colors.white.withValues(alpha: .46)
      ..strokeWidth = .9;
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(
        Offset(center.dx, center.dy),
        Offset(center.dx + i * radius * .34, center.dy - radius * .58),
        ridge,
      );
    }
  }

  void _drawBettaFish(Canvas canvas, Color color, double time, int fishIndex) {
    final wave = math.sin(time * 6.2 + fishIndex * 1.37);
    final finWave = math.sin(time * 4.8 + fishIndex * .91);
    final dark = HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness - .20).clamp(0, 1))
        .toColor();
    final light = HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness + .18).clamp(0, 1))
        .toColor();

    // A broad, layered fan tail gives the fish its Betta silhouette. Each
    // control point moves at a slightly different rate for a soft fabric-like
    // swimming motion instead of a rigid pivot.
    final tail = Path()
      ..moveTo(-9, -3)
      ..cubicTo(-17, -14 - wave * 2, -30, -16 + finWave * 2, -32, -5 + wave * 3)
      ..cubicTo(-29, -1, -29, 2, -33, 7 + finWave * 2)
      ..cubicTo(-26, 17 + wave * 2, -16, 13 - finWave * 2, -9, 4)
      ..close();
    canvas.drawPath(
      tail,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: .88),
            light.withValues(alpha: .55),
            dark.withValues(alpha: .72),
          ],
        ).createShader(const Rect.fromLTWH(-34, -18, 27, 36)),
    );

    final dorsalFin = Path()
      ..moveTo(-8, -5)
      ..quadraticBezierTo(-4, -14 - finWave * 2, 5, -7)
      ..lineTo(7, -4)
      ..close();
    final lowerFin = Path()
      ..moveTo(-5, 5)
      ..quadraticBezierTo(1, 16 + wave * 2, 9, 5)
      ..close();
    final finPaint = Paint()
      ..color = light.withValues(alpha: .62)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dorsalFin, finPaint);
    canvas.drawPath(lowerFin, finPaint);

    canvas.drawOval(
      const Rect.fromLTWH(-12, -7, 26, 14),
      Paint()
        ..shader = LinearGradient(
          colors: [dark, color, light],
          stops: const [0, .55, 1],
        ).createShader(const Rect.fromLTWH(-12, -7, 26, 14)),
    );

    // Translucent pectoral fins flutter independently from the tail.
    canvas.save();
    canvas.rotate(finWave * .16);
    canvas.drawOval(
      const Rect.fromLTWH(-1, 1, 10, 4),
      Paint()..color = Colors.white.withValues(alpha: .24),
    );
    canvas.restore();
    canvas.drawArc(
      const Rect.fromLTWH(-5, -5, 12, 10),
      -.9,
      1.5,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .24)
        ..strokeWidth = 1.1
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
        const Offset(8, -2), 1.7, Paint()..color = const Color(0xFF04192E));
    canvas.drawCircle(
        const Offset(8.5, -2.5), .55, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _AquariumPainter oldDelegate) => true;
}
