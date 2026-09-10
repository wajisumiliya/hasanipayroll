import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final encoder = img.GifEncoder();
  for (var frameNumber = 1; frameNumber <= 8; frameNumber++) {
    final source = img.decodePng(
      File('assets/login_cat_walk_$frameNumber.png').readAsBytesSync(),
    );
    if (source == null) {
      throw StateError('Unable to decode walking frame $frameNumber');
    }

    for (final pixel in source) {
      final red = pixel.r.toInt();
      final green = pixel.g.toInt();
      final blue = pixel.b.toInt();
      final brightest = [red, green, blue].reduce((a, b) => a > b ? a : b);
      final darkest = [red, green, blue].reduce((a, b) => a < b ? a : b);
      final neutral = brightest - darkest < 13;
      final lightChecker = neutral && (red + green + blue) / 3 > 168;
      if (lightChecker) {
        pixel.a = 0;
      }
    }

    encoder.addFrame(source, duration: 110);
  }

  final gif = encoder.finish();
  if (gif == null) throw StateError('Unable to encode walking GIF');
  File('assets/login_cat_walking.gif').writeAsBytesSync(gif);
}