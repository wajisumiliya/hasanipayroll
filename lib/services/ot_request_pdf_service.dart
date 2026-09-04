import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OtRequestPdfService {
  static Future<Uint8List> build(Map<String, dynamic> row) async {
    String v(String key, [String fallback = '-']) {
      final text = row[key]?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }

    String tm(String key) {
      final text = v(key);
      return text.length >= 5 ? text.substring(0, 5) : text;
    }

    final minutes = int.tryParse(v('requested_minutes', '0')) ?? 0;
    final duration =
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
    final blue = PdfColor.fromHex('#3155A4');
    pw.Widget cell(String text,
            {bool header = false,
            pw.Alignment alignment = pw.Alignment.center,
            double height = 31}) =>
        pw.Container(
          height: height,
          alignment: alignment,
          padding: const pw.EdgeInsets.all(4),
          color: header ? blue : null,
          child: pw.Text(text,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  color: header ? PdfColors.white : PdfColor.fromHex('#263B73'),
                  fontSize: header ? 7 : 8,
                  fontWeight:
                      header ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );
    final document = pw.Document();
    document.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Container(
              color: PdfColor.fromHex('#FFFCED'),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(children: [
                      pw.Container(
                          color: blue,
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('BORANG TUNTUTAN\nKERJA LEBIH MASA',
                              style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold))),
                      pw.SizedBox(width: 12),
                      pw.Text('hasani BOOKS',
                          style: pw.TextStyle(
                              color: blue,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold))
                    ]),
                    pw.SizedBox(height: 8),
                    pw.Table(
                        border: pw.TableBorder.all(color: blue),
                        children: [
                          pw.TableRow(children: [
                            cell('NAMA'),
                            cell(v('employee_name'),
                                alignment: pw.Alignment.centerLeft),
                            cell('CAWANGAN'),
                            cell(v('branch_id'),
                                alignment: pw.Alignment.centerLeft)
                          ]),
                          pw.TableRow(children: [
                            cell('BAHAGIAN'),
                            cell(v('department'),
                                alignment: pw.Alignment.centerLeft),
                            cell('NO. PEKERJA'),
                            cell(v('employee_id'),
                                alignment: pw.Alignment.centerLeft)
                          ]),
                        ]),
                    pw.SizedBox(height: 7),
                    pw.Table(
                        border: pw.TableBorder.all(color: blue),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(.45),
                          1: pw.FlexColumnWidth(1),
                          2: pw.FlexColumnWidth(1),
                          3: pw.FlexColumnWidth(1.1),
                          4: pw.FlexColumnWidth(1),
                          5: pw.FlexColumnWidth(1.25),
                          6: pw.FlexColumnWidth(2.4),
                          7: pw.FlexColumnWidth(1.25)
                        },
                        children: [
                          pw.TableRow(
                              children: [
                            'NO',
                            'TARIKH',
                            'MASA\nMASUK',
                            'KELUAR\nSEBENAR',
                            'KELUAR',
                            'JUMLAH OT\n(JAM:MINIT)',
                            'SEBAB\nLEBIH MASA',
                            'DISAHKAN\nOLEH'
                          ]
                                  .map((text) =>
                                      cell(text, header: true, height: 35))
                                  .toList()),
                          pw.TableRow(children: [
                            cell('1'),
                            cell(v('overtime_date')),
                            cell(tm('shift_start')),
                            cell(tm('overtime_start')),
                            cell(tm('overtime_end')),
                            cell(duration),
                            cell(v('reason')),
                            cell(v('status').toUpperCase())
                          ]),
                          for (var number = 2; number <= 8; number++)
                            pw.TableRow(children: [
                              cell('$number'),
                              for (var column = 1; column < 8; column++)
                                cell('')
                            ]),
                        ]),
                    pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6),
                        child: pw.Text(
                            'Tuntutan kerja lebih masa tidak sah sekiranya tiada kelulusan oleh pengurus cawangan dengan sebab yang munasabah.',
                            style: pw.TextStyle(fontSize: 7, color: blue))),
                    pw.Row(children: [
                      pw.Expanded(
                          child: cell(
                              'DIMOHON OLEH\n${v('employee_name')}\n${v('submitted_at', 'Waiting')}',
                              header: true,
                              height: 42)),
                      pw.Expanded(
                          child: cell(
                              'DISEMAK OLEH\n${v('branch_id')}\n${v('branch_approved_at', 'Waiting')}',
                              header: true,
                              height: 42)),
                      pw.Expanded(
                          child: cell(
                              'DISAHKAN OLEH\nADMIN\n${v('admin_approved_at', 'Waiting')}',
                              header: true,
                              height: 42)),
                    ]),
                  ]),
            )));
    return document.save();
  }
}
