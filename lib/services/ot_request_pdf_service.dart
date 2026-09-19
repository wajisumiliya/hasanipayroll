import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OtRequestPdfService {
  static Future<Uint8List> build(
    Map<String, dynamic> row, {
    List<Map<String, dynamic>>? monthlyRequests,
  }) async {
    final requests = (monthlyRequests == null || monthlyRequests.isEmpty)
        ? <Map<String, dynamic>>[row]
        : List<Map<String, dynamic>>.from(monthlyRequests)
      ..sort((a, b) => (a['overtime_date'] ?? '')
          .toString()
          .compareTo((b['overtime_date'] ?? '').toString()));
    final document = pw.Document();
    final blue = PdfColor.fromHex('#3155A4');

    String value(Map<String, dynamic> source, String key,
        [String fallback = '-']) {
      final text = source[key]?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }

    String time(Map<String, dynamic> source, String key) {
      final text = value(source, key);
      return text.length >= 5 ? text.substring(0, 5) : text;
    }

    String duration(Map<String, dynamic> source) {
      final minutes =
          int.tryParse(value(source, 'requested_minutes', '0')) ?? 0;
      return '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
          '${(minutes % 60).toString().padLeft(2, '0')}';
    }

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

    for (var start = 0; start < requests.length; start += 8) {
      final end = (start + 8).clamp(0, requests.length);
      final pageRows = requests.sublist(start, end);
      final header = pageRows.first;
      final approval = pageRows.last;

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
                              cell(value(header, 'employee_name'),
                                  alignment: pw.Alignment.centerLeft),
                              cell('CAWANGAN'),
                              cell(value(header, 'branch_id'),
                                  alignment: pw.Alignment.centerLeft)
                            ]),
                            pw.TableRow(children: [
                              cell('BAHAGIAN'),
                              cell(value(header, 'department'),
                                  alignment: pw.Alignment.centerLeft),
                              cell('NO. PEKERJA'),
                              cell(value(header, 'employee_id'),
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
                            for (var index = 0; index < 8; index++)
                              if (index < pageRows.length)
                                pw.TableRow(children: [
                                  cell('${start + index + 1}'),
                                  cell(value(pageRows[index], 'overtime_date')),
                                  cell(time(pageRows[index], 'shift_start')),
                                  cell(time(pageRows[index], 'overtime_start')),
                                  cell(time(pageRows[index], 'overtime_end')),
                                  cell(duration(pageRows[index])),
                                  cell(value(pageRows[index], 'reason')),
                                  cell(value(pageRows[index], 'status')
                                      .toUpperCase())
                                ])
                              else
                                pw.TableRow(children: [
                                  cell('${start + index + 1}'),
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
                                'DIMOHON OLEH\n${value(header, 'employee_name')}\n${value(header, 'submitted_at', 'Waiting')}',
                                header: true,
                                height: 42)),
                        pw.Expanded(
                            child: cell(
                                'DISEMAK OLEH\n${value(approval, 'branch_approved_name', value(approval, 'branch_id'))}\n${value(approval, 'branch_approved_at', 'Waiting')}',
                                header: true,
                                height: 42)),
                        pw.Expanded(
                            child: cell(
                                'DISAHKAN OLEH\nADMIN\n${value(approval, 'admin_approved_at', 'Waiting')}',
                                header: true,
                                height: 42)),
                      ]),
                    ]),
              )));
    }
    return document.save();
  }
}
