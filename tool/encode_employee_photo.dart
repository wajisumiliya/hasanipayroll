// One-shot migration helper. Reads image bytes from stdin and writes a small JPEG.
import 'dart:io';
import 'package:image/image.dart' as img;

Future<void> main() async {
  try {
    final input = <int>[];
    await for (final chunk in stdin) {
      input.addAll(chunk);
      if (input.length > 5 * 1024 * 1024) throw StateError('Photo too large');
    }
    final decoded = img.decodeImage(input);
    if (decoded == null || decoded.width * decoded.height > 40000000) {
      throw StateError('Invalid photo');
    }
    final oriented = img.bakeOrientation(decoded);
    final resized = oriented.width > 480 || oriented.height > 480
        ? img.copyResize(oriented,
            width: oriented.width >= oriented.height ? 480 : null,
            height: oriented.height > oriented.width ? 480 : null,
            interpolation: img.Interpolation.average)
        : oriented;
    final output = img.encodeJpg(resized, quality: 78);
    if (output.length > 512 * 1024) throw StateError('Photo too large');
    stdout.add(output);
    await stdout.flush();
  } catch (_) {
    stderr.writeln('Unable to optimize photo.');
    exitCode = 1;
  }
}
