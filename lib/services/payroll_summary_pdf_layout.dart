import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const payrollSummaryPdfMargin = 10 * PdfPageFormat.mm;

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
