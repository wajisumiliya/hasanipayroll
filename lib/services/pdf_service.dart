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
    final document = pw.Document();
    pw.MemoryImage? logo;

    try {
      final data = await rootBundle.load('assets/hasani_books_logo.jpg');
      logo = pw.MemoryImage(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {}

    final month = DateFormat('MMMM, yyyy').format(p.period);
    final monthlyAttendance = attendance.where((record) =>
        record.employeeId == p.employeeId &&
        record.date.year == p.period.year &&
        record.date.month == p.period.month).toList();
    final calendarDays = DateTime(p.period.year, p.period.month + 1, 0).day;
    final workedDays = monthlyAttendance.where(_worked).length;
    final overtimeHours = monthlyAttendance.fold<double>(0, (sum, record) => sum + _overtimeHours(record));
    final earlyOutDays = monthlyAttendance.where(_earlyOut).length;
    final unpaidDays = monthlyAttendance.where(_unpaid).length;

    final income = <String, double>{
      'BASIC PAY': p.basicSalary,
      'FW SALARY': p.fwSalary,
      'ELAUN KEDATANGAN': p.elaunKedatangan,
      'ELAUN PERKHIDMATAN': p.elaunPerkhidmatan,
      'ELAUN KERAJINAN': p.elaunKerajinan,
      'OVERTIME': p.overtime,
      'CUTI UMUM': p.cutiUmum,
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
    final gross = income.values.fold<double>(0, (sum, value) => sum + value);
    final totalDeductions = p.totalDeductions;
    final net = gross - totalDeductions;

    document.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 22),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(children: [
            if (logo != null)
              pw.Container(width: 125, height: 48, padding: const pw.EdgeInsets.only(right: 12), child: pw.Image(logo, fit: pw.BoxFit.contain))
            else
              pw.SizedBox(width: 125),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('HASANI BOOKS EDAR SDN BHD', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Payroll Statement', style: const pw.TextStyle(fontSize: 8)),
            ])),
            pw.Text('PAYSLIP\n$month', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.Divider(thickness: 0.8),
          pw.Row(children: [_info('EMPLOYEE NO.', employee.employeeId), _info('NAME', employee.name), _info('EPF NO.', employee.bankAccount)]),
          pw.SizedBox(height: 3),
          pw.Row(children: [_info('IC NO.', employee.newIcNo), _info('DEPARTMENT', employee.department), _info('SOCSO NO.', employee.bankCode)]),
          pw.SizedBox(height: 3),
          pw.Row(children: [_info('DESIGNATION', employee.designation), _info('BRANCH', employee.branchId), _info('TAX NO.', '')]),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(width: 0.65),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.8), 1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(2.8), 3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(2.8), 5: pw.FlexColumnWidth(1.2),
            },
            children: [
              _row(['EARNINGS / INCOME', 'CURRENT', 'DEDUCTION', 'CURRENT', 'OTHERS', 'CURRENT'], bold: true),
              ..._detailRows(income, deductions, {
                'WORKING DAYS': calendarDays.toString(),
                'DAY WORK': workedDays.toString(),
                'OVERTIME': overtimeHours.toStringAsFixed(2),
                'EARLY OUT': earlyOutDays.toString(),
                'TIME OFF': unpaidDays.toString(),
              }),
              _row(['TOTAL', _money(gross), 'TOTAL', _money(totalDeductions), 'NET PAY', _money(net)], bold: true),
            ],
          ),
          pw.SizedBox(height: 9),
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.65)),
            child: pw.Column(children: [
              _section('EMPLOYER CONTRIBUTIONS'),
              pw.Row(children: [
                _footer('EPF', _money(p.epfEmployer)),
                _footer('SOCSO', _money(p.socsoEmployer)),
                _footer('EIS', _money(p.eisEmployer)),
                _footer('EMPLOYER COST', _money(gross + p.epfEmployer + p.socsoEmployer + p.eisEmployer)),
              ]),
            ]),
          ),
          pw.SizedBox(height: 12),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('APPROVED BY: ____________________', style: const pw.TextStyle(fontSize: 7)),
            pw.Text('RECEIVED BY: ____________________', style: const pw.TextStyle(fontSize: 7)),
          ]),
        ],
      ),
    ));
    return document.save();
  }

  static List<pw.TableRow> _detailRows(Map<String, double> income, Map<String, double> deductions, Map<String, String> others) {
    final incomeEntries = income.entries.toList();
    final deductionEntries = deductions.entries.toList();
    final otherEntries = others.entries.toList();
    final count = [incomeEntries.length, deductionEntries.length, otherEntries.length].reduce((a, b) => a > b ? a : b);
    return List.generate(count, (index) => _row([
      index < incomeEntries.length ? incomeEntries[index].key : '',
      index < incomeEntries.length ? _money(incomeEntries[index].value) : '',
      index < deductionEntries.length ? deductionEntries[index].key : '',
      index < deductionEntries.length ? _money(deductionEntries[index].value) : '',
      index < otherEntries.length ? otherEntries[index].key : '',
      index < otherEntries.length ? otherEntries[index].value : '',
    ]));
  }

  static pw.TableRow _row(List<String> values, {bool bold = false}) {
    return pw.TableRow(children: values.map((value) => _cell(value, bold: bold)).toList());
  }

  static pw.Widget _cell(String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(value, style: pw.TextStyle(fontSize: 7, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _info(String label, String value) {
    return pw.Expanded(child: pw.RichText(text: pw.TextSpan(children: [
      pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
      pw.TextSpan(text: value.isEmpty ? '-' : value, style: const pw.TextStyle(fontSize: 7)),
    ])));
  }

  static pw.Widget _footer(String label, String value) {
    return pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('$label: ${value.isEmpty ? '-' : value}', style: const pw.TextStyle(fontSize: 7))));
  }

  static pw.Widget _section(String title) {
    return pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text(title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))));
  }

  static bool _worked(AttendanceRecord record) {
    final status = record.status.toLowerCase().trim();
    return status != 'absent' && status != 'leave' && status != 'vacation' && record.effectiveCheckIn.trim().isNotEmpty;
  }

  static bool _unpaid(AttendanceRecord record) {
    final status = record.status.toLowerCase().trim();
    return status == 'time off' || status == 'unpaid' || status == 'unpaid leave';
  }

  static bool _earlyOut(AttendanceRecord record) => _worked(record) && !_unpaid(record) && _workMinutes(record) > 0 && _workMinutes(record) < 630;

  static int _workMinutes(AttendanceRecord record) {
    final start = _minutes(record.effectiveCheckIn);
    final end = _minutes(record.effectiveCheckOut);
    return start == null || end == null || end <= start ? 0 : end - start;
  }

  static double _overtimeHours(AttendanceRecord record) {
    if (!record.otAuthorized) return 0;
    final start = _minutes(record.overtimeIn);
    final end = _minutes(record.overtimeOut);
    return start == null || end == null || end <= start ? 0 : (end - start) / 60.0;
  }

  static int? _minutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    return hour == null || minute == null || hour > 23 || minute > 59 ? null : hour * 60 + minute;
  }

  static String _money(double value) => value == 0 ? '' : value.toStringAsFixed(2);
}
