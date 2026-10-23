import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../services/mystery_egg_hatch_controller.dart';
import '../services/penguin_family_scene.dart';
import 'mystery_egg_teaser.dart';

/// A shared branch habitat, separate from employees' personal pet adoption.
class BranchPenguinCrew extends StatefulWidget {
  const BranchPenguinCrew(
      {super.key, required this.branchName, this.controller});
  final String branchName;
  final MysteryEggHatchController? controller;
  @override
  State<BranchPenguinCrew> createState() => _BranchPenguinCrewState();
}

class _BranchPenguinCrewState extends State<BranchPenguinCrew>
    with SingleTickerProviderStateMixin {
  MysteryEggHatchController get _clock =>
      widget.controller ?? MysteryEggHatchController.branch;
  late final Ticker _ticker = createTicker(_tick);
  final _time = ValueNotifier<double>(0);
  Map<String, ui.Image>? _images;
  bool _loading = false;
  bool _failed = false;
  bool _reduced = false;
  Duration? _last;
  @override
  void initState() {
    super.initState();
    _clock.addListener(_changed);
    _clock.attach();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant BranchPenguinCrew oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final old = oldWidget.controller ?? MysteryEggHatchController.branch;
      old.removeListener(_changed);
      old.detach();
      _clock.addListener(_changed);
      _clock.attach();
      _prepare();
      _sync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _sync();
  }

  void _changed() {
    _prepare();
    _sync();
    if (mounted) setState(() {});
  }

  void _prepare() {
    if (_clock.stage != 'egg' || _clock.hatching) unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading || _images != null || _failed) return;
    _loading = true;
    final loaded = <String, ui.Image>{};
    try {
      final keys = [
        for (final action in ['walk', 'swim', 'eat', 'baby'])
          for (final direction in [2, 6]) '${action}_$direction'
      ];
      final decoded = await Future.wait(keys.map((key) async {
        final path = key.startsWith('baby')
            ? 'assets/penguins/walk/walk_${key.split('_').last}.png'
            : 'assets/penguins/family/$key.png';
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        try {
          return (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }), cleanUp: (ui.Image image) => image.dispose());
      loaded.addAll(Map.fromIterables(keys, decoded));
      if (!mounted) {
        for (final image in loaded.values) {
          image.dispose();
        }
        return;
      }
      setState(() => _images = loaded);
      _sync();
    } catch (_) {
      for (final image in loaded.values) {
        image.dispose();
      }
      if (mounted) setState(() => _failed = true);
      debugPrint('Branch penguin family animation unavailable.');
    } finally {
      _loading = false;
    }
  }

  void _sync() {
    final moving = !_reduced && _images != null && _clock.stage != 'egg';
    if (moving && !_ticker.isActive) {
      _last = null;
      _ticker.start();
    }
    if (!moving && _ticker.isActive) {
      _ticker.stop();
      _last = null;
    }
  }

  void _tick(Duration elapsed) {
    if (_last != null) {
      _time.value += ((elapsed - _last!).inMicroseconds / 1e6).clamp(0, .1);
    }
    _last = elapsed;
  }

  @override
  void dispose() {
    _clock.removeListener(_changed);
    _clock.detach();
    _ticker.dispose();
    _time.dispose();
    for (final image in _images?.values ?? <ui.Image>[]) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hatched = _clock.stage != 'egg';
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      return Container(
        height: compact ? 310 : 360,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFB9DDED))),
        child: Stack(children: [
          Positioned.fill(
              child:
                  Image.asset('assets/penguin_habitat.png', fit: BoxFit.fill)),
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 110,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                    Colors.white.withValues(alpha: .85),
                    Colors.white.withValues(alpha: 0)
                  ])))),
          Positioned(
              top: 18,
              left: 20,
              right: 20,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        hatched
                            ? 'A LITTLE FAMILY. A LIVING WORLD.'
                            : 'A LITTLE SURPRISE IS GROWING.',
                        style: const TextStyle(
                            color: Color(0xFF173D60),
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(
                        hatched
                            ? '${widget.branchName} · Two adults, one young penguin and one baby'
                            : '${widget.branchName} · Some surprises are worth waiting for',
                        style: const TextStyle(
                            color: Color(0xFF426680), fontSize: 11)),
                  ])),
          if (!hatched)
            Positioned(
                left: 10,
                right: 10,
                bottom: 20,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                        4,
                        (_) => MysteryEggTeaser(
                            size: compact ? 76 : 128, controller: _clock)))),
          if (hatched && _images != null)
            Positioned.fill(
                child: IgnorePointer(
                    child: Semantics(
                        label:
                            'Penguin family: two adults, one young and one baby. '
                            'Adults swim and feed the baby; the young penguin plays on the ice.',
                        child: RepaintBoundary(
                            child: CustomPaint(
                                painter: _FamilyPainter(
                                    _images!, _time, compact)))))),
          if (hatched && _images == null)
            Positioned(
                bottom: 24,
                left: 20,
                child: Text(
                    _failed
                        ? 'The family scene is unavailable. Please reopen this page.'
                        : 'The penguin family is arriving…',
                    style: const TextStyle(color: Color(0xFF173D60)))),
          if (hatched)
            Positioned(
                top: 82,
                left: 20,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .75),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('ICE SHORE  ·  FAMILY HABITAT',
                        style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF426680),
                            letterSpacing: 1.2)))),
        ]),
      );
    });
  }
}

class _FamilyPainter extends CustomPainter {
  _FamilyPainter(this.images, this.time, this.compact) : super(repaint: time);
  final Map<String, ui.Image> images;
  final ValueNotifier<double> time;
  final bool compact;
  @override
  void paint(Canvas canvas, Size size) {
    final members = penguinFamilyAt(time.value)
      ..sort((a, b) => a.position.dy.compareTo(b.position.dy));
    for (final member in members) {
      final swimming = member.activity == FamilyActivity.swimming;
      final anchor = Offset(
          member.position.dx * size.width, member.position.dy * size.height);
      final feeding = !member.baby && member.activity == FamilyActivity.feeding;
      final height = (compact ? 116.0 : 154.0) *
          member.scale *
          (feeding ? 4.1 / 3.15 : 1.0);
      final image = images[
          '${member.baby ? 'baby' : member.action}_${member.direction}']!;
      final walking = member.activity == FamilyActivity.walking ||
          member.activity == FamilyActivity.playing;
      final phase = walking
          ? ((anchor.dx / (height * .20)) * (member.direction == 2 ? 1 : -1)) %
              1
          : member.phase;
      final frame =
          member.activity == FamilyActivity.resting || (member.baby && !walking)
              ? 0
              : (phase * 16).floor() % 16;
      final cell = image.width / 4;
      final source =
          Rect.fromLTWH(frame % 4 * cell, frame ~/ 4 * cell, cell, cell);
      final target = Rect.fromLTWH(
          anchor.dx - height / 2,
          anchor.dy -
              height *
                  (swimming
                      ? .87
                      : feeding
                          ? .80
                          : .91),
          height,
          height);
      if (swimming) {
        // Transparent surface glints and expanding wakes anchor strokes in water.
        for (var ring = 0; ring < 3; ring++) {
          final p = (time.value / 1.8 + ring / 3) % 1;
          canvas.drawOval(
              Rect.fromCenter(
                  center: anchor.translate(0, -height * .23),
                  width: height * (.35 + p * .5),
                  height: height * (.06 + p * .08)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.3
                ..color = Colors.white.withValues(alpha: (1 - p) * .65));
        }
      } else {
        canvas.drawOval(
            Rect.fromCenter(
                center: anchor, width: height * .45, height: height * .055),
            Paint()
              ..color = const Color(0x30274659)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
      canvas.save();
      if (swimming) {
        canvas.clipRect(
            Rect.fromLTRB(0, 0, size.width, anchor.dy - height * .22));
      }
      canvas.drawImageRect(
          image, source, target, Paint()..filterQuality = FilterQuality.high);
      canvas.restore();
      if (swimming) {
        canvas.drawOval(
            Rect.fromCenter(
                center: anchor.translate(0, -height * .22),
                width: height * .43,
                height: 5),
            Paint()..color = const Color(0x70C2EAF6));
      }
    }
    // A small silver fish is visible only during the parent's feeding routine.
    final t = time.value % 80;
    if (t >= 38 && t < 54) {
      final p = Offset(
          size.width * .445, size.height * .79 + math.sin(time.value * 3) * 2);
      canvas.drawOval(
          Rect.fromCenter(center: p, width: compact ? 9 : 15, height: 5),
          Paint()..color = const Color(0xFF8EA7B8));
      canvas.drawCircle(
          p.translate(4, -1), .8, Paint()..color = const Color(0xFF203D50));
    }
  }

  @override
  bool shouldRepaint(covariant _FamilyPainter oldDelegate) =>
      oldDelegate.images != images || oldDelegate.compact != compact;
}
