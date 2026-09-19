import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DailyReportPdfService {
  static Future<Uint8List> build(Map<String, dynamic> report) async {
    final blue = PdfColor.fromInt(0xFF263B97);
    final red = PdfColor.fromInt(0xFFE51B2A);
    final document = pw.Document();
    final orsanco = report['orsanco'] is Map
        ? Map<String, dynamic>.from(report['orsanco'] as Map)
        : <String, dynamic>{};

    String value(dynamic input, [String fallback = '-']) {
      final text = input?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }

    String malaysiaTime(dynamic input) {
      final parsed = DateTime.tryParse(input?.toString() ?? '');
      if (parsed == null) return '-';
      final malaysia = parsed.toUtc().add(const Duration(hours: 8));
      return '${DateFormat('dd/MM/yyyy hh:mm a').format(malaysia)} MYT';
    }

    pw.Widget heading(String text) => pw.Container(
          width: double.infinity,
          color: blue,
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(text,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold)),
        );

    pw.Widget field(String label, dynamic input) => pw.Container(
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: blue)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        color: blue,
                        fontSize: 6,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text(value(input), style: const pw.TextStyle(fontSize: 8)),
              ]),
        );

    pw.Widget area(String label, dynamic input) => pw.Container(
          width: double.infinity,
          constraints: const pw.BoxConstraints(minHeight: 46),
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: blue)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        color: blue,
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text(value(input), style: const pw.TextStyle(fontSize: 8)),
              ]),
        );

    pw.Widget four(List<(String, dynamic)> values) => pw.Row(
          children: [
            for (var i = 0; i < values.length; i++) ...[
              pw.Expanded(child: field(values[i].$1, values[i].$2)),
              if (i < values.length - 1) pw.SizedBox(width: 4),
            ],
          ],
        );

    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(22),
      footer: (_) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Printed ${malaysiaTime(DateTime.now().toUtc())}',
          style: const pw.TextStyle(fontSize: 6),
        ),
      ),
      build: (_) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: blue, width: 1.4)),
          child: pw.Column(children: [
            pw.Row(children: [
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(
                      text: 'hasani ',
                      style: pw.TextStyle(
                          color: blue,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold)),
                  pw.TextSpan(
                      text: 'BOOKS',
                      style: pw.TextStyle(
                          color: red,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold)),
                ]),
              ),
              pw.Spacer(),
              pw.Text('MAINTENANCE DAILY REPORT',
                  style: pw.TextStyle(
                      color: blue,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 8),
            four([
              ('BRANCH', report['branch_id']),
              ('REPORT DATE', report['report_date']),
              ('REPORTED BY', report['reported_by']),
              ('REVIEWED BY', report['reviewed_by']),
            ]),
            pw.SizedBox(height: 7),
            heading('ATTENDANCE'),
            four([
              ('Attendance', report['attendance']),
              ('Unpaid Leave', report['unpaid_leave']),
              ('Weekly Leave', report['weekly_leave']),
              ('Annual Leave', report['annual_leave']),
            ]),
            pw.SizedBox(height: 7),
            heading('MAINTENANCE'),
            four([
              ('Air Conditioner', report['air_conditioner']),
              ('Total', report['maintenance_total']),
              ('Working Condition', report['working_condition']),
              ('To Service / Repair', report['service_repair']),
            ]),
            area('MAINTENANCE / ELECTRICAL / EQUIPMENT', report['maintenance_report']),
            pw.SizedBox(height: 7),
            heading('ORSANCO'),
            four([
              ('Agama', orsanco['agama']),
              ('S.K', orsanco['sk']),
              ('S.M', orsanco['sm']),
              ('Umum', orsanco['umum']),
            ]),
            four([
              ('Novel', orsanco['novel']),
              ('Alat Tulis', orsanco['alat_tulis']),
              ('Tadika', orsanco['tadika']),
              ('Kanak Kanak', orsanco['kanak']),
            ]),
            four([
              ('Quran', orsanco['quran']),
              ('Others', orsanco['others']),
              ('Branch Stamp', 'HASANI BOOKS - ${value(report['branch_id'])}'),
              ('Reviewed At', malaysiaTime(report['reviewed_at'])),
            ]),
            pw.SizedBox(height: 7),
            heading('REPORT CREW'),
            area('CREW', report['report_crew']),
            pw.SizedBox(height: 7),
            heading('RECOMMENDATION / DEMAND / SALES'),
            area('RECOMMENDATION', report['recommendation']),
            pw.SizedBox(height: 7),
            heading('COMMENT BY HQ'),
            area('HQ COMMENT', report['hq_comment']),
          ]),
        ),
      ],
    ));
    return document.save();
  }
}
