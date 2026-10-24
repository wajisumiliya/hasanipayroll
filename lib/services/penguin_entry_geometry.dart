import 'dart:typed_data';
import 'dart:ui';

class PenguinEntryPose {
  const PenguinEntryPose(
      this.source, this.bodyRow, this.footX, this.silhouette);
  final Rect source;
  final double bodyRow;
  final double footX;
  final Path silhouette;
}

/// Reads sprite bounds without altering the original image. Generative pose
/// sheets have unequal vertical spacing; a uniform grid can show adjacent feet.
/// The sixteen large connected silhouettes define their actual frame bounds.
List<PenguinEntryPose> penguinEntryGeometry(
    int width, int height, ByteData rgba) {
  final count = width * height;
  final seen = Int32List(count);
  var componentId = 0;
  final queue = Int32List(count);
  final components = <({Rect rect, int area, int id})>[];
  bool opaque(int p) => rgba.getUint8(p * 4 + 3) > 100;
  for (var pixel = 0; pixel < count; pixel++) {
    if (seen[pixel] != 0 || !opaque(pixel)) continue;
    componentId++;
    var head = 0;
    var tail = 1;
    queue[0] = pixel;
    seen[pixel] = componentId;
    var left = width;
    var right = 0;
    var top = height;
    var bottom = 0;
    while (head < tail) {
      final p = queue[head++];
      final x = p % width;
      final y = p ~/ width;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
      if (x > 0 && seen[p - 1] == 0 && opaque(p - 1)) {
        seen[p - 1] = componentId;
        queue[tail++] = p - 1;
      }
      if (x + 1 < width && seen[p + 1] == 0 && opaque(p + 1)) {
        seen[p + 1] = componentId;
        queue[tail++] = p + 1;
      }
      if (y > 0 && seen[p - width] == 0 && opaque(p - width)) {
        seen[p - width] = componentId;
        queue[tail++] = p - width;
      }
      if (y + 1 < height && seen[p + width] == 0 && opaque(p + width)) {
        seen[p + width] = componentId;
        queue[tail++] = p + width;
      }
    }
    if (tail > 500) {
      components.add((
        rect: Rect.fromLTRB(
            left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0),
        area: tail,
        id: componentId
      ));
    }
  }
  components.sort((a, b) => b.area.compareTo(a.area));
  if (components.length < 16) throw StateError('Entry poses are not isolated');
  final columns = List.generate(4, (_) => <({Rect rect, int area, int id})>[]);
  for (final c in components.take(16)) {
    final col = (c.rect.center.dx / width * 4).floor().clamp(0, 3);
    columns[col].add(c);
  }
  if (columns.any((column) => column.length != 4)) {
    throw StateError('Entry pose layout is invalid');
  }
  for (final column in columns) {
    column.sort((a, b) => a.rect.top.compareTo(b.rect.top));
  }
  final result = <PenguinEntryPose>[];
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 4; col++) {
      final component = columns[col][row];
      final r = component.rect;
      final silhouette = Path();
      var bestCount = 0;
      var body = r.height / 2;
      var footSum = 0.0;
      var footCount = 0;
      for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) {
        var rowCount = 0;
        int? run;
        for (var x = r.left.toInt(); x < r.right.toInt(); x++) {
          final belongs = seen[y * width + x] == component.id;
          if (belongs) {
            run ??= x;
            rowCount++;
            if (y >= r.bottom - 8) {
              footSum += x - r.left;
              footCount++;
            }
          }
          if (!belongs && run != null) {
            silhouette
                .addRect(Rect.fromLTRB(run - 1.0, y - 1.0, x + 1.0, y + 2.0));
            run = null;
          }
        }
        if (run != null) {
          silhouette
              .addRect(Rect.fromLTRB(run - 1.0, y - 1.0, r.right + 1, y + 2.0));
        }
        if (rowCount > bestCount) {
          bestCount = rowCount;
          body = y - r.top;
        }
      }
      result.add(PenguinEntryPose(r, body / r.height,
          footCount == 0 ? .5 : footSum / footCount / r.width, silhouette));
    }
  }
  return result;
}
