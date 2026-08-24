import 'dart:typed_data';

import 'package:flutter/services.dart'
    show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/payroll.dart';

class PdfService {
  static Future<Uint8List> buildPayslip({
    required Employee employee,
    required PayrollRecord p,
  }) async {
    final doc = pw.Document();

    pw.MemoryImage? logo;

    try {
      final logoBytes = await rootBundle.load(
        'assets/hasani_books_logo.jpg',
      );

      logo = pw.MemoryImage(
        logoBytes.buffer.asUint8List(),
      );
    } catch (_) {
      logo = null;
    }

    final monthNames = [
      '',
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];

    final month =
    monthNames[p.period.month];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        build: (_) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment:
                pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'HASANI EDAR SDN BHD',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight:
                            pw.FontWeight.bold,
                          ),
                        ),

                        pw.Text(
                          '199801000949 (457075-U)',
                          style: const pw.TextStyle(
                            fontSize: 8,
                          ),
                        ),

                        pw.SizedBox(height: 8),

                        pw.Text(
                          'NAME : ${employee.name}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                          ),
                        ),

                        pw.Text(
                          'EMPLOYEE ID : ${employee.employeeId}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                          ),
                        ),

                        pw.Text(
                          'DESIGNATION : ${employee.designation}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                          ),
                        ),

                        pw.Text(
                          'DEPARTMENT : ${employee.department}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'NEW IC NO : ${employee.newIcNo}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                          ),
                        ),

                        pw.Text(
                          'BANK CODE : ${employee.bankCode}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                          ),
                        ),

                        pw.Text(
                          'BANK A/C : ${employee.bankAccount}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.Text(
                    'PAYSLIP\n$month ${p.period.year}',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight:
                      pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 15),

              pw.Table(
                border: pw.TableBorder.all(
                  width: 0.7,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(1),
                },
                children: [
                  _row(
                    'GROSS EARNING',
                    'AMOUNT (RM)',
                    'DEDUCTIONS',
                    'AMOUNT (RM)',
                    bold: true,
                  ),

                  _row(
                    'BASIC SALARY',
                    money(p.basicSalary),
                    'EPF (EMPLOYEE)',
                    money(p.epfEmployee),
                  ),

                  _row(
                    'FOOD ALLOWANCE',
                    money(p.foodAllowance),
                    'SOCSO (EMPLOYEE)',
                    money(p.socsoEmployee),
                  ),

                  _row(
                    'OTHER ALLOWANCE',
                    money(p.otherAllowance),
                    'EIS (EMPLOYEE)',
                    money(p.eisEmployee),
                  ),

                  _row(
                    '',
                    '',
                    'PCB',
                    money(p.pcb),
                  ),

                  _row(
                    '',
                    '',
                    'OTHER DEDUCTION',
                    money(p.otherDeduction),
                  ),

                  _row(
                    'TOTAL EARNINGS',
                    money(p.totalEarnings),
                    'TOTAL DEDUCTIONS',
                    money(p.totalDeductions),
                    bold: true,
                  ),

                  _row(
                    'NET PAY',
                    money(p.netPay),
                    'EMPLOYER CONTRIBUTIONS',
                    '',
                    bold: true,
                  ),

                  _row(
                    '',
                    '',
                    'EPF (EMPLOYER)',
                    money(p.epfEmployer),
                  ),

                  _row(
                    '',
                    '',
                    'SOCSO (EMPLOYER)',
                    money(p.socsoEmployer),
                  ),

                  _row(
                    '',
                    '',
                    'EIS (EMPLOYER)',
                    money(p.eisEmployer),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              pw.Row(
                mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment:
                pw.CrossAxisAlignment.end,
                children: [
                  if (logo != null)
                    pw.Image(
                      logo,
                      width: 140,
                    )
                  else
                    pw.Text(
                      'HASANI BOOKS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight:
                        pw.FontWeight.bold,
                      ),
                    ),

                  pw.Column(
                    children: [
                      pw.Container(
                        width: 180,
                        height: 1,
                        color: PdfColors.black,
                      ),

                      pw.SizedBox(height: 5),

                      pw.Text(
                        'Employee Signature',
                        style:
                        const pw.TextStyle(
                          fontSize: 7,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.TableRow _row(
      String leftTitle,
      String leftAmount,
      String rightTitle,
      String rightAmount, {
        bool bold = false,
      }) {
    final style = pw.TextStyle(
      fontSize: 7.5,
      fontWeight: bold
          ? pw.FontWeight.bold
          : pw.FontWeight.normal,
    );

    return pw.TableRow(
      children: [
        _cell(
          leftTitle,
          style,
        ),

        _cell(
          leftAmount,
          style,
          right: true,
        ),

        _cell(
          rightTitle,
          style,
        ),

        _cell(
          rightAmount,
          style,
          right: true,
        ),
      ],
    );
  }

  static pw.Widget _cell(
      String text,
      pw.TextStyle style, {
        bool right = false,
      }) {
    return pw.Padding(
      padding:
      const pw.EdgeInsets.all(5),
      child: pw.Align(
        alignment: right
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: style,
        ),
      ),
    );
  }

  static String money(double value) {
    return value.toStringAsFixed(2);
  }
}