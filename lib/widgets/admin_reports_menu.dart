import 'package:flutter/material.dart';

/// Entry points grouped under Reports in the administrator navigation.
class AdminReportsMenu extends StatelessWidget {
  const AdminReportsMenu({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  static const pages = {10, 13, 11, 14};

  @override
  Widget build(BuildContext context) {
    const destinations = [
      (10, 'Employee Requests', Icons.approval_outlined),
      (13, 'Leave Requests', Icons.flight_outlined),
      (11, 'OT Requests', Icons.more_time_outlined),
      (14, 'Daily Reports', Icons.article_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: destinations.map((destination) {
            return SizedBox(
              width: width,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
                onPressed: () => onNavigate(destination.$1),
                icon: Icon(destination.$3),
                label: Text(destination.$2, textAlign: TextAlign.center),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
