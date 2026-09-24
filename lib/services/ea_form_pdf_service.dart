import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Draws values on the original uploaded LHDN C.P.8A page. The template
/// remains an unmodified, edge-to-edge page background.
class EaFormPdfService {
  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static Future<Uint8List> build(Map<String, dynamic> form) async {
    final data = Map<String, dynamic>.from(
      form['form_data'] as Map? ?? const {},
    );
    final asset = await rootBundle.load('assets/ea_form_template/page_4.png');
    final background = pw.MemoryImage(asset.buffer.asUint8List());
    final document = pw.Document(
      title: 'EA ${form['tax_year']} - ${data['employee_name'] ?? ''}',
      author: 'Hasani Edar Sdn Bhd',
    );

    String text(dynamic value) => value?.toString().trim() ?? '';
    String money(dynamic value) {
      final amount = _number(value);
      return amount == 0 ? '' : amount.toStringAsFixed(2);
    }

    pw.Widget field(
      double left,
      double top,
      double width,
      String content, {
      double size = 6.7,
      bool right = false,
    }) {
      if (content.isEmpty) return pw.SizedBox();
      return pw.Positioned(
        left: left,
        top: top,
        child: pw.SizedBox(
          width: width,
          height: size + 3,
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            child: pw.Text(
              content,
              maxLines: 1,
              style: pw.TextStyle(fontSize: size, color: PdfColors.black),
            ),
          ),
        ),
      );
    }

    final year = text(form['tax_year'] ?? data['tax_year']);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Stack(children: [
            pw.Positioned.fill(child: pw.Image(background, fit: pw.BoxFit.fill)),

            // Header
            field(99, 63, 86, text(data['employer_tin'])),
            field(424, 48, 136, text(data['income_tax_no'])),
            field(493, 64, 92, text(data['lhdn_branch'])),
            field(375, 64, 38, year),

            // A - Butiran pekerja
            field(260, 109, 320, text(data['employee_name'])),
            field(145, 123, 166, text(data['designation'])),
            field(432, 123, 153, text(data['employee_id'])),
            field(145, 137, 166, text(data['identification_no'])),
            field(432, 137, 153, text(data['passport_no'])),
            field(145, 151, 166, text(data['epf_no'])),
            field(432, 151, 153, text(data['socso_no'])),
            field(188, 178, 120, text(data['eligible_children'])),
            field(432, 178, 153, text(data['employment_start'])),
            field(432, 195, 153, text(data['employment_end'])),

            // B - Pendapatan penggajian, manfaat dan tempat kediaman
            field(480, 244, 74, money(data['salary_wages']), right: true),
            field(480, 258, 74, money(data['commission_bonus']), right: true),
            field(480, 272, 74, money(data['allowances_overtime']), right: true),
            field(480, 287, 74, money(data['tax_paid_by_employer']), right: true),
            field(480, 301, 74, money(data['esos_benefit']), right: true),
            field(480, 315, 74, money(data['gratuity']), right: true),
            field(480, 372, 74, money(data['arrears']), right: true),
            field(480, 386, 74, money(data['benefits_in_kind']), right: true),
            field(480, 400, 74, money(data['living_accommodation']), right: true),
            field(480, 414, 74, money(data['pension_refund']), right: true),
            field(480, 429, 74, money(data['compensation']), right: true),

            // C - Pencen dan lain-lain
            field(480, 453, 74, money(data['pension']), right: true),
            field(480, 467, 74, money(data['other_income']), right: true),

            // D - Jumlah potongan
            field(480, 522, 74, money(data['pcb']), right: true),
            field(480, 535, 74, money(data['cp38']), right: true),
            field(480, 548, 74, money(data['zakat']), right: true),
            field(480, 561, 74, money(data['approved_donations']), right: true),
            field(480, 614, 74, text(data['eligible_children']), right: true),

            // E - Caruman pekerja
            field(185, 654, 262, 'KUMPULAN WANG SIMPANAN PEKERJA', size: 5.8),
            field(480, 678, 74, money(data['epf_employee']), right: true),
            field(480, 695, 74, money(data['socso_employee']), right: true),

            // F - Elaun/manfaat dikecualikan cukai
            field(480, 708, 74, money(data['tax_exempt_allowances']), right: true),

            // Employer certification
            field(354, 738, 225, text(data['officer_name'])),
            field(354, 751, 225, text(data['officer_designation'])),
            field(354, 765, 225, text(data['employer_name']), size: 6.2),
            field(354, 778, 225, text(data['employer_address']), size: 6.2),
            field(354, 791, 225, text(data['employer_phone'])),
            field(93, 791, 103, text(data['generated_date'])),
          ]),
        ),
      ),
    );
    return document.save();
  }
}
