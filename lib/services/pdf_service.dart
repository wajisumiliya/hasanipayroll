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
    List<AttendanceRecord> attendance = const [],
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

    final month = DateFormat('MMMM, yyyy').format(p.period);

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

    final calculatedGross = p.basicSalary +
        p.fwSalary +
        p.elaunKedatangan +
        p.elaunPerkhidmatan +
        p.elaunKerajinan +
        p.overtime +
        p.cutiUmum;
    final calculatedDeductions = p.totalDeductions;
    final calculatedNet = calculatedGross - calculatedDeductions;
    final currentRows = <String, double>{
      'BASIC PAY': p.basicSalary,
      'FW SALARY': p.fwSalary,
      'ELAUN KEDATANGAN': p.elaunKedatangan,
      'ELAUN PERKHIDMATAN': p.elaunPerkhidmatan,
      'ELAUN KERAJINAN': p.elaunKerajinan,
      'NORMAL OT': p.overtime,
      'CUTI UMUM': p.cutiUmum,
    };

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
            pw.Row(children: [
              _info('EMPLOYEE NO.', employee.employeeId),
              _info('NAME', employee.name),
              _info('EPF NO.', p.bankAccount),
            ]),
            pw.SizedBox(height: 3),
            pw.Row(children: [
              _info('IC NO.', employee.newIcNo),
              _info('DEPARTMENT', employee.department),
              _info('SOCSO NO.', p.bankCode),
            ]),
            pw.SizedBox(height: 3),
            pw.Row(children: [
              _info('DESIGNATION', employee.designation),
              _info('BRANCH', employee.branchId),
              _info('TAX NO.', ''),
            ]),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(width: 0.65),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.8),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(2.8),
                3: pw.FlexColumnWidth(1.2),
                4: pw.FlexColumnWidth(2.8),
                5: pw.FlexColumnWidth(1.2),
              },
              children: [
                _sixHeaderRow(),
                ..._currentPayslipRows(
                  currentRows,
                  deductions,
                  p,
                  attendance.where((record) =>
                      record.employeeId == p.employeeId &&
                      record.date.year == p.period.year &&
                      record.date.month == p.period.month).toList(),
                ),
                _sixSummaryRow(
                  'TOTAL', calculatedGross, 'TOTAL', calculatedDeductions,
                  'NET PAY', calculatedNet,
                ),
              ],
            ),
            pw.SizedBox(height: 9),
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.65)),
              child: pw.Column(children: [
                _sectionTitle('EMPLOYER CONTRIBUTIONS'),
                pw.Row(children: [
                  _footerValue('EPF', _money(p.epfEmployer)),
                  _footerValue('SOCSO', _money(p.socsoEmployer)),
                  _footerValue('EIS', _money(p.eisEmployer)),
                ]),
                pw.Row(children: [
                  _footerValue('EMPLOYER COST', _money(p.totalEmployerCost)),
                ]),
              ]),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'APPROVED BY: ____________________',
                  style: const pw.TextStyle(fontSize: 7),
                ),
                pw.Column(
                  children: [
                    pw.Text('RECEIVED BY: ____________________', style: const pw.TextStyle(fontSize: 7)),
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

  static pw.TableRow _sixHeaderRow() {
    return pw.TableRow(
      children: [
        _cell('EARNINGS / INCOME', bold: true),
        _cell('CURRENT', bold: true),
        _cell('DEDUCTION', bold: true),
        _cell('CURRENT', bold: true),
        _cell('OTHERS', bold: true),
        _cell('CURRENT', bold: true),
      ],
    );
  }

  static List<pw.TableRow> _currentPayslipRows(
    Map<String, double> income,
    Map<String, double> deductions,
    PayrollRecord current,
    List<AttendanceRecord> attendance,
  ) {
    final incomeEntries = income.entries.toList();
    final deductionEntries = deductions.entries.toList();
    final calendarDays = DateTime(current.period.year, current.period.month + 1, 0).day;
    final workedDays = attendance.where(_isWorked).length;
    final overtimeHours = attendance.fold<double>(0, (sum, record) => sum + _overtimeHours(record));
    final earlyOutDays = attendance.where(_isEarlyOut).length;
    final unpaidDays = attendance.where(_isUnpaid).length;
    final others = <String, String>{
      'WORKING DAYS': calendarDays.toString(),
      'DAY WORK': workedDays.toString(),
      'OVERTIME': overtimeHours.toStringAsFixed(2),
      'EARLY OUT': earlyOutDays.toString(),
      'TIME OFF': unpaidDays.toString(),
    };
    return List.generate(9, (index) {
      final incomeEntry = index < incomeEntries.length ? incomeEntries[index] : null;
      final deductionEntry = index < deductionEntries.length ? deductionEntries[index] : null;
        final otherEntry = index < others.length ? others.entries.elementAt(index) : null;
      return pw.TableRow(children: [
        _cell(incomeEntry?.key ?? ''),
        _cell(_money(incomeEntry?.value ?? 0), right: true),
        _cell(deductionEntry?.key ?? ''),
        _cell(_money(deductionEntry?.value ?? 0), right: true),
        _cell(otherEntry?.key ?? ''),
        _cell(otherEntry?.value ?? '', right: true),
      ]);
    });
  }

  static pw.TableRow _sixSummaryRow(
    String incomeLabel,
    double incomeValue,
    String deductionLabel,
    double deductionValue,
    String otherLabel,
    double otherValue,
  ) {
    return pw.TableRow(children: [
      _cell(incomeLabel, bold: true),
      _cell(_money(incomeValue), right: true, bold: true),
      _cell(deductionLabel, bold: true),
      _cell(_money(deductionValue), right: true, bold: true),
      _cell(otherLabel, bold: true),
      _cell(_money(otherValue), right: true, bold: true),
    ]);
  }

  static pw.TableRow _eightHeaderRow() {
    return pw.TableRow(
      children: [
        _cell('EARNINGS / INCOME', bold: true),
        _cell('CURRENT', bold: true),
        _cell('DEDUCTION', bold: true),
        _cell('CURRENT', bold: true),
        _cell('YEAR-TO-DATE', bold: true),
        _cell('CURRENT', bold: true),
        _cell('OTHERS', bold: true),
        _cell('CURRENT', bold: true),
      ],
    );
  }

  static List<pw.TableRow> _referenceRows(
    Map<String, double> income,
    Map<String, double> deductions,
    List<PayrollRecord> records,
    PayrollRecord current,
  ) {
    final incomeEntries = income.entries.toList();
    final deductionEntries = deductions.entries.toList();
    final rows = <pw.TableRow>[];
    final labels = <String>[
      'BASIC PAY',
      'FW SALARY',
      'ELAUN KEDATANGAN',
      'ELAUN PERKHIDMATAN',
      'ELAUN KERAJINAN',
      'NORMAL OT',
      'WORKING DAYS',
      'DAY WORK',
      'REST OT',
    ];

    for (var index = 0; index < labels.length; index++) {
      final incomeEntry = index < incomeEntries.length ? incomeEntries[index] : null;
      final deductionEntry = index < deductionEntries.length ? deductionEntries[index] : null;
        final double ytdIncome = incomeEntry == null
          ? 0.0
          : records.fold<double>(
              0,
              (sum, record) => sum + _incomeValue(record, incomeEntry.key),
            );
      rows.add(_referenceRow(
        incomeEntry?.key ?? labels[index],
        incomeEntry?.value ?? 0,
        deductionEntry?.key ?? '',
        deductionEntry?.value ?? 0,
        incomeEntry == null ? '' : _money(ytdIncome),
        index == 0 ? 'PAYMENT STATUS' : '',
        index == 0 ? (current.isPaid ? 'PAID' : 'UNPAID') : '',
      ));
    }
    return rows;
  }

  static pw.TableRow _referenceRow(
    String income,
    double incomeCurrent,
    String deduction,
    double deductionCurrent,
    String yearToDate,
    String otherLabel,
    String otherValue,
  ) {
    return pw.TableRow(children: [
      _cell(income),
      _cell(_money(incomeCurrent), right: true),
      _cell(deduction),
      _cell(_money(deductionCurrent), right: true),
      _cell(yearToDate, right: true),
      _cell('', right: true),
      _cell(otherLabel),
      _cell(otherValue, right: true),
    ]);
  }

  static pw.TableRow _eightSummaryRow(
    String incomeLabel,
    double incomeValue,
    String deductionLabel,
    double deductionValue,
    String ytdLabel,
    double ytdValue,
    String otherLabel,
    double otherValue,
  ) {
    return pw.TableRow(children: [
      _cell(incomeLabel, bold: true),
      _cell(_money(incomeValue), right: true, bold: true),
      _cell(deductionLabel, bold: true),
      _cell(_money(deductionValue), right: true, bold: true),
      _cell(ytdLabel, bold: true),
      _cell(_money(ytdValue), right: true, bold: true),
      _cell(otherLabel, bold: true),
      _cell(_money(otherValue), right: true, bold: true),
    ]);
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      alignment: pw.Alignment.center,
      child: pw.Text(title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );
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

  static double _incomeValue(PayrollRecord p, String key) {
    switch (key) {
      case 'BASIC SALARY': return p.basicSalary;
      case 'FW SALARY': return p.fwSalary;
      case 'ELAUN KEDATANGAN': return p.elaunKedatangan;
      case 'ELAUN PERKHIDMATAN': return p.elaunPerkhidmatan;
      case 'ELAUN KERAJINAN': return p.elaunKerajinan;
      case 'OVERTIME': return p.overtime;
      case 'CUTI UMUM': return p.cutiUmum;
      default: return 0;
    }
  }

  static bool _isWorked(AttendanceRecord record) {
    final status = record.status.toLowerCase().trim();
    return status != 'absent' && status != 'leave' && status != 'vacation' &&
        (record.effectiveCheckIn.isNotEmpty || record.morningOut.isNotEmpty);
  }

  static bool _isUnpaid(AttendanceRecord record) {
    final status = record.status.toLowerCase().trim();
    return status == 'time off' || status == 'unpaid' || status == 'unpaid leave';
  }

  static bool _isEarlyOut(AttendanceRecord record) {
    if (!_isWorked(record) || _isUnpaid(record)) return false;
    final workedMinutes = _workMinutes(record);
    return workedMinutes > 0 && workedMinutes < 630;
  }

  static double _overtimeHours(AttendanceRecord record) {
    if (!record.otAuthorized) return 0;
    final start = _minutes(record.overtimeIn);
    final end = _minutes(record.overtimeOut);
    if (start == null || end == null || end <= start) return 0;
    return (end - start) / 60.0;
  }

  static int _workMinutes(AttendanceRecord record) {
    final start = _minutes(record.effectiveCheckIn);
    final end = _minutes(record.effectiveCheckOut);
    if (start == null || end == null || end <= start) return 0;
    return end - start;
  }

  static int? _minutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  static double _payslipGross(PayrollRecord p) {
    return p.basicSalary +
        p.fwSalary +
        p.elaunKedatangan +
        p.elaunPerkhidmatan +
        p.elaunKerajinan +
        p.overtime;
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
