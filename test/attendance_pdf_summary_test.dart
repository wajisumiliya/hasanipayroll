import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_pdf_service.dart';

// Inspect actual PDF content streams without requiring a platform PDF reader.
String pdfContents(Uint8List bytes) {
  final source = latin1.decode(bytes), output = StringBuffer(source);
  for (final match
      in RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream').allMatches(source)) {
    try {
      output.writeln(
          latin1.decode(ZLibDecoder().convert(latin1.encode(match[1]!))));
    } on FormatException {/* Image streams may use other filters. */}
  }
  return RegExp(r'\(((?:\\.|[^\\)])*)\)')
      .allMatches(output.toString())
      .map((match) => match[1]!)
      .join(' ');
}

AttendancePrintDay day({int arrival = 0}) => AttendancePrintDay(
    day: 23,
    workingIn: arrival == 0 ? '10:00' : '10:15',
    workingOut: '19:00',
    morningIn: '13:00',
    morningOut: '14:32',
    afternoonIn: '',
    afternoonOut: '',
    eveningIn: '',
    eveningOut: '',
    status: 'Present',
    workMinutes: 540,
    breakMinutes: 92,
    netMinutes: 448,
    overtimeMinutes: 0,
    lateMinutes: arrival);
Future<Uint8List> build({int arrival = 0, int? shortfall, double amount = 0}) =>
    AttendancePdfService.build(
        employeeId: 'HED1016',
        employeeName: 'Sample Employee',
        department: 'Online',
        section: '-',
        branchId: 'SUNGAI PETANI',
        isForeignEmployee: false,
        month: DateTime(2026, 10),
        days: [day(arrival: arrival)],
        deductionMinutes: shortfall,
        lateDeductionAmount: amount);
String block(String pdf, String from, String until) =>
    pdf.substring(pdf.indexOf(from), pdf.indexOf(until, pdf.indexOf(from)));
void main() {
  test(
      'on-time arrival with two-minute excess break prints zero late and separate two-minute shortfall',
      () async {
    final bytes = await build(shortfall: 2);
    final text = pdfContents(bytes);
    final debugOutput = Platform.environment['ATTENDANCE_SUMMARY_REVIEW_PDF'];
    if (debugOutput != null) {
      await File(debugOutput).writeAsBytes(bytes);
    }
    expect(block(text, 'LATE HOURS', 'SHORT HOURS'), contains('00:00'));
    expect(block(text, 'SHORT HOURS', 'UNPAID HOURS'), contains('00:02'));
    expect(block(text, 'LATE HOURS', 'SHORT HOURS'), isNot(contains('(RM ')));
    expect(block(text, 'SHORT HOURS', 'UNPAID HOURS'), contains('RM 0.00'));
    expect(text, contains('No late arrivals.'));
    final output = Platform.environment['ATTENDANCE_SUMMARY_REVIEW_PDF'];
    if (output != null) await File(output).writeAsBytes(bytes);
  });
  test('missing shortfall cannot be inferred from arrival lateness', () async {
    final text = pdfContents(await build(arrival: 15));
    expect(block(text, 'LATE HOURS', 'SHORT HOURS'), contains('00:15'));
    expect(
        block(text, 'SHORT HOURS', 'UNPAID HOURS'), contains('Not calculated'));
    expect(
        block(text, 'SHORT HOURS', 'UNPAID HOURS'), isNot(contains('00:15')));
  });
  test(
      'saved money stays visible against shortfall and mismatches remain flagged',
      () async {
    final text = pdfContents(await build(shortfall: 0, amount: 20));
    expect(block(text, 'LATE HOURS', 'SHORT HOURS'), contains('00:00'));
    expect(block(text, 'SHORT HOURS', 'UNPAID HOURS'), contains('RM 20.00'));
    expect(text, contains('Review saved payroll:'));
  });
}
