import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/penguin_entry_geometry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('entry poses isolate each penguin despite unequal vertical spacing',
      () async {
    final data =
        await rootBundle.load('assets/penguins/family/adult_enter_2.png');
    final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    try {
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final poses = penguinEntryGeometry(image.width, image.height, bytes);
      expect(poses, hasLength(16));
      expect(poses.first.source.height, greaterThan(poses.first.source.width));
      expect(poses.last.source.width, greaterThan(poses.last.source.height));
      var excludedPixels = 0;
      for (var index = 0; index < 16; index++) {
        final pose = poses[index];
        expect(pose.source.left, greaterThanOrEqualTo(0));
        expect(pose.source.top, greaterThanOrEqualTo(0));
        expect(pose.source.right, lessThanOrEqualTo(image.width));
        expect(pose.source.bottom, lessThanOrEqualTo(image.height));
        expect(pose.bodyRow, inInclusiveRange(0, 1));
        expect(pose.footX, inInclusiveRange(0, 1));
        for (var y = pose.source.top.toInt(); y < pose.source.bottom; y += 7) {
          for (var x = pose.source.left.toInt();
              x < pose.source.right;
              x += 7) {
            if (bytes.getUint8((y * image.width + x) * 4 + 3) > 150 &&
                !pose.silhouette.contains(ui.Offset(x + .5, y + .5))) {
              excludedPixels++;
            }
          }
        }
        if (index >= 4) {
          expect(poses[index - 4].source.bottom, lessThan(pose.source.top),
              reason: 'No neighboring row fragments can enter this frame');
        }
      }
      expect(excludedPixels, greaterThan(0),
          reason:
              'Silhouette masks exclude neighboring fragments inside a bounding rectangle');
    } finally {
      image.dispose();
    }
  });
}
