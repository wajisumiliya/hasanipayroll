import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

class PayslipDownloadService {
  static const _channel = MethodChannel('com.hasani.payroll/downloads');

  /// Returns false when the user cancels the legacy Android save picker.
  static Future<bool> save(Uint8List bytes, String filename) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final saved = await _channel.invokeMethod<bool>('savePdf', {
        'bytes': bytes,
        'filename': filename,
      });
      if (saved == true) return true;
      // Android before scoped storage uses a system save picker. No broad
      // storage permission or share sheet is needed.
      final path = await FileSaver.instance.saveAs(
        name: filename.replaceFirst(RegExp(r'\.pdf$'), ''),
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      return path != null;
    }
    return Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
