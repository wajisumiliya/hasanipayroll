import 'dart:math' as math;
import 'dart:ui';
import 'login_habitat_scene.dart';
import 'login_penguin_terrain.dart';

/// A dry-ground out-and-back trail. Its turns are explicit rest stops rather
/// than a closed loop that can cut across open water or the sign-in card.
class PenguinWalkPath {
  PenguinWalkPath(this.size,
      {bool compact = false,
      LoginHabitatScene scene = const LoginHabitatScene(5, 'evening'),
      Size imageSize = const Size(1672, 941)}) {
    final source = compact
        ? const [
            Offset(.18, .85),
            Offset(.4, .84),
            Offset(.62, .84),
            Offset(.82, .85)
          ]
        : LoginPenguinTerrain.forScene(scene).points;
    final projection = LoginPhotoProjection(imageSize, size);
    final projected = source
        .map((p) => compact
            ? Offset(p.dx * size.width, p.dy * size.height)
            : projection.project(p))
        .toList();
    final left = compact
        ? math.min(88.0, size.width * .30)
        : math.min(110.0, size.width * .20);
    final right = compact
        ? size.width - math.min(88.0, size.width * .30)
        : math.max(left + 12, size.width * .55 - 110);
    // Clip only along authored straight ground segments; do not clamp a point
    // onto arbitrary terrain after projecting the background's cover crop.
    final visible = <Offset>[];
    for (var i = 0; i < projected.length - 1; i++) {
      final a = projected[i], b = projected[i + 1];
      final dx = b.dx - a.dx;
      if (dx.abs() < .001) continue;
      final lo =
          math.max(0.0, math.min((left - a.dx) / dx, (right - a.dx) / dx));
      final hi =
          math.min(1.0, math.max((left - a.dx) / dx, (right - a.dx) / dx));
      if (lo > hi) continue;
      final start = Offset.lerp(a, b, lo)!, end = Offset.lerp(a, b, hi)!;
      if (visible.isEmpty || (visible.last - start).distance > .1) {
        visible.add(start);
      }
      visible.add(end);
    }
    if (visible.length < 2) throw StateError('No visible dry-ground trail');
    final points = visible.reversed.toList();
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    _metric = path.computeMetrics().first;
  }
  final Size size;
  late final PathMetric _metric;
  double get length => _metric.length;
  Tangent at(double distance) =>
      _metric.getTangentForOffset(distance.clamp(0.0, length - .001))!;
  static int direction(Offset tangent) =>
      (math.atan2(tangent.dx, tangent.dy) / (math.pi / 4)).round() % 8;
  static double projectedStride(int direction) {
    final angle = direction * math.pi / 4;
    return math.sqrt(
        math.pow(math.sin(angle), 2) + math.pow(math.cos(angle) * .234, 2));
  }

  static double depth(Offset position, Size size) =>
      .56 + .44 * ((position.dy / size.height - .35) / .65).clamp(0.0, 1.0);
}
