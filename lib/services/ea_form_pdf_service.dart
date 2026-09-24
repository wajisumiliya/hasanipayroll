import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class EaFormPdfService {
  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static Future<Uint8List> build(Map<String, dynamic> form) async {
    final data = Map<String, dynamic>.from(form['form_data'] as Map? ?? const {});
    final year = form['tax_year'] ?? data['tax_year'] ?? '';
    final document = pw.Document(
      title: 'EA Form $year - ${data['employee_name'] ?? ''}',
      author: 'Hasani Books Edar Sdn Bhd',
    );
    final money = (dynamic value) => _number(value).toStringAsFixed(2);

    pw.Widget cell(String text,
            {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) =>
        pw.Container(
          alignment: alignment,
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    pw.Widget row(String code, String label, dynamic value) => pw.Table(
          border: pw.TableBorder.all(width: .45),
          columnWidths: const {
            0: pw.FixedColumnWidth(30),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(92),
          },
          children: [
            pw.TableRow(children: [
              cell(code, bold: true, alignment: pw.Alignment.center),
              cell(label),
              cell(money(value), bold: true, alignment: pw.Alignment.centerRight),
            ])
          ],
        );

    pw.Widget section(String title, List<pw.Widget> children) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              color: PdfColors.grey300,
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(title,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            ...children,
            pw.SizedBox(height: 8),
          ],
        );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 25),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('EA $year', style: const pw.TextStyle(fontSize: 7)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
        build: (_) => [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
              width: 58,
              height: 42,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.2)),
              child: pw.Text('EA',
                  style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(children: [
                pw.Text('STATEMENT OF REMUNERATION FROM EMPLOYMENT',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text('FOR THE YEAR ENDED 31 DECEMBER $year',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('C.P. 8A - Pin. 2025', style: const pw.TextStyle(fontSize: 8)),
              ]),
            ),
            pw.SizedBox(width: 70, child: pw.Text('MALAYSIA', textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
          ]),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('EMPLOYER INFORMATION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Name: ${data['employer_name'] ?? 'HASANI BOOKS EDAR SDN BHD'}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Employer no.: ${data['employer_no'] ?? '-'}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Address: ${data['employer_address'] ?? '-'}', style: const pw.TextStyle(fontSize: 8)),
            ]),
          ),
          pw.SizedBox(height: 8),
          section('A. PARTICULARS OF EMPLOYEE', [
            pw.Table(border: pw.TableBorder.all(width: .45), columnWidths: const {0: pw.FixedColumnWidth(135), 1: pw.FlexColumnWidth()}, children: [
              pw.TableRow(children: [cell('Employee name', bold: true), cell('${data['employee_name'] ?? '-'}')]),
              pw.TableRow(children: [cell('Employee / staff number', bold: true), cell('${data['employee_id'] ?? '-'}')]),
              pw.TableRow(children: [cell('Identification / passport no.', bold: true), cell('${data['identification_no'] ?? '-'}')]),
              pw.TableRow(children: [cell('Income tax no.', bold: true), cell('${data['income_tax_no'] ?? '-'}')]),
              pw.TableRow(children: [cell('EPF no.', bold: true), cell('${data['epf_no'] ?? '-'}')]),
              pw.TableRow(children: [cell('SOCSO no.', bold: true), cell('${data['socso_no'] ?? '-'}')]),
              pw.TableRow(children: [cell('Employment period', bold: true), cell('${data['employment_period'] ?? '01/01/$year - 31/12/$year'}')]),
            ]),
          ]),
          section('B. INCOME FROM EMPLOYMENT, BENEFITS AND LIVING ACCOMMODATION (RM)', [
            row('B1(a)', 'Gross salary, wages or leave pay', data['salary_wages']),
            row('B1(b)', 'Fees, commission and bonus', data['commission_bonus']),
            row('B1(c)', 'Tips, allowances, overtime and other taxable income', data['allowances_overtime']),
            row('B2', 'Benefits in kind', data['benefits_in_kind']),
            row('B3', 'Value of living accommodation', data['living_accommodation']),
            row('B4', 'Refund from unapproved pension/provident fund', data['pension_refund']),
            row('B5', 'Compensation for loss of employment', data['compensation']),
            row('B', 'TOTAL', data['total_employment_income']),
          ]),
          section('C. PENSION AND OTHER INCOME (RM)', [
            row('C1', 'Pension', data['pension']),
            row('C2', 'Annuities or other periodic payments', data['other_income']),
          ]),
          section('D. DEDUCTIONS / CONTRIBUTIONS (RM)', [
            row('D1', 'Monthly Tax Deduction (PCB)', data['pcb']),
            row('D2', 'CP38 deduction', data['cp38']),
            row('D3', 'Employee EPF contribution', data['epf_employee']),
            row('D4', 'Zakat paid through payroll', data['zakat']),
          ]),
          section('E. TAX-EXEMPT ALLOWANCES / BENEFITS (RM)', [
            row('E', 'Tax-exempt allowances and benefits', data['tax_exempt_allowances']),
          ]),
          pw.Container(
            padding: const pw.EdgeInsets.all(7),
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('CERTIFICATION', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('This statement was generated from the employer payroll records and published to the employee portal.', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 16),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Generated: ${data['generated_date'] ?? ''}', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Employer: HASANI BOOKS EDAR SDN BHD', style: const pw.TextStyle(fontSize: 8)),
              ]),
            ]),
          ),
          pw.SizedBox(height: 7),
          pw.Text('Important: Please verify personal and tax information. Report any discrepancy to payroll administration.',
              style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
        ],
      ),
    );
    return document.save();
  }
}
