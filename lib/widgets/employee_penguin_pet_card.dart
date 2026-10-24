import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/neon_api.dart';
import 'penguin_companion_reaction.dart';
import '../services/penguin_growth.dart';

/// Server-backed penguin companion. Growth and care use server time.
class EmployeePenguinPetCard extends StatefulWidget {
  const EmployeePenguinPetCard({super.key, this.request});

  /// Optional transport for isolated previews and tests; production uses NeonApi.
  final Future<Map<String, dynamic>> Function(String? action)? request;

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
  Timer? _reactionTimer;
  String? _speech;
  bool _petted = false;
  int _reactionSerial = 0;

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
    });
    try {
      final data = await (widget.request != null
          ? widget.request!(careAction)
          : NeonApi.jsonRequest(
              careAction == null
                  ? '/api/employee/penguin'
                  : '/api/employee/penguin/$careAction',
              method: careAction == null ? 'GET' : 'POST',
            ));
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
        if (careAction != null && stage != 'egg') {
          _react(
              careAction == 'feed' ? 'eating' : 'playing',
              careAction == 'feed'
                  ? 'Yum! Thank you for the fish!'
                  : 'A snowball! Let’s play!');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Penguin home is temporarily unavailable.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void _scheduleHatch(DateTime? hatchAt, DateTime? serverNow, String stage) {
    _crackTimer?.cancel();
    _hatchTimer?.cancel();
    if (hatchAt == null || serverNow == null) return;
    if (stage != 'egg') {
      if (stage != 'adult') {
        // Advance daily growth even if the employee keeps the portal open.
        final nextDay = hatchAt
            .add(Duration(days: serverNow.difference(hatchAt).inDays + 1));
        _hatchTimer = Timer(nextDay.difference(serverNow), _refreshAtHatch);
      }
      return;
    }

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
    _reactionTimer?.cancel();
    super.dispose();
  }

  void _toggleSleep() {
    if (busy || pet == null || pet?['stage'] == 'egg') return;
    _reactionTimer?.cancel();
    setState(() {
      sleeping = !sleeping;
      action = sleeping ? 'sleeping' : 'idle';
      _speech = sleeping
          ? 'Zzz… a little rest on the ice.'
          : 'Hello again! Ready to play?';
      _reactionSerial++;
    });
  }

  void _react(String next, String message) {
    _reactionTimer?.cancel();
    setState(() {
      sleeping = false;
      action = next;
      _speech = message;
      if (next == 'petting') {
        _petted = true;
      }
      _reactionSerial++;
    });
    _reactionTimer = Timer(const Duration(milliseconds: 3400), () {
      if (mounted) {
        setState(() {
          action = 'idle';
          _speech = null;
        });
      }
    });
  }

  void _pet() {
    if (busy || pet == null || pet?['stage'] == 'egg') return;
    if (sleeping) {
      _toggleSleep();
      return;
    }
    _react('petting', 'That feels lovely. Thank you!');
  }

  void _care(String kind) {
    if (busy || pet == null || pet?['stage'] == 'egg') return;
    if (pet?[kind == 'feed' ? 'fedToday' : 'playedToday'] == true) {
      _react(kind == 'feed' ? 'eating' : 'playing',
          kind == 'feed' ? 'Another little fish? Yum!' : 'Let’s play again!');
    } else {
      unawaited(_load(kind));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = pet?['stage']?.toString() ?? 'egg';
    final days = (pet?['ageDays'] as num?)?.toInt() ?? 0;
    final nickname = pet?['nickname']?.toString() ?? 'Pingu';
    final hatched = stage != 'egg';
    final fed = pet?['fedToday'] == true;
    final played = pet?['playedToday'] == true;
    final happiness =
        (.40 + (fed ? .25 : 0) + (played ? .25 : 0) + (_petted ? .10 : 0));
    final energy =
        sleeping ? .95 : (.65 + (fed ? .20 : 0) - (played ? .10 : 0));
    final message = _speech ??
        (_showHatchWelcome
            ? 'Surprise! Welcome, $nickname — your penguin has hatched!'
            : hatched
                ? 'Hello! Ready for today?'
                : _isHatching
                    ? 'Something is stirring inside...'
                    : 'Your surprise is growing. Come back soon!');
    final enabled = !busy && pet != null && hatched;
    final character = hatched && action != 'idle'
        ? Semantics(
            button: true,
            label: sleeping
                ? 'Sleeping penguin. Tap to wake.'
                : 'Penguin. Tap to pet.',
            child: GestureDetector(
                onTap: _pet,
                child: PenguinCompanionReaction(
                    key: ValueKey(stage),
                    reactionId: _reactionSerial,
                    stage: stage,
                    action: action,
                    daysSinceHatch: (days - 3).clamp(0, 100000))))
        : PenguinIllustration(
            key: ValueKey(stage),
            stage: stage,
            daysSinceHatch: (days - 3).clamp(0, 100000),
            action: action,
            hatching: _isHatching,
            onTap: hatched ? _pet : null,
            tapLabel: hatched ? 'Penguin. Tap to pet.' : null);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Stack(children: [
        Positioned.fill(
            child:
                Image.asset('assets/penguin_habitat.png', fit: BoxFit.cover)),
        const Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
              Color(0xA6F0F9FF),
              Color(0x38F0F9FF),
              Color(0xD9F7FBFF)
            ],
                        stops: [
              0,
              .5,
              1
            ])))),
        Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(hatched ? 'MY PENGUIN' : 'A LITTLE SURPRISE',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF173D60))),
                      if (hatched)
                        const Text('Your little daily companion',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF426680))),
                    ])),
                IconButton(
                    tooltip: 'Refresh penguin',
                    onPressed: busy ? null : () => _load(),
                    icon: const Icon(Icons.refresh, color: Color(0xFF173D60))),
              ]),
              const SizedBox(height: 10),
              Center(
                  child: Semantics(
                      liveRegion: true,
                      child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          child: Container(
                              key: ValueKey(message),
                              constraints: const BoxConstraints(maxWidth: 380),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .94),
                                  borderRadius: BorderRadius.circular(18)),
                              child: Text(message,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Color(0xFF173D60),
                                      fontWeight: FontWeight.w700)))))),
              SizedBox(
                  height: hatched ? 270 : 200,
                  width: double.infinity,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(children: [
                        if (hatched)
                          Positioned.fill(
                              child: Image.asset(
                                  'assets/penguins/family/coast.png',
                                  fit: BoxFit.cover,
                                  alignment: Alignment.bottomLeft)),
                        Align(
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                                width: 300,
                                height: hatched ? 260 : 190,
                                child: FittedBox(
                                    fit: BoxFit.contain, child: character))),
                      ]))),
              if (hatched) ...[
                Center(
                    child: Text(
                        '$nickname • Day $days • ${stage.toUpperCase()}',
                        style: const TextStyle(
                            color: Color(0xFF173D60),
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                const SizedBox(height: 12),
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .90),
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      Expanded(
                          child: _meter('Happiness', happiness, Icons.favorite,
                              const Color(0xFFD4A52D))),
                      const SizedBox(width: 18),
                      Expanded(
                          child: _meter('Energy', energy, Icons.bolt,
                              const Color(0xFF4578B6)))
                    ])),
              ],
              if (error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(error!,
                        style: const TextStyle(color: Color(0xFFAA263B)))),
              if (pet == null && busy)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator())),
              const SizedBox(height: 12),
              Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .96),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _careButton(
                            'Feed',
                            Icons.set_meal,
                            enabled ? () => _care('feed') : null,
                            const Color(0xFFB88A21)),
                        _careButton(
                            'Play',
                            Icons.sports_baseball,
                            enabled ? () => _care('play') : null,
                            const Color(0xFF467FB5)),
                        _careButton('Pet', Icons.front_hand,
                            enabled ? _pet : null, const Color(0xFFB88A21)),
                        _careButton(
                            sleeping ? 'Wake' : 'Rest',
                            sleeping ? Icons.wb_sunny : Icons.nightlight_round,
                            enabled ? _toggleSleep : null,
                            const Color(0xFF183B60)),
                      ])),
              const SizedBox(height: 8),
              Text(
                  hatched
                      ? 'Daily care: ${fed ? 'fed' : 'fish waiting'} · ${played ? 'played' : 'ready to play'}. Keep interacting whenever you like.'
                      : 'Your penguin grows with time, even when you are away.',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF425F74))),
            ])),
      ]),
    );
  }

  Widget _meter(String label, double value, IconData icon, Color color) =>
      Row(children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 6),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF173D60))),
          const SizedBox(height: 5),
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 7,
                  color: color,
                  backgroundColor: const Color(0xFFE1E8F0),
                  semanticsLabel: label)),
        ])),
      ]);

  Widget _careButton(
          String label, IconData icon, VoidCallback? onTap, Color color) =>
      Expanded(
          child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  foregroundColor: const Color(0xFF173D60)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: onTap == null ? const Color(0xFFCCD5DF) : color),
                    child: Icon(icon, color: Colors.white, size: 23)),
                const SizedBox(height: 6),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12)),
              ])));
}

/// Detailed feathered artwork with local breathing, waddling and care motion.
class PenguinIllustration extends StatefulWidget {
  const PenguinIllustration({
    super.key,
    required this.stage,
    this.action = 'idle',
    this.hatching = false,
    this.daysSinceHatch,
    this.onTap,
    this.tapLabel,
  });

  final String stage;
  final String action;
  final bool hatching;
  final int? daysSinceHatch;
  final VoidCallback? onTap;
  final String? tapLabel;

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
      label: widget.tapLabel ??
          (widget.action == 'sleeping'
              ? 'Sleeping penguin. Tap to wake.'
              : 'Penguin. Tap to sleep.'),
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
              final growth = penguinGrowthScale(widget.daysSinceHatch ??
                  (widget.stage == 'adult'
                      ? 42
                      : widget.stage == 'juvenile'
                          ? 12
                          : 0));
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
                        child: AnimatedScale(
                          scale: growth,
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 800),
                          alignment: Alignment.bottomCenter,
                          child: Transform.scale(
                            scale: (1 +
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
                  ),
                  if (eating || widget.action == 'playing')
                    Positioned.fill(
                        child: AnimatedScale(
                      scale: growth,
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 800),
                      alignment: Alignment.bottomCenter,
                      child: CustomPaint(
                        painter: _PenguinCarePainter(
                            action: widget.action, phase: phase),
                      ),
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
