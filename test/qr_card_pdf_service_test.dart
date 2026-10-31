import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/qr_card_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('individual and 100-card batches produce complete printable A4 PDFs',
      () async {
    final renderer = await QrCardPdfService.load();
    for (final count in [1, 100]) {
      final cards = List.generate(
          count,
          (index) => <String, dynamic>{
                'employee_id': 'SAMPLE$index',
                'name': 'SAMPLE EMPLOYEE $index',
                'branch_id': 'ALOR SETAR',
                'qr_value': 'HBQR1_${List.filled(43, 'A').join()}',
              });
      final bytes = await renderer.build(cards, {});
      expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
      final pages =
          RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;
      expect(pages, count == 1 ? 1 : 17);
      if (count == 1) {
        await File('${Directory.systemTemp.path}/hasani-qr-card-preview.pdf')
            .writeAsBytes(bytes);
      }
    }
  });
}
