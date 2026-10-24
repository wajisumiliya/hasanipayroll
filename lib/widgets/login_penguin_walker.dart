import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../services/login_habitat_scene.dart';
import '../services/login_penguin_terrain.dart';
import '../services/mystery_egg_hatch_controller.dart';
import '../services/penguin_entry_geometry.dart';
import '../services/penguin_growth.dart';
import '../services/penguin_walk_path.dart';
import 'mystery_egg_teaser.dart';

/// A photographic-style, age-aware penguin on the current scene's dry trail.
/// The welcome cue is a focus boolean, never a username/password value.
class LoginPenguinWalker extends StatefulWidget {
  const LoginPenguinWalker(
      {super.key,
      required this.controller,
      this.compact = false,
      this.scene = const LoginHabitatScene(5, 'evening'),
      this.lookAtForm = false});
  final MysteryEggHatchController controller;
  final bool compact;
  final LoginHabitatScene scene;
  final bool lookAtForm;
  @override
  State<LoginPenguinWalker> createState() => _LoginPenguinWalkerState();
}

class _LoginPenguinAssets {
  _LoginPenguinAssets(
      this.walk, this.idle, this.photo, this.walkPoses, this.idlePoses);
  static double _medianHeight(List<PenguinEntryPose> poses) {
    final heights = poses.map((pose) => pose.source.height).toList()..sort();
    return (heights[7] + heights[8]) / 2;
  }

  late final double walkHeight = _medianHeight(walkPoses);
  late final double idleHeight = _medianHeight(idlePoses);
  final ui.Image walk, idle, photo;
  final List<PenguinEntryPose> walkPoses, idlePoses;
  void dispose() {
    walk.dispose();
    idle.dispose();
    photo.dispose();
  }
}

class _LoginPenguinWalkerState extends State<LoginPenguinWalker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  _LoginPenguinAssets? _assets;
  String? _requestedKey;
  int _generation = 0;
  bool _failed = false, _reduceMotion = false, _forward = true;
  Duration? _previous;
  PenguinWalkPath? _route;
  double _distance = 0,
      _phase = 0,
      _seconds = 0,
      _pause = 1.6,
      _rest = 0,
      _greeting = 0;
  static const _gaitCycleSeconds =
      .4; // Preserve the requested doubled gait cadence.
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
    _sync();
  }

  @override
  void didUpdateWidget(covariant LoginPenguinWalker old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      old.controller.detach();
      widget.controller.addListener(_changed);
      widget.controller.attach();
    }
    if (old.lookAtForm != widget.lookAtForm) {
      _greeting = widget.lookAtForm ? 1.6 : 0;
      _rest = 0;
    }
    if (old.scene.asset != widget.scene.asset ||
        old.compact != widget.compact ||
        old.controller != widget.controller) {
      _route = null;
      _distance = 0;
      _forward = true;
      _pause = 1.6;
      _prepare();
    }
    _sync();
  }

  void _changed() {
    if (!mounted) return;
    _prepare();
    _sync();
    setState(() {});
  }

  void _prepare() {
    if (widget.controller.stage == 'egg' && !widget.controller.hatching) return;
    final variant = loginPenguinVariant(widget.controller.daysSinceHatch);
    final photo = widget.compact
        ? 'assets/penguins/family/coast.png'
        : widget.scene.asset;
    final key = '$variant|$photo';
    if (key == _requestedKey) return;
    _requestedKey = key;
    _failed = false;
    _route = null;
    _assets?.dispose();
    _assets = null;
    final version = ++_generation;
    unawaited(_load(variant, photo, version));
  }

  Future<void> _load(String variant, String photo, int version) async {
    final decoded = <ui.Image>[];
    try {
      final images = await Future.wait(
          [
            'assets/penguins/family/${variant == 'baby' ? 'baby_walk_natural' : '${variant}_walk_2'}.png',
            'assets/penguins/family/${variant == 'baby' ? 'baby_idle_natural' : '${variant}_idle_2'}.png',
            photo,
          ].map((path) async {
            final bytes = await rootBundle.load(path);
            final codec = await ui.instantiateImageCodec(bytes.buffer
                .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
            try {
              return (await codec.getNextFrame()).image;
            } finally {
              codec.dispose();
            }
          }),
          cleanUp: (ui.Image image) => image.dispose());
      decoded.addAll(images);
      final poses = <List<PenguinEntryPose>>[];
      for (final image in images.take(2)) {
        final pixels =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (pixels == null) throw StateError('Penguin pose data unavailable');
        poses.add(penguinEntryGeometry(image.width, image.height, pixels));
      }
      if (!mounted || version != _generation) {
        for (final image in decoded) {
          image.dispose();
        }
        return;
      }
      setState(() {
        _assets = _LoginPenguinAssets(
            images[0], images[1], images[2], poses[0], poses[1]);
        _route = null;
      });
      _sync();
    } catch (_) {
      for (final image in decoded) {
        image.dispose();
      }
      if (mounted && version == _generation) setState(() => _failed = true);
    }
  }

  void _sync() {
    final moving =
        !_reduceMotion && _assets != null && widget.controller.stage != 'egg';
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
    final adult = widget.compact
        ? math.min(150.0, width * .45)
        : (width * .15).clamp(160.0, 240.0);
    return adult * penguinGrowthScale(widget.controller.daysSinceHatch);
  }

  void _tick(Duration elapsed) {
    if (_previous == null) {
      _previous = elapsed;
      return;
    }
    final delta = elapsed - _previous!;
    if (delta.inMicroseconds < 32000) return;
    _previous = elapsed;
    if (!mounted || _route == null) return;
    final dt = (delta.inMicroseconds / 1e6).clamp(0.0, .1);
    _seconds += dt;
    if (_greeting > 0) {
      _greeting = math.max(0, _greeting - dt);
      _rest += dt;
    } else if (_pause > 0) {
      _pause = math.max(0, _pause - dt);
      _rest += dt;
    } else {
      final depth =
          PenguinWalkPath.depth(_route!.at(_distance).position, _route!.size);
      final travel = _height() * depth * .20 / _gaitCycleSeconds * dt;
      _distance += _forward ? travel : -travel;
      _phase = (_phase + dt / _gaitCycleSeconds) % 1;
      if (_distance >= _route!.length || _distance <= 0) {
        _distance = _distance.clamp(0.0, _route!.length);
        _forward = !_forward;
        _pause = widget.scene.period == 'night' ? 4 : 2.2;
        _rest = 0;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _generation++;
    widget.controller.removeListener(_changed);
    widget.controller.detach();
    _ticker.dispose();
    _assets?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
          return const SizedBox.shrink();
        }
        if (widget.controller.stage == 'egg') {
          return Align(
              alignment: Alignment.bottomCenter,
              child: MysteryEggTeaser(
                  size: widget.compact ? 160 : 180,
                  controller: widget.controller));
        }
        final assets = _assets;
        if (assets == null) {
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
        if (_route == null || _route!.size != size) {
          final fraction = _route == null ? 0.0 : _distance / _route!.length;
          _route = PenguinWalkPath(size,
              compact: widget.compact,
              scene: widget.scene,
              imageSize: Size(assets.photo.width.toDouble(),
                  assets.photo.height.toDouble()));
          _distance = _route!.length * fraction;
        }
        final quiet = _reduceMotion || _pause > 0 || _greeting > 0;
        final direction = _greeting > 0
            ? 2
            : ((_route!.at(_distance).vector.dx * (_forward ? 1 : -1)) >= 0
                ? 2
                : 6);
        final frame = quiet
            ? (_reduceMotion ? 0 : (_rest / 1.6 * 15).floor().clamp(0, 15))
            : (_phase * 16).floor() % 16;
        final painter = _NaturalLoginPainter(
            assets,
            _route!,
            _distance,
            _height(),
            frame,
            quiet,
            direction,
            widget.scene,
            _seconds,
            widget.compact);
        final canvas = Semantics(
            label: _reduceMotion
                ? 'Penguin resting on the ice'
                : _greeting > 0
                    ? 'Penguin looking towards the sign-in form'
                    : 'Penguin exploring its dry-ground trail',
            child: RepaintBoundary(
                child: CustomPaint(size: size, painter: painter)));
        return widget.compact
            ? ClipRRect(borderRadius: BorderRadius.circular(22), child: canvas)
            : canvas;
      }));
}

class _NaturalLoginPainter extends CustomPainter {
  _NaturalLoginPainter(
      this.assets,
      this.route,
      this.distance,
      this.height,
      this.frame,
      this.quiet,
      this.direction,
      this.scene,
      this.seconds,
      this.compact);
  final _LoginPenguinAssets assets;
  final PenguinWalkPath route;
  final double distance, height, seconds;
  final int frame, direction;
  final bool quiet, compact;
  final LoginHabitatScene scene;
  Color get tint => scene.period == 'night'
      ? const Color(0xFF8A9FBC)
      : scene.period == 'evening'
          ? const Color(0xFFFFE6D0)
          : const Color(0xFFF3F7FC);
  @override
  void paint(Canvas canvas, Size size) {
    if (compact) {
      // A dedicated photographed ice perch prevents walking on a portrait
      // background crop that happens to show only open water.
      final ground = Rect.fromLTWH(0, assets.photo.height * .80,
          assets.photo.width * .52, assets.photo.height * .20);
      final fit = applyBoxFit(BoxFit.cover, ground.size, size);
      final source = Alignment.center.inscribe(fit.source, ground);
      canvas.drawImageRect(
          assets.photo,
          source,
          Offset.zero & size,
          Paint()
            ..filterQuality = FilterQuality.high
            ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate));
    } else {
      _paintAtmosphere(canvas, size);
    }
    final foot = route.at(distance).position;
    final side = height * PenguinWalkPath.depth(foot, size);
    canvas.drawOval(
        Rect.fromCenter(
            center: foot.translate(2, 1),
            width: side * .44,
            height: side * .06),
        Paint()
          ..color = const Color(0x222B4256)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawOval(
        Rect.fromCenter(center: foot, width: side * .23, height: side * .025),
        Paint()
          ..color = const Color(0x38304350)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3));
    final image = quiet ? assets.idle : assets.walk;
    // Both gait and idle poses use their actual silhouettes. Transparent cell
    // padding must not lift the feet or change the animal's scale at rest.
    final pose = (quiet ? assets.idlePoses : assets.walkPoses)[frame];
    final source = pose.source;
    final scale = side * .90 / (quiet ? assets.idleHeight : assets.walkHeight);
    final drawSize = Size(source.width * scale, source.height * scale);
    final target = Rect.fromLTWH(foot.dx - drawSize.width * pose.footX,
        foot.dy - drawSize.height, drawSize.width, drawSize.height);
    canvas.save();
    if (direction == 6) {
      canvas.translate(foot.dx * 2, 0);
      canvas.scale(-1, 1);
    }
    canvas.clipPath(
        pose.silhouette.transform(Float64List.fromList([
          scale,
          0,
          0,
          0,
          0,
          scale,
          0,
          0,
          0,
          0,
          1,
          0,
          target.left - source.left * scale,
          target.top - source.top * scale,
          0,
          1,
        ])),
        doAntiAlias: false);
    canvas.drawImageRect(
        image,
        source,
        target,
        Paint()
          ..filterQuality = FilterQuality.high
          ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate));
    canvas.restore();
  }

  void _paintAtmosphere(Canvas canvas, Size size) {
    final projection = LoginPhotoProjection(
        Size(assets.photo.width.toDouble(), assets.photo.height.toDouble()),
        size);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * .54, size.height));
    if (scene.period != 'night' && scene.weekday != 7) {
      final sky = projection.projectRect(const Rect.fromLTWH(.40, 0, .15, .15));
      canvas.save();
      canvas.clipRect(sky);
      canvas.saveLayer(sky, Paint());
      final drift = math.sin(seconds / 70) * 5;
      canvas.drawImageRect(
          assets.photo,
          Rect.fromLTWH(0, 0, assets.photo.width.toDouble(),
              assets.photo.height.toDouble()),
          Rect.fromLTWH(
              drift,
              projection.top,
              assets.photo.width * projection.scale,
              assets.photo.height * projection.scale),
          Paint()..color = const Color(0x20FFFFFF));
      canvas.drawRect(
          sky,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = ui.Gradient.linear(sky.topCenter, sky.bottomCenter,
                [Colors.white, Colors.transparent]));
      canvas.restore();
      canvas.restore();
    }
    final water = Path();
    final points = scene.weekday == 7
        ? const [
            Offset(.28, .72),
            Offset(.99, .72),
            Offset(.99, .90),
            Offset(.32, .90)
          ]
        : const [
            Offset(.43, .56),
            Offset(.54, .56),
            Offset(.54, .62),
            Offset(.43, .62)
          ];
    for (var i = 0; i < points.length; i++) {
      final p = projection.project(points[i]);
      if (i == 0) {
        water.moveTo(p.dx, p.dy);
      } else {
        water.lineTo(p.dx, p.dy);
      }
    }
    water.close();
    canvas.clipPath(water);
    for (var i = 0; i < 18; i++) {
      final p = projection.project(Offset(
          .30 + ((i * .117 + seconds * .002) % 1) * .7, .56 + (i % 4) * .018));
      canvas.drawLine(
          p,
          p.translate(8 + 4.0 * (i % 3), 0),
          Paint()
            ..strokeWidth = .7
            ..color = Colors.white
                .withValues(alpha: scene.period == 'night' ? .035 : .055));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NaturalLoginPainter old) =>
      old.distance != distance ||
      old.frame != frame ||
      old.quiet != quiet ||
      old.direction != direction ||
      old.assets != assets ||
      old.seconds != seconds ||
      old.height != height ||
      old.route != route ||
      old.scene.asset != scene.asset;
}
