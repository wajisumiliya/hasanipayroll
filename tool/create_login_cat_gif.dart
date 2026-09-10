import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final encoder = img.GifEncoder();
  for (var frame = 1; frame <= 8; frame++) {
    final bytes = File('assets/login_cat_walk_$frame.png').readAsBytesSync();
    final image = img.decodePng(bytes);
    if (image == null) {
      throw StateError('Unable to decode walking frame $frame');
    }
    encoder.addFrame(image, duration: 110);
  }
  final gif = encoder.finish();
  if (gif == null) throw StateError('Unable to encode walking GIF');
  File('assets/login_cat_walking.gif').writeAsBytesSync(gif);
}
