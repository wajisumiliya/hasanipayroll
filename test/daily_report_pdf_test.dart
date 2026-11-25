import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/daily_report_pdf_service.dart';

import 'attendance_pdf_summary_test.dart' show pdfContents;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'long multiline narratives print completely on a single A4 page',
    () async {
      final crew = List.generate(
        8,
        (index) =>
            'TASK${index + 1} Staff cleaned the counter, arranged stationery, '
            'checked prices and stock, and prepared customer orders. '
            'Completed all assigned work for the department. END${index + 1}',
      ).join('\n\n');
      final bytes = await DailyReportPdfService.build({
        'branch_id': 'LANGKAWI',
        'report_date': '2026-11-24',
        'report_crew': crew,
        'maintenance_report': '$crew\nMAINTENANCE_COMPLETE',
        'recommendation': '$crew\nRECOMMENDATION_COMPLETE',
      });
      final contents = pdfContents(bytes);
      for (var index = 1; index <= 8; index++) {
        expect(contents, contains('TASK$index'));
        expect(contents, contains('END$index'));
      }
      expect(contents, contains('MAINTENANCE_COMPLETE'));
      expect(contents, contains('RECOMMENDATION_COMPLETE'));
      expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)),
          hasLength(1));
      final output = Platform.environment['DAILY_REPORT_REVIEW_PDF'];
      if (output != null) await File(output).writeAsBytes(bytes);
    },
  );
}
