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
      logo = pw.MemoryImage(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {}

    final month = DateFormat('MMMM, yyyy').format(p.period);
    final monthlyAttendance = attendance
        .where((record) =>
            record.employeeId == p.employeeId &&
            record.date.year == p.period.year &&
            record.date.month == p.period.month)
        .toList();
    final calendarDays = DateTime(p.period.year, p.period.month + 1, 0).day;
    final workedDays = monthlyAttendance.where(_worked).length;
    final overtimeHours = monthlyAttendance.fold<double>(
        0, (sum, record) => sum + _overtimeHours(record));
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
      'BONUS': p.bonus,
      'COMMISSION': p.commission,
      'HOUSING ALLOWANCE': p.housingAllowance,
      'TRAVEL ALLOWANCE': p.travelAllowance,
      'OTHER EARNINGS': p.otherEarnings,
    };
    final deductions = <String, double>{
      'ADVANCE': p.advanceDeduction,
      'LOAN': p.loanDeduction,
      'UNPAID LEAVE': p.unpaidLeave,
      'LATE DEDUCTION': p.lateDeduction,
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

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5.landscape,
        margin: const pw.EdgeInsets.all(18),
        theme: pw.ThemeData.withFont(
          base: pw.Font.courier(),
          bold: pw.Font.courierBold(),
        ),
        build: (_) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.1, color: PdfColors.black),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _slipHeader(logo, month, employee, p),
              pw.Expanded(
                child: _ledger(income, deductions),
              ),
              _totalsRow(gross, totalDeductions),
              _paymentRow(net, employee, p),
              _contributionAndAttendance(
                p: p,
                calendarDays: calendarDays,
                workedDays: workedDays,
                overtimeHours: overtimeHours,
                earlyOutDays: earlyOutDays,
                unpaidDays: unpaidDays,
              ),
              if ((p.remarks ?? '').trim().isNotEmpty)
                _singleLine('REMARKS', p.remarks!.trim()),
              pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'COMPUTER-GENERATED PAYSLIP',
                      style: const pw.TextStyle(fontSize: 5.5),
                    ),
                    pw.Text(
                      'RECEIVED BY: ____________________',
                      style: const pw.TextStyle(fontSize: 5.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  static pw.Widget _slipHeader(
    pw.MemoryImage? logo,
    String month,
    Employee employee,
    PayrollRecord payroll,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: .8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null)
            pw.Container(
              width: 58,
              height: 27,
              margin: const pw.EdgeInsets.only(right: 8),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'HASANI BOOKS EDAR SDN BHD',
                  style:
                      pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 3),
                _headerPair('EMPLOYEE', employee.name),
                _headerPair('I/C NO.', employee.newIcNo),
                _headerPair('POSITION', employee.designation),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _headerPair('PERIOD', month.toUpperCase()),
                _headerPair('EMPLOYEE ID', employee.employeeId),
                _headerPair('DEPARTMENT', employee.department),
                _headerPair('BRANCH', employee.branchId),
                _headerPair('STATUS', payroll.isPaid ? 'PAID' : 'UNPAID'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _headerPair(String label, String value) {
    return pw.Text(
      '$label : ${value.trim().isEmpty ? '-' : value.trim()}',
      style: const pw.TextStyle(fontSize: 6.3, height: 1.25),
      maxLines: 1,
    );
  }

  static pw.Widget _ledger(
    Map<String, double> income,
    Map<String, double> deductions,
  ) {
    final incomeEntries = income.entries.toList();
    final deductionEntries = deductions.entries.toList();
    final count = incomeEntries.length > deductionEntries.length
        ? incomeEntries.length
        : deductionEntries.length;
    return pw.Table(
      border: const pw.TableBorder(
        verticalInside: pw.BorderSide(width: .55),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.1),
        1: pw.FlexColumnWidth(1.25),
        2: pw.FlexColumnWidth(3.1),
        3: pw.FlexColumnWidth(1.25),
      },
      children: [
        _ledgerRow('EARNINGS', 'AMOUNT', 'DEDUCTIONS', 'AMOUNT', header: true),
        for (var index = 0; index < count; index++)
          _ledgerRow(
            index < incomeEntries.length ? incomeEntries[index].key : '',
            index < incomeEntries.length
                ? _money(incomeEntries[index].value)
                : '',
            index < deductionEntries.length ? deductionEntries[index].key : '',
            index < deductionEntries.length
                ? _money(deductionEntries[index].value)
                : '',
          ),
      ],
    );
  }

  static pw.TableRow _ledgerRow(
    String earning,
    String earningAmount,
    String deduction,
    String deductionAmount, {
    bool header = false,
  }) {
    return pw.TableRow(
      decoration: header
          ? const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: .7)),
            )
          : null,
      children: [
        _ledgerCell(earning, bold: header),
        _ledgerCell(earningAmount, bold: header, right: !header),
        _ledgerCell(deduction, bold: header),
        _ledgerCell(deductionAmount, bold: header, right: !header),
      ],
    );
  }

  static pw.Widget _ledgerCell(
    String value, {
    bool bold = false,
    bool right = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.2),
      child: pw.Text(
        value,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 6.2,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _totalsRow(double gross, double deductions) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: .8),
          bottom: pw.BorderSide(width: .8),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: pw.Row(
        children: [
          pw.Expanded(child: _amountPair('TOTAL EARNINGS', gross)),
          pw.Container(width: .6, height: 12, color: PdfColors.black),
          pw.Expanded(child: _amountPair('TOTAL DEDUCTIONS', deductions)),
        ],
      ),
    );
  }

  static pw.Widget _amountPair(String label, double value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
        pw.Text(_money(value),
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _paymentRow(
    double net,
    Employee employee,
    PayrollRecord payroll,
  ) {
    final bankAccount = payroll.bankAccount.isNotEmpty
        ? payroll.bankAccount
        : employee.bankAccount;
    final bankName = payroll.bankName.isNotEmpty
        ? payroll.bankName
        : payroll.bankCode.isNotEmpty
            ? payroll.bankCode
            : employee.bankCode;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: .8)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'BANK ACC : ${bankName.isEmpty ? '-' : bankName}  ${bankAccount.isEmpty ? '-' : bankAccount}',
              style: const pw.TextStyle(fontSize: 6.2),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'NET PAY  ',
                  style:
                      pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                  child: pw.Text(
                    'RM ${net.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _contributionAndAttendance({
    required PayrollRecord p,
    required int calendarDays,
    required int workedDays,
    required double overtimeHours,
    required int earlyOutDays,
    required int unpaidDays,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: .8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              'EMPLOYER  EPF ${_money(p.epfEmployer)}  |  SOCSO ${_money(p.socsoEmployer)}  |  EIS ${_money(p.eisEmployer)}',
              style: const pw.TextStyle(fontSize: 5.8, height: 1.3),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              'ATTENDANCE  DAYS $workedDays/$calendarDays  |  OT ${overtimeHours.toStringAsFixed(2)} HRS  |  EARLY $earlyOutDays  |  UNPAID $unpaidDays',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 5.8, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _singleLine(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: .8)),
      ),
      child:
          pw.Text('$label : $value', style: const pw.TextStyle(fontSize: 5.8)),
    );
  }

  static bool _worked(AttendanceRecord record) {
    final status = record.status.toLowerCase().trim();
    return status != 'absent' &&
        status != 'leave' &&
        status != 'vacation' &&
        record.effectiveCheckIn.trim().isNotEmpty;
  }

  static bool _unpaid(AttendanceRecord record) {
    final status = record.status.toLowerCase().trim();
    return status == 'time off' ||
        status == 'unpaid' ||
        status == 'unpaid leave';
  }

  static bool _earlyOut(AttendanceRecord record) =>
      _worked(record) &&
      !_unpaid(record) &&
      _workMinutes(record) > 0 &&
      _workMinutes(record) < 630;

  static int _workMinutes(AttendanceRecord record) {
    final start = _minutes(record.effectiveCheckIn);
    final end = _minutes(record.effectiveCheckOut);
    return start == null || end == null || end <= start ? 0 : end - start;
  }

  static double _overtimeHours(AttendanceRecord record) {
    if (!record.otAuthorized) return 0;
    final start = _minutes(record.overtimeIn);
    final end = _minutes(record.overtimeOut);
    return start == null || end == null || end <= start
        ? 0
        : (end - start) / 60.0;
  }

  static int? _minutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    return hour == null || minute == null || hour > 23 || minute > 59
        ? null
        : hour * 60 + minute;
  }

  static String _money(double value) =>
      value == 0 ? '' : value.toStringAsFixed(2);
}
