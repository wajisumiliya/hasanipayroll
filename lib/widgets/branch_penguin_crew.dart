import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../services/mystery_egg_hatch_controller.dart';
import '../services/penguin_family_scene.dart';
import '../services/penguin_feeding.dart';
import '../services/penguin_entry_geometry.dart';
import 'mystery_egg_teaser.dart';
import 'penguin_habitat_effects.dart';

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
  List<double> _swimRows = List.filled(16, .65);
  List<PenguinEntryPose> _entryPoses = const [];
  Map<String, List<PenguinEntryPose>> _idlePoses = const {};
  PenguinFeedPhase? _feedPhase;
  bool _loading = false;
  bool _failed = false;
  bool _reduced = false;
  Duration? _last;
  PenguinFeeding? _feeding;
  int _fishEaten = 0;
  String get _feedLabel => _feeding == null
      ? 'Feed fish'
      : _feedPhase == PenguinFeedPhase.returning
          ? 'Walking back…'
          : 'Feeding…';
  String get _feedStatus => _feeding == null
      ? _fishEaten == 0
          ? 'Offer a fish to the family'
          : '$_fishEaten fish eaten · Thank you!'
      : switch (_feedPhase) {
          PenguinFeedPhase.noticing => 'It noticed the fish',
          PenguinFeedPhase.eating => 'Eating its fish',
          PenguinFeedPhase.returning => 'Fish eaten · Returning to family',
          _ => 'Coming for the fish',
        };
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
    if (oldWidget.branchName != widget.branchName ||
        oldWidget.controller != widget.controller) {
      _feeding = null;
      _feedPhase = null;
      _fishEaten = 0;
    }
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
    if (_reduced && _feeding != null) {
      _feeding = null;
      _feedPhase = null;
      _fishEaten++;
    }
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
        for (final variant in ['adult', 'young', 'baby'])
          for (final action in [
            'walk',
            if (variant != 'young') 'idle',
            if (variant == 'adult') 'eat',
            if (variant == 'adult') 'swim',
            if (variant == 'adult') 'enter'
          ])
            '${variant}_${action}_2',
        'herring',
        'coast'
      ];
      final decoded = await Future.wait(keys.map((key) async {
        final path = 'assets/penguins/family/$key.png';
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
      // Generated swimming poses have different wing extents. Anchor each
      // frame to its widest opaque torso row, not the wing's bounding box.
      // This is render geometry; the original atlas pixels remain untouched.
      Future<List<double>> bodyRows(ui.Image swimmer) async {
        final pixels =
            await swimmer.toByteData(format: ui.ImageByteFormat.rawRgba);
        final swimRows = List<double>.filled(16, .65);
        if (pixels != null) {
          for (var frame = 0; frame < 16; frame++) {
            final left = (frame % 4 * swimmer.width / 4).floor();
            final top = (frame ~/ 4 * swimmer.height / 4).floor();
            final width = swimmer.width ~/ 4;
            final height = swimmer.height ~/ 4;
            var bestCount = 0;
            var bestRow = height ~/ 2;
            for (var y = 0; y < height; y++) {
              var count = 0;
              for (var x = (width * .08).floor(); x < width * .92; x++) {
                if (pixels.getUint8(
                        ((top + y) * swimmer.width + left + x) * 4 + 3) >
                    150) {
                  count++;
                }
              }
              if (count > bestCount) {
                bestCount = count;
                bestRow = y;
              }
            }
            swimRows[frame] = bestRow / height;
          }
        }
        return swimRows;
      }

      final swimRows = await bodyRows(loaded['adult_swim_2']!);
      final entryImage = loaded['adult_enter_2']!;
      final entryPixels =
          await entryImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (entryPixels == null) throw StateError('Entry pose data unavailable');
      final entryPoses = penguinEntryGeometry(
          entryImage.width, entryImage.height, entryPixels);
      final idlePoses = <String, List<PenguinEntryPose>>{};
      for (final variant in ['adult', 'baby']) {
        final idle = loaded['${variant}_idle_2']!;
        final pixels =
            await idle.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (pixels == null) throw StateError('Idle pose data unavailable');
        idlePoses[variant] =
            penguinEntryGeometry(idle.width, idle.height, pixels);
      }
      if (!mounted) {
        for (final image in loaded.values) {
          image.dispose();
        }
        return;
      }
      setState(() {
        _images = loaded;
        _swimRows = swimRows;
        _entryPoses = entryPoses;
        _idlePoses = idlePoses;
      });
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
    if (_last == null) {
      _last = elapsed;
      return;
    }
    final delta = elapsed - _last!;
    // Quiet head poses and ripples do not need a full display-rate redraw.
    // Keep elapsed scene time intact while limiting canvas work to about 30fps.
    if (delta.inMicroseconds < 32000) return;
    _time.value += (delta.inMicroseconds / 1e6).clamp(0, .1);
    _last = elapsed;
    if (_feeding?.phaseAt(_time.value) == PenguinFeedPhase.complete) {
      setState(() {
        _feeding = null;
        _feedPhase = null;
        _fishEaten++;
      });
    } else {
      final phase = _feeding?.phaseAt(_time.value);
      if (phase != _feedPhase) setState(() => _feedPhase = phase);
    }
  }

  void _feed(double width, bool compact) {
    if (_feeding != null || _images == null || _clock.stage == 'egg') return;
    if (_reduced) {
      setState(() => _fishEaten++);
      return;
    }
    setState(() {
      _feedPhase = PenguinFeedPhase.noticing;
      _feeding = PenguinFeeding(
          startedAt: _time.value,
          sceneWidth: width,
          adultHeight: compact ? 116 : 154);
    });
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
              child: Image.asset('assets/penguins/family/coast.png',
                  fit: BoxFit.fill)),
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
              right: hatched && !compact ? 230 : 20,
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
                                    _images!,
                                    _time,
                                    compact,
                                    _feeding,
                                    _swimRows,
                                    _entryPoses,
                                    _idlePoses)))))),
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
                top: compact ? 108 : 18,
                right: 16,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FilledButton.icon(
                          onPressed: _images == null || _feeding != null
                              ? null
                              : () => _feed(constraints.maxWidth, compact),
                          icon: const Icon(Icons.set_meal_rounded, size: 19),
                          label: Text(_feedLabel),
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF173D60),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF536A7E),
                              disabledForegroundColor: Colors.white,
                              minimumSize: const Size(130, 46))),
                      const SizedBox(height: 5),
                      Semantics(
                          liveRegion: true,
                          child: Text(_feedStatus,
                              style: const TextStyle(
                                  color: Color(0xFF173D60), fontSize: 10))),
                    ])),
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
  _FamilyPainter(this.images, this.time, this.compact, this.feeding,
      this.swimRows, this.entryPoses, this.idlePoses)
      : super(repaint: time);
  final Map<String, ui.Image> images;
  final ValueNotifier<double> time;
  final bool compact;
  final PenguinFeeding? feeding;
  final List<double> swimRows;
  final List<PenguinEntryPose> entryPoses;
  final Map<String, List<PenguinEntryPose>> idlePoses;
  @override
  void paint(Canvas canvas, Size size) {
    paintPenguinHabitat(canvas, size, time.value, images['coast']!);
    final members = (feeding?.familyAt(time.value) ??
        penguinFamilyAt(time.value))
      ..sort((a, b) => a.position.dy.compareTo(b.position.dy));
    for (final member in members) {
      final water = member.immersion;
      final swimming = water > 0;
      final transition = water > 0 && water < 1;
      final anchor = Offset(
          member.position.dx * size.width, member.position.dy * size.height);
      final resting = member.activity == FamilyActivity.resting ||
          member.activity == FamilyActivity.observing;
      final breathing = resting
          ? 1 + .003 * math.sin(time.value * 1.8 + member.scale * 7)
          : 1.0;
      final height = (compact ? 116.0 : 154.0) *
          member.scale *
          penguinGroundScale(member.position.dy) *
          breathing;
      final variant = member.baby
          ? 'baby'
          : member.scale < .9
              ? 'young'
              : 'adult';
      final idle = resting && variant != 'young';
      final action = idle
          ? 'idle'
          : variant != 'adult'
              ? 'walk'
              : transition
                  ? 'enter'
                  : water >= 1
                      ? 'swim'
                      : member.activity == FamilyActivity.swimming
                          ? 'walk'
                          : member.action;
      final image = images['${variant}_${action}_2']!;
      final walking = member.activity == FamilyActivity.walking ||
          member.activity == FamilyActivity.playing;
      final phase = walking
          ? ((anchor.dx / (height * .20)) * (member.direction == 2 ? 1 : -1)) %
              1
          : member.phase;
      final frame = idle
          ? penguinIdleFrameAt(time.value,
              baby: member.baby, identity: member.scale)
          : transition
              ? (water * 15).round()
              : resting ||
                      (member.baby && !walking) ||
                      (member.activity == FamilyActivity.swimming && water == 0)
                  ? 0
                  : (phase * 16).floor() % 16;
      final cell = image.width / 4;
      final cellHeight = image.height / 4;
      final poses = transition
          ? entryPoses
          : idle
              ? idlePoses[variant]
              : null;
      final source = poses != null
          ? poses[frame].source
          : Rect.fromLTWH(
              frame % 4 * cell, frame ~/ 4 * cellHeight, cell, cellHeight);
      final entry = poses == null ? null : poses[frame];
      final entryScale =
          poses == null ? 1.0 : height * .96 / poses.first.source.height;
      final drawWidth = entry == null
          ? height * cell / cellHeight
          : entry.source.width * entryScale;
      final drawHeight =
          entry == null ? height : entry.source.height * entryScale;
      final target = Rect.fromLTWH(
          anchor.dx -
              drawWidth *
                  (entry == null ? .5 : entry.footX * (1 - water) + .5 * water),
          anchor.dy -
              (entry == null
                  ? height * (swimming ? .22 + swimRows[frame] : .96)
                  : drawHeight * .99 * (1 - water) +
                      (height * .22 + drawHeight * entry.bodyRow) * water),
          drawWidth,
          drawHeight);
      if (swimming) {
        // Transparent surface glints and expanding wakes anchor strokes in water.
        for (var ring = 0; ring < 3; ring++) {
          final p = (time.value / 1.8 + ring / 3) % 1;
          canvas.drawOval(
              Rect.fromCenter(
                  center: anchor.translate(0, -height * .23 * water),
                  width: height * (.35 + p * .5),
                  height: height * (.06 + p * .08)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.3
                ..color =
                    Colors.white.withValues(alpha: (1 - p) * .65 * water));
        }
      }
      if (water < 1) {
        // A diffuse sky shadow, a small directional cast, then foot contact.
        // Keep the darkest part under the feet so the animal does not float.
        canvas.drawOval(
            Rect.fromCenter(
                center: anchor.translate(2, 1),
                width: height * .53,
                height: height * .075),
            Paint()
              ..color =
                  const Color(0xFF2F4659).withValues(alpha: .094 * (1 - water))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawOval(
            Rect.fromCenter(
                center: anchor.translate(height * .10, 2),
                width: height * .47,
                height: height * .035),
            Paint()
              ..color =
                  const Color(0xFF344B60).withValues(alpha: .078 * (1 - water))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        canvas.drawOval(
            Rect.fromCenter(
                center: anchor, width: height * .25, height: height * .025),
            Paint()
              ..color =
                  const Color(0xFF344655).withValues(alpha: .196 * (1 - water))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
      }
      canvas.save();
      if (swimming) {
        canvas.clipRect(
            Rect.fromLTRB(0, 0, size.width, anchor.dy - height * .22 * water));
      }
      if (member.direction == 6) {
        canvas.translate(anchor.dx * 2, 0);
        canvas.scale(-1, 1);
      }
      if (entry != null) {
        final sx = target.width / source.width;
        final sy = target.height / source.height;
        canvas.clipPath(
            entry.silhouette.transform(Float64List.fromList([
              sx,
              0,
              0,
              0,
              0,
              sy,
              0,
              0,
              0,
              0,
              1,
              0,
              target.left - source.left * sx,
              target.top - source.top * sy,
              0,
              1,
            ])),
            doAntiAlias: false);
      }
      canvas.drawImageRect(
          image,
          source,
          target,
          Paint()
            ..filterQuality = FilterQuality.high
            ..colorFilter =
                const ColorFilter.mode(Color(0xFFF1F5FA), BlendMode.modulate));
      canvas.restore();
      if (swimming) {
        canvas.drawOval(
            Rect.fromCenter(
                center: anchor.translate(0, -height * .22 * water),
                width: height * .43,
                height: 5),
            Paint()
              ..color = const Color(0xFFC2EAF6).withValues(alpha: .44 * water));
      }
    }
    final feed = feeding;
    if (feed != null && feed.fishVisible(time.value)) {
      final p = feed.fishPosition(time.value);
      final width = (compact ? 25.0 : 35.0) * feed.fishScale(time.value);
      final image = images['herring']!;
      canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromCenter(
              center: Offset(p.dx * size.width, p.dy * size.height),
              width: width,
              height: width),
          Paint()..filterQuality = FilterQuality.high);
    }
  }

  @override
  bool shouldRepaint(covariant _FamilyPainter oldDelegate) =>
      oldDelegate.images != images ||
      oldDelegate.compact != compact ||
      oldDelegate.feeding != feeding;
}
