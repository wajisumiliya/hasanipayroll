import 'package:flutter/material.dart';
import '../services/salary_transfer.dart';

class SalaryTransferField extends StatelessWidget {
  const SalaryTransferField({
    super.key,
    required this.account,
    required this.method,
    required this.onChanged,
    this.enabled = true,
  });

  final TextEditingController account;
  final String method;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: account,
        builder: (context, accountValue, child) {
          final selected = SalaryTransfer.resolve(method, accountValue.text);
          return DropdownButtonFormField<String>(
            key: ValueKey(selected),
            initialValue: selected,
            decoration: const InputDecoration(
              labelText: 'Salary transfer via',
              helperText:
                  'Bank accounts default to RHB. Otherwise choose Instant or Cash.',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                  value: '', child: Text('Select payment method')),
              if (accountValue.text.trim().isNotEmpty)
                const DropdownMenuItem(value: 'rhb', child: Text('RHB')),
              const DropdownMenuItem(value: 'instant', child: Text('Instant')),
              const DropdownMenuItem(value: 'cash', child: Text('Cash')),
            ],
            onChanged: enabled ? (value) => onChanged(value ?? '') : null,
          );
        },
      );
}
