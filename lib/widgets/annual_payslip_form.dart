import 'package:flutter/material.dart';
import '../services/annual_payslip_summary.dart';
import '../services/annual_payslip_export.dart';

/// A paper-shaped preview of the supplied annual salary form, scaled as a whole
/// on narrow screens so all twelve months and the welfare section stay together.
class AnnualPayslipForm extends StatelessWidget {
  const AnnualPayslipForm(
      {super.key, required this.summary, required this.name});
  final AnnualPayslipSummary summary;
  final String name;

  Widget table(
      List<String> headers, List<List<String>> rows, List<double> widths) {
    Widget cell(String text, {bool header = false, int column = 0}) =>
        Container(
          constraints: BoxConstraints(minHeight: header ? 40 : 36),
          alignment: column == 2 && headers.length == 4 && !header
              ? Alignment.centerLeft
              : Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(text,
              textAlign: header ? TextAlign.center : null,
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: header ? FontWeight.bold : FontWeight.normal)),
        );
    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        for (var i = 0; i < widths.length; i++) i: FlexColumnWidth(widths[i])
      },
      children: [
        TableRow(children: [
          for (var i = 0; i < headers.length; i++)
            cell(headers[i], header: true, column: i)
        ]),
        for (final row in rows)
          TableRow(children: [
            for (var i = 0; i < row.length; i++) cell(row[i], column: i)
          ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(
              width: 760,
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                            child: Image.asset('assets/hasani_books_logo.jpg',
                                width: 320, height: 65, fit: BoxFit.contain)),
                        Center(
                            child: Text('ANNUAL SALARY YEAR ${summary.year}',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black))),
                        const SizedBox(height: 12),
                        Text('NAME: $name   |   ID: ${summary.employeeId}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black)),
                        const SizedBox(height: 14),
                        table(
                            AnnualPayslipSummary.salaryHeaders,
                            AnnualPayslipExport.salaryRows(summary),
                            [.25, 1.2, 1.2, 1.2, 1.3, 1.45]),
                        const SizedBox(height: 30),
                        Center(
                            child: Text(
                                'WELFARE/GIFT/BONUS YEAR ${summary.year}',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black))),
                        const SizedBox(height: 18),
                        table(
                            AnnualPayslipSummary.bonusHeaders,
                            AnnualPayslipExport.bonusRows(summary),
                            [.25, 1.2, 3.7, 1.45]),
                      ],
                    )),
              )),
        ),
      );
}
