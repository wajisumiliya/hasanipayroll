import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/payroll.dart';

class EmployeeIdentityCard extends StatefulWidget {
  final Employee employee;

  const EmployeeIdentityCard({super.key, required this.employee});

  @override
  State<EmployeeIdentityCard> createState() => _EmployeeIdentityCardState();
}

class _EmployeeIdentityCardState extends State<EmployeeIdentityCard> {
  static const navy = Color(0xFF062D69);
  static const blue = Color(0xFF174CA4);
  static const red = Color(0xFFED1C24);
  static const pale = Color(0xFFEAF4FF);
  static const _screenSecurity =
      MethodChannel('com.hasani.payroll/screen_security');
  static int _visibleSecureCards = 0;

  Employee get employee => widget.employee;
  String get _branch => employee.branchId.trim().isEmpty ? '-' : employee.branchId;
  String get _joining => employee.joiningDate == null
      ? '-'
      : DateFormat('dd MMM yyyy').format(employee.joiningDate!);

  @override
  void initState() {
    super.initState();
    _visibleSecureCards++;
    if (_visibleSecureCards == 1) _setSecureScreen(true);
  }

  Future<void> _setSecureScreen(bool enabled) async {
    try {
      await _screenSecurity.invokeMethod<void>(
        enabled ? 'enableSecureScreen' : 'disableSecureScreen',
      );
    } on MissingPluginException {
      // Screenshot prevention is a native Android capability. Web browsers do
      // not expose an equivalent API and other platforms remain unaffected.
    } on PlatformException {
      // Do not prevent the identity card from rendering if the host platform
      // cannot change its window security state.
    }
  }

  @override
  void dispose() {
    if (_visibleSecureCards > 0) _visibleSecureCards--;
    if (_visibleSecureCards == 0) _setSecureScreen(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = constraints.maxWidth.clamp(280.0, 390.0);
      return Center(
        child: SizedBox(
          width: cardWidth,
          child: _front(),
        ),
      );
    });
  }

  Widget _front() => AspectRatio(
        aspectRatio: .68,
        child: _shell(
          background: const _IdentityFrontBackground(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Column(
              children: [
                _logo(showValues: true),
                const SizedBox(height: 10),
                _portraitPhoto(),
                const SizedBox(height: 10),
                Text(
                  employee.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 20,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  employee.employeeId,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  width: 74,
                  height: 3,
                  margin: const EdgeInsets.only(top: 4, bottom: 10),
                  color: red,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _info(Icons.person_outline, 'Designation', employee.designation),
                          _info(Icons.apartment_outlined, 'Department', employee.department),
                          _info(Icons.location_on_outlined, 'Branch', _branch),
                          _info(Icons.calendar_month_outlined, 'Joining Date', _joining),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 92,
                      child: Column(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: navy),
                            ),
                            child: const Icon(Icons.qr_code_2, color: Colors.black, size: 68),
                          ),
                          const SizedBox(height: 3),
                          Text(employee.employeeId,
                              style: const TextStyle(
                                  color: navy, fontSize: 9, fontWeight: FontWeight.w800)),
                          const Text('Scan to verify',
                              style: TextStyle(color: navy, fontSize: 7)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(height: 8),
                const Text(
                  'HASANI BOOKS SDN BHD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
                const Text(
                  'PEOPLE  •  KNOWLEDGE  •  PROGRESS',
                  style: TextStyle(color: Colors.white70, fontSize: 7, letterSpacing: 1.2),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _back() => AspectRatio(
        aspectRatio: .68,
        child: _shell(
          background: const _IdentityBackBackground(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(25, 18, 25, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _logo(),
                const SizedBox(height: 18),
                const Text('OUR VALUES', style: _sectionStyle),
                const SizedBox(height: 12),
                _value(Icons.menu_book_rounded, 'Knowledge', 'We Learn'),
                _value(Icons.groups_rounded, 'People', 'We Grow'),
                _value(Icons.trending_up_rounded, 'Progress', 'We Achieve'),
                _value(Icons.handshake_outlined, 'Integrity', 'We Always Do the Right Thing'),
                const Divider(height: 20, color: navy),
                const Text('IMPORTANT NOTES', style: _sectionStyle),
                const SizedBox(height: 8),
                _note('1. This digital card is the property of Hasani Books Sdn Bhd.'),
                _note('2. It must be used only for authorised company identification.'),
                _note('3. This employee card is non-transferable.'),
                _note('4. If any information is incorrect, please contact HR.'),
                _note('5. Card access ends when employment with the company ends.'),
                const Spacer(),
                const Row(children: [
                  Icon(Icons.email_outlined, color: navy, size: 18),
                  SizedBox(width: 7),
                  Text('hr@hasanibooks.com', style: TextStyle(color: navy, fontSize: 11)),
                ]),
                const SizedBox(height: 7),
                const Row(children: [
                  Icon(Icons.language, color: navy, size: 18),
                  SizedBox(width: 7),
                  Text('www.hasanibooks.com', style: TextStyle(color: navy, fontSize: 11)),
                ]),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'HASANI BOOKS SDN BHD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _shell({required Widget background, required Widget child}) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: navy.withValues(alpha: .18)),
          boxShadow: [
            BoxShadow(
              color: navy.withValues(alpha: .18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(children: [Positioned.fill(child: background), Positioned.fill(child: child)]),
      );

  Widget _logo({bool showValues = false}) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/hasani_books_logo.jpg',
                  height: 37,
                  cacheWidth: 900,
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'hasani BOOKS',
                    style: TextStyle(color: navy, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                const Text(
                  'Knowledge for a Better Tomorrow',
                  style: TextStyle(color: navy, fontSize: 8.5),
                ),
              ],
            ),
          ),
          if (showValues)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('PEOPLE', style: _miniStyle),
                Text('KNOWLEDGE', style: _miniStyle),
                Text('PROGRESS', style: _miniStyle),
              ],
            ),
        ],
      );

  Widget _portraitPhoto() {
    Widget fallback() {
      final initial = employee.name.trim().isEmpty
          ? '?'
          : employee.name.trim().substring(0, 1).toUpperCase();
      return Container(
        color: pale,
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(color: navy, fontSize: 62, fontWeight: FontWeight.w900),
        ),
      );
    }

    return Container(
      width: 165,
      height: 150,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: navy, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: .15),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: employee.photoUrl.trim().isEmpty
            ? fallback()
            : Image.network(
                employee.photoUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => fallback(),
              ),
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(width: 35, child: Icon(icon, color: navy, size: 23)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: navy.withValues(alpha: .60), fontSize: 10)),
              Text(
                value.trim().isEmpty ? '-' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: navy, fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ]),
          ),
        ]),
      );

  Widget _verification() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .93),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(children: [
          const Icon(Icons.qr_code_2_rounded, color: navy, size: 30),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DIGITAL EMPLOYEE CARD',
                  style: TextStyle(color: navy, fontSize: 10, fontWeight: FontWeight.w900)),
              Text(employee.employeeId,
                  style: TextStyle(color: navy.withValues(alpha: .65), fontSize: 10)),
            ]),
          ),
          const Icon(Icons.verified, color: Color(0xFF16A34A), size: 25),
        ]),
      );

  Widget _value(IconData icon, String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 13)),
              Text(subtitle, style: TextStyle(color: navy.withValues(alpha: .7), fontSize: 11)),
            ]),
          ),
        ]),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text, style: TextStyle(color: navy.withValues(alpha: .88), fontSize: 10.5)),
      );

  static const _sectionStyle = TextStyle(
    color: blue,
    fontSize: 14,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
  );
  static const _miniStyle = TextStyle(
    color: Colors.white,
    fontSize: 8,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
  );
}

class _IdentityFrontBackground extends StatelessWidget {
  const _IdentityFrontBackground();

  @override
  Widget build(BuildContext context) => Stack(children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF7FBFF), Color(0xFFEAF4FF)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          right: -70,
          top: -80,
          child: Transform.rotate(
            angle: -.45,
            child: Container(
              width: 205,
              height: 225,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF062D69), Color(0xFF174CA4)]),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
        ),
        Positioned(
          left: -80,
          right: -20,
          bottom: -45,
          child: Container(
            height: 120,
            decoration: const BoxDecoration(
              color: Color(0xFF062D69),
              borderRadius: BorderRadius.only(topRight: Radius.circular(150)),
            ),
          ),
        ),
        Positioned(
          left: -80,
          right: -10,
          bottom: 76,
          child: Transform.rotate(
            angle: -.08,
            child: Container(height: 8, color: const Color(0xFFED1C24)),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 160,
          child: Icon(Icons.menu_book_rounded,
              size: 300, color: const Color(0xFF174CA4).withValues(alpha: .035)),
        ),
      ]);
}

class _IdentityBackBackground extends StatelessWidget {
  const _IdentityBackBackground();

  @override
  Widget build(BuildContext context) => Stack(children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF5FAFF), Color(0xFFE6F2FF)],
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          right: -110,
          top: 150,
          child: Icon(Icons.apartment_rounded,
              size: 350, color: const Color(0xFF174CA4).withValues(alpha: .035)),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF062D69), Color(0xFF07418C)]),
            ),
            child: SizedBox(height: 105),
          ),
        ),
      ]);
}
