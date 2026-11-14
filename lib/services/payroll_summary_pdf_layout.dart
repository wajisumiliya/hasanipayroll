import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const payrollSummaryPdfMargin = 10 * PdfPageFormat.mm;

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
