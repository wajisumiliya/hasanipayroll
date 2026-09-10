import 'dart:io';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  for (final path in args) {
    final animation = img.decodeImage(File(path).readAsBytesSync());
    if (animation == null) { print(path + ': decode failed'); continue; }
    print(path + ': ' + animation.width.toString() + 'x' + animation.height.toString() + ', frames=' + animation.numFrames.toString());
    for (var f = 0; f < animation.numFrames; f++) {
      final frame = animation.frames[f];
      var minX = frame.width, minY = frame.height, maxX = -1, maxY = -1;
      var visible = 0;
      for (final pixel in frame) {
        if (pixel.a > 10) {
          visible++;
          if (pixel.x < minX) minX = pixel.x;
          if (pixel.y < minY) minY = pixel.y;
          if (pixel.x > maxX) maxX = pixel.x;
          if (pixel.y > maxY) maxY = pixel.y;
        }
      }
      print(' frame ' + f.toString() + ': visible=' + visible.toString() + ' bbox=' + minX.toString() + ',' + minY.toString() + '-' + maxX.toString() + ',' + maxY.toString());
    }
  }
}