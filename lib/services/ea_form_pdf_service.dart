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
      author: 'Hasani Books Edar Sdn Bhd',
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
      double size = 7.2,
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
            field(380, 46, 106, text(data['income_tax_no'])),
            field(493, 64, 92, text(data['lhdn_branch'])),
            field(375, 64, 38, year),

            // A - Butiran pekerja
            field(190, 111, 390, text(data['employee_name'])),
            field(128, 129, 180, text(data['designation'])),
            field(409, 129, 176, text(data['employee_id'])),
            field(128, 147, 180, text(data['identification_no'])),
            field(409, 147, 176, text(data['passport_no'])),
            field(128, 165, 180, text(data['epf_no'])),
            field(409, 165, 176, text(data['socso_no'])),
            field(188, 190, 120, text(data['eligible_children'])),
            field(409, 183, 176, text(data['employment_start'])),
            field(409, 201, 176, text(data['employment_end'])),

            // B - Pendapatan penggajian, manfaat dan tempat kediaman
            field(510, 253, 76, money(data['salary_wages']), right: true),
            field(510, 271, 76, money(data['commission_bonus']), right: true),
            field(510, 289, 76, money(data['allowances_overtime']), right: true),
            field(510, 307, 76, money(data['tax_paid_by_employer']), right: true),
            field(510, 325, 76, money(data['esos_benefit']), right: true),
            field(510, 343, 76, money(data['gratuity']), right: true),
            field(510, 378, 76, money(data['arrears']), right: true),
            field(510, 396, 76, money(data['benefits_in_kind']), right: true),
            field(510, 414, 76, money(data['living_accommodation']), right: true),
            field(510, 432, 76, money(data['pension_refund']), right: true),
            field(510, 450, 76, money(data['compensation']), right: true),

            // C - Pencen dan lain-lain
            field(510, 488, 76, money(data['pension']), right: true),
            field(510, 506, 76, money(data['other_income']), right: true),

            // D - Jumlah potongan
            field(510, 557, 76, money(data['pcb']), right: true),
            field(510, 575, 76, money(data['cp38']), right: true),
            field(510, 593, 76, money(data['zakat']), right: true),
            field(510, 611, 76, money(data['approved_donations']), right: true),
            field(510, 620, 76, text(data['eligible_children'])),

            // E - Caruman pekerja
            field(85, 657, 360, 'KUMPULAN WANG SIMPANAN PEKERJA'),
            field(510, 675, 76, money(data['epf_employee']), right: true),
            field(510, 693, 76, money(data['socso_employee']), right: true),

            // F - Elaun/manfaat dikecualikan cukai
            field(510, 711, 76, money(data['tax_exempt_allowances']), right: true),

            // Employer certification
            field(354, 749, 225, text(data['officer_name'])),
            field(354, 763, 225, text(data['officer_designation'])),
            field(354, 777, 225, text(data['employer_name'])),
            field(354, 791, 225, text(data['employer_address'])),
            field(354, 808, 225, text(data['employer_phone'])),
            field(76, 803, 120, text(data['generated_date'])),
          ]),
        ),
      ),
    );
    return document.save();
  }
}
