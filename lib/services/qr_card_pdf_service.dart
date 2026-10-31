import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class QrCardPdfService {
  QrCardPdfService._(this.font, this.bold);
  final pw.Font font, bold;
  static Future<QrCardPdfService> load() async => QrCardPdfService._(
        pw.Font.ttf(await rootBundle.load('assets/qr_fonts/DejaVuSans.ttf')),
        pw.Font.ttf(
            await rootBundle.load('assets/qr_fonts/DejaVuSans-Bold.ttf')),
      );
  Future<Uint8List> build(
      List<Map<String, dynamic>> cards, Map<String, Uint8List> photos) async {
    final doc =
        pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));
    doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text('HASANI PAYROLL · EMPLOYEE QR CARDS',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        build: (_) => [
              pw.Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards
                      .map((card) => pw.Container(
                            width: 260,
                            height: 185,
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                                border:
                                    pw.Border.all(color: PdfColors.blueGrey300),
                                borderRadius: pw.BorderRadius.circular(8)),
                            child: pw.Row(children: [
                              pw.Column(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.center,
                                  children: [
                                    pw.Container(
                                        color: PdfColors.white,
                                        padding: const pw.EdgeInsets.all(16),
                                        child: pw.BarcodeWidget(
                                            barcode: pw.Barcode.qrCode(),
                                            data: '${card['qr_value']}',
                                            width: 88,
                                            height: 88,
                                            drawText: false)),
                                    pw.SizedBox(height: 6),
                                    pw.Text('${card['employee_id']}',
                                        style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold,
                                            fontSize: 10)),
                                  ]),
                              pw.SizedBox(width: 10),
                              pw.Expanded(
                                  child: pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          pw.MainAxisAlignment.center,
                                      children: [
                                    if (photos['${card['employee_id']}'] !=
                                        null)
                                      pw.Image(
                                          pw.MemoryImage(photos[
                                              '${card['employee_id']}']!),
                                          width: 50,
                                          height: 50,
                                          fit: pw.BoxFit.cover),
                                    pw.SizedBox(height: 6),
                                    pw.Text('${card['name']}',
                                        style: pw.TextStyle(
                                            fontWeight: pw.FontWeight.bold,
                                            fontSize: 10)),
                                    pw.Text('${card['branch_id']}',
                                        style: const pw.TextStyle(fontSize: 9)),
                                    pw.SizedBox(height: 8),
                                    pw.Text(
                                        'Keep this card private. Return to admin if lost.',
                                        style: const pw.TextStyle(fontSize: 7)),
                                  ]))
                            ]),
                          ))
                      .toList())
            ]));
    return doc.save();
  }
}
