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

  static const pdfHeaders = [
    'Employee ID', 'Name', 'Branch', 'Reason', 'Date / Evidence',
    'Default RM', 'Deduct RM',
  ];

  static List<String> pdfValues(AttendanceAllowanceDeduction row) {
    String money(double? value) => value == null ? 'Not available'
        : '${value.toStringAsFixed(2)}${row.snapshot ? '' : '*'}';
    return [row.employeeId, row.name, row.branch, row.reasonText, row.dateText,
      money(row.baseline), money(row.deducted)];
  }

  /// Choose the orientation retaining the largest readable text after fitting
  /// the fully measured report. If both fit, prefer portrait without upscaling.
  static PdfPageFormat choosePdfFormat({
    required double portraitHeight, required double landscapeHeight,
  }) {
    double score(PdfPageFormat format, double height) => height <= 0
        ? 1 : ((format.height - 40) / height).clamp(0.0, 1.0).toDouble();
    final portrait = score(PdfPageFormat.a4, portraitHeight);
    final landscape = score(PdfPageFormat.a4.landscape, landscapeHeight);
    return landscape > portrait ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
  }

  static Future<Uint8List> pdf(AttendanceAllowanceReport report,
      List<AttendanceAllowanceDeduction> rows) async {
    final theme = pw.ThemeData.base();
    final doc = pw.Document(theme: theme);
    pw.MemoryImage? logo;
    try {
      final asset = await rootBundle.load('assets/hasani_books_logo.jpg');
      logo = pw.MemoryImage(asset.buffer.asUint8List());
    } catch (_) {}
    final data = rows.map(pdfValues).toList();
    final hasEstimates = rows.any((row) => !row.snapshot &&
        (row.baseline != null || row.deducted != null));

    pw.Widget content(double width) => pw.SizedBox(width: width,
      child: pw.Column(mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(children: [
            if (logo != null) ...[
              pw.Image(logo!, width: 75, height: 26), pw.SizedBox(width: 10),
            ],
            pw.Expanded(child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Elaun Kedatangan Deduction Report',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('${DateFormat('MMMM yyyy').format(report.month)} - ${report.branchName}',
                  style: const pw.TextStyle(fontSize: 9)),
              ])),
          ]),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: pdfHeaders, data: data,
            headerStyle: pw.TextStyle(fontSize: 8.5,
              fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF11345F)),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            cellAlignment: pw.Alignment.topLeft,
            cellAlignments: {5: pw.Alignment.topRight, 6: pw.Alignment.topRight},
            columnWidths: {
              0: const pw.FlexColumnWidth(.09), 1: const pw.FlexColumnWidth(.21),
              2: const pw.FlexColumnWidth(.10), 3: const pw.FlexColumnWidth(.14),
              4: const pw.FlexColumnWidth(.28), 5: const pw.FlexColumnWidth(.09),
              6: const pw.FlexColumnWidth(.09),
            },
          ),
          if (hasEstimates) ...[
            pw.SizedBox(height: 5),
            pw.Text('* Estimated from current salary default; no saved allowance baseline.',
                style: const pw.TextStyle(fontSize: 7)),
          ],
        ],
      ));

    // Measure every row at each A4 width before choosing the orientation.
    // The unconstrained height prevents a table from dropping or spanning rows.
    final measure = pw.Context(document: doc.document).inheritFrom(theme);
    double height(PdfPageFormat format) {
      final body = content(format.width - 40);
      body.layout(measure, const pw.BoxConstraints());
      return body.box!.height;
    }
    final format = choosePdfFormat(
      portraitHeight: height(PdfPageFormat.a4),
      landscapeHeight: height(PdfPageFormat.a4.landscape),
    );
    // A single Page plus scaleDown keeps all data on exactly one physical A4
    // page. No rows are omitted, clipped, or moved to a second page.
    doc.addPage(pw.Page(pageFormat: format,
      margin: const pw.EdgeInsets.all(20),
      build: (_) => pw.Align(alignment: pw.Alignment.topCenter,
        child: pw.FittedBox(fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.topLeft, child: content(format.width - 40))),
    ));
    return doc.save();
  }
}
