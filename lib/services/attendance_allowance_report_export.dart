import 'dart:typed_data';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'attendance_allowance_report.dart';

class AttendanceAllowanceReportExport {
  static const note = 'The full allowance is removed once for membership in '
      'Late, MC or UL-Unpaid reports. Late follows the existing Late Report '
      '(3 or more events). Current-default comparisons are estimates, not '
      'verified historical deduction amounts. Reasons reflect current attendance '
      'reports. No payroll is changed by this report.';
  static const headers = [
    'Employee ID',
    'Employee name',
    'Branch',
    'Month',
    'Reason',
    'Dates / evidence',
    'Default RM',
    'Paid RM',
    'Deducted RM',
    'Baseline source',
    'Result'
  ];
  static List<dynamic> values(
          AttendanceAllowanceDeduction row, DateTime month) =>
      [
        row.employeeId,
        row.name,
        row.branch,
        DateFormat('MMM yyyy').format(month),
        row.reasonText,
        row.dateText,
        row.baseline,
        row.paid,
        row.deducted,
        row.baseline == null
            ? 'Not available'
            : row.snapshot
                ? 'Saved payroll baseline'
                : 'Current default (estimate)',
        row.status,
      ];

  static Uint8List excel(AttendanceAllowanceReport report,
      List<AttendanceAllowanceDeduction> rows) {
    final book = xls.Excel.createExcel();
    final first = book.getDefaultSheet();
    if (first != null) book.rename(first, 'Allowance deductions');
    final sheet = book['Allowance deductions'];
    final data = <List<dynamic>>[
      ['Elaun Kedatangan Deduction Report'],
      [DateFormat('MMMM yyyy').format(report.month), report.branchName],
      [note],
      headers,
      ...rows.map((row) => values(row, report.month)),
      [
        'Snapshot-based deduction total',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        report.confirmedTotal
      ],
      [
        'Estimated deduction total',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        report.estimatedTotal
      ],
    ];
    for (var r = 0; r < data.length; r++) {
      for (var c = 0; c < data[r].length; c++) {
        final cell = sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        final value = data[r][c];
        cell.value = value is num
            ? xls.DoubleCellValue(value.toDouble())
            : xls.TextCellValue(value?.toString() ?? 'Not available');
        cell.cellStyle = xls.CellStyle(
            bold: r == 0 || r == 3 || r >= data.length - 2,
            textWrapping: xls.TextWrapping.WrapText);
        if (value is num) {
          cell.cellStyle = cell.cellStyle!
              .copyWith(numberFormat: xls.NumFormat.custom(formatCode: '0.00'));
        }
      }
    }
    for (var c = 0; c < headers.length; c++) {
      sheet.setColumnWidth(
          c,
          c == 5
              ? 48
              : c == 1
                  ? 28
                  : 20);
    }
    sheet.merge(
        xls.CellIndex.indexByString('A1'), xls.CellIndex.indexByString('K1'));
    sheet.merge(
        xls.CellIndex.indexByString('A3'), xls.CellIndex.indexByString('K3'));
    sheet.setRowHeight(0, 26);
    sheet.setRowHeight(2, 48);
    sheet.setRowHeight(3, 30);
    for (var index = 0; index < rows.length; index++) {
      sheet.setRowHeight(
          index + 4,
          ((rows[index].dateText.length / 45).ceil() * 15 + 20)
              .clamp(32, 400)
              .toDouble());
    }
    final output = book.encode();
    if (output == null) throw StateError('Unable to generate allowance Excel.');
    return Uint8List.fromList(output);
  }

  static Future<Uint8List> pdf(AttendanceAllowanceReport report,
      List<AttendanceAllowanceDeduction> rows) async {
    final doc = pw.Document();
    pw.MemoryImage? logo;
    try {
      final asset = await rootBundle.load('assets/hasani_books_logo.jpg');
      logo = pw.MemoryImage(asset.buffer.asUint8List());
    } catch (_) {}
    String text(dynamic value) => value is num
        ? value.toStringAsFixed(2)
        : value?.toString() ?? 'Not available';
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (_) =>
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          if (logo != null) ...[
            pw.Image(logo, width: 85, height: 30),
            pw.SizedBox(width: 12)
          ],
          pw.Text('Elaun Kedatangan Deduction Report',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))
        ]),
        pw.Text(
            '${DateFormat('MMMM yyyy').format(report.month)} - ${report.branchName}'),
        pw.SizedBox(height: 8),
      ]),
      build: (_) => [
        pw.Text(note, style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 8),
        pw.Text(
            'Snapshot-based total: RM ${report.confirmedTotal.toStringAsFixed(2)}'
            ' | Estimated total: RM ${report.estimatedTotal.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows
              .map((row) => values(row, report.month).map(text).toList())
              .toList(),
          headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFF11345F)),
          cellStyle: const pw.TextStyle(fontSize: 6),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FixedColumnWidth(48),
            1: const pw.FixedColumnWidth(90),
            5: const pw.FixedColumnWidth(145)
          },
        ),
      ],
      footer: (context) => pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8)),
    ));
    return doc.save();
  }
}
