import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnualLeaveBalanceCard extends StatelessWidget {
  const AnnualLeaveBalanceCard({super.key, required this.balance});
  final double? balance;
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDCE6F2))),
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.event_available,
                    color: Color(0xFF1565C0))),
            const SizedBox(width: 14),
            const Expanded(
                child: Text('Annual Leave (AL)',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            Text(
                balance == null
                    ? 'Not set'
                    : '${NumberFormat('0.##').format(balance)} days',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Color(0xFF08255F)))
          ])));
}
