import 'dart:typed_data';
import 'payroll_calculation_service.dart';
import 'attendance_net_hours.dart';
import 'attendance_working_rules.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
// Viewer preferences are not exposed by the pdf widgets API.
// ignore: implementation_imports
import 'package:pdf/src/pdf/format/dict.dart' show PdfDict;
import 'package:pdf/widgets.dart' as pw;

class AttendancePrintDay {
  const AttendancePrintDay({
    required this.day,
    required this.workingIn,
    required this.workingOut,
    required this.morningIn,
    required this.morningOut,
    required this.afternoonIn,
    required this.afternoonOut,
    required this.eveningIn,
    required this.eveningOut,
    required this.status,
    required this.workMinutes,
    required this.breakMinutes,
    required this.netMinutes,
    required this.overtimeMinutes,
    required this.lateMinutes,
    this.assignedNetMinutes,
    this.isUnpaid = false,
  });

  final int day;
  final String workingIn;
  final String workingOut;
  final String morningIn;
  final String morningOut;
  final String afternoonIn;
  final String afternoonOut;
  final String eveningIn;
  final String eveningOut;
  final String status;
  final int workMinutes;
  final int breakMinutes;
  final int netMinutes;
  final int overtimeMinutes;
  final int lateMinutes;
  final int? assignedNetMinutes;
  final bool isUnpaid;
  bool get countsAsUnpaid =>
      isUnpaid || PayrollCalculationService.isUnpaidAttendanceStatus(status);
}

class AttendancePrintSheet {
  const AttendancePrintSheet(
      {required this.employeeId,
      required this.employeeName,
      required this.department,
      required this.section,
      required this.branchId,
      required this.isForeignEmployee,
      required this.month,
      required this.days,
      this.basicSalary = 0,
      this.payrollBasicSalary,
      this.approvedOtAmount,
      this.lateDeductionAmount,
      this.unpaidDeductionAmount,
      this.estimatedAmounts = false,
      this.deductionMinutes});
  final String employeeId, employeeName, department, section, branchId;
  final bool isForeignEmployee, estimatedAmounts;
  final DateTime month;
  final List<AttendancePrintDay> days;
  final double basicSalary;
  final double? payrollBasicSalary;
  final int? deductionMinutes;
  final double? approvedOtAmount, lateDeductionAmount, unpaidDeductionAmount;
}

class AttendancePdfService {
  static const _blue = PdfColors.black;
  static const _red = PdfColors.black;
  static const _ink = PdfColors.black;
  static const _paleBlue = PdfColors.white;
  static const _paleRed = PdfColors.white;

  static Future<Uint8List> build({
    required String employeeId,
    required String employeeName,
    required String department,
    required String section,
    required String branchId,
    required bool isForeignEmployee,
    required DateTime month,
    required List<AttendancePrintDay> days,
    bool estimatedAmounts = false,
    int? deductionMinutes,
    double basicSalary = 0,
    double? payrollBasicSalary,
    double? approvedOtAmount,
    double? lateDeductionAmount,
    double? unpaidDeductionAmount,
  }) async {
    return buildBatch([
      AttendancePrintSheet(
        employeeId: employeeId,
        employeeName: employeeName,
        department: department,
        section: section,
        branchId: branchId,
        isForeignEmployee: isForeignEmployee,
        month: month,
        days: days,
        basicSalary: basicSalary,
        payrollBasicSalary: payrollBasicSalary,
        approvedOtAmount: approvedOtAmount,
        lateDeductionAmount: lateDeductionAmount,
        unpaidDeductionAmount: unpaidDeductionAmount,
        estimatedAmounts: estimatedAmounts,
        deductionMinutes: deductionMinutes,
      )
    ]);
  }

  static Future<Uint8List> buildBatch(List<AttendancePrintSheet> sheets) async {
    if (sheets.isEmpty) throw ArgumentError('Select at least one employee.');
    final document = pw.Document();
    document.document.catalog.params['/ViewerPreferences'] = PdfDict.values({
      '/Duplex': const PdfName('/DuplexFlipLongEdge'),
      '/PrintScaling': const PdfName('/None'),
    });
    for (final sheet in sheets) {
      await _append(document, sheet);
    }
    return document.save();
  }

  static Future<void> _append(
      pw.Document document, AttendancePrintSheet sheet) async {
    final employeeId = sheet.employeeId,
        employeeName = sheet.employeeName,
        department = sheet.department,
        section = sheet.section,
        branchId = sheet.branchId;
    final isForeignEmployee = sheet.isForeignEmployee;
    final month = sheet.month;
    // Keep the source's actual worked minutes intact for payroll calculations.
    // Only the attendance display includes paid absence credits.
    final days = sheet.days.map((day) {
      final breaks = AttendanceWorkingRules.breakMinutes(
        isForeignEmployee: isForeignEmployee,
        workMinutes: day.workMinutes,
        actualMinutes: day.breakMinutes,
        status: day.status,
      );
      return AttendancePrintDay(
        day: day.day,
        workingIn: day.workingIn,
        workingOut: day.workingOut,
        morningIn: day.morningIn,
        morningOut: day.morningOut,
        afternoonIn: day.afternoonIn,
        afternoonOut: day.afternoonOut,
        eveningIn: day.eveningIn,
        eveningOut: day.eveningOut,
        status: day.status,
        workMinutes: day.workMinutes,
        breakMinutes: breaks,
        netMinutes: AttendanceNetHours.displayMinutes(
          status: day.status,
          actualMinutes: breaks != day.breakMinutes
              ? (day.workMinutes - breaks).clamp(0, 1440).toInt()
              : day.netMinutes,
          assignedMinutes:
              day.assignedNetMinutes ?? (isForeignEmployee ? 630 : 450),
        ),
        overtimeMinutes: AttendanceNetHours.isPaidAbsence(day.status)
            ? 0
            : day.overtimeMinutes,
        lateMinutes: day.lateMinutes,
        assignedNetMinutes: day.assignedNetMinutes,
        isUnpaid: day.isUnpaid,
      );
    }).toList();
    final lateDeductionAmount = sheet.lateDeductionAmount,
        estimatedAmounts = sheet.estimatedAmounts;
    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/hasani_books_logo.jpg');
      logo = pw.MemoryImage(bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      ));
    } catch (_) {}

    final workTotal = days.fold<int>(0, (sum, day) => sum + day.workMinutes);
    final breakTotal = days.fold<int>(0, (sum, day) => sum + day.breakMinutes);
    final netTotal = days.fold<int>(0, (sum, day) => sum + day.netMinutes);
    final otTotal = days.fold<int>(0, (sum, day) => sum + day.overtimeMinutes);
    // Attendance approval controls this printout. A saved payroll amount may
    // predate an Admin override and must not imply approved OT when hours are 0.
    final approvedOtAmount = otTotal > 0 ? sheet.approvedOtAmount : 0.0;
    final bonusDays = PayrollCalculationService.localUnusedOffBonusDays(
        month: month,
        isLocalEmployee: !isForeignEmployee,
        attendance: [
          for (final day in days)
            {
              'attendance_date':
                  DateTime(month.year, month.month, day.day).toIso8601String(),
              'status': day.status,
              'net_working_minutes': day.netMinutes,
            }
        ]);
    final bonusAmount = PayrollCalculationService.localUnusedOffBonusAmount(
        basicSalary: sheet.basicSalary, bonusDays: bonusDays);
    final lateTotal = days.fold<int>(0, (sum, day) => sum + day.lateMinutes);
    // Arrival lateness and net-work shortfall are different measurements.
    // Never infer a deductible shortage from arrival minutes alone.
    final shortfallTotal = sheet.deductionMinutes;
    final unpaidDays = days.where((day) => day.countsAsUnpaid).toList();
    final unpaidTotal = unpaidDays.fold<int>(
        0,
        (sum, day) =>
            sum + (isForeignEmployee ? 630 : day.assignedNetMinutes ?? 450));
    // Use the month-specific saved salary when available. Current defaults are
    // only a fallback; saved payroll amounts are never rewritten by printing.
    final unpaidSalary = sheet.payrollBasicSalary ??
        (sheet.basicSalary > 0 ? sheet.basicSalary : null);
    final calculatedUnpaid = unpaidDays.isEmpty
        ? 0.0
        : unpaidSalary != null && unpaidSalary.isFinite && unpaidSalary >= 0
            ? (PayrollCalculationService.unpaidDailyRate(
                            basicSalary: unpaidSalary, month: month) *
                        unpaidDays.length *
                        100)
                    .round() /
                100.0
            : null;
    final unpaidDeductionAmount =
        calculatedUnpaid ?? sheet.unpaidDeductionAmount;
    final unpaidMismatch = calculatedUnpaid != null &&
        sheet.unpaidDeductionAmount != null &&
        (calculatedUnpaid - sheet.unpaidDeductionAmount!).abs() >= 0.005;
    final offDays =
        days.where((day) => day.status.trim().toUpperCase() == 'OFF').length;
    final assignedTotal = AttendanceWorkingRules.monthlyTarget(
      employeeId: employeeId,
      month: month,
      offDays: offDays,
      isForeignEmployee: isForeignEmployee,
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 20),
        build: (_) => _watermarkedPage(
          logo: logo,
          branchName: branchId,
          content: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(logo, 'WORK ATTENDANCE', month),
              pw.SizedBox(height: 7),
              _employeeInfo(
                  employeeId, employeeName, department, section, branchId),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  _summary('ASSIGNED HOURS', 'Monthly target', assignedTotal,
                      PdfColors.black),
                  pw.SizedBox(width: 5),
                  _summary(
                      'GROSS WORK', 'Check-out - Check-in', workTotal, _blue),
                  pw.SizedBox(width: 5),
                  _summary(
                      'BREAK HOURS', 'All recorded breaks', breakTotal, _red),
                  pw.SizedBox(width: 5),
                  _summary('LATE HOURS', 'Arrival after shift', lateTotal,
                      PdfColors.black),
                  pw.SizedBox(width: 5),
                  _summary(
                    'SHORT HOURS',
                    isForeignEmployee
                        ? 'Exempt from deduction'
                        : shortfallTotal == null
                            ? 'Not calculated'
                            : 'Deductible shortfall',
                    shortfallTotal,
                    PdfColors.black,
                    lateDeductionAmount,
                  ),
                  pw.SizedBox(width: 5),
                  _summary(
                    'UNPAID HOURS',
                    isForeignEmployee
                        ? '10:30 per unpaid day'
                        : 'Assigned unpaid time',
                    unpaidTotal,
                    PdfColors.black,
                    unpaidDeductionAmount,
                  ),
                  pw.SizedBox(width: 5),
                  _summary('NET HOURS', 'Work + paid absence credits', netTotal,
                      _blue),
                  pw.SizedBox(width: 5),
                  _summary(
                    'APPROVED OT',
                    'Authorized overtime only',
                    otTotal,
                    PdfColors.black,
                    approvedOtAmount,
                  ),
                ],
              ),
              if (unpaidDays.isNotEmpty || unpaidMismatch)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Text(
                    calculatedUnpaid == null
                        ? 'Unpaid deduction cannot be verified: basic salary is unavailable. The displayed RM amount is from saved payroll.'
                        : 'Unpaid RM: ${unpaidDays.length} unpaid day(s), basic salary / calendar days. '
                            '${sheet.payrollBasicSalary == null ? "Current salary default estimate. " : "Saved payroll salary basis. "}'
                            '${unpaidMismatch ? "Current attendance estimate: RM ${calculatedUnpaid.toStringAsFixed(2)}; saved payroll deduction: RM ${sheet.unpaidDeductionAmount!.toStringAsFixed(2)}. Review and save payroll to apply the correction. " : ""}'
                            'Printing does not change payroll.',
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                ),
              if (isForeignEmployee)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Text(
                    'FRN worked days: recorded breaks below 01:00 count as 01:30 for net hours.',
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                ),
              if (bonusDays > 0)
                pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 5),
                    child: pw.Text(
                        'Unused fifth OFF bonus at normal basic salary / 26'
                        '${sheet.basicSalary > 0 ? " = RM ${bonusAmount.toStringAsFixed(2)}" : ""}. '
                        'Paid through Bonus, separately from the OT amount above. Current attendance entitlement.',
                        style: const pw.TextStyle(fontSize: 6))),
              if (shortfallTotal == 0 && (lateDeductionAmount ?? 0) > 0)
                pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 5),
                    child: pw.Text(
                        'Review saved payroll: the late deduction has no matching deductible shortfall in current attendance.',
                        style: const pw.TextStyle(fontSize: 6))),
              if (otTotal == 0 && (sheet.approvedOtAmount ?? 0) > 0)
                pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 5),
                    child: pw.Text(
                        'Review saved payroll: its OT amount has no matching approved OT in current attendance. Payroll has not been changed.',
                        style: const pw.TextStyle(fontSize: 6))),
              if (lateTotal == 0 && (shortfallTotal ?? 0) > 0)
                pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 5),
                    child: pw.Text(
                        'No late arrivals. Short hours are net-work shortfall, including eligible excess breaks or early checkout.',
                        style: const pw.TextStyle(fontSize: 6))),
              if (estimatedAmounts)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Text(
                    'RM values are estimates from current attendance and salary defaults; payroll has not been saved.',
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                ),
              pw.SizedBox(height: 8),
              _workTable(days),
              pw.Spacer(),
              _signatures(),
              _pageFooter(1, 'Front - Work attendance and monthly totals'),
            ],
          ),
        ),
      ),
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 20),
        build: (_) => _watermarkedPage(
          logo: logo,
          branchName: branchId,
          content: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(logo, 'BREAK ATTENDANCE', month),
              pw.SizedBox(height: 7),
              _employeeInfo(
                  employeeId, employeeName, department, section, branchId),
              pw.SizedBox(height: 8),
              _breakTable(days),
              pw.Spacer(),
              _signatures(),
              _pageFooter(2, 'Back - Morning, afternoon and evening breaks'),
            ],
          ),
        ),
      ),
    );
  }

  static pw.Widget _header(pw.MemoryImage? logo, String title, DateTime month) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 7),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.2)),
      ),
      child: pw.Row(
        children: [
          if (logo != null)
            pw.Container(
                width: 92,
                height: 40,
                child: pw.Image(logo, fit: pw.BoxFit.contain))
          else
            pw.SizedBox(width: 92),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('HASANI EDAR SDN BHD',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink)),
                pw.SizedBox(height: 2),
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: title.startsWith('BREAK') ? _red : _blue)),
              ],
            ),
          ),
          pw.Text(DateFormat('MMMM yyyy').format(month),
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
        ],
      ),
    );
  }

  static pw.Widget _watermarkedPage({
    required pw.MemoryImage? logo,
    required String branchName,
    required pw.Widget content,
  }) {
    return pw.Stack(
      children: [
        content,
        pw.Positioned(
          left: 45,
          right: 45,
          top: 245,
          child: pw.Center(
            child: pw.Transform.rotate(
              angle: -.42,
              child: pw.Opacity(
                opacity: .065,
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    if (logo != null)
                      pw.Image(logo, width: 260, fit: pw.BoxFit.contain)
                    else
                      pw.Text(
                        'HASANI BOOKS',
                        style: pw.TextStyle(
                          fontSize: 34,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 7,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.black,
                          width: 1.5,
                        ),
                      ),
                      child: pw.Text(
                        branchName.trim().isEmpty
                            ? 'BRANCH'
                            : branchName.toUpperCase(),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2.5,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _employeeInfo(String id, String name, String department,
      String section, String branch) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: PdfColors.black, width: .6)),
      child: pw.Row(children: [
        _info('EMPLOYEE', name),
        _info('EMPLOYEE ID', id),
        _info('DEPARTMENT', department),
        _info('SECTION', section),
        _info('BRANCH', branch),
      ]),
    );
  }

  static pw.Widget _info(String label, String value) => pw.Expanded(
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 5.5,
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(value.trim().isEmpty ? '-' : value,
                  maxLines: 1,
                  style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink)),
            ]),
      );

  static pw.Widget _summary(
          String label, String description, int? minutes, PdfColor color,
          [double? amount]) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: color, width: .7)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 5.5,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
                pw.SizedBox(height: 1),
                pw.Text(description,
                    maxLines: 1,
                    style: const pw.TextStyle(
                        fontSize: 4.5, color: PdfColors.black)),
                pw.SizedBox(height: 2),
                pw.Text(minutes == null ? '--:--' : _duration(minutes),
                    maxLines: 1,
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
                if (amount != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('RM ${amount.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: color)),
                ],
              ]),
        ),
      );

  static pw.Widget _workTable(List<AttendancePrintDay> days) {
    const widths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(27),
      1: pw.FlexColumnWidth(1),
      2: pw.FlexColumnWidth(1),
      3: pw.FlexColumnWidth(1),
      4: pw.FlexColumnWidth(1),
      5: pw.FlexColumnWidth(1),
      6: pw.FlexColumnWidth(1),
      7: pw.FlexColumnWidth(1),
      8: pw.FlexColumnWidth(1.35),
    };
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: .45),
      columnWidths: widths,
      children: [
        _row([
          'DAY',
          'CHECK IN',
          'CHECK OUT',
          'WORK',
          'BREAK',
          'NET',
          'OT',
          'STATUS'
        ], headerColor: _paleBlue, textColor: _blue),
        ...days.map((d) => _row([
              d.day.toString(),
              _value(d.workingIn),
              _value(d.workingOut),
              _duration(d.workMinutes),
              _duration(d.breakMinutes),
              _duration(d.netMinutes),
              _duration(d.overtimeMinutes),
              _value(d.status),
            ])),
      ],
    );
  }

  static pw.Widget _breakTable(List<AttendancePrintDay> days) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: .45),
      columnWidths: const {
        0: pw.FixedColumnWidth(25),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1),
        5: pw.FlexColumnWidth(1),
        6: pw.FlexColumnWidth(1),
        7: pw.FlexColumnWidth(1.1),
      },
      children: [
        _row([
          'DAY',
          'MORNING IN',
          'MORNING OUT',
          'AFTERNOON IN',
          'AFTERNOON OUT',
          'EVENING IN',
          'EVENING OUT',
          'TOTAL BREAK'
        ], headerColor: _paleRed, textColor: _red),
        ...days.map((d) => _row([
              d.day.toString(),
              _value(d.morningIn),
              _value(d.morningOut),
              _value(d.afternoonIn),
              _value(d.afternoonOut),
              _value(d.eveningIn),
              _value(d.eveningOut),
              _duration(d.breakMinutes),
            ])),
      ],
    );
  }

  static pw.TableRow _row(List<String> values,
          {PdfColor? headerColor, PdfColor textColor = _ink}) =>
      pw.TableRow(
        decoration:
            headerColor == null ? null : pw.BoxDecoration(color: headerColor),
        children: values
            .map((value) => pw.Container(
                  height: headerColor == null ? 15.2 : 20,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(value,
                      maxLines: 1,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: headerColor == null ? 6.1 : 5.6,
                          fontWeight: headerColor == null
                              ? pw.FontWeight.normal
                              : pw.FontWeight.bold,
                          color: textColor)),
                ))
            .toList(),
      );

  static pw.Widget _signatures() => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 7),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('PREPARED BY: ____________________',
                  style: const pw.TextStyle(fontSize: 6.5)),
              pw.Text('CHECKED BY: ____________________',
                  style: const pw.TextStyle(fontSize: 6.5)),
              pw.Text('EMPLOYEE: ____________________',
                  style: const pw.TextStyle(fontSize: 6.5)),
            ]),
      );

  static pw.Widget _pageFooter(int page, String label) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.black)),
          pw.Text('Page $page of 2',
              style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.black)),
        ],
      );

  static String _value(String value) =>
      value.trim().isEmpty ? '-' : value.trim();
  static String _duration(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}
