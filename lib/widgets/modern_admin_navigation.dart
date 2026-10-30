import 'package:flutter/material.dart';

import 'premium_portal_sidebar.dart';

class ModernAdminSidebar extends StatelessWidget {
  const ModernAdminSidebar({
    super.key,
    required this.items,
    required this.name,
    required this.detail,
    required this.onLogout,
  });
  final List<PremiumPortalSidebarItem> items;
  final String name, detail;
  final VoidCallback onLogout;

  String _sectionFor(String label) {
    if (label == 'Overview') return 'Workspace';
    if ({
      'Employees',
      'Attendance',
      'Late Report',
      'Branch Logs',
    }.contains(label)) {
      return 'Workforce';
    }
    if ({
      'Payroll',
      'Employee Payslips',
      'EA Forms',
      'Edit Payroll',
      'RHB Layout',
    }.contains(label)) {
      return 'Payroll';
    }
    if ({
      'Employee Requests',
      'OT Requests',
      'Leave Requests',
    }.contains(label)) {
      return 'Approvals';
    }
    return 'Management';
  }

  List<Widget> _navigationItems() {
    final children = <Widget>[];
    String? section;
    for (final item in items) {
      final nextSection = _sectionFor(item.label);
      if (section != nextSection) {
        section = nextSection;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 10, 8),
            child: Text(
              nextSection.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF9D8D77),
                fontSize: 9,
                letterSpacing: 1.7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Material(
            color: item.selected ? const Color(0xFF9B7132) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: item.selected
                      ? Border.all(color: const Color(0x55FFF1D2))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: item.selected
                          ? Colors.white
                          : const Color(0xFFD1C5B3),
                      size: 20,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.selected
                              ? Colors.white
                              : const Color(0xFFF0E9DE),
                          fontSize: 12.5,
                          fontWeight:
                              item.selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (item.selected)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE3A7),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return children;
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 252,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF342A21), Color(0xFF191612)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 24,
              offset: Offset(8, 0),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
                  child: Column(
                    children: [
                      Container(
                        height: 54,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: const [
                            BoxShadow(color: Color(0x24000000), blurRadius: 12),
                          ],
                        ),
                        child: Image.asset(
                          'assets/hasani_books_logo.jpg',
                          width: 188,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'PAYROLL  •  COMMAND CENTRE',
                        style: TextStyle(
                          color: Color(0xFFBCAE98),
                          fontSize: 8.5,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: _navigationItems(),
                  ),
                ),
                const Divider(color: Color(0xFF493D2E)),
                ListTile(
                  leading: const CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFF645039),
                    child: Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    detail,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: TextButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, size: 17),
                    label: const Text('Sign out'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      minimumSize: const Size.fromHeight(38),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
