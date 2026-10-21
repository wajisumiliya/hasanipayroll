import 'package:flutter/material.dart';

/// Keeps complete currency values readable on narrow Android screens.
class PayrollYearSummary extends StatelessWidget {
  const PayrollYearSummary({
    super.key,
    required this.year,
    required this.gross,
    required this.deductions,
    required this.net,
  });

  final int year;
  final String gross;
  final String deductions;
  final String net;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
        final minimumWidth = 270 * textScale.clamp(1.0, 2.0);
        final columns = ((constraints.maxWidth + 10) / (minimumWidth + 10))
            .floor()
            .clamp(1, 4);
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _item(width, Icons.calendar_today_outlined, 'Year', '$year',
                const Color(0xFF0B347C)),
            _item(width, Icons.payments_outlined, 'Gross', gross,
                const Color(0xFF214E7A)),
            _item(width, Icons.remove_circle_outline, 'Year Deduction',
                deductions, const Color(0xFF52657B)),
            _item(width, Icons.account_balance_wallet_outlined, 'Year Net', net,
                const Color(0xFF08255F)),
          ],
        );
      },
    );
  }

  Widget _item(
      double width, IconData icon, String label, String value, Color color) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFE8EEF6)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD1DBE7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2208255F),
              blurRadius: 9,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: color.withValues(alpha: .13),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.black54, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    softWrap: true,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
