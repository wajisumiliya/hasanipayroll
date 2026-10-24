import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('photoreal animation sheets have sixteen distinct isolated poses',
      () async {
    for (final name in [
      'adult_walk_2',
      'adult_swim_2',
      'adult_eat_2',
      'adult_enter_2',
      'young_walk_2',
      'baby_walk_2'
    ]) {
      final data = await rootBundle.load('assets/penguins/family/$name.png');
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      try {
        expect(image.width, greaterThan(1000));
        expect(image.height, greaterThan(1000));
        final rgba =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final hashes = <int>{};
        for (var frame = 0; frame < 16; frame++) {
          var opaque = 0;
          var transparent = 0;
          var hash = 17;
          final left = (frame % 4 * image.width / 4).floor();
          final top = (frame ~/ 4 * image.height / 4).floor();
          for (var y = 0; y < image.height ~/ 4; y += 7) {
            for (var x = 0; x < image.width ~/ 4; x += 7) {
              final index = ((top + y) * image.width + left + x) * 4;
              final alpha = rgba.getUint8(index + 3);
              if (alpha > 150) opaque++;
              if (alpha == 0) transparent++;
              hash = (hash * 31 + rgba.getUint32(index)) & 0x3fffffff;
            }
          }
          expect(opaque, greaterThan(50),
              reason: '$name frame $frame has an animal');
          expect(transparent, greaterThan(50),
              reason: '$name frame $frame has alpha isolation');
          hashes.add(hash);
        }
        expect(hashes, hasLength(16),
            reason: '$name animates actual changing poses');
      } finally {
        image.dispose();
      }
    }
  });
}
