import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

/// Fixed A4 print layout that follows the supplied Daily Report form exactly.
class DailyReportPdfService {
  static Future<Uint8List> build(Map<String, dynamic> report) async {
    const ink = PdfColor.fromInt(0xff303030);
    const blue = PdfColor.fromInt(0xff123b86);
    final document = pw.Document();
    pw.ThemeData? theme;
    try {
      final poppins = await PdfGoogleFonts.poppinsRegular();
      final poppinsBold = await PdfGoogleFonts.poppinsBold();
      theme = pw.ThemeData.withFont(base: poppins, bold: poppinsBold);
    } catch (_) {
      // Keep PDF printing available when a device is offline.
    }
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/hasani_books_logo.jpg');
      logo = pw.MemoryImage(logoData.buffer.asUint8List(
        logoData.offsetInBytes,
        logoData.lengthInBytes,
      ));
    } catch (_) {}
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

    String malaysianDateTime(dynamic value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed == null) return '-';
      final local = parsed.isUtc ? parsed.add(const Duration(hours: 8)) : parsed;
      String two(int number) => number.toString().padLeft(2, '0');
      return '${two(local.day)}/${two(local.month)}/${local.year} '
          '${two(local.hour)}:${two(local.minute)} MYT';
    }

    String stampDate() {
      final date = DateTime.tryParse(report['report_date']?.toString() ?? '');
      const months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
      ];
      return date == null ? '-' : '${date.day} ${months[date.month - 1]} ${date.year}';
    }

    final reviewedAt = malaysianDateTime(report['reviewed_at']);

    int narrativeFlex(dynamic value) {
      final length = text(value).length;
      return (2 + (length / 110).ceil()).clamp(2, 6).toInt();
    }

    double narrativeFontSize(dynamic value) {
      final length = text(value).length;
      if (length > 600) return 6.5;
      if (length > 420) return 7.5;
      if (length > 280) return 8.5;
      if (length > 160) return 9;
      return 10;
    }

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
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 34,
                    height: 16,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: ink, width: .8),
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text(text(value),
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                ),
              ),
            ]),
          ),
        );

    pw.Widget categoryHeading(String label) => pw.Expanded(
          child: pw.Container(
            height: 35,
            alignment: pw.Alignment.centerLeft,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: ink)),
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          ),
        );

    pw.Widget reportInfoCell(String label, String value, {int flex = 1}) =>
        pw.Expanded(
          flex: flex,
          child: pw.Container(
            height: 39,
            padding: const pw.EdgeInsets.fromLTRB(5, 4, 5, 3),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: ink, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label.toUpperCase(),
                    style: pw.TextStyle(
                        color: ink,
                        fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text(value,
                    maxLines: 1,
                    style: pw.TextStyle(
                        color: ink, fontSize: 7, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        );

    pw.Widget reportArea(String label, dynamic value, {int flex = 1}) =>
        pw.Expanded(
          flex: flex,
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 6),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: ink)),
            child:
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                        decorationThickness: .8)),
              ),
              pw.SizedBox(height: 6),
              pw.Text(text(value),
                  style: pw.TextStyle(
                      fontSize: narrativeFontSize(value), lineSpacing: 6)),
            ]),
          ),
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
              pw.SizedBox(height: 3),
              pw.Container(height: .7, color: ink),
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
      theme: theme,
      build: (_) => pw.Container(
        height: PdfPageFormat.a4.height - 20,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: ink, width: 2)),
        padding: const pw.EdgeInsets.all(5),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            height: 70,
            alignment: pw.Alignment.center,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Image(logo!, width: 190, height: 34, fit: pw.BoxFit.contain)
                else
                  pw.Text('HASANI BOOKS',
                      style: pw.TextStyle(
                          color: blue,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('DAILY MAINTAINANCE REPORT',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        color: blue,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Row(children: [
            reportInfoCell('Branch', text(report['branch_id']), flex: 2),
            reportInfoCell('Report Date', text(report['report_date']), flex: 2),
            reportInfoCell('Reported By', text(report['reported_by']), flex: 2),
            reportInfoCell('Submitted At', malaysianDateTime(report['submitted_at']),
                flex: 3),
            reportInfoCell('Day', dayName()),
          ]),
          pw.Row(children: [
            inlineField('Attendance', report['attendance']),
            inlineField('Unpaid Leave', report['unpaid_leave']),
            inlineField('Weekly Leave', report['weekly_leave']),
            inlineField('Annual Leave', report['annual_leave']),
          ]),
          section('MAINTENANCE'),
          pw.Row(children: [
            categoryHeading('Air Conditioner'),
            inlineField('Total', report['maintenance_total']),
            inlineField('Working Condition', report['working_condition']),
            inlineField('To Service or Repair', report['service_repair']),
          ]),
          section('MAINTENANCE / ELECTRICAL / EQUIPMENT'),
          reportArea('Report', report['maintenance_report'],
              flex: narrativeFlex(report['maintenance_report'])),
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
          reportArea('Report Crew', report['report_crew'],
              flex: narrativeFlex(report['report_crew'])),
          reportArea('Recommandation / Demand / Sales', report['recommendation'],
              flex: narrativeFlex(report['recommendation'])),
          pw.Row(children: [
            bottomBox(
              'Reported By:',
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(text(report['reported_by']),
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ),
            bottomBox(
              'Branch Stamp',
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Align(
                  alignment: pw.Alignment.topCenter,
                  child: pw.Container(
                    width: 72,
                    height: 72,
                    padding: const pw.EdgeInsets.all(3),
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: blue, width: 2),
                    ),
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: blue, width: 1.1),
                      ),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                        children: [
                          pw.Text('HASANI BOOKS',
                              maxLines: 1,
                              style: pw.TextStyle(
                                  color: blue,
                                  fontSize: 5.5,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Container(height: .7, color: blue),
                          pw.Text(stampDate(),
                              maxLines: 1,
                              style: pw.TextStyle(
                                  color: blue,
                                  fontSize: 7,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Container(height: .7, color: blue),
                          pw.Text(text(report['branch_id']).toUpperCase(),
                              maxLines: 2,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                  color: blue,
                                  fontSize: 5.5,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            bottomBox(
              'Reviewed By:',
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      text(report['reviewed_by']) == '-'
                          ? 'Nur Muhammad Faizal'
                          : text(report['reviewed_by']),
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                    if (reviewedAt != '-') ...[
                      pw.SizedBox(height: 5),
                      pw.Text('Reviewed At:',
                          style: pw.TextStyle(
                              fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.Text(reviewedAt,
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ],
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
