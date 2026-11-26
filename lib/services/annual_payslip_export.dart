import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:intl/intl.dart';
import 'annual_payslip_summary.dart';

class AnnualPayslipExport {
  static String money(double? value) =>
      value == null ? '' : NumberFormat('#,##0.00').format(value);
  static List<List<String>> salaryRows(AnnualPayslipSummary summary) => [
        for (final m in summary.months)
          [
            '${m.month}',
            AnnualPayslipSummary.monthNames[m.month - 1],
            money(m.salary),
            money(m.allowance),
            money(m.increment),
            money(m.total)
          ],
      ];
  static List<List<String>> bonusRows(AnnualPayslipSummary summary) => [
        for (var i = 0;
            i < (summary.benefits.length < 5 ? 5 : summary.benefits.length);
            i++)
          i < summary.benefits.length
              ? [
                  '${i + 1}',
                  summary.benefits[i].dateLabel,
                  summary.benefits[i].particulars,
                  money(summary.benefits[i].amount)
                ]
              : ['${i + 1}', '', '', ''],
      ];
  static Future<Uint8List> pdf(
      AnnualPayslipSummary summary, String name) async {
    final doc = pw.Document();
    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/hasani_books_logo.jpg');
      logo = pw.MemoryImage(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {}
    pw.Widget table(List<String> headers, List<List<String>> rows,
            Map<int, pw.TableColumnWidth> widths) =>
        pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            columnWidths: widths,
            headerStyle:
                pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.white),
            border: pw.TableBorder.all(width: .7),
            cellHeight: 24,
            cellAlignment: pw.Alignment.center,
            cellPadding: const pw.EdgeInsets.all(4));
    doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.topCenter,
            child: pw.SizedBox(
                width: PdfPageFormat.a4.width - 72,
                child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      if (logo != null)
                        pw.Center(
                            child: pw.Image(logo,
                                width: 250,
                                height: 48,
                                fit: pw.BoxFit.contain)),
                      pw.Center(
                          child: pw.Text('ANNUAL SALARY YEAR ${summary.year}',
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold))),
                      pw.SizedBox(height: 10),
                      pw.Text('NAME: $name   |   ID: ${summary.employeeId}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 10),
                      table(AnnualPayslipSummary.salaryHeaders,
                          salaryRows(summary), {
                        0: const pw.FixedColumnWidth(22),
                        1: const pw.FixedColumnWidth(100),
                        for (var i = 2; i < 6; i++)
                          i: const pw.FlexColumnWidth(),
                      }),
                      pw.SizedBox(height: 24),
                      pw.Center(
                          child: pw.Text(
                              'WELFARE/GIFT/BONUS YEAR ${summary.year}',
                              style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold))),
                      pw.SizedBox(height: 12),
                      table(AnnualPayslipSummary.bonusHeaders,
                          bonusRows(summary), {
                        0: const pw.FixedColumnWidth(22),
                        1: const pw.FixedColumnWidth(100),
                        2: const pw.FlexColumnWidth(3),
                        3: const pw.FlexColumnWidth(1.3),
                      }),
                    ])))));
    return doc.save();
  }

  static Uint8List excel(AnnualPayslipSummary summary, String name) {
    final book = xls.Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();
    if (defaultSheet != null) {
      book.rename(defaultSheet, 'Annual Summary');
    }
    final sheet = book['Annual Summary'];
    final border = xls.Border(borderStyle: xls.BorderStyle.Thin);
    void row(int index, List<dynamic> values, {bool header = false}) {
      for (var c = 0; c < values.length; c++) {
        final cell = sheet.cell(
            xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: index));
        final v = values[c];
        cell.value = v is num
            ? xls.DoubleCellValue(v.toDouble())
            : xls.TextCellValue('$v');
        cell.cellStyle = xls.CellStyle(
            bold: header,
            textWrapping: xls.TextWrapping.WrapText,
            horizontalAlign: xls.HorizontalAlign.Center,
            verticalAlign: xls.VerticalAlign.Center,
            leftBorder: border,
            rightBorder: border,
            topBorder: border,
            bottomBorder: border,
            numberFormat: v is num && c >= 2
                ? xls.NumFormat.custom(formatCode: '#,##0.00')
                : xls.NumFormat.standard_0);
      }
      sheet.setRowHeight(index, index == 4 || index == 21 ? 36 : 26);
    }

    row(0, ['ANNUAL SALARY YEAR ${summary.year}'], header: true);
    sheet.merge(
        xls.CellIndex.indexByString('A1'), xls.CellIndex.indexByString('F2'));
    row(2, ['NAME: $name', '', 'ID: ${summary.employeeId}']);
    row(4, AnnualPayslipSummary.salaryHeaders, header: true);
    for (final m in summary.months) {
      row(4 + m.month, [
        m.month,
        AnnualPayslipSummary.monthNames[m.month - 1],
        m.salary ?? '',
        m.allowance ?? '',
        m.increment ?? '',
        m.total ?? ''
      ]);
    }
    row(19, ['WELFARE/GIFT/BONUS YEAR ${summary.year}'], header: true);
    sheet.merge(
        xls.CellIndex.indexByString('A20'), xls.CellIndex.indexByString('F20'));
    row(21, ['NO', 'DATE', 'PARTICULAR', '', '', 'TOTAL AMOUNT (RM)'],
        header: true);
    final bonuses = bonusRows(summary);
    for (var i = 0; i < bonuses.length; i++) {
      row(22 + i, [
        i + 1,
        bonuses[i][1],
        bonuses[i][2],
        '',
        '',
        i < summary.benefits.length ? summary.benefits[i].amount : ''
      ]);
    }
    for (var r = 21; r < 22 + bonuses.length; r++) {
      sheet.merge(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r),
          xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r));
    }
    for (var c = 0; c < 6; c++) {
      sheet.setColumnWidth(
          c,
          c == 0
              ? 7
              : c == 1
                  ? 18
                  : 22);
    }
    final bytes = book.encode();
    if (bytes == null) {
      throw StateError('Annual summary Excel generation failed.');
    }
    return Uint8List.fromList(bytes);
  }
}
