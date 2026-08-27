import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/payroll.dart';

class PdfService {
  static Future<Uint8List> buildPayslip({
    required Employee employee,
    required PayrollRecord p,
    List<PayrollRecord> history = const [],
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? logo;

    try {
      final logoData = await rootBundle.load('assets/hasani_books_logo.jpg');
      logo = pw.MemoryImage(
        logoData.buffer.asUint8List(
          logoData.offsetInBytes,
          logoData.lengthInBytes,
        ),
      );
    } catch (_) {}

    final yearRecords = history
        .where((record) =>
            record.employeeId == p.employeeId &&
            record.period.year == p.period.year &&
            !record.period.isAfter(p.period))
        .toList();
    final records = yearRecords.isEmpty ? [p] : yearRecords;
    final month = DateFormat('MMMM, yyyy').format(p.period);

    double ytd(double Function(PayrollRecord) value) => records.fold(
          0,
          (sum, record) => sum + value(record),
        );

    final income = <String, double>{
      'BASIC SALARY': p.basicSalary,
      'FW SALARY': p.fwSalary,
      'ELAUN KEDATANGAN': p.elaunKedatangan,
      'ELAUN PERKHIDMATAN': p.elaunPerkhidmatan,
      'ELAUN KERAJINAN': p.elaunKerajinan,
      'OVERTIME': p.overtime,
      'BONUS': p.bonus,
      'COMMISSION': p.commission,
      'OTHER EARNINGS': p.otherEarnings,
      'HOUSING ALLOWANCE': p.housingAllowance,
      'TRAVEL ALLOWANCE': p.travelAllowance,
    };

    final deductions = <String, double>{
      'ADVANCE': p.advanceDeduction,
      'LOAN': p.loanDeduction,
      'UNPAID LEAVE': p.unpaidLeave,
      'EPF': p.epfEmployee,
      'SOCSO': p.socsoEmployee,
      'EIS': p.eisEmployee,
      'PCB': p.pcb,
      'ZAKAT': p.zakat,
      'OTHER DEDUCTION': p.otherDeductionAmount,
    };

    final employer = <String, double>{
      'EMPLOYER EPF': p.epfEmployer,
      'EMPLOYER SOCSO': p.socsoEmployer,
      'EMPLOYER EIS': p.eisEmployer,
    };

    final calculatedGross = p.storedGrossSalary ?? p.totalEarnings;
    final calculatedDeductions = p.storedTotalDeductions ?? p.totalDeductions;
    final calculatedNet = p.storedNetSalary ?? p.netPay;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 22),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 125,
                    height: 48,
                    padding: const pw.EdgeInsets.only(right: 12),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(width: 125),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'HASANI BOOKS EDAR SDN BHD',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Payroll Statement',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
                pw.Text(
                  'PAYSLIP\n$month',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 0.8),
            pw.Row(
              children: [
                _info('NAME', employee.name),
                _info('EMPLOYEE ID', employee.employeeId),
                _info('DESIGNATION', employee.designation),
                _info('DEPARTMENT', employee.department),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                _info('NEW IC NO', employee.newIcNo),
                _info('BANK', _bankText(employee, p)),
                _info('BRANCH', employee.branchId),
                _info('STATUS', p.isPaid ? 'PAID' : 'UNPAID'),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(width: 0.65),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.7),
                1: pw.FlexColumnWidth(1.15),
                2: pw.FlexColumnWidth(1.15),
                3: pw.FlexColumnWidth(2.7),
                4: pw.FlexColumnWidth(1.15),
                5: pw.FlexColumnWidth(1.15),
              },
              children: [
                _headerRow('INCOME', 'CURRENT', 'Y-T-D', 'DEDUCTION',
                    'CURRENT', 'Y-T-D'),
                ..._detailRows(income, deductions, ytd),
                _summaryRow(
                  'GROSS SALARY',
                  calculatedGross,
                  ytd((record) => record.totalEarnings),
                  'TOTAL DEDUCTIONS',
                  calculatedDeductions,
                  ytd((record) => record.totalDeductions),
                ),
                ...employer.entries.map(
                  (entry) => _detailRow(
                    '',
                    0,
                    0,
                    entry.key,
                    entry.value,
                    ytd((record) => _employerValue(record, entry.key)),
                  ),
                ),
                _summaryRow(
                  'NET INCOME',
                  calculatedNet,
                  ytd((record) => record.netPay),
                  'EMPLOYER COST',
                  p.totalEmployerCost,
                  ytd((record) => record.totalEmployerCost),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                _footerValue('PAYMENT REFERENCE', p.paymentReference),
                _footerValue('PAID DATE', _date(p.paidAt)),
                _footerValue('REMARKS', p.remarks ?? ''),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'This is a computer-generated payslip.',
                  style: const pw.TextStyle(fontSize: 7),
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 150, height: 0.7, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Employee Signature', style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static List<pw.TableRow> _detailRows(
    Map<String, double> income,
    Map<String, double> deductions,
    double Function(double Function(PayrollRecord)) ytd,
  ) {
    final count = income.length > deductions.length ? income.length : deductions.length;
    final incomeEntries = income.entries.toList();
    final deductionEntries = deductions.entries.toList();
    return List.generate(count, (index) {
      final incomeEntry = index < incomeEntries.length ? incomeEntries[index] : null;
      final deductionEntry = index < deductionEntries.length ? deductionEntries[index] : null;
      return _detailRow(
        incomeEntry?.key ?? '',
        incomeEntry?.value ?? 0,
        incomeEntry == null
          ? 0
          : ytd((record) => _incomeValue(record, incomeEntry.key)),
        deductionEntry?.key ?? '',
        deductionEntry?.value ?? 0,
        deductionEntry == null
          ? 0
          : ytd((record) => _deductionValue(record, deductionEntry.key)),
      );
    });
  }

  static pw.TableRow _headerRow(String a, String b, String c, String d, String e, String f) {
    return pw.TableRow(
      children: [a, b, c, d, e, f].map((value) => _cell(value, bold: true)).toList(),
    );
  }

  static pw.TableRow _detailRow(
    String income,
    double incomeCurrent,
    double incomeYtd,
    String deduction,
    double deductionCurrent,
    double deductionYtd,
  ) {
    return pw.TableRow(children: [
      _cell(income),
      _cell(_money(incomeCurrent), right: true),
      _cell(_money(incomeYtd), right: true),
      _cell(deduction),
      _cell(_money(deductionCurrent), right: true),
      _cell(_money(deductionYtd), right: true),
    ]);
  }

  static pw.TableRow _summaryRow(
    String left,
    double leftCurrent,
    double leftYtd,
    String right,
    double rightCurrent,
    double rightYtd,
  ) {
    return pw.TableRow(children: [
      _cell(left, bold: true),
      _cell(_money(leftCurrent), right: true, bold: true),
      _cell(_money(leftYtd), right: true, bold: true),
      _cell(right, bold: true),
      _cell(_money(rightCurrent), right: true, bold: true),
      _cell(_money(rightYtd), right: true, bold: true),
    ]);
  }

  static pw.Widget _info(String label, String value) {
    return pw.Expanded(
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
            pw.TextSpan(text: value.isEmpty ? '-' : value, style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _footerValue(String label, String value) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(right: 8),
        child: pw.Text('$label: ${value.isEmpty ? '-' : value}', style: const pw.TextStyle(fontSize: 7)),
      ),
    );
  }

  static pw.Widget _cell(String value, {bool right = false, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Align(
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(value, style: pw.TextStyle(fontSize: 7, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ),
    );
  }

  static double _employerValue(PayrollRecord p, String key) {
    switch (key) {
      case 'EMPLOYER EPF': return p.epfEmployer;
      case 'EMPLOYER SOCSO': return p.socsoEmployer;
      case 'EMPLOYER EIS': return p.eisEmployer;
      default: return 0;
    }
  }

  static double _incomeValue(PayrollRecord p, String key) {
    switch (key) {
      case 'BASIC SALARY': return p.basicSalary;
      case 'FW SALARY': return p.fwSalary;
      case 'ELAUN KEDATANGAN': return p.elaunKedatangan;
      case 'ELAUN PERKHIDMATAN': return p.elaunPerkhidmatan;
      case 'ELAUN KERAJINAN': return p.elaunKerajinan;
      case 'OVERTIME': return p.overtime;
      case 'BONUS': return p.bonus;
      case 'COMMISSION': return p.commission;
      case 'OTHER EARNINGS': return p.otherEarnings;
      case 'HOUSING ALLOWANCE': return p.housingAllowance;
      case 'TRAVEL ALLOWANCE': return p.travelAllowance;
      default: return 0;
    }
  }

  static double _deductionValue(PayrollRecord p, String key) {
    switch (key) {
      case 'ADVANCE': return p.advanceDeduction;
      case 'LOAN': return p.loanDeduction;
      case 'UNPAID LEAVE': return p.unpaidLeave;
      case 'EPF': return p.epfEmployee;
      case 'SOCSO': return p.socsoEmployee;
      case 'EIS': return p.eisEmployee;
      case 'PCB': return p.pcb;
      case 'ZAKAT': return p.zakat;
      case 'OTHER DEDUCTION': return p.otherDeductionAmount;
      default: return 0;
    }
  }

  static String _bankText(Employee employee, PayrollRecord p) {
    final code = p.bankCode.isEmpty ? employee.bankCode : p.bankCode;
    final account = p.bankAccount.isEmpty ? employee.bankAccount : p.bankAccount;
    return [code, account].where((value) => value.isNotEmpty).join(' / ');
  }

  static String _date(DateTime? value) => value == null ? '' : DateFormat('dd/MM/yyyy').format(value);

  static String _money(double value) => value == 0 ? '' : value.toStringAsFixed(2);
}
