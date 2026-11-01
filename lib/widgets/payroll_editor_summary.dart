import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PayrollEditorSummary extends StatelessWidget {
  const PayrollEditorSummary(
      {super.key,
      required this.earnings,
      required this.deductions,
      required this.net});
  final double earnings, deductions, net;
  static const ink = Color(0xFF082E65);
  @override
  Widget build(BuildContext context) {
    String money(double value) =>
        NumberFormat.currency(locale: 'en_MY', symbol: 'RM ', decimalDigits: 2)
            .format(value);
    Widget line(String label, double value, IconData icon, Color color) =>
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ink))),
              Text(money(value),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: ink)),
            ]));
    return Container(
        decoration: BoxDecoration(
            color: const Color(0xFFFAFAFD),
            border: Border.all(color: const Color(0xFFE1E4ED)),
            borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              color: const Color(0xFFF0F0F8),
              padding: const EdgeInsets.all(16),
              child: const Row(children: [
                Icon(Icons.calculate_outlined, color: ink, size: 20),
                SizedBox(width: 9),
                Text('Payroll Summary',
                    style: TextStyle(
                        color: ink, fontSize: 16, fontWeight: FontWeight.w800))
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(15, 3, 15, 15),
              child: Column(children: [
                line('Total Earnings', earnings, Icons.add_circle_outline,
                    const Color(0xFF179C4B)),
                line('Total Deductions', deductions,
                    Icons.remove_circle_outline, const Color(0xFFD03C49)),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE8EFFF),
                        borderRadius: BorderRadius.circular(9)),
                    child: Row(children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 19, color: ink),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text('Net Payroll',
                              style: TextStyle(
                                  color: ink, fontWeight: FontWeight.w800))),
                      Text(money(net),
                          style: const TextStyle(
                              color: ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w900))
                    ])),
              ])),
        ]));
  }
}
