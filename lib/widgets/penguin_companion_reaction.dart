import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/penguin_entry_geometry.dart';
import '../services/penguin_growth.dart';

/// Separate articulated expressions, keeping the feet planted in one place.
class PenguinCompanionReaction extends StatefulWidget {
  const PenguinCompanionReaction(
      {super.key,
      required this.stage,
      required this.action,
      required this.daysSinceHatch,
      this.reactionId = 0});
  final String stage, action;
  final int daysSinceHatch;
  final int reactionId;
  @override
  State<PenguinCompanionReaction> createState() =>
      _PenguinCompanionReactionState();
}

class _PenguinCompanionReactionState extends State<PenguinCompanionReaction>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  ui.Image? _image;
  List<PenguinEntryPose>? _poses;
  int _generation = 0;
  bool _failed = false;
  String get _age => widget.stage == 'chick' ? 'chick' : 'adult';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  void _start() {
    if (MediaQuery.disableAnimationsOf(context) || widget.action == 'idle') {
      _motion.stop();
      _motion.value = 1;
    } else {
      _motion.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant PenguinCompanionReaction old) {
    super.didUpdateWidget(old);
    if ((old.stage == 'chick') != (widget.stage == 'chick')) {
      _load();
    }
    if (old.action != widget.action || old.reactionId != widget.reactionId) {
      _start();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    ui.Image? image;
    try {
      final data =
          await rootBundle.load('assets/penguins/${_age}_reactions.png');
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (pixels == null) throw StateError('Missing pose data');
      final poses = penguinEntryGeometry(image.width, image.height, pixels);
      if (!mounted || generation != _generation) {
        image.dispose();
        return;
      }
      final previous = _image;
      setState(() {
        _image = image;
        _poses = poses;
        _failed = false;
      });
      previous?.dispose();
      _start();
    } catch (_) {
      image?.dispose();
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _generation++;
    _motion.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = switch (widget.action) {
      'eating' => 0,
      'idle' => 0,
      'playing' => 1,
      'petting' => 2,
      _ => 3
    };
    final image = _image, poses = _poses;
    return SizedBox(
        width: 220,
        height: 190,
        child: image == null || poses == null
            ? Transform.scale(
                scale: penguinGrowthScale(widget.daysSinceHatch),
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                    'assets/penguins/$_age${widget.action == 'sleeping' ? '_sleep' : ''}.png',
                    fit: BoxFit.contain,
                    semanticLabel: _failed ? 'Penguin resting' : 'Penguin',
                    cacheHeight: 512))
            : AnimatedBuilder(
                animation: _motion,
                builder: (context, _) => CustomPaint(
                    painter: _ReactionPainter(
                        image,
                        poses,
                        row,
                        _motion.value,
                        penguinGrowthScale(widget.daysSinceHatch),
                        MediaQuery.disableAnimationsOf(context)),
                    child: Semantics(label: 'Penguin ${widget.action}'))));
  }
}

class _ReactionPainter extends CustomPainter {
  _ReactionPainter(this.image, this.poses, this.row, this.progress, this.growth,
      this.reduced);
  final ui.Image image;
  final List<PenguinEntryPose> poses;
  final int row;
  final double progress, growth;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    final frame = (progress * 4).floor().clamp(0, 3);
    final pose = poses[row * 4 + frame];
    final heights = poses.map((p) => p.source.height).toList()..sort();
    final scale = size.height * .90 * growth / ((heights[7] + heights[8]) / 2);
    final foot = Offset(size.width * .50, size.height * .96);
    final source = pose.source;
    final target = Rect.fromLTWH(
        foot.dx - source.width * scale * pose.footX,
        foot.dy - source.height * scale,
        source.width * scale,
        source.height * scale);
    canvas.drawOval(
        Rect.fromCenter(center: foot, width: 45 * growth, height: 6 * growth),
        Paint()
          ..color = const Color(0x28243E50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.save();
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
        image, source, target, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();
    if (row == 0 && progress < .5) {
      // The fish reaches the open beak before the chewing expression starts.
      final t = (progress / .5).clamp(0.0, 1.0);
      final beak = Offset(
          target.left + target.width * .68, target.top + target.height * .18);
      final center =
          Offset.lerp(foot + Offset(70 * growth, -65 * growth), beak, t)!;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(growth);
      canvas.drawOval(const Rect.fromLTWH(-10, -4, 20, 8),
          Paint()..color = const Color(0xFF99BACB));
      canvas.drawPath(
          Path()
            ..moveTo(8, 0)
            ..lineTo(16, -6)
            ..lineTo(16, 6)
            ..close(),
          Paint()..color = const Color(0xFF55778B));
      canvas.drawCircle(const Offset(-6, -1), 1, Paint()..color = Colors.black);
      canvas.restore();
    }
    if (row == 1) {
      final x = reduced ? 0 : math.sin(progress * math.pi * 2) * 35 * growth;
      final ball = foot + Offset(x + 40 * growth, -7 * growth);
      canvas.drawCircle(
          ball, 9 * growth, Paint()..color = const Color(0xFFEAF8FF));
      canvas.drawCircle(ball + Offset(-2 * growth, -2 * growth), 3 * growth,
          Paint()..color = Colors.white);
    }
    if (row == 2) {
      final rise = reduced ? 0 : progress * 22 * growth;
      final heart = Path()
        ..moveTo(0, 7)
        ..cubicTo(-16, -3, -6, -14, 0, -6)
        ..cubicTo(6, -14, 16, -3, 0, 7)
        ..close();
      for (final offset in [
        Offset(-45 * growth, -115 * growth - rise),
        Offset(32 * growth, -140 * growth - rise)
      ]) {
        canvas.save();
        canvas.translate(foot.dx + offset.dx, foot.dy + offset.dy);
        canvas.scale(growth * .75);
        canvas.drawPath(heart, Paint()..color = const Color(0xFFD96E8F));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReactionPainter old) =>
      old.image != image ||
      old.progress != progress ||
      old.row != row ||
      old.growth != growth ||
      old.reduced != reduced;
}
