import 'dart:math' as math;
import 'dart:ui';

/// The user's marked ice route, normalised to the login viewport. No guide line
/// is painted. A separate compact trail stays below the mobile sign-in form.
class PenguinWalkPath {
  PenguinWalkPath(this.size, {bool compact = false}) {
    final points = compact
        ? const [
            Offset(.50, .90),
            Offset(.82, .88),
            Offset(.87, .62),
            Offset(.65, .48),
            Offset(.27, .48),
            Offset(.14, .68),
            Offset(.20, .89)
          ]
        : const [
            Offset(.50, .94),
            Offset(.565, .935),
            Offset(.555, .84),
            Offset(.345, .79),
            Offset(.16, .70),
            Offset(.083, .63),
            Offset(.087, .60),
            Offset(.22, .565),
            Offset(.365, .565),
            Offset(.37, .495),
            Offset(.16, .495),
            Offset(.142, .46),
            Offset(.145, .417),
            Offset(.41, .409),
            Offset(.41, .378),
            Offset(.07, .375),
            Offset(.068, .448),
            Offset(.045, .454),
            Offset(.047, .67),
            Offset(.065, .73),
            Offset(.065, .76),
            Offset(.051, .773),
            Offset(.062, .90),
            Offset(.24, .974),
            Offset(.31, .975),
            Offset(.43, .93),
            Offset(.46, .93),
            Offset(.48, .975)
          ];
    final p = points
        .map((v) => Offset(v.dx * size.width, v.dy * size.height))
        .toList();
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 0; i < p.length; i++) {
      final previous = p[(i - 1 + p.length) % p.length];
      final start = p[i];
      final end = p[(i + 1) % p.length];
      final next = p[(i + 2) % p.length];
      // Mild corner rounding follows the hand-marked route without sharp snaps.
      final control1 = start + (end - previous) * .10;
      final control2 = end - (next - start) * .10;
      path.cubicTo(
          control1.dx, control1.dy, control2.dx, control2.dy, end.dx, end.dy);
    }
    path.close();
    _metric = path.computeMetrics().first;
  }
  final Size size;
  late final PathMetric _metric;
  double get length => _metric.length;
  Tangent at(double distance) =>
      _metric.getTangentForOffset(distance % length)!;

  /// Rendered headings: front (0), right profile (2), back (4), left profile (6).
  static int direction(Offset tangent) =>
      (math.atan2(tangent.dx, tangent.dy) / (math.pi / 4)).round() % 8;

  /// Ground movement towards/away from this render camera is foreshortened.
  /// Matching projected stride to the model's camera keeps stance feet planted.
  static double projectedStride(int direction) {
    final angle = direction * math.pi / 4;
    return math.sqrt(
        math.pow(math.sin(angle), 2) + math.pow(math.cos(angle) * .234, 2));
  }

  static double depth(Offset position, Size size) =>
      .56 + .44 * ((position.dy / size.height - .35) / .65).clamp(0.0, 1.0);
}
