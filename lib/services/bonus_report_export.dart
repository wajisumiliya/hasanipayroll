import 'dart:typed_data';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'bonus_report.dart';

class BonusReportExport {
  static const note =
      'Saved payroll bonuses only. Reasons use saved payroll notes; '
      'current attendance is not used to recalculate entitlement.';
  static const headers = [
    'Employee ID',
    'Name',
    'Branch',
    'Reason',
    'Bonus RM'
  ];
  static List<dynamic> values(BonusRecipient row, DateTime month) =>
      [row.employeeId, row.name, row.branch, row.reason, row.amount];

  static Uint8List excel(BonusReport report, List<BonusRecipient> rows) {
    final book = xls.Excel.createExcel();
    final first = book.getDefaultSheet();
    if (first != null) book.rename(first, 'Bonus recipients');
    final sheet = book['Bonus recipients'];
    final total =
        rows.fold<int>(0, (sum, row) => sum + (row.amount * 100).round()) / 100;
    final data = <List<dynamic>>[
      ['Bonus Recipients Report'],
      [DateFormat('MMMM yyyy').format(report.month), report.branchName],
      [note],
      headers,
      ...rows.map((row) => values(row, report.month)),
      ['Total bonus', '', '', '', total],
    ];
    for (var r = 0; r < data.length; r++) {
      for (var c = 0; c < data[r].length; c++) {
        final value = data[r][c];
        final cell = sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        cell.value = value is num
            ? xls.DoubleCellValue(value.toDouble())
            : xls.TextCellValue('$value');
        cell.cellStyle = xls.CellStyle(
            bold: r == 0 || r == 3 || r == data.length - 1,
            textWrapping: xls.TextWrapping.WrapText);
        if (value is num) {
          cell.cellStyle = cell.cellStyle!
              .copyWith(numberFormat: xls.NumFormat.custom(formatCode: '0.00'));
        }
      }
      sheet.setRowHeight(
          r,
          r == 2
              ? 42
              : r >= 4 && r < data.length - 1
                  ? 45
                  : 28);
    }
    for (var c = 0; c < headers.length; c++) {
      sheet.setColumnWidth(
          c,
          c == 3
              ? 60
              : c == 1
                  ? 30
                  : 22);
    }
    for (final r in ['1', '3']) {
      sheet.merge(xls.CellIndex.indexByString('A$r'),
          xls.CellIndex.indexByString('E$r'));
    }
    final bytes = book.encode();
    if (bytes == null) throw StateError('Unable to generate bonus Excel.');
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> pdf(
      BonusReport report, List<BonusRecipient> rows) async {
    final theme = pw.ThemeData.base();
    final doc = pw.Document(theme: theme);
    final total =
        rows.fold<int>(0, (sum, row) => sum + (row.amount * 100).round()) / 100;
    pw.Widget content(double width) => pw.SizedBox(
        width: width,
        child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('Bonus Recipients Report',
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  '${DateFormat('MMMM yyyy').format(report.month)} - ${report.branchName}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: [
                  for (final row in rows)
                    [
                      row.employeeId,
                      row.name,
                      row.branch,
                      row.reason,
                      row.amount.toStringAsFixed(2)
                    ],
                  ['Total bonus', '', '', '', total.toStringAsFixed(2)],
                ],
                headerStyle: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFF11345F)),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.all(4),
                cellAlignment: pw.Alignment.topLeft,
                cellAlignments: {4: pw.Alignment.topRight},
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(3),
                  4: const pw.FlexColumnWidth(1)
                },
              ),
              pw.SizedBox(height: 6),
              pw.Text(note, style: const pw.TextStyle(fontSize: 7)),
            ]));
    final context = pw.Context(document: doc.document).inheritFrom(theme);
    double score(PdfPageFormat format) {
      final body = content(format.width - 40);
      body.layout(context, const pw.BoxConstraints());
      return ((format.height - 40) / body.box!.height)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    final portrait = PdfPageFormat.a4;
    final landscape = portrait.landscape;
    final format = score(landscape) > score(portrait) ? landscape : portrait;
    doc.addPage(pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                alignment: pw.Alignment.topLeft,
                child: content(format.width - 40)))));
    return doc.save();
  }
}
