import 'package:flutter/material.dart';

import 'employee_photo.dart';

class EmployeeProfileDetails extends StatelessWidget {
  const EmployeeProfileDetails({
    super.key,
    required this.employee,
    this.photoActions,
    this.photoBusy = false,
    this.showSummary = true,
  });

  final Map<String, dynamic> employee;
  final Widget? photoActions;
  final bool photoBusy;
  final bool showSummary;

  static const navy = Color(0xFF062D69);
  static const blue = Color(0xFF1769D2);

  String value(String key, [String fallback = '-']) {
    final result = employee[key]?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  bool get active =>
      employee['is_active'] == true ||
      employee['is_active']?.toString().toLowerCase() == 'true';

  String get category => employee['is_management_staff'] == true
      ? 'Management Staff'
      : employee['is_temp_staff'] == true
          ? 'Temporary Staff'
          : employee['is_support_staff'] == true
              ? 'Support Staff'
              : employee['is_other_staff'] == true
                  ? 'Other Staff'
                  : 'Regular Staff';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showSummary) _summary(),
          if (photoActions != null) ...[
            const SizedBox(height: 8),
            Center(child: photoActions!),
          ],
          if (photoBusy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 18),
          _tabs(),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 620;
              final width = twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _section(
                      'Personal Information',
                      Icons.person_rounded,
                      const Color(0xFFEAF4FF),
                      [
                        ('Full Name', value('name')),
                        ('IC No.', value('new_ic_no')),
                        ('Email', value('email')),
                        ('Phone', value('phone')),
                        ('Address', value('address')),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _section(
                      'Employment Information',
                      Icons.work_rounded,
                      const Color(0xFFE9F8EE),
                      [
                        ('Employee ID', value('employee_id')),
                        ('Designation', value('designation')),
                        ('Department', value('department')),
                        ('Joining Date', value('joining_date')),
                        ('Employee Category', category),
                        ('Employment Status', active ? 'Active' : 'Inactive'),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _section(
                      'Payroll & Bank Information',
                      Icons.account_balance_rounded,
                      const Color(0xFFFFF5DE),
                      [
                        ('Bank Code', value('bank_code')),
                        ('Bank Account', value('bank_account')),
                        ('EPF No.', value('epf_no')),
                        ('SOCSO No.', value('socso_no')),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _section(
                      'Branch Information',
                      Icons.apartment_rounded,
                      const Color(0xFFEFECFF),
                      [
                        ('Branch', value('branch_id')),
                        (
                          'Payroll Branch',
                          value(
                              'payroll_branch_id', 'Same as attendance branch')
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      );

  Widget _summary() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF4F9FF), Color(0xFFE5F1FF)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFC9DDF7)),
        ),
        child: Row(children: [
          EmployeePhoto(
            name: value('name', 'Employee'),
            photoUrl: employee['photo_url']?.toString(),
            radius: 52,
            borderColor: blue,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('EMPLOYEE',
                      style: TextStyle(
                          color: blue,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                Text(value('name').toUpperCase(),
                    style: const TextStyle(
                        color: navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Wrap(spacing: 12, runSpacing: 6, children: [
                  _summaryItem(Icons.badge_outlined, value('employee_id')),
                  _summaryItem(Icons.work_outline, value('designation')),
                  _statusChip(),
                  _summaryItem(
                      Icons.calendar_month_outlined, value('joining_date')),
                  _summaryItem(Icons.location_on_outlined, value('branch_id')),
                ]),
              ],
            ),
          ),
        ]),
      );

  Widget _tabs() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFD7E1F0))),
        ),
        child: const Row(children: [
          _ProfileTab(Icons.person_rounded, 'Profile', selected: true),
          _ProfileTab(Icons.work_rounded, 'Employment'),
          _ProfileTab(Icons.credit_card_rounded, 'Payroll & Bank'),
          _ProfileTab(Icons.apartment_rounded, 'Branch & Others'),
        ]),
      );

  Widget _section(String title, IconData icon, Color color,
          List<(String, String)> rows) =>
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCE5F2)),
        ),
        child: Column(children: [
          Container(
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(children: [
              Icon(icon, color: navy, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: navy, fontWeight: FontWeight.w900)),
            ]),
          ),
          ...rows.map((row) => _row(row.$1, row.$2)),
        ]),
      );

  Widget _row(String label, String content) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 112,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF69758A),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(content,
                style: const TextStyle(
                    color: navy, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _summaryItem(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: navy, size: 14),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: navy, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _statusChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE1F8E9) : const Color(0xFFFFE7E7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(active ? '● Active' : '● Inactive',
            style: TextStyle(
                color:
                    active ? const Color(0xFF15965D) : const Color(0xFFD94242),
                fontSize: 9,
                fontWeight: FontWeight.w800)),
      );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab(this.icon, this.label, {this.selected = false});
  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: selected
                ? const Border(
                    bottom: BorderSide(color: Color(0xFF1769D2), width: 3))
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 15,
                color: selected
                    ? const Color(0xFF1769D2)
                    : const Color(0xFF68758B)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: selected
                          ? const Color(0xFF1769D2)
                          : const Color(0xFF68758B),
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      );
}
