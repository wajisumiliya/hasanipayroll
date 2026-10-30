import 'package:flutter/material.dart';

class PremiumPortalSidebarItem {
  const PremiumPortalSidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
}

/// Shared high-contrast navigation for the admin, branch, and employee portals.
class PremiumPortalSidebar extends StatelessWidget {
  const PremiumPortalSidebar({
    super.key,
    required this.portalLabel,
    required this.profileName,
    required this.profileDetail,
    required this.profileIcon,
    this.profileImageAsset,
    required this.items,
    required this.onLogout,
    this.referenceDashboardStyle = false,
  });

  final String portalLabel;
  final String profileName;
  final String profileDetail;
  final IconData profileIcon;
  final String? profileImageAsset;
  final List<PremiumPortalSidebarItem> items;
  final VoidCallback onLogout;
  final bool referenceDashboardStyle;

  static const _navy = Color(0xFF08111F);
  static const _navyLight = Color(0xFF111D2E);
  static const _gold = Color(0xFFF5C451);
  static const _goldDark = Color(0xFFD9A62E);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: referenceDashboardStyle ? 210 : 265,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_navyLight, _navy],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: CustomPaint(
                size: Size(100, 205),
                painter: _GoldAccentPainter(),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  referenceDashboardStyle ? 10 : 18,
                  referenceDashboardStyle ? 14 : 22,
                  referenceDashboardStyle ? 10 : 18,
                  14),
              child: Column(
                children: [
                  _logo(),
                  SizedBox(height: referenceDashboardStyle ? 14 : 25),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, index) => _menuItem(items[index]),
                    ),
                  ),
                  if (!referenceDashboardStyle) _profile(),
                  const SizedBox(height: 14),
                  if (!referenceDashboardStyle)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout_rounded, size: 19),
                        label: const Text('Logout',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _gold,
                          side: const BorderSide(color: _goldDark, width: 1.2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() => Column(
        children: [
          Container(
            padding: EdgeInsets.all(referenceDashboardStyle ? 5 : 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset('assets/hasani_books_logo.jpg',
                width: referenceDashboardStyle ? 170 : 176,
                errorBuilder: (context, error, stackTrace) => const Text(
                    'HASANI BOOKS',
                    style: TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 18))),
          ),
          SizedBox(height: referenceDashboardStyle ? 5 : 10),
          Text(
              referenceDashboardStyle
                  ? 'PEOPLE  •  PAYROLL  •  PROGRESS'
                  : portalLabel.toUpperCase(),
              style: TextStyle(
                  color: _gold,
                  fontSize: 8,
                  letterSpacing: referenceDashboardStyle ? .7 : 2.2,
                  fontWeight: FontWeight.w800)),
        ],
      );

  Widget _menuItem(PremiumPortalSidebarItem item) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: referenceDashboardStyle ? 42 : 48,
            padding: EdgeInsets.symmetric(
                horizontal: referenceDashboardStyle ? 11 : 14),
            decoration: BoxDecoration(
              gradient: item.selected
                  ? (referenceDashboardStyle
                      ? const LinearGradient(
                          colors: [Color(0xFF2382F7), Color(0xFF075DCE)])
                      : const LinearGradient(colors: [_gold, _goldDark]))
                  : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: item.selected
                  ? const [BoxShadow(color: Color(0x35F5C451), blurRadius: 14)]
                  : null,
            ),
            child: Row(children: [
              SizedBox(
                  width: referenceDashboardStyle ? 22 : 32,
                  height: referenceDashboardStyle ? 22 : 32,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: referenceDashboardStyle
                          ? null
                          : item.selected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFFF4B8),
                                    Color(0xFFFFD85A)
                                  ],
                                )
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF28B6FF),
                                    Color(0xFF0754D8)
                                  ],
                                ),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: item.selected
                            ? const Color(0x66FFFFFF)
                            : const Color(0x554EDBFF),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: item.selected
                              ? const Color(0x55F5C451)
                              : const Color(0x660A78FF),
                          blurRadius: item.selected ? 8 : 11,
                          spreadRadius: item.selected ? 0 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      item.icon,
                      color: Colors.white,
                      size: referenceDashboardStyle ? 18 : 20,
                    ),
                  )),
              const SizedBox(width: 11),
              Expanded(
                child: Text(item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          item.selected ? FontWeight.w800 : FontWeight.w600,
                    )),
              ),
              if (item.selected)
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ]),
          ),
        ),
      );

  Widget _profile() => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _navyLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          Container(
            width: 39,
            height: 39,
            decoration: const BoxDecoration(
                color: Color(0x1AFFFFFF), shape: BoxShape.circle),
            child: profileImageAsset == null
                ? Icon(profileIcon, color: _gold, size: 20)
                : Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(profileImageAsset!, fit: BoxFit.contain),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(profileDetail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFFAAB4C3), fontSize: 11)),
            ]),
          ),
        ]),
      );
}

class _GoldAccentPainter extends CustomPainter {
  const _GoldAccentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x55F5C451)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(
        Path()
          ..moveTo(size.width, 8)
          ..lineTo(30, 105)
          ..lineTo(size.width, 72),
        paint);
    canvas.drawPath(
        Path()
          ..moveTo(size.width, 55)
          ..lineTo(54, 165)
          ..lineTo(size.width, 130),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
