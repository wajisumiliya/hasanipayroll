import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../services/mystery_egg_hatch_controller.dart';
import '../services/penguin_growth.dart';
import '../services/penguin_walk_path.dart';
import 'mystery_egg_teaser.dart';

/// An original 3D-rendered articulated walk, not a translated still photograph.
/// Eight headings x sixteen poses give real stance/swing feet, body weight shift,
/// counterbalancing flippers and head motion. All platforms use the same frames.
class LoginPenguinWalker extends StatefulWidget {
  const LoginPenguinWalker(
      {super.key, required this.controller, this.compact = false});
  final MysteryEggHatchController controller;
  final bool compact;
  @override
  State<LoginPenguinWalker> createState() => _LoginPenguinWalkerState();
}

class _LoginPenguinWalkerState extends State<LoginPenguinWalker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  List<ui.Image>? _atlases;
  bool _loading = false;
  bool _failed = false;
  bool _reduceMotion = false;
  Duration? _previous;
  PenguinWalkPath? _route;
  double _distance = 0;
  double _phase = 0;
  // Twice the original walking speed; travel and footsteps share one clock.
  static const _gaitCycleSeconds = .4;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.attach();
    _prepare();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant LoginPenguinWalker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      oldWidget.controller.detach();
      widget.controller.addListener(_changed);
      widget.controller.attach();
      _distance = 0;
      _phase = 0;
      _prepare();
    }
  }

  void _changed() {
    if (!mounted) return;
    _prepare();
    _syncTicker();
    setState(() {});
  }

  void _prepare() {
    if (widget.controller.stage != 'egg' || widget.controller.hatching) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_loading || _atlases != null || _failed) return;
    _loading = true;
    try {
      final images = await Future.wait(
          List.generate(8, (direction) async {
            final data = await rootBundle
                .load('assets/penguins/walk/walk_$direction.png');
            final codec =
                await ui.instantiateImageCodec(data.buffer.asUint8List());
            try {
              return (await codec.getNextFrame()).image;
            } finally {
              codec.dispose();
            }
          }),
          cleanUp: (ui.Image image) => image.dispose());
      if (!mounted) {
        for (final image in images) {
          image.dispose();
        }
        return;
      }
      setState(() => _atlases = images);
      _syncTicker();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      debugPrint('Penguin walking animation unavailable.');
    } finally {
      _loading = false;
    }
  }

  void _syncTicker() {
    final moving =
        !_reduceMotion && _atlases != null && widget.controller.stage != 'egg';
    if (moving && !_ticker.isActive) {
      _previous = null;
      _ticker.start();
    }
    if (!moving && _ticker.isActive) {
      _ticker.stop();
      _previous = null;
    }
  }

  double _height() {
    final width = _route?.size.width ?? 1000;
    final adult = widget.compact ? 220.0 : (width * .18).clamp(160.0, 300.0);
    return adult * penguinGrowthScale(widget.controller.daysSinceHatch);
  }

  void _tick(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    if (!mounted || previous == null || _route == null) return;
    // Resume without teleporting forward across time spent in the background.
    final dt = ((elapsed - previous).inMicroseconds / 1000000).clamp(0.0, .05);
    final tangent = _route!.at(_distance);
    final depth = PenguinWalkPath.depth(tangent.position, _route!.size);
    // Each rendered gait cycle advances .20 body-box heights. The planted foot
    // travels back by the same amount, preventing the photo-sliding effect.
    final stride = PenguinWalkPath.projectedStride(
        PenguinWalkPath.direction(tangent.vector));
    _distance = (_distance +
            _height() * depth * .20 * stride / _gaitCycleSeconds * dt) %
        _route!.length;
    _phase = (_phase + dt / _gaitCycleSeconds) % 1;
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.controller.detach();
    _ticker.dispose();
    for (final image in _atlases ?? <ui.Image>[]) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: LayoutBuilder(builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
            return const SizedBox.shrink();
          }
          if (_route?.size != size) {
            final fraction = _route == null ? 0.0 : _distance / _route!.length;
            _route = PenguinWalkPath(size, compact: widget.compact);
            _distance = _route!.length * fraction;
          }
          if (widget.controller.stage == 'egg') {
            final eggSize =
                widget.compact ? 180.0 : (size.width * .18).clamp(160.0, 300.0);
            return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MysteryEggTeaser(
                        size: eggSize, controller: widget.controller)));
          }
          if (_atlases == null) {
            return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _failed
                        ? const Text('Your penguin is resting.')
                        : const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))));
          }
          return Semantics(
              label: _reduceMotion
                  ? 'Penguin resting on the ice'
                  : 'Penguin walking around its icy habitat',
              child: RepaintBoundary(
                  child: CustomPaint(
                      size: size,
                      painter: _WalkerPainter(
                          _atlases!,
                          _route!,
                          _distance,
                          _reduceMotion ? 0 : (_phase * 16).floor() % 16,
                          _height(),
                          widget.compact))));
        }),
      );
}

class _WalkerPainter extends CustomPainter {
  _WalkerPainter(this.atlases, this.route, this.distance, this.frame,
      this.height, this.compact);
  final List<ui.Image> atlases;
  final PenguinWalkPath route;
  final double distance;
  final int frame;
  final double height;
  final bool compact;
  @override
  void paint(Canvas canvas, Size size) {
    final tangent = route.at(distance);
    final depth = PenguinWalkPath.depth(tangent.position, size);
    final side = height * depth;
    final visualHalf = side * .30;
    final right =
        compact ? size.width - visualHalf - 4 : size.width * .59 - visualHalf;
    final foot = Offset(
        tangent.position.dx
            .clamp(visualHalf + 4, math.max(visualHalf + 4, right)),
        tangent.position.dy.clamp(side * .92, size.height * .98));
    canvas.drawOval(
        Rect.fromCenter(
            center: foot.translate(0, 1),
            width: side * .40,
            height: side * .065),
        Paint()
          ..color = Colors.black.withValues(alpha: .20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    final image = atlases[PenguinWalkPath.direction(tangent.vector)];
    final source =
        Rect.fromLTWH((frame % 4) * 256.0, (frame ~/ 4) * 256.0, 256, 256);
    final target =
        Rect.fromLTWH(foot.dx - side / 2, foot.dy - side * .91, side, side);
    canvas.drawImageRect(
        image, source, target, Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(covariant _WalkerPainter old) =>
      old.distance != distance ||
      old.frame != frame ||
      old.height != height ||
      old.route != route ||
      old.atlases != atlases;
}
