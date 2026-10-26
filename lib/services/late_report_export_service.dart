import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

String lateReviewStatus(dynamic value) => switch (value) {
      'noted' => 'Reviewed',
      'approved' => 'Approved',
      'correction_required' => 'Correction required',
      _ => 'Pending',
    };
String lateReasonLabel(dynamic value) => switch (value) {
      'transport' => 'Transport delay',
      'approved_late' => 'Approved late arrival / break',
      'attendance_error' => 'Incorrect attendance',
      _ => 'Other',
    };
String lateSeverityLabel(int count) => count >= 7
    ? 'High'
    : count >= 5
        ? 'Medium'
        : 'Low';
String lateLocalReviewTime(dynamic value) {
  final time = DateTime.tryParse('$value');
  return time == null
      ? '-'
      : '${DateFormat('dd MMM yyyy HH:mm').format(time.toUtc().add(const Duration(hours: 8)))} MYT';
}

class LateReportExportData {
  const LateReportExportData(
      {required this.month,
      required this.branchLabel,
      required this.branchNames,
      required this.reports,
      required this.missing,
      required this.previousMissing});
  final DateTime month;
  final String branchLabel;
  final Map<String, String> branchNames;
  final List<Map<String, dynamic>> reports, missing, previousMissing;
  String branch(dynamic id) => branchNames['$id'.toUpperCase()] ?? '$id';
  int total(String field) =>
      reports.fold(0, (sum, r) => sum + (r[field] as num).toInt());
  String get comparisonNote => previousMissing.isEmpty
      ? 'Previous-month comparison uses recorded attendance.'
      : 'Previous month has ${previousMissing.length} incomplete day(s); comparisons may be incomplete.';
  Map<String, List<List<dynamic>>> sheets() => {
        'Summary': [
          [
            'Hasani Books - Late Report',
            DateFormat('MMMM yyyy').format(month),
            branchLabel
          ],
          ['Flagged employees', reports.length],
          ['Late arrivals (flagged employees)', total('arrival_count')],
          ['Exceeded breaks (flagged employees)', total('break_count')],
          ['Excess minutes (flagged employees)', total('total_minutes')],
          ['Incomplete current days', missing.length],
          ['Comparison', comparisonNote],
          [
            'Policy',
            '3+ combined occurrences per employee/branch. Reviews retain original totals.'
          ],
          [
            'Branch',
            'Employee ID',
            'Employee',
            'Severity',
            'Arrivals',
            'Exceeded breaks',
            'Total count',
            'Excess minutes',
            'Previous count',
            'Change'
          ],
          ...reports.map((r) => [
                branch(r['branch_id']),
                r['employee_id'],
                r['name'],
                lateSeverityLabel(r['count']),
                r['arrival_count'],
                r['break_count'],
                r['count'],
                r['total_minutes'],
                r['previous_count'] ?? 0,
                r['change'] ?? r['count']
              ]),
        ],
        'Events': [
          [
            'Branch',
            'Employee ID',
            'Employee',
            'Date',
            'Issue',
            'Scheduled / allowed',
            'Actual / used',
            'Excess minutes',
            'Review status',
            'Reason category',
            'Reason',
            'Reviewed by',
            'Reviewed at (MYT)'
          ],
          for (final r in reports)
            for (final e in r['events'] as List)
              [
                branch(r['branch_id']),
                r['employee_id'],
                r['name'],
                e['date'],
                e['type'] == 'arrival' ? 'Late arrival' : 'Break exceeded',
                e['type'] == 'arrival'
                    ? e['scheduled']
                    : '${e['allocated_minutes']} min',
                e['type'] == 'arrival'
                    ? e['actual']
                    : '${e['actual_minutes']} min',
                e['minutes'],
                e['review_outdated'] == true
                    ? 'Needs re-review'
                    : lateReviewStatus(e['review']?['status']),
                e['review'] == null
                    ? ''
                    : lateReasonLabel(e['review']['reason_code']),
                e['review']?['reason'] ?? '',
                e['review']?['reviewed_by'] ?? '',
                lateLocalReviewTime(e['review']?['reviewed_at']),
              ],
        ],
        'Incomplete records': [
          [
            'Period',
            'Branch',
            'Employee ID',
            'Employee',
            'Date',
            'Missing / invalid details'
          ],
          for (final r in missing)
            [
              'Current',
              branch(r['branch_id']),
              r['employee_id'],
              r['name'],
              r['date'],
              (r['issues'] as List).join('; ')
            ],
          for (final r in previousMissing)
            [
              'Previous',
              branch(r['branch_id']),
              r['employee_id'],
              r['name'],
              r['date'],
              (r['issues'] as List).join('; ')
            ],
        ],
        'Review history': [
          [
            'Branch',
            'Employee ID',
            'Employee',
            'Event date',
            'Issue',
            'Status',
            'Category',
            'Reason',
            'Reviewer',
            'Reviewed at (MYT)',
            'Reviewed excess minutes',
            'Applies to current timing'
          ],
          for (final r in reports)
            for (final e in r['events'] as List)
              for (final h in e['review_history'] as List? ?? [])
                [
                  branch(r['branch_id']),
                  r['employee_id'],
                  r['name'],
                  e['date'],
                  e['type'],
                  lateReviewStatus(h['status']),
                  lateReasonLabel(h['reason_code']),
                  h['reason'],
                  h['reviewed_by'],
                  lateLocalReviewTime(h['reviewed_at']),
                  h['event_snapshot']?['minutes'] ?? '',
                  h['event_fingerprint'] == e['fingerprint'] ? 'Yes' : 'No',
                ],
        ],
      };
}

class LateReportExportService {
  static Uint8List excel(LateReportExportData data) {
    final book = xls.Excel.createExcel();
    final initial = book.getDefaultSheet();
    for (final entry in data.sheets().entries) {
      final sheet = book[entry.key];
      for (final row in entry.value) {
        sheet.appendRow(row
            .map((v) => v is num
                ? xls.DoubleCellValue(v.toDouble())
                : xls.TextCellValue('${v ?? ''}'))
            .toList());
      }
    }
    if (initial != null && !data.sheets().containsKey(initial)) {
      book.delete(initial);
    }
    final bytes = book.encode();
    if (bytes == null) throw StateError('Unable to generate Excel report.');
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> pdf(LateReportExportData data) async {
    final regular = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final bold = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    final doc = pw.Document(
        theme: pw.ThemeData.withFont(
            base: pw.Font.ttf(regular), bold: pw.Font.ttf(bold)));
    final sheets = data.sheets();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 1000,
      margin: const pw.EdgeInsets.all(28),
      footer: (context) => pw.Text(
          'Hasani Books | ${DateFormat('MMMM yyyy').format(data.month)} | ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8)),
      build: (_) => [
        pw.Text('Late Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.Text(
            '${DateFormat('MMMM yyyy').format(data.month)} | ${data.branchLabel}'),
        pw.SizedBox(height: 10),
        pw.Text(
            '${data.reports.length} flagged employees | ${data.total('arrival_count')} late arrivals | ${data.total('break_count')} exceeded breaks | ${data.total('total_minutes')} excess minutes'),
        pw.Text(
            '3+ combined occurrences per employee/branch. Totals include all recorded events, including approved events.',
            style: const pw.TextStyle(fontSize: 9)),
        pw.Text(data.comparisonNote, style: const pw.TextStyle(fontSize: 9)),
        if (data.missing.isNotEmpty)
          pw.Text(
              '${data.missing.length} current day(s) are incomplete. See incomplete records below.',
              style:
                  const pw.TextStyle(fontSize: 9, color: PdfColors.orange800)),
        for (final r in data.reports) ...[
          pw.SizedBox(height: 14),
          pw.Text(
              '${data.branch(r['branch_id'])} | ${r['name']} (${r['employee_id']})',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(
              '${lateSeverityLabel(r['count'])} severity | ${r['count']} this month / ${r['previous_count'] ?? 0} previous month | ${r['total_minutes']} excess minutes',
              style: const pw.TextStyle(fontSize: 9)),
          pw.TableHelper.fromTextArray(
              headers: const [
                'Date',
                'Issue',
                'Scheduled / allowed',
                'Actual / used',
                'Excess',
                'Review'
              ],
              data: [
                for (final e in r['events'] as List)
                  [
                    e['date'],
                    e['type'] == 'arrival' ? 'Late arrival' : 'Break exceeded',
                    e['type'] == 'arrival'
                        ? e['scheduled']
                        : '${e['allocated_minutes']} min',
                    e['type'] == 'arrival'
                        ? e['actual']
                        : '${e['actual_minutes']} min',
                    '${e['minutes']} min',
                    e['review_outdated'] == true
                        ? 'Needs re-review'
                        : lateReviewStatus(e['review']?['status'])
                  ]
              ],
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle:
                  pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          for (final e in r['events'] as List)
            for (final h in e['review_history'] as List? ?? [])
              pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Text(
                      '${e['date']} ${e['type']} | ${lateReviewStatus(h['status'])} | ${lateReasonLabel(h['reason_code'])}: ${h['reason']} | ${h['reviewed_by']} | ${lateLocalReviewTime(h['reviewed_at'])}${h['event_fingerprint'] != e['fingerprint'] ? ' | Previous timing' : ''}',
                      style: const pw.TextStyle(fontSize: 8))),
        ],
        if (data.reports.isEmpty)
          pw.Text('No employees meet the monthly threshold.'),
        pw.SizedBox(height: 16),
        pw.Text('Incomplete records',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        if (data.missing.isEmpty && data.previousMissing.isEmpty)
          pw.Text('No incomplete saved attendance records found.'),
        if (data.missing.isNotEmpty || data.previousMissing.isNotEmpty)
          pw.TableHelper.fromTextArray(
              headers:
                  sheets['Incomplete records']!.first.map((v) => '$v').toList(),
              data: sheets['Incomplete records']!.skip(1).toList(),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle:
                  pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      ],
    ));
    return doc.save();
  }
}
