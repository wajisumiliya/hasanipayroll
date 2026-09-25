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

    final sectionCTotal =
        _number(data['salary_wages']) + _number(data['allowances_overtime']);

    pw.Widget field(
      double left,
      double top,
      double width,
      String content, {
      double size = 6.7,
      bool right = false,
      bool bold = false,
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
            alignment:
                right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            child: pw.Text(
              content,
              maxLines: 1,
              style: pw.TextStyle(
                fontSize: size,
                color: PdfColors.black,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    pw.Widget amountField(double top, dynamic value) => field(
          480,
          top,
          74,
          money(value),
          size: 7.5,
          right: true,
          bold: true,
        );

    final year = text(form['tax_year'] ?? data['tax_year']);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Stack(children: [
            pw.Positioned.fill(
                child: pw.Image(background, fit: pw.BoxFit.fill)),

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
            amountField(244, data['salary_wages']),
            amountField(258, data['commission_bonus']),
            amountField(272, data['allowances_overtime']),
            amountField(287, data['tax_paid_by_employer']),
            amountField(301, data['esos_benefit']),
            amountField(315, data['gratuity']),
            amountField(372, data['arrears']),
            amountField(386, data['benefits_in_kind']),
            amountField(400, data['living_accommodation']),
            amountField(414, data['pension_refund']),
            amountField(429, data['compensation']),

            // C - Pencen dan lain-lain
            amountField(453, data['pension']),
            amountField(467, data['other_income']),
            amountField(484, sectionCTotal),

            // D - Jumlah potongan
            amountField(522, data['pcb']),
            amountField(535, data['cp38']),
            amountField(548, data['zakat']),
            amountField(561, data['approved_donations']),
            field(480, 614, 74, text(data['eligible_children']), right: true),

            // E - Caruman pekerja
            field(185, 654, 262, 'KUMPULAN WANG SIMPANAN PEKERJA', size: 5.8),
            amountField(678, data['epf_employee']),
            amountField(695, data['socso_employee']),

            // F - Elaun/manfaat dikecualikan cukai
            amountField(708, data['tax_exempt_allowances']),

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
