import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/neon_api.dart';

/// Server-backed penguin companion. Growth and care use server time.
class EmployeePenguinPetCard extends StatefulWidget {
  const EmployeePenguinPetCard({super.key});

  @override
  State<EmployeePenguinPetCard> createState() => _EmployeePenguinPetCardState();
}

class _EmployeePenguinPetCardState extends State<EmployeePenguinPetCard> {
  Map<String, dynamic>? pet;
  bool busy = false;
  bool sleeping = false;
  String action = 'idle';
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? careAction]) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      if (careAction != null) {
        action = careAction == 'feed' ? 'eating' : 'playing';
        sleeping = false;
      }
    });
    try {
      final data = await NeonApi.jsonRequest(
        careAction == null
            ? '/api/employee/penguin'
            : '/api/employee/penguin/$careAction',
        method: careAction == null ? 'GET' : 'POST',
      );
      if (mounted) {
        setState(() => pet = Map<String, dynamic>.from(data['pet'] as Map));
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Penguin home is temporarily unavailable.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (careAction != null) {
          Future<void>.delayed(
            Duration(milliseconds: careAction == 'feed' ? 2200 : 3000),
            () {
              if (mounted) setState(() => action = 'idle');
            },
          );
        }
      }
    }
  }

  void _toggleSleep() {
    setState(() {
      sleeping = !sleeping;
      action = sleeping ? 'sleeping' : 'idle';
    });
  }

  @override
  Widget build(BuildContext context) {
    final stage = pet?['stage']?.toString() ?? 'egg';
    final days = pet?['ageDays'] ?? 0;
    final fed = pet?['fedToday'] == true;
    final played = pet?['playedToday'] == true;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB6DFF4), Color(0xFFF3FBFF)],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MY LIVING PENGUIN',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF173D60),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Semantics(
                label: 'Penguin growth stage: $stage',
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: PenguinIllustration(
                    key: ValueKey(stage),
                    stage: stage,
                    action: action,
                    onTap: _toggleSleep,
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                '${pet?['nickname'] ?? 'Pingu'} • Day $days • ${stage.toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Center(
              child: Text(
                'Tap your penguin to let it nap or wake it up',
                style: TextStyle(fontSize: 11, color: Color(0xFF426680)),
              ),
            ),
            const SizedBox(height: 12),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (pet == null && busy)
              const Center(child: CircularProgressIndicator()),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      busy || pet == null || fed ? null : () => _load('feed'),
                  icon: const Icon(Icons.set_meal),
                  label: Text(fed ? 'Fed today' : 'Feed fish'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || pet == null || played
                      ? null
                      : () => _load('play'),
                  icon: const Icon(Icons.sports_esports),
                  label: Text(played ? 'Played today' : 'Play'),
                ),
                IconButton(
                  tooltip: 'Refresh penguin',
                  onPressed: busy ? null : () => _load(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Your penguin grows with time, even when you are away. Feeding and play become available again after 24 hours.',
              style: TextStyle(fontSize: 12, color: Color(0xFF425F74)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Original vector penguin, animated locally without downloaded artwork.
class PenguinIllustration extends StatefulWidget {
  const PenguinIllustration({
    super.key,
    required this.stage,
    this.action = 'idle',
    this.onTap,
  });

  final String stage;
  final String action;
  final VoidCallback? onTap;

  @override
  State<PenguinIllustration> createState() => _PenguinIllustrationState();
}

class _PenguinIllustrationState extends State<PenguinIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion && motion.isAnimating) motion.stop();
    if (!reduceMotion && !motion.isAnimating) motion.repeat();

    return Semantics(
      button: widget.onTap != null,
      label: widget.action == 'sleeping'
          ? 'Sleeping penguin. Tap to wake.'
          : 'Penguin. Tap to sleep.',
      onTap: widget.onTap,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          height: 190,
          width: 220,
          child: AnimatedBuilder(
            animation: motion,
            builder: (context, _) => CustomPaint(
              painter: _PenguinPainter(
                stage: widget.stage,
                action: widget.action,
                phase: reduceMotion ? 0 : motion.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PenguinPainter extends CustomPainter {
  const _PenguinPainter({
    required this.stage,
    required this.action,
    required this.phase,
  });

  final String stage;
  final String action;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = const Color(0xFF6B7280);
    final detail = Paint()..color = const Color(0xFF26313A);\n    final belly = Paint()..color = const Color(0xFFFFFFFF);
    final orange = Paint()..color = const Color(0xFFFF8A00);\n    final green = Paint()..color = const Color(0xFFA8E63E);
    final accent = Paint()..color = const Color(0xFF54B8DD);
    final shadow = Paint()..color = const Color(0x44265A78);
    final asleep = action == 'sleeping';
    final eating = action == 'eating';
    final playing = action == 'playing';
    final walking = playing || action == 'waddling';
    final swing = math.sin(phase * math.pi * 2);
    final breath = math.sin(phase * math.pi * 2) * .018;
    final blink = !asleep && !eating && phase > .49 && phase < .535;

    canvas.drawOval(
      Rect.fromLTWH(size.width * .13, size.height * .88, size.width * .74, 13),
      shadow,
    );

    if (stage == 'egg') {
      final egg = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * .51),
        width: 79,
        height: 126,
      );
      canvas.drawOval(
        egg,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFE3F0F4)],
          ).createShader(egg),
      );
      canvas.drawOval(
        egg,
        Paint()
          ..color = const Color(0xFFB6C9D3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }

    final scale = stage == 'chick'
        ? .76
        : stage == 'juvenile'
            ? .89
            : 1.0;
    final center = Offset(size.width / 2, size.height * .88);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(
      asleep
          ? -.08
          : walking
              ? swing * .07
              : swing * .012,
    );
    canvas.scale(scale * (1 + (asleep ? 0 : breath)));
    canvas.translate(-center.dx, -center.dy);

    // Tail and body silhouette.
    canvas.drawOval(Rect.fromLTWH(88, 50, 45, 104), body);
    canvas.drawOval(Rect.fromLTWH(59, 35, 102, 132), body);\n    // Orange crown and white face mask match the supplied penguin reference.\n    canvas.drawOval(Rect.fromLTWH(64, 29, 92, 82), orange);

    // Flippers swing while walking or playing.
    canvas.save();
    canvas.translate(70, 108);
    canvas.rotate(walking ? -.25 + swing * .24 : -.05 + swing * .035);
    canvas.drawOval(Rect.fromLTWH(-15, -8, 31, 70), body);
    canvas.restore();
    canvas.save();
    canvas.translate(150, 108);
    canvas.rotate(walking ? .25 - swing * .24 : .05 - swing * .035);
    canvas.drawOval(Rect.fromLTWH(-1, -8, 31, 70), body);
    canvas.restore();

    // Warm white facial mask and softly shaded belly.
    final chest = Rect.fromLTWH(76, 76, 68, 82);
    canvas.drawOval(
      chest,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFE5EEF1)],
        ).createShader(chest),
    );
    canvas.drawOval(Rect.fromLTWH(73, 52, 73, 55), belly);

    // Feet alternate to create a readable waddling gait.
    final step = walking ? swing * 7 : 0.0;
    canvas.drawOval(Rect.fromLTWH(73 + step, 154, 38, 17), green);
    canvas.drawOval(Rect.fromLTWH(110 - step, 154, 38, 17), green);

    if (asleep) {
      final eyePaint = Paint()
        ..color = const Color(0xFF26333B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromLTWH(83, 75, 15, 8), 0, math.pi, false, eyePaint);
      canvas.drawArc(
        Rect.fromLTWH(119, 75, 15, 8),
        0,
        math.pi,
        false,
        eyePaint,
      );
      _drawSleepyZ(canvas, 157, 48, 1);
      _drawSleepyZ(canvas, 169, 32, .72);
    } else {
      final eyeHeight = blink ? 2.0 : 10.0;
      canvas.drawOval(Rect.fromLTWH(83, 70, 14, eyeHeight), belly);
      canvas.drawOval(Rect.fromLTWH(119, 70, 14, eyeHeight), belly);
      if (!blink) {
        canvas.drawCircle(const Offset(90, 75), 3.3, detail);
        canvas.drawCircle(const Offset(126, 75), 3.3, detail);
        canvas.drawCircle(
          const Offset(91, 73),
          1.1,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          const Offset(127, 73),
          1.1,
          Paint()..color = Colors.white,
        );
      }
      final beak = Path()
        ..moveTo(98, 89)
        ..lineTo(117, 89)
        ..lineTo(eating ? 107.5 : 107.5, eating ? 105 : 101)
        ..close();
      canvas.drawPath(beak, green);
      if (eating) {
        canvas.drawCircle(const Offset(108, 112), 4, accent);
        canvas.drawCircle(const Offset(108, 112), 1.3, belly);
      }
    }

    if (playing) {
      canvas.drawCircle(const Offset(39, 104), 9, accent);
      canvas.drawCircle(const Offset(39, 104), 5, Paint()..color = belly.color);
      canvas.drawCircle(const Offset(39, 104), 2, accent);
    }
    canvas.restore();
  }

  void _drawSleepyZ(Canvas canvas, double x, double y, double scale) {
    final paint = Paint()
      ..color = const Color(0xFF527B91)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(x, y)
      ..lineTo(x + 8 * scale, y)
      ..lineTo(x, y + 9 * scale)
      ..lineTo(x + 8 * scale, y + 9 * scale);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PenguinPainter old) =>
      old.stage != stage || old.action != action || old.phase != phase;
}
