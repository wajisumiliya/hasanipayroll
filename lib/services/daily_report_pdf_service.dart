import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fixed A4 print layout that follows the supplied Daily Report form exactly.
class DailyReportPdfService {
  static Future<Uint8List> build(Map<String, dynamic> report) async {
    const ink = PdfColor.fromInt(0xff303030);
    const blue = PdfColor.fromInt(0xff123b86);
    const pale = PdfColor.fromInt(0xffe9e9eb);
    final document = pw.Document();
    final orsano = report['orsanco'] is Map
        ? Map<String, dynamic>.from(report['orsanco'] as Map)
        : <String, dynamic>{};

    String text(dynamic value) {
      final result = value?.toString().trim() ?? '';
      return result.isEmpty ? '-' : result;
    }

    String dayName() {
      final date = DateTime.tryParse(report['report_date']?.toString() ?? '');
      const names = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return date == null ? '-' : names[date.weekday - 1];
    }

    pw.Widget rule() => pw.Container(height: .45, color: ink);

    pw.Widget section(String label) => pw.Container(
          height: 19,
          alignment: pw.Alignment.center,
          color: ink,
          child: pw.Text(label,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold)),
        );

    pw.Widget inlineField(String label, dynamic value) => pw.Expanded(
          child: pw.Container(
            height: 35,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: ink)),
            child: pw.Row(children: [
              pw.Text('$label: ',
                  style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Expanded(child: pw.Text(text(value), style: const pw.TextStyle(fontSize: 8))),
            ]),
          ),
        );

    pw.Widget reportArea(String label, dynamic value, double height) => pw.Container(
          height: height,
          padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 6),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: ink)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: pw.BoxDecoration(
                  color: pale, borderRadius: pw.BorderRadius.circular(5)),
              child: pw.Text(label,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 6),
            pw.Text(text(value), style: const pw.TextStyle(fontSize: 8)),
            pw.Spacer(),
            rule(),
            pw.SizedBox(height: 10),
            rule(),
            pw.SizedBox(height: 10),
            rule(),
          ]),
        );

    pw.Widget orsanoCell(String label, dynamic value) => pw.Expanded(
          child: pw.Container(
            height: 42,
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: ink)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text(label,
                  maxLines: 2,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6)),
              pw.Spacer(),
              pw.Text(text(value), style: const pw.TextStyle(fontSize: 8)),
            ]),
          ),
        );

    pw.Widget bottomBox(String title, pw.Widget content, {int flex = 1}) => pw.Expanded(
          flex: flex,
          child: pw.Container(
            height: 104,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: ink)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              pw.Container(
                height: 20,
                alignment: pw.Alignment.center,
                color: ink,
                child: pw.Text(title,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold)),
              ),
              pw.Expanded(child: content),
            ]),
          ),
        );

    document.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(10),
      build: (_) => pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: ink, width: 2)),
        padding: const pw.EdgeInsets.all(5),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.SizedBox(height: 4),
          pw.Text('hasani BOOKS',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold)),
          pw.Text('DAILY REPORT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  color: blue, fontSize: 28, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Container(
            height: 20,
            color: ink,
            padding: const pw.EdgeInsets.symmetric(horizontal: 7),
            child: pw.Row(children: [
              pw.Text('Date:', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 6),
              pw.Container(width: 125, height: 12, color: PdfColors.white, child: pw.Text(text(report['report_date']), style: const pw.TextStyle(fontSize: 7))),
              pw.SizedBox(width: 12),
              pw.Text('Day:', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 6),
              pw.Container(width: 125, height: 12, color: PdfColors.white, child: pw.Text(dayName(), style: const pw.TextStyle(fontSize: 7))),
            ]),
          ),
          pw.Row(children: [
            inlineField('Attendance', report['attendance']),
            inlineField('Unpaid Leave', report['unpaid_leave']),
            inlineField('Weekly Leave', report['weekly_leave']),
            inlineField('Annual Leave', report['annual_leave']),
          ]),
          section('MAINTENANCE'),
          pw.Row(children: [
            inlineField('Air Conditioner', report['air_conditioner']),
            inlineField('Total', report['maintenance_total']),
            inlineField('Working Condition', report['working_condition']),
            inlineField('To Service or Repair', report['service_repair']),
          ]),
          section('MAINTENANCE/ELECTRICAL/EQUIPMENT'),
          reportArea('Report:', report['maintenance_report'], 104),
          section('ORSANO'),
          pw.Row(children: [
            orsanoCell('Agama', orsano['agama']),
            orsanoCell('S.K', orsano['sk']),
            orsanoCell('S.M', orsano['sm']),
            orsanoCell('Umum', orsano['umum']),
            orsanoCell('Novel', orsano['novel']),
            orsanoCell('Alat Tulis', orsano['alat_tulis']),
            orsanoCell('Tadika', orsano['tadika']),
            orsanoCell('Kanak Kanak', orsano['kanak']),
            orsanoCell('Quran', orsano['quran']),
            orsanoCell('Others', orsano['others']),
          ]),
          reportArea('Report Crew:', report['report_crew'], 112),
          reportArea('Recommendation/Demand/Sales:', report['recommendation'], 128),
          pw.Row(children: [
            bottomBox(
              'Reported By:',
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Spacer(),
                    rule(),
                    pw.SizedBox(height: 6),
                    pw.Text('Name: ${text(report['reported_by'])}',
                        style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ),
            ),
            bottomBox(
              'Branch Stamp',
              pw.Center(
                child: pw.Text(
                  'HASANI BOOKS\n${text(report['branch_id'])}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            bottomBox(
              'Comment by HQ:',
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(children: [
                  pw.Text(text(report['hq_comment']),
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Spacer(),
                  rule(),
                  pw.SizedBox(height: 9),
                  rule(),
                  pw.SizedBox(height: 9),
                  rule(),
                ]),
              ),
              flex: 2,
            ),
          ]),
        ]),
      ),
    ));
    return document.save();
  }
}
