import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const payrollSummaryPdfMargin = 10 * PdfPageFormat.mm;

pw.Widget payrollSummaryZeroContributorLists(
    List<Map<String, dynamic>> epf, List<Map<String, dynamic>> socso) {
  pw.Widget section(String label, List<Map<String, dynamic>> employees) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('$label - zero contributions (${employees.length} emp)',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        if (employees.isEmpty)
          pw.Text('None', style: const pw.TextStyle(fontSize: 7))
        else
          pw.TableHelper.fromTextArray(
            headers: const ['EMPLOYEE ID', 'NAME', 'BRANCH'],
            data: employees
                .map((row) => [row['employeeId'], row['name'], row['branch']])
                .toList(),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(2.5),
              2: pw.FlexColumnWidth(1.5),
            },
            headerStyle:
                pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 6),
            cellPadding: const pw.EdgeInsets.all(2),
          ),
      ],
    );
  }

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: section('EPF', epf)),
      pw.SizedBox(width: 10),
      pw.Expanded(child: section('SOCSO', socso)),
    ],
  );
}

/// Shrink the complete value to the cell width instead of wrapping decimals.
pw.Widget payrollSummarySingleLine(String text,
    {double fontSize = 7.2, bool bold = false}) {
  return pw.FittedBox(
    fit: pw.BoxFit.scaleDown,
    child: pw.Text(
      text,
      maxLines: 1,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

/// Keep the complete report inside a landscape A4 page's printable area.
/// The content must use a natural-height column without vertical flex children.
pw.Widget fitPayrollSummaryToA4(pw.Widget content) {
  return pw.FittedBox(
    fit: pw.BoxFit.scaleDown,
    alignment: pw.Alignment.topCenter,
    child: pw.SizedBox(
      width: PdfPageFormat.a4.landscape.width - 2 * payrollSummaryPdfMargin,
      child: content,
    ),
  );
}
