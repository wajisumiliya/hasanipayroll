import 'dart:math' as math;

import 'package:flutter/material.dart';

class EmployeeAquariumCard extends StatelessWidget {
  const EmployeeAquariumCard({
    super.key,
    required this.fishCount,
    required this.totalFeed,
    required this.weeklyLogins,
    required this.loginsUntilNextFish,
    this.loading = false,
  });

  final int fishCount;
  final int totalFeed;
  final int weeklyLogins;
  final int loginsUntilNextFish;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final visibleFish = fishCount.clamp(1, 12);
    final weeklyProgress = (weeklyLogins % 5) / 5;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073B72), Color(0xFF087DB5), Color(0xFF20B7C9)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33055B8E), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _AquariumPainter(
                    fishCount: visibleFish,
                    growth: math.min(1, .42 + totalFeed * .025),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.water_rounded,
                              color: Colors.white),
                        ),
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
                              Text('Every login feeds your fish',
                                  style: TextStyle(
                                      color: Color(0xCCFFFFFF), fontSize: 11)),
                            ],
                          ),
                        ),
                        if (loading)
                          const SizedBox.square(
                            dimension: 19,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 82 : 102),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _stat(Icons.set_meal_rounded, '$fishCount', 'Fish'),
                        _stat(Icons.restaurant_rounded, '$totalFeed', 'Feed'),
                        _stat(Icons.login_rounded, '$weeklyLogins / 5',
                            'This week'),
                      ],
                    ),
                    const SizedBox(height: 13),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: weeklyProgress,
                        minHeight: 7,
                        color: const Color(0xFFFFD95A),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '$loginsUntilNextFish more login${loginsUntilNextFish == 1 ? '' : 's'} to welcome a new fish',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xCC06365E),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFFFD95A)),
            const SizedBox(width: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      );
}

class _AquariumPainter extends CustomPainter {
  const _AquariumPainter({required this.fishCount, required this.growth});

  final int fishCount;
  final double growth;

  @override
  void paint(Canvas canvas, Size size) {
    final bubble = Paint()..color = Colors.white.withValues(alpha: .18);
    for (var i = 0; i < 9; i++) {
      final x = (size.width * (.08 + (i * .113) % .84));
      final y = size.height * (.24 + (i * .19) % .48);
      canvas.drawCircle(Offset(x, y), 2.0 + (i % 3) * 1.4, bubble);
    }
    final colors = [
      const Color(0xFFFFD54F),
      const Color(0xFFFF8A65),
      const Color(0xFF7CFFCB),
      const Color(0xFFBFA5FF),
    ];
    for (var i = 0; i < fishCount; i++) {
      final row = i ~/ 6;
      final column = i % 6;
      final x = size.width * (.18 + column * .13) + (row.isEven ? 0 : 18);
      final y = size.height * (.34 + row * .18 + (column.isEven ? .03 : 0));
      final scale = growth * (.78 + (i % 3) * .11);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: .92);
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale);
      canvas.drawOval(const Rect.fromLTWH(-13, -7, 26, 14), paint);
      final tail = Path()
        ..moveTo(-11, 0)
        ..lineTo(-22, -9)
        ..lineTo(-22, 9)
        ..close();
      canvas.drawPath(tail, paint);
      canvas.drawCircle(
          const Offset(7, -2), 1.6, Paint()..color = const Color(0xFF082B4A));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AquariumPainter oldDelegate) =>
      oldDelegate.fishCount != fishCount || oldDelegate.growth != growth;
}
