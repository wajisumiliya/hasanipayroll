import 'dart:async';
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
  bool _isHatching = false;
  bool _showHatchWelcome = false;
  Timer? _crackTimer;
  Timer? _hatchTimer;

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
        final nextPet = Map<String, dynamic>.from(data['pet'] as Map);
        final hatchAt = DateTime.tryParse(nextPet['hatchAt']?.toString() ?? '');
        final serverNow =
            DateTime.tryParse(nextPet['serverNow']?.toString() ?? '');
        final stage = nextPet['stage']?.toString() ?? 'egg';
        final timeUntilHatch = hatchAt != null && serverNow != null
            ? hatchAt.difference(serverNow)
            : null;
        setState(() {
          pet = nextPet;
          _isHatching = stage == 'egg' &&
              timeUntilHatch != null &&
              timeUntilHatch <= const Duration(minutes: 5);
          _showHatchWelcome = stage == 'chick' &&
              hatchAt != null &&
              serverNow != null &&
              !serverNow.isBefore(hatchAt) &&
              serverNow.isBefore(hatchAt.add(const Duration(hours: 24)));
        });
        _scheduleHatch(hatchAt, serverNow, stage);
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

  void _scheduleHatch(DateTime? hatchAt, DateTime? serverNow, String stage) {
    _crackTimer?.cancel();
    _hatchTimer?.cancel();
    if (stage != 'egg' || hatchAt == null || serverNow == null) return;

    final untilHatch = hatchAt.difference(serverNow);
    if (untilHatch <= Duration.zero) {
      _hatchTimer = Timer(const Duration(seconds: 1), _refreshAtHatch);
      return;
    }

    const crackWindow = Duration(minutes: 5);
    if (untilHatch > crackWindow) {
      _crackTimer = Timer(untilHatch - crackWindow, () {
        if (mounted) setState(() => _isHatching = true);
      });
    }
    _hatchTimer = Timer(untilHatch, _refreshAtHatch);
  }

  void _refreshAtHatch() {
    if (!mounted) return;
    if (busy) {
      _hatchTimer = Timer(const Duration(seconds: 1), _refreshAtHatch);
      return;
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _crackTimer?.cancel();
    _hatchTimer?.cancel();
    super.dispose();
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
    final nickname = pet?['nickname'] ?? 'Pingu';
    final hatched = stage != 'egg';
    final fed = pet?['fedToday'] == true;
    final played = pet?['playedToday'] == true;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/penguin_habitat.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x77F1FAFF), Color(0xBFFFFFFF)],
                  stops: [0, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hatched ? 'MY LIVING PENGUIN' : 'A LITTLE SURPRISE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF173D60),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Semantics(
                    label: hatched
                        ? 'Penguin growth stage: $stage'
                        : 'A surprise is growing inside an egg.',
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: PenguinIllustration(
                        key: ValueKey(stage),
                        stage: stage,
                        action: action,
                        hatching: _isHatching,
                        onTap: _toggleSleep,
                      ),
                    ),
                  ),
                ),
                if (hatched)
                  Center(
                    child: Text(
                      '${pet?['nickname'] ?? 'Pingu'} • Day $days • ${stage.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                Center(
                  child: Text(
                    _showHatchWelcome
                        ? 'Surprise! Welcome, $nickname — your penguin has hatched!'
                        : hatched
                            ? 'Tap your penguin to let it nap or wake it up'
                            : _isHatching
                                ? 'Something is stirring inside...'
                                : 'Your surprise is growing. Come back soon!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _showHatchWelcome ? 13 : 11,
                      fontWeight: _showHatchWelcome ? FontWeight.w700 : null,
                      color: const Color(0xFF426680),
                    ),
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
                      onPressed: busy || pet == null || fed
                          ? null
                          : () => _load('feed'),
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
        ],
      ),
    );
  }
}

/// Detailed feathered artwork with local breathing, waddling and care motion.
class PenguinIllustration extends StatefulWidget {
  const PenguinIllustration({
    super.key,
    required this.stage,
    this.action = 'idle',
    this.hatching = false,
    this.onTap,
  });

  final String stage;
  final String action;
  final bool hatching;
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
            builder: (context, _) {
              final phase = reduceMotion ? 0.0 : motion.value;
              if (widget.stage == 'egg') {
                return CustomPaint(
                  painter: _PenguinPainter(
                    stage: widget.stage,
                    action: widget.action,
                    phase: phase,
                    hatching: widget.hatching,
                  ),
                );
              }
              final sleeping = widget.action == 'sleeping';
              final walking =
                  widget.action == 'waddling' || widget.action == 'playing';
              final eating = widget.action == 'eating';
              final swing = math.sin(phase * math.pi * 2);
              final growth = widget.stage == 'chick'
                  ? .84
                  : widget.stage == 'juvenile'
                      ? .94
                      : 1.0;
              final assetStage = widget.stage == 'chick' ? 'chick' : 'adult';
              final asset =
                  'assets/penguins/$assetStage${sleeping ? '_sleep' : ''}.png';
              return Stack(
                children: [
                  Positioned.fill(
                    child: Transform.translate(
                      offset: reduceMotion
                          ? Offset.zero
                          : Offset(
                              walking ? swing * 4 : 0,
                              walking
                                  ? -swing.abs() * 2
                                  : eating
                                      ? -swing.abs() * 1.5
                                      : 0,
                            ),
                      child: Transform.rotate(
                        angle: reduceMotion
                            ? 0
                            : walking
                                ? swing * .045
                                : eating
                                    ? swing * .018
                                    : swing * .004,
                        alignment: Alignment.bottomCenter,
                        child: Transform.scale(
                          scale: growth *
                              (1 +
                                  (reduceMotion
                                      ? 0
                                      : swing * (sleeping ? .007 : .005))),
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 3, 20, 8),
                            child: Image.asset(
                              asset,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              cacheHeight: 512,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (eating || widget.action == 'playing')
                    Positioned.fill(
                        child: CustomPaint(
                      painter: _PenguinCarePainter(
                          action: widget.action, phase: phase),
                    )),
                ],
              );
            },
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
    required this.hatching,
  });

  final String stage;
  final String action;
  final double phase;
  final bool hatching;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()..color = const Color(0x44265A78);
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
      canvas.save();
      if (hatching) {
        canvas.translate(
          math.sin(phase * math.pi * 2) * 1.8,
          -math.sin(phase * math.pi * 2).abs() * 1.6,
        );
      }
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
      if (hatching) {
        final crackPaint = Paint()
          ..color = const Color(0xFF82939A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final crack = Path()
          ..moveTo(egg.center.dx, egg.top + 4)
          ..lineTo(egg.center.dx - 5, egg.top + 15)
          ..lineTo(egg.center.dx + 3, egg.top + 22)
          ..lineTo(egg.center.dx - 4, egg.top + 32)
          ..lineTo(egg.center.dx + 2, egg.top + 40);
        canvas.drawPath(crack, crackPaint);
        final sideCrack = Path()
          ..moveTo(egg.center.dx - 4, egg.top + 32)
          ..lineTo(egg.center.dx - 13, egg.top + 35)
          ..lineTo(egg.center.dx - 17, egg.top + 42);
        canvas.drawPath(sideCrack, crackPaint);
      }
      canvas.restore();
      return;
    }
  }

  @override
  bool shouldRepaint(covariant _PenguinPainter old) =>
      old.stage != stage ||
      old.action != action ||
      old.phase != phase ||
      old.hatching != hatching;
}

/// Small care props accompany the realistic bird without redrawing its body.
class _PenguinCarePainter extends CustomPainter {
  const _PenguinCarePainter({required this.action, required this.phase});
  final String action;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (action == 'eating') {
      final x = size.width * .57;
      final y = size.height * (.46 - phase * .12);
      final fish = Rect.fromCenter(center: Offset(x, y), width: 16, height: 7);
      canvas.drawOval(
          fish,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFD5EAF3), Color(0xFF51798A)],
            ).createShader(fish));
      canvas.drawPath(
          Path()
            ..moveTo(x + 7, y)
            ..lineTo(x + 13, y - 5)
            ..lineTo(x + 13, y + 5)
            ..close(),
          Paint()..color = const Color(0xFF63899A));
      canvas.drawCircle(
          Offset(x - 4, y - 1), .9, Paint()..color = const Color(0xFF26313A));
    } else {
      final center = Offset(size.width * .23,
          size.height * (.80 - math.sin(phase * math.pi * 2).abs() * .16));
      final bounds = Rect.fromCircle(center: center, radius: 8);
      canvas.drawCircle(
          center,
          8,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-.4, -.5),
              colors: [Color(0xFFDBF6FF), Color(0xFF368AB6)],
            ).createShader(bounds));
    }
  }

  @override
  bool shouldRepaint(covariant _PenguinCarePainter old) =>
      old.action != action || old.phase != phase;
}
