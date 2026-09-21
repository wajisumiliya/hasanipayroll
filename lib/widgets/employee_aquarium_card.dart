import 'dart:math' as math;
import 'package:flutter/material.dart';

class EmployeeAquariumCard extends StatefulWidget {
  const EmployeeAquariumCard(
      {super.key,
      required this.fishCount,
      required this.totalFeed,
      required this.availableFood,
      required this.weeklyLogins,
      required this.loginsUntilNextFish,
      required this.onFeed,
      this.loading = false});
  final int fishCount,
      totalFeed,
      availableFood,
      weeklyLogins,
      loginsUntilNextFish;
  final Future<bool> Function() onFeed;
  final bool loading;
  @override
  State<EmployeeAquariumCard> createState() => _EmployeeAquariumCardState();
}

class _EmployeeAquariumCardState extends State<EmployeeAquariumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _feeding = false;
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
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() => _feeding = false);
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF073B72),
                Color(0xFF087DB5),
                Color(0xFF20B7C9)
              ]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33055B8E), blurRadius: 22, offset: Offset(0, 10))
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
                            fishCount: widget.fishCount.clamp(1, 12),
                            growth: math.min(1, .42 + widget.totalFeed * .025),
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
                            Text('MY LOGIN AQUARIUM',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1)),
                            Text('Login to collect food, then feed your fish',
                                style: TextStyle(
                                    color: Color(0xCCFFFFFF), fontSize: 11)),
                          ])),
                      FilledButton.icon(
                        onPressed: widget.availableFood > 0 && !_feeding
                            ? _feed
                            : null,
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD54F),
                            foregroundColor: const Color(0xFF073B72),
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
                    SizedBox(height: compact ? 88 : 108),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _stat(Icons.set_meal_rounded, '${widget.fishCount}',
                          'Fish'),
                      _stat(Icons.restaurant_rounded, '${widget.totalFeed}',
                          'Eaten'),
                      _stat(Icons.inventory_2_rounded,
                          '${widget.availableFood}', 'Food ready'),
                      _stat(Icons.login_rounded, '${widget.weeklyLogins} / 5',
                          'This week'),
                    ]),
                    const SizedBox(height: 13),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                            value: (widget.weeklyLogins % 5) / 5,
                            minHeight: 7,
                            color: const Color(0xFFFFD95A),
                            backgroundColor: Colors.white24)),
                    const SizedBox(height: 7),
                    Text(
                        '${widget.loginsUntilNextFish} more login${widget.loginsUntilNextFish == 1 ? '' : 's'} to welcome a new fish',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                )),
          ]);
        }),
      );

  Widget _badge(IconData icon) => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24)),
      child: Icon(icon, color: Colors.white));

  Widget _stat(IconData icon, String value, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: const Color(0xCC06365E),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white24)),
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
      {required this.fishCount,
      required this.growth,
      required this.progress,
      required this.feeding,
      required this.feedStart});
  final int fishCount;
  final double growth, progress, feedStart;
  final bool feeding;

  @override
  void paint(Canvas canvas, Size size) {
    final bubble = Paint()..color = Colors.white.withValues(alpha: .18);
    for (var i = 0; i < 10; i++) {
      final phase = (progress + i * .13) % 1;
      canvas.drawCircle(
          Offset(size.width * (.06 + (i * .117) % .88),
              size.height * (.76 - phase * .58)),
          2.0 + (i % 3) * 1.3,
          bubble);
    }
    if (feeding) {
      final elapsed = (progress - feedStart + 1) % 1;
      final foodPaint = Paint()..color = const Color(0xFFFFC928);
      for (var i = 0; i < 7; i++) {
        final fall = ((elapsed * 4) + i * .11) % 1;
        canvas.drawCircle(
            Offset(size.width * (.43 + (i % 4) * .045), 48 + fall * 90),
            2.5,
            foodPaint);
      }
    }
    const colors = [
      Color(0xFFFFD54F),
      Color(0xFFFF8A65),
      Color(0xFF7CFFCB),
      Color(0xFFBFA5FF)
    ];
    for (var i = 0; i < fishCount; i++) {
      final direction = i.isEven ? 1.0 : -1.0;
      final travel = (progress * (.45 + i * .035) + i * .17) % 1;
      final x = direction > 0
          ? -25 + travel * (size.width + 50)
          : size.width + 25 - travel * (size.width + 50);
      final y = size.height * (.31 + (i % 4) * .085) +
          math.sin(progress * math.pi * 2 + i) * 6;
      final scale = growth * (.80 + (i % 3) * .11);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: .95);
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(direction * scale, scale);
      canvas.drawOval(const Rect.fromLTWH(-13, -7, 26, 14), paint);
      canvas.drawPath(
          Path()
            ..moveTo(-11, 0)
            ..lineTo(-22, -9)
            ..lineTo(-22, 9)
            ..close(),
          paint);
      canvas.drawCircle(
          const Offset(7, -2), 1.6, Paint()..color = const Color(0xFF082B4A));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AquariumPainter oldDelegate) => true;
}
