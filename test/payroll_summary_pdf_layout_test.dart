import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../lib/services/payroll_summary_pdf_layout.dart';

void main() {
  test('Amounts scale to narrow cells without wrapping decimals', () async {
    final document = pw.Document();
    final amount = payrollSummarySingleLine('26,828.00');
    document.addPage(pw.Page(
      build: (_) => pw.Align(
        alignment: pw.Alignment.topLeft,
        child: pw.SizedBox(width: 20, child: amount),
      ),
    ));
    await document.save();
    expect(amount.box!.width, lessThanOrEqualTo(20));
    final text = ((amount as pw.FittedBox).child as pw.Text);
    expect(text.box!.height, lessThan(10));
    expect(text.box!.width, greaterThan(20));
  });
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
          payrollSummarySingleLine('58230.00 / 170 emp'),
          payrollSummaryZeroContributorLists(
            List.generate(
                branchCount,
                (i) => {
                      'employeeId': 'EPF$i',
                      'name': 'EPF zero contribution employee $i',
                      'branch': 'Branch $i',
                    }),
            List.generate(
                branchCount + 5,
                (i) => {
                      'employeeId': 'SOCSO$i',
                      'name': 'SOCSO zero contribution employee $i',
                      'branch': 'Branch $i',
                    }),
          ),
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
