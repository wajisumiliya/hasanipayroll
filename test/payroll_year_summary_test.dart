import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/widgets/payroll_year_summary.dart';

void main() {
  for (final width in [320.0, 360.0, 393.0, 480.0, 768.0, 1200.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('full payroll amounts at width $width and text scale $scale',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(24),
                child: PayrollYearSummary(
                  year: 2026,
                  gross: 'RM 1,234,567.89',
                  deductions: 'RM 869.00',
                  net: 'RM 1,233,698.89',
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final value in ['RM 1,234,567.89', 'RM 1,233,698.89']) {
          final finder = find.text(value);
          expect(finder, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.maxLines, isNull);
          expect(paragraph.overflow, isNot(TextOverflow.ellipsis));
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: value.length),
          );
          expect(boxes, isNotEmpty);
          for (final box in boxes) {
            expect(box.left, greaterThanOrEqualTo(-0.5));
            expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.5));
            expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.5));
          }
        }
      });
    }
  }
}
