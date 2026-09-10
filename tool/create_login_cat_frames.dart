import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  for (var frameNumber = 1; frameNumber <= 8; frameNumber++) {
    final decoded = img.decodePng(
      File('assets/login_cat_walk_$frameNumber.png').readAsBytesSync(),
    );
    if (decoded == null) throw StateError('Cannot decode frame $frameNumber');
    final source = decoded.convert(numChannels: 4);
    for (final pixel in source) {
      final red = pixel.r.toInt();
      final green = pixel.g.toInt();
      final blue = pixel.b.toInt();
      final brightest = [red, green, blue].reduce((a, b) => a > b ? a : b);
      final darkest = [red, green, blue].reduce((a, b) => a < b ? a : b);
      if (brightest - darkest < 13 && (red + green + blue) / 3 > 168) {
        pixel.setRgba(0, 0, 0, 0);
      }
    }
    File('assets/login_cat_clean_$frameNumber.png')
        .writeAsBytesSync(img.encodePng(source));
  }
}