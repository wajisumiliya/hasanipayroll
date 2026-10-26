import 'dart:convert';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/late_report_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LateReportExportData data({int people = 1}) => LateReportExportData(
        month: DateTime(2026, 10),
        branchLabel: 'ALOR SETAR',
        branchNames: {'A': 'ALOR SETAR'},
        reports: List.generate(
            people,
            (i) => {
                  'branch_id': 'A',
                  'employee_id': 'E$i',
                  'name': 'Employee $i',
                  'count': 4,
                  'arrival_count': 2,
                  'break_count': 2,
                  'total_minutes': 50,
                  'previous_count': 7,
                  'change': -3,
                  'events': [
                    {
                      'date': '2026-10-01',
                      'type': 'arrival',
                      'scheduled': '09:00',
                      'actual': '09:10',
                      'minutes': 10,
                      'fingerprint': 'new',
                      'review_outdated': true,
                      'review_history': [
                        {
                          'status': 'approved',
                          'reason_code': 'transport',
                          'reason': '=HYPERLINK("example")',
                          'reviewed_by': 'admin1',
                          'reviewed_at': '2026-10-26T01:00:00Z',
                          'event_fingerprint': 'old',
                          'event_snapshot': {'minutes': 5}
                        },
                      ]
                    },
                    {
                      'date': '2026-10-02',
                      'type': 'break',
                      'allocated_minutes': 60,
                      'actual_minutes': 80,
                      'minutes': 20,
                      'review': {
                        'status': 'noted',
                        'reason_code': 'other',
                        'reason': 'Manager reviewed',
                        'reviewed_by': 'admin2',
                        'reviewed_at': '2026-10-26T02:00:00Z'
                      }
                    },
                  ]
                }),
        missing: [
          {
            'branch_id': 'A',
            'employee_id': 'E9',
            'name': 'Employee 9',
            'date': '2026-10-03',
            'issues': ['Missing roster']
          }
        ],
        previousMissing: [
          {
            'branch_id': 'A',
            'employee_id': 'E9',
            'name': 'Employee 9',
            'date': '2026-09-03',
            'issues': ['Missing check-in']
          }
        ],
      );
  test(
      'Excel includes summary, timings, audit history and incomplete records as literal cells',
      () {
    final book = xls.Excel.decodeBytes(LateReportExportService.excel(data()));
    expect(
        book.tables.keys,
        containsAll(
            ['Summary', 'Events', 'Incomplete records', 'Review history']));
    final events = book['Events'].rows;
    expect(events.length, 3);
    expect(events[1][0]!.value.toString(), 'ALOR SETAR');
    expect(events[1][8]!.value.toString(), 'Needs re-review');
    expect(events[2][10]!.value.toString(), 'Manager reviewed');
    expect(book['Incomplete records'].rows.length, 3);
    final note = book['Review history'].rows[1][7]!.value;
    expect(note, isA<xls.TextCellValue>());
    expect(note.toString(), '=HYPERLINK("example")');
    expect(book['Summary'].rows.last[8]!.value.toString(), contains('7'));
    expect(
        lateLocalReviewTime('2026-10-26T01:00:00Z'), '26 Oct 2026 09:00 MYT');
  });
  test('PDF generates a multi-page document for a substantial report',
      () async {
    final bytes = await LateReportExportService.pdf(data(people: 50));
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(10000));
  });
  test('empty reports still export valid Excel and PDF', () async {
    final empty = LateReportExportData(
        month: DateTime(2026, 10),
        branchLabel: 'All branches',
        branchNames: {},
        reports: [],
        missing: [],
        previousMissing: []);
    expect(
        xls.Excel.decodeBytes(LateReportExportService.excel(empty))
            .tables['Events']!
            .rows
            .length,
        1);
    expect((await LateReportExportService.pdf(empty)).length, greaterThan(100));
  });
}
