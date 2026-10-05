import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/payroll.dart';
import 'employee_photo.dart';

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
  String get _branch {
    final value = employee.branchId.trim();
    if (value.isEmpty) return '-';
    return value.toUpperCase() == 'SUNGAI PETANI' ? 'SP-EDAR' : value;
  }

  String get _joining => employee.joiningDate == null
      ? '-'
      : DateFormat('dd MMM yyyy').format(employee.joiningDate!);

  String get _dateOfBirth => employee.birthday == null
      ? '-'
      : DateFormat('dd MMM yyyy').format(employee.birthday!);

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
      final cardWidth = constraints.maxWidth.clamp(320.0, 460.0);
      return Center(
        child: SizedBox(
          width: cardWidth,
          child: _horizontalPremiumCard(),
        ),
      );
    });
  }

  Widget _horizontalPremiumCard() => AspectRatio(
        aspectRatio: 1.64,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF090A0C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD6AD5C), width: 2.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
              BoxShadow(
                color: Color(0x55E8C778),
                blurRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _BlackGoldBackground()),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: const Color(0xFFD6AD5C),
                              ),
                            ),
                            child: Image.asset(
                              'assets/hasani_books_logo_card.jpg',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/hasani_books_payslip_logo.jpeg',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _blackGoldPortrait(),
                          const Spacer(),
                          const Text(
                            'HASANI EDAR SDN BHD',
                            style: TextStyle(
                              color: Color(0xFFE8C778),
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFFE8C778),
                                size: 14,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'EMPLOYEE IDENTITY',
                                style: TextStyle(
                                  color: Color(0xFFD6AD5C),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            employee.name.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFF2D38A),
                              fontSize: 19,
                              height: 1.02,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .25,
                            ),
                          ),
                          Container(
                            width: 86,
                            height: 2,
                            margin: const EdgeInsets.only(top: 5, bottom: 7),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFEF233C), Color(0xFFD6AD5C)],
                              ),
                            ),
                          ),
                          _horizontalDetail('Employee ID', employee.employeeId),
                          _horizontalDetail(
                            'Designation',
                            employee.designation.trim().isEmpty
                                ? 'EMPLOYEE'
                                : employee.designation,
                          ),
                          _horizontalDetail('Department', employee.department),
                          _horizontalDetail('Branch', _branch),
                          _horizontalDetail('Joined', _joining),
                          _horizontalDetail(
                            'Date of Birth',
                            _dateOfBirth,
                            valueSize: 10,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111315),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: employee.isActive
                                        ? const Color(0xFF59C984)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: employee.isActive
                                            ? const Color(0xFF59C984)
                                            : const Color(0xFF9CA3AF),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      employee.isActive ? 'ACTIVE' : 'INACTIVE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.2,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .7,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'KNOWLEDGE • PEOPLE • PROGRESS',
                                style: TextStyle(
                                  color: Color(0xFFFFE49A),
                                  fontSize: 7.2,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .35,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xCC000000),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _blackGoldPortrait() => Container(
        width: 114,
        height: 140,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFD6AD5C),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x44000000), blurRadius: 10),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11.5),
          child: EmployeePhotoImage(
            photoUrl: employee.photoUrl,
            fallbackBuilder: (_) => Container(
              color: const Color(0xFFE9EAEC),
              alignment: Alignment.center,
              child: Text(
                employee.name.trim().isEmpty
                    ? '?'
                    : employee.name.trim()[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF17191D),
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _horizontalDetail(
    String label,
    String value, {
    double valueSize = 10,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4.5),
        child: Row(
          children: [
            SizedBox(
              width: 75,
              child: Text(
                label,
                style: TextStyle(
                  color: Color(0xFFC7A85E),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Text(
              ':',
              style: TextStyle(
                color: Color(0xFFD6AD5C),
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value.trim().isEmpty ? '-' : value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFF7F3E8),
                  fontSize: valueSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _badgeFront() => AspectRatio(
        aspectRatio: .62,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              top: 22,
              child: _shell(
                background: const _BadgeFrontBackground(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 22),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/hasani_books_payslip_logo.jpeg',
                        height: 52,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text(
                          'HASANI BOOKS',
                          style: TextStyle(
                            color: navy,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Text(
                        'EMPLOYEE IDENTIFICATION CARD',
                        style: TextStyle(
                          color: navy,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _portraitPhoto(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF123F86), Color(0xFF031C4C)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .18),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                employee.name.toUpperCase(),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .35,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                employee.designation.trim().isEmpty
                                    ? 'EMPLOYEE'
                                    : employee.designation.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFDCEAFF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Container(
                                width: 68,
                                height: 2,
                                margin:
                                    const EdgeInsets.only(top: 6, bottom: 9),
                                color: red,
                              ),
                              _badgeDetail('Employee ID', employee.employeeId),
                              _badgeDetail('Department', employee.department),
                              _badgeDetail('Branch', _branch),
                              _badgeDetail('Joining Date', _joining),
                              _badgeDetail('Mobile', employee.phone),
                              const Spacer(),
                              const Text(
                                'HASANI EDAR SDN BHD',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 7),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              employee.isActive ? red : const Color(0xFF6B7280),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              employee.isActive
                                  ? 'ACTIVE EMPLOYEE'
                                  : 'INACTIVE EMPLOYEE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 84,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFF94A3B8)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                  bottom: Radius.circular(12),
                ),
                border: Border.all(color: const Color(0xFF64748B), width: 3),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 35,
                height: 13,
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _badgeDetail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFCADCFA),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Text(
              ':',
              style: TextStyle(
                color: Color(0xFFED1C24),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.trim().isEmpty ? '-' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

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
                          _info(Icons.person_outline, 'Designation',
                              employee.designation),
                          _info(Icons.apartment_outlined, 'Department',
                              employee.department),
                          _info(Icons.location_on_outlined, 'Branch', _branch),
                          _info(Icons.calendar_month_outlined, 'Joining Date',
                              _joining),
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
                            child: const Icon(Icons.qr_code_2,
                                color: Colors.black, size: 68),
                          ),
                          const SizedBox(height: 3),
                          Text(employee.employeeId,
                              style: const TextStyle(
                                  color: navy,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
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
                  'HASANI EDAR SDN BHD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
                const Text(
                  'PEOPLE  •  KNOWLEDGE  •  PROGRESS',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 7, letterSpacing: 1.2),
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
                _value(Icons.handshake_outlined, 'Integrity',
                    'We Always Do the Right Thing'),
                const Divider(height: 20, color: navy),
                const Text('IMPORTANT NOTES', style: _sectionStyle),
                const SizedBox(height: 8),
                _note(
                    '1. This digital card is the property of Hasani Edar Sdn Bhd.'),
                _note(
                    '2. It must be used only for authorised company identification.'),
                _note('3. This employee card is non-transferable.'),
                _note('4. If any information is incorrect, please contact HR.'),
                _note(
                    '5. Card access ends when employment with the company ends.'),
                const Spacer(),
                const Row(children: [
                  Icon(Icons.email_outlined, color: navy, size: 18),
                  SizedBox(width: 7),
                  Text('hr@hasanibooks.com',
                      style: TextStyle(color: navy, fontSize: 11)),
                ]),
                const SizedBox(height: 7),
                const Row(children: [
                  Icon(Icons.language, color: navy, size: 18),
                  SizedBox(width: 7),
                  Text('www.hasanibooks.com',
                      style: TextStyle(color: navy, fontSize: 11)),
                ]),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'HASANI EDAR SDN BHD',
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

  Widget _shell({required Widget background, required Widget child}) =>
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF94A3B8), width: 3),
          boxShadow: [
            BoxShadow(
              color: navy.withValues(alpha: .28),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
            const BoxShadow(
              color: Color(0x99FFFFFF),
              blurRadius: 2,
              offset: Offset(-2, -2),
            ),
          ],
        ),
        child: Stack(children: [
          Positioned.fill(child: background),
          Positioned.fill(child: child)
        ]),
      );

  Widget _logo({bool showValues = false}) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/hasani_books_logo_card.jpg',
                  height: 37,
                  cacheWidth: 1400,
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/hasani_books_payslip_logo.jpeg',
                    height: 37,
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox(),
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

  Widget _portraitPhoto({double width = 145, double height = 165}) {
    Widget fallback() {
      final initial = employee.name.trim().isEmpty
          ? '?'
          : employee.name.trim().substring(0, 1).toUpperCase();
      return Container(
        color: pale,
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(
              color: navy, fontSize: 62, fontWeight: FontWeight.w900),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
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
        child: EmployeePhotoImage(
          photoUrl: employee.photoUrl,
          fallbackBuilder: (_) => fallback(),
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      color: navy.withValues(alpha: .60), fontSize: 10)),
              Text(
                value.trim().isEmpty ? '-' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: navy, fontSize: 13, fontWeight: FontWeight.w800),
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DIGITAL EMPLOYEE CARD',
                  style: TextStyle(
                      color: navy, fontSize: 10, fontWeight: FontWeight.w900)),
              Text(employee.employeeId,
                  style: TextStyle(
                      color: navy.withValues(alpha: .65), fontSize: 10)),
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
            decoration: BoxDecoration(
                color: pale, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: navy, fontWeight: FontWeight.w900, fontSize: 13)),
              Text(subtitle,
                  style: TextStyle(
                      color: navy.withValues(alpha: .7), fontSize: 11)),
            ]),
          ),
        ]),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text,
            style:
                TextStyle(color: navy.withValues(alpha: .88), fontSize: 10.5)),
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

class _BlackGoldBackground extends StatelessWidget {
  const _BlackGoldBackground();

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF17191D),
                  Color(0xFF090A0C),
                  Color(0xFF12100D),
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            right: -42,
            bottom: -24,
            child: Transform.rotate(
              angle: -.27,
              child: Container(
                width: 190,
                height: 74,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0x00D6AD5C),
                      Color(0xAAE8C778),
                      Color(0xFFD6AD5C),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(80),
                ),
              ),
            ),
          ),
          Positioned(
            right: -18,
            bottom: 9,
            child: Container(
              width: 145,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFEF233C),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 55,
            child: Icon(
              Icons.menu_book_rounded,
              size: 112,
              color: const Color(0xFFD6AD5C).withValues(alpha: .07),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00E8C778),
                    Color(0xFFE8C778),
                    Color(0x00E8C778),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

class _BadgeFrontBackground extends StatelessWidget {
  const _BadgeFrontBackground();

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF8FBFF), Color(0xFFEFF5FC)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ColoredBox(
              color: Color(0xFFED1C24),
              child: SizedBox(height: 8),
            ),
          ),
          Positioned(
            right: 20,
            top: 145,
            child: Wrap(
              direction: Axis.vertical,
              spacing: 5,
              children: List.generate(
                7,
                (row) => Row(
                  children: List.generate(
                    3,
                    (column) => Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(left: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF062D69).withValues(
                          alpha: .16 + (row * .02),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -70,
            right: -25,
            bottom: 43,
            child: Transform.rotate(
              angle: .08,
              child: Container(
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFED1C24),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(120),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -70,
            right: -20,
            bottom: -28,
            child: Container(
              height: 104,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF062D69), Color(0xFF16127A)],
                ),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(150),
                ),
              ),
            ),
          ),
          Positioned(
            left: -32,
            top: 190,
            child: Transform.rotate(
              angle: -.32,
              child: Container(
                width: 90,
                height: 14,
                color: const Color(0xFF174CA4),
              ),
            ),
          ),
        ],
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
                gradient: const LinearGradient(
                    colors: [Color(0xFF062D69), Color(0xFF174CA4)]),
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
              size: 300,
              color: const Color(0xFF174CA4).withValues(alpha: .035)),
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
              size: 350,
              color: const Color(0xFF174CA4).withValues(alpha: .035)),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF062D69), Color(0xFF07418C)]),
            ),
            child: SizedBox(height: 105),
          ),
        ),
      ]);
}
