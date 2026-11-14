import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../lib/services/payroll_summary_pdf_layout.dart';

void main() {
  for (final branchCount in [1, 20, 60]) {
    test('Payroll Summary fits A4 with $branchCount branches', () async {
      final document = pw.Document();
      final content = pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text('Payroll Summary - October 2026'),
          pw.TableHelper.fromTextArray(
            headers: List.generate(22, (i) => 'COLUMN $i'),
            data: List.generate(
              branchCount,
              (i) => [
                'LONG BRANCH NAME $i',
                ...List.filled(21, '1,234,567.89'),
              ],
            ),
            cellStyle: const pw.TextStyle(fontSize: 7.2),
          ),
          pw.Text('Statutory payment reconciliation'),
          pw.Text('EPF 58,230.00 - 1,520.00 = 56,710.00'),
          pw.Text('Prepared by Admin'),
        ],
      );
      final fitted = fitPayrollSummaryToA4(content);
      final page = PdfPageFormat.a4.landscape;
      document.addPage(pw.Page(
        pageFormat: page,
        margin: const pw.EdgeInsets.all(payrollSummaryPdfMargin),
        build: (_) => fitted,
      ));

      final bytes = await document.save();
      final pdf = latin1.decode(bytes);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, 1);
      expect(fitted.box!.width,
          lessThanOrEqualTo(page.width - 2 * payrollSummaryPdfMargin + .01));
      expect(fitted.box!.height,
          lessThanOrEqualTo(page.height - 2 * payrollSummaryPdfMargin + .01));
      expect(
          payrollSummaryPdfMargin, greaterThanOrEqualTo(10 * PdfPageFormat.mm));
    });
  }
}
