import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AttendancePrintDay {
  const AttendancePrintDay({
    required this.day,
    required this.workingIn,
    required this.workingOut,
    required this.morningIn,
    required this.morningOut,
    required this.afternoonIn,
    required this.afternoonOut,
    required this.eveningIn,
    required this.eveningOut,
    required this.status,
    required this.workMinutes,
    required this.breakMinutes,
    required this.netMinutes,
    required this.overtimeMinutes,
    required this.lateMinutes,
  });

  final int day;
  final String workingIn;
  final String workingOut;
  final String morningIn;
  final String morningOut;
  final String afternoonIn;
  final String afternoonOut;
  final String eveningIn;
  final String eveningOut;
  final String status;
  final int workMinutes;
  final int breakMinutes;
  final int netMinutes;
  final int overtimeMinutes;
  final int lateMinutes;
}

class AttendancePdfService {
  static const _blue = PdfColors.black;
  static const _red = PdfColors.black;
  static const _ink = PdfColors.black;
  static const _paleBlue = PdfColors.white;
  static const _paleRed = PdfColors.white;

  static Future<Uint8List> build({
    required String employeeId,
    required String employeeName,
    required String department,
    required String section,
    required String branchId,
    required DateTime month,
    required List<AttendancePrintDay> days,
  }) async {
    final document = pw.Document();
    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/hasani_books_logo.jpg');
      logo = pw.MemoryImage(bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      ));
    } catch (_) {}

    final workTotal = days.fold<int>(0, (sum, day) => sum + day.workMinutes);
    final breakTotal = days.fold<int>(0, (sum, day) => sum + day.breakMinutes);
    final netTotal = days.fold<int>(0, (sum, day) => sum + day.netMinutes);
    final otTotal = days.fold<int>(0, (sum, day) => sum + day.overtimeMinutes);
    final lateTotal = days.fold<int>(0, (sum, day) => sum + day.lateMinutes);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 20),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(logo, 'WORK ATTENDANCE', month),
            pw.SizedBox(height: 7),
            _employeeInfo(
                employeeId, employeeName, department, section, branchId),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                _summary(
                    'GROSS WORK', 'Check-out - Check-in', workTotal, _blue),
                pw.SizedBox(width: 5),
                _summary(
                    'BREAK HOURS', 'All recorded breaks', breakTotal, _red),
                pw.SizedBox(width: 5),
                _summary('NET HOURS', 'Gross work - breaks', netTotal, _blue),
                pw.SizedBox(width: 5),
                _summary('APPROVED OT', 'Authorized overtime', otTotal,
                    PdfColors.black),
                pw.SizedBox(width: 5),
                _summary('LATE HOURS', 'After roster start', lateTotal,
                    PdfColors.black),
              ],
            ),
            pw.SizedBox(height: 8),
            _workTable(days),
            pw.Spacer(),
            _signatures(),
            _pageFooter(1, 'Front - Work attendance and monthly totals'),
          ],
        ),
      ),
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 20),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(logo, 'BREAK ATTENDANCE', month),
            pw.SizedBox(height: 7),
            _employeeInfo(
                employeeId, employeeName, department, section, branchId),
            pw.SizedBox(height: 8),
            _breakTable(days),
            pw.Spacer(),
            _signatures(),
            _pageFooter(2, 'Back - Morning, afternoon and evening breaks'),
          ],
        ),
      ),
    );

    return document.save();
  }

  static pw.Widget _header(pw.MemoryImage? logo, String title, DateTime month) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 7),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.2)),
      ),
      child: pw.Row(
        children: [
          if (logo != null)
            pw.Container(
                width: 92,
                height: 40,
                child: pw.Image(logo, fit: pw.BoxFit.contain))
          else
            pw.SizedBox(width: 92),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('HASANI BOOKS EDAR SDN BHD',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink)),
                pw.SizedBox(height: 2),
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: title.startsWith('BREAK') ? _red : _blue)),
              ],
            ),
          ),
          pw.Text(DateFormat('MMMM yyyy').format(month),
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
        ],
      ),
    );
  }

  static pw.Widget _employeeInfo(String id, String name, String department,
      String section, String branch) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: PdfColors.black, width: .6)),
      child: pw.Row(children: [
        _info('EMPLOYEE', name),
        _info('EMPLOYEE ID', id),
        _info('DEPARTMENT', department),
        _info('SECTION', section),
        _info('BRANCH', branch),
      ]),
    );
  }

  static pw.Widget _info(String label, String value) => pw.Expanded(
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 5.5,
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(value.trim().isEmpty ? '-' : value,
                  maxLines: 1,
                  style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink)),
            ]),
      );

  static pw.Widget _summary(
          String label, String description, int minutes, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: color, width: .7)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 5.5,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
                pw.SizedBox(height: 1),
                pw.Text(description,
                    maxLines: 1,
                    style: const pw.TextStyle(
                        fontSize: 4.5, color: PdfColors.black)),
                pw.SizedBox(height: 2),
                pw.Text(_duration(minutes),
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
              ]),
        ),
      );

  static pw.Widget _workTable(List<AttendancePrintDay> days) {
    const widths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(27),
      1: pw.FlexColumnWidth(1),
      2: pw.FlexColumnWidth(1),
      3: pw.FlexColumnWidth(1),
      4: pw.FlexColumnWidth(1),
      5: pw.FlexColumnWidth(1),
      6: pw.FlexColumnWidth(1),
      7: pw.FlexColumnWidth(1),
      8: pw.FlexColumnWidth(1.35),
    };
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: .45),
      columnWidths: widths,
      children: [
        _row([
          'DAY',
          'CHECK IN',
          'CHECK OUT',
          'WORK',
          'BREAK',
          'NET',
          'OT',
          'STATUS'
        ], headerColor: _paleBlue, textColor: _blue),
        ...days.map((d) => _row([
              d.day.toString(),
              _value(d.workingIn),
              _value(d.workingOut),
              _duration(d.workMinutes),
              _duration(d.breakMinutes),
              _duration(d.netMinutes),
              _duration(d.overtimeMinutes),
              _value(d.status),
            ])),
      ],
    );
  }

  static pw.Widget _breakTable(List<AttendancePrintDay> days) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: .45),
      columnWidths: const {
        0: pw.FixedColumnWidth(25),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1),
        5: pw.FlexColumnWidth(1),
        6: pw.FlexColumnWidth(1),
        7: pw.FlexColumnWidth(1.1),
      },
      children: [
        _row([
          'DAY',
          'MORNING IN',
          'MORNING OUT',
          'AFTERNOON IN',
          'AFTERNOON OUT',
          'EVENING IN',
          'EVENING OUT',
          'TOTAL BREAK'
        ], headerColor: _paleRed, textColor: _red),
        ...days.map((d) => _row([
              d.day.toString(),
              _value(d.morningIn),
              _value(d.morningOut),
              _value(d.afternoonIn),
              _value(d.afternoonOut),
              _value(d.eveningIn),
              _value(d.eveningOut),
              _duration(d.breakMinutes),
            ])),
      ],
    );
  }

  static pw.TableRow _row(List<String> values,
          {PdfColor? headerColor, PdfColor textColor = _ink}) =>
      pw.TableRow(
        decoration:
            headerColor == null ? null : pw.BoxDecoration(color: headerColor),
        children: values
            .map((value) => pw.Container(
                  height: headerColor == null ? 15.2 : 20,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(value,
                      maxLines: 1,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: headerColor == null ? 6.1 : 5.6,
                          fontWeight: headerColor == null
                              ? pw.FontWeight.normal
                              : pw.FontWeight.bold,
                          color: textColor)),
                ))
            .toList(),
      );

  static pw.Widget _signatures() => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 7),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('PREPARED BY: ____________________',
                  style: const pw.TextStyle(fontSize: 6.5)),
              pw.Text('CHECKED BY: ____________________',
                  style: const pw.TextStyle(fontSize: 6.5)),
              pw.Text('EMPLOYEE: ____________________',
                  style: const pw.TextStyle(fontSize: 6.5)),
            ]),
      );

  static pw.Widget _pageFooter(int page, String label) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.black)),
          pw.Text('Page $page of 2',
              style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.black)),
        ],
      );

  static String _value(String value) =>
      value.trim().isEmpty ? '-' : value.trim();
  static String _duration(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}
