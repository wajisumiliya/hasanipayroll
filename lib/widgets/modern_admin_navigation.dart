import 'package:flutter/material.dart';
import 'premium_portal_sidebar.dart';
import 'modern_admin_overview.dart';

class ModernAdminSidebar extends StatelessWidget {
  const ModernAdminSidebar(
      {super.key,
      required this.items,
      required this.name,
      required this.detail,
      required this.onLogout});
  final List<PremiumPortalSidebarItem> items;
  final String name, detail;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Container(
      width: 232,
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF12345E), Color(0xFF0A2344)])),
      child: Material(
          color: Colors.transparent,
          child: SafeArea(
              child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                child: Column(children: [
                  Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10)),
                      child: Image.asset('assets/hasani_books_logo.jpg',
                          width: 170, height: 40, fit: BoxFit.contain)),
                  const SizedBox(height: 12),
                  const Text('PAYROLL PORTAL',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w600)),
                ])),
            Expanded(
                child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: items
                        .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                                color: item.selected
                                    ? adminBlue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                child: ListTile(
                                    dense: true,
                                    minTileHeight: 43,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    leading: Icon(item.icon,
                                        color: item.selected
                                            ? Colors.white
                                            : const Color(0xFFBDCDE1),
                                        size: 20),
                                    title: Text(item.label,
                                        style: TextStyle(
                                            color: item.selected
                                                ? Colors.white
                                                : const Color(0xFFDCE6F3),
                                            fontSize: 13,
                                            fontWeight: item.selected
                                                ? FontWeight.w700
                                                : FontWeight.w400)),
                                    onTap: item.onTap))))
                        .toList())),
            const Divider(color: Color(0xFF2A4769)),
            ListTile(
                leading: const CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFF4B6687),
                    child: Icon(Icons.person_outline,
                        color: Colors.white, size: 20)),
                title: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                subtitle: Text(detail,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 11))),
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: TextButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, size: 17),
                    label: const Text('Logout'),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.white70))),
          ]))));
}
