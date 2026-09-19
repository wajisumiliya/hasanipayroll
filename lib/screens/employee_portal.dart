import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/payroll.dart';
import '../services/app_service.dart';
import '../theme/daily_portal_theme.dart';
import '../screens/attendance_dialog.dart';
import '../services/pdf_service.dart';
import 'employee_ot_request_page.dart';
import 'employee_leave_request_page.dart';
import 'login_screen.dart';
import '../widgets/employee_photo.dart';
import '../widgets/app_reload_button.dart';

class EmployeePortal extends StatefulWidget {
  const EmployeePortal({super.key});

  @override
  State<EmployeePortal> createState() => _EmployeePortalState();
}

class _EmployeePortalState extends State<EmployeePortal>
    with SingleTickerProviderStateMixin {
  final AppService service = AppService.instance;

  int tab = 0;
  int? _selectedPayslipYear;
  bool _showFinancialDetails = false;
  late final AnimationController _birthdayController;
  Timer? _birthdayCelebrationTimer;
  bool _showBirthdayCelebration = false;

  @override
  void initState() {
    super.initState();
    _birthdayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    if (_isBirthdayToday) {
      _showBirthdayCelebration = true;
      _birthdayController.repeat();
      _birthdayCelebrationTimer = Timer(const Duration(seconds: 15), () {
        if (!mounted) return;
        _birthdayController.stop();
        setState(() => _showBirthdayCelebration = false);
      });
    }
  }

  @override
  void dispose() {
    _birthdayCelebrationTimer?.cancel();
    _birthdayController.dispose();
    super.dispose();
  }

  void _toggleFinancialDetails() {
    setState(() => _showFinancialDetails = !_showFinancialDetails);
  }

  String _moneyText(double value) {
    if (!_showFinancialDetails) return 'RM ••••••';
    return 'RM ${NumberFormat('#,##0.00').format(value)}';
  }

  String _privateText(String value) {
    if (!_showFinancialDetails) return '••••••••';
    return value.trim().isEmpty ? '-' : value;
  }

  Widget _financialVisibilityButton({Color? color}) {
    return IconButton(
      onPressed: _toggleFinancialDetails,
      tooltip: _showFinancialDetails
          ? 'Hide salary and bank details'
          : 'Show salary and bank details',
      icon: Icon(
        _showFinancialDetails
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        color: color,
      ),
    );
  }

  _EmployeeDailyTheme get _dailyTheme =>
      _EmployeeDailyTheme.forWeekday(DateTime.now().weekday);

  DateTime _attendanceMonth =
      DateTime(DateTime.now().year, DateTime.now().month);

  /// =============================================================
  /// CURRENT EMPLOYEE
  /// =============================================================

  Employee? get employee => service.currentEmployee;

  bool get _isBirthdayToday {
    final birthday = employee?.birthday;
    if (birthday == null) return false;
    final today = DateTime.now();
    return birthday.month == today.month && birthday.day == today.day;
  }

  String get employeeId => service.currentUser?.employeeId ?? '';

  List<PayrollRecord> get records {
    if (employeeId.isEmpty) {
      return [];
    }

    return service.employeePayroll(
      employeeId,
    );
  }

  /// =============================================================
  /// LOGOUT
  /// =============================================================

  Future<void> logout() async {
    await service.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  /// =============================================================
  /// BUILD
  /// =============================================================

  @override
  Widget build(BuildContext context) {
    if (employee == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Employee Portal'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_outlined,
                size: 60,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Employee information not found.',
                style: TextStyle(
                  color: tab == 0 ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: logout,
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final portal = constraints.maxWidth >= 900 ? _desktop() : _mobile();
          return _showBirthdayCelebration && tab == 0
              ? _birthdayDashboardFrame(portal)
              : portal;
        },
      ),
    );
  }

  Widget _birthdayDashboardFrame(Widget portal) {
    return AnimatedBuilder(
      animation: _birthdayController,
      child: portal,
      builder: (context, child) {
        final progress = _birthdayController.value;
        final size = MediaQuery.sizeOf(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFD166).withValues(alpha: .08),
                      const Color(0xFFED1C24).withValues(alpha: .06),
                      const Color(0xFF7C3AED).withValues(alpha: .08),
                    ],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Stack(
                children: [
                  for (var index = 0; index < 42; index++)
                    Positioned(
                      left: (index * 97.0) % size.width,
                      top: (((progress + index * .047) % 1) *
                              (size.height + 90)) -
                          60,
                      child: Transform.rotate(
                        angle: (progress * math.pi * 2) + index,
                        child: Text(
                          const ['🎉', '✨', '🎊', '⭐', '🎈', '🎁'][index % 6],
                          style: TextStyle(
                            fontSize: 16.0 + (index % 5) * 4,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: size.width >= 900 ? 88 : 74,
                    left: size.width >= 900 ? 280 : 18,
                    right: 18,
                    child: Center(
                      child: Transform.scale(
                        scale: .97 +
                            ((math.sin(progress * math.pi * 2) + 1) / 2) * .03,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 560),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFED1C24), Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x44000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🎂', style: TextStyle(fontSize: 26)),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Happy Birthday, ${employee!.name}!',
                                  maxLines: size.width < 600 ? 3 : 2,
                                  overflow: TextOverflow.visible,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: size.width < 600 ? 14 : 18,
                                    height: 1.15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('🎈', style: TextStyle(fontSize: 26)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // =============================================================
  // DESKTOP
  // =============================================================

  Widget _desktop() {
    final dailyTheme = _dailyTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isBirthdayToday
              ? const [Color(0xFFFFF3D6), Color(0xFFFFE4EA), Color(0xFFEDE4FF)]
              : dailyTheme.pageBackground,
        ),
      ),
      child: Row(
        children: [
          _desktopSidebar(),
          Expanded(
            child: Column(
              children: [
                _desktopTopBar(),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: tab == 0
                            ? (_isBirthdayToday
                                ? const [
                                    Color(0xFFFFF3D6),
                                    Color(0xFFFFE4EA),
                                    Color(0xFFEDE4FF),
                                  ]
                                : const [Color(0xFFF3F8FF), Color(0xFFFFFFFF)])
                            : [
                                dailyTheme.surfaceTint.withValues(alpha: .96),
                                const Color(0xFFF5F7FB),
                              ],
                      ),
                    ),
                    child: _page(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // DESKTOP SIDEBAR
  // =============================================================

  Widget _desktopSidebar() {
    return Container(
      width: 272,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123E70), Color(0xFF06294F)],
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 90,
            width: double.infinity,
            color: Colors.white,
            alignment: Alignment.center,
            child: Image.asset(
              'assets/hasani_books_payslip_logo.jpeg',
              width: 210,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'hasani BOOKS',
                style: TextStyle(
                  color: Color(0xFF08255F),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _side(
            'Dashboard',
            Icons.dashboard_outlined,
            0,
          ),
          _side('Leave', Icons.flight_takeoff_outlined, 3),
          _side('Attendance', Icons.calendar_month_outlined, 2),
          _side('OT Request', Icons.more_time_outlined, 6),
          _side('Payslip', Icons.receipt_long_outlined, 1),
          _side(
            'Bank Information',
            Icons.account_balance_outlined,
            4,
          ),
          _side(
            'Change Password',
            Icons.lock_outline,
            5,
          ),
          const Spacer(),
          const Divider(color: Colors.white24),
          _side(
            'Logout',
            Icons.logout,
            7,
          ),
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              '© 2026 Hasani Books',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // DESKTOP MENU ITEM
  // =============================================================

  Widget _side(
    String title,
    IconData icon,
    int index,
  ) {
    final selected = tab == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 2,
      ),
      child: ListTile(
        selected: selected,
        selectedTileColor: const Color(0xFF1976E9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: Icon(
          icon,
          color: title == 'Logout' ? Colors.red.shade200 : Colors.white,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: title == 'Logout'
                ? Colors.red
                : selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: .86),
          ),
        ),
        onTap: () {
          if (index == 7) {
            logout();
            return;
          }

          setState(() {
            tab = index;
          });
        },
      ),
    );
  }

  // =============================================================
  // DESKTOP TOP BAR
  // =============================================================

  Widget _desktopTopBar() {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF08255F).withValues(alpha: .08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 28,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              constraints: const BoxConstraints(maxWidth: 700),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Color(0xFF7890B5)),
                  hintText: 'Search anything...',
                  hintStyle: TextStyle(color: Color(0xFF9AAECD)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 22),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Badge(
              label: Text('3'),
              child: Icon(Icons.notifications_outlined, color: Color(0xFF08255F)),
            ),
          ),
          _financialVisibilityButton(color: const Color(0xFF08255F)),
          const SizedBox(width: 8),
          const AppReloadButton(color: Color(0xFF08255F)),
          const SizedBox(width: 16),
          EmployeePhoto(
            name: employee!.name,
            photoUrl: employee!.photoUrl,
            radius: 20,
            backgroundColor: const Color(0xFFE8F1FF),
            foregroundColor: const Color(0xFF08255F),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee!.name,
                style: const TextStyle(
                  color: Color(0xFF08255F),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                employee!.employeeId,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF60759B),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          IconButton(
            onPressed: logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.expand_more, color: Color(0xFF08255F)),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // MOBILE
  // =============================================================

  Widget _mobile() {
    final dailyTheme = _dailyTheme;
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: dailyTheme.header),
          ),
        ),
        title: Text(_mobileTitle()),
        actions: [
          _financialVisibilityButton(),
          const AppReloadButton(color: Colors.white),
          IconButton(
            onPressed: logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: tab == 0
                ? dailyTheme.pageBackground
                : [
                    dailyTheme.surfaceTint,
                    const Color(0xFFF5F7FB),
                  ],
          ),
        ),
        child: _page(),
      ),
      bottomNavigationBar: NavigationBar(
        indicatorColor: dailyTheme.accent.withValues(alpha: .22),
        selectedIndex: tab == 6
            ? 3
            : (tab == 3
                ? 4
                : tab > 2
                    ? 0
                    : tab),
        onDestinationSelected: (index) {
          setState(() {
            tab = const [0, 1, 2, 6, 3][index];
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Payslips',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_time_outlined),
            selectedIcon: Icon(Icons.more_time),
            label: 'OT Request',
          ),
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff_outlined),
            selectedIcon: Icon(Icons.flight_takeoff),
            label: 'Leave',
          ),
        ],
      ),
    );
  }

  // =============================================================
  // TITLES
  // =============================================================

  String _pageTitle() {
    switch (tab) {
      case 0:
        return 'Dashboard';

      case 1:
        return 'My Payslips';

      case 2:
        return 'Attendance';

      case 3:
        return 'Leave';

      case 4:
        return 'Bank Information';

      case 5:
        return 'Change Password';

      case 6:
        return 'OT Request';

      default:
        return 'Employee Portal';
    }
  }

  String _mobileTitle() {
    switch (tab) {
      case 1:
        return 'My Payslips';

      case 2:
        return 'Attendance';

      case 3:
        return 'Leave';

      case 4:
        return 'Bank Information';

      case 5:
        return 'Change Password';

      case 6:
        return 'OT Request';

      default:
        return 'Employee Portal';
    }
  }

  // =============================================================
  // PAGE ROUTER
  // =============================================================

  Widget _page() {
    switch (tab) {
      case 0:
        return _dashboard();

      case 1:
        return _payslips();

      case 2:
        return _attendance();

      case 3:
        return EmployeeLeaveRequestPage(employee: employee!);

      case 4:
        return _bankInformation();

      case 5:
        return const _ChangePasswordPage();

      case 6:
        return EmployeeOtRequestPage(employee: employee!);

      default:
        return _dashboard();
    }
  }

  // =============================================================
  // DASHBOARD
  // =============================================================

  Widget _dashboard() {
    if (records.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dashboardIntro(),
            const SizedBox(height: 18),
            _welcome(),
            const SizedBox(height: 24),
            _emptyPayroll(),
          ],
        ),
      );
    }

    final payroll = records.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dashboardIntro(),
              const SizedBox(height: 18),
              _welcome(),
              const SizedBox(height: 12),
              if (compact) ...[
                _salary(payroll),
                const SizedBox(height: 12),
                _quickAccessPanel(),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _salary(payroll)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _quickAccessPanel()),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Recent Payslips',
                    style: TextStyle(
                      color: tab == 0 ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        tab = 1;
                      });
                    },
                    child: const Text(
                      'View All',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...records.take(3).map(_recentPayslipTile),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyPayroll() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: tab == 0 ? const Color(0xE6102A43) : Colors.white,
        borderRadius: BorderRadius.circular(tab == 0 ? 18 : 14),
        border: tab == 0
            ? Border.all(color: _dailyTheme.accent.withValues(alpha: .38))
            : null,
      ),
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 50,
            color: Colors.black38,
          ),
          SizedBox(height: 12),
          Text(
            'No payroll records available.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // WELCOME
  // =============================================================

  Widget _welcome() {
    final dailyTheme = _dailyTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF092E6E), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF08255F).withValues(alpha: .20),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: const Color(0xFFED1C24).withValues(alpha: .08),
                blurRadius: 18,
                offset: const Offset(-8, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Color(0xFFF4F8FF)],
                  ),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFD7E2F2)),
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/hasani_books_payslip_logo.jpeg',
                      width: compact ? 105 : 150,
                      height: 46,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'hasani BOOKS',
                        style: TextStyle(
                          color: Color(0xFF08255F),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'EMPLOYEE CARD',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Color(0xFF08255F),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            'PEOPLE  •  KNOWLEDGE  •  PROGRESS',
                            style: TextStyle(
                              color: Color(0xFF526A96),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEAF3FF), Color(0xFFFCFDFF), Color(0xFFE7F0FC)],
                  ),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFED1C24), width: 5),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -72,
                      right: -38,
                      child: Transform.rotate(
                        angle: -.35,
                        child: Container(
                          width: compact ? 150 : 270,
                          height: 115,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF083E91), Color(0xFF031D4B)],
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -48,
                      right: compact ? 44 : 105,
                      child: Transform.rotate(
                        angle: -.35,
                        child: Container(
                          width: compact ? 62 : 100,
                          height: 105,
                          decoration: BoxDecoration(
                            color: const Color(0xFFED1C24),
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -54,
                      bottom: -68,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0B57B7).withValues(alpha: .13),
                            width: 22,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: .035,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: const Color(0xFF08255F),
                              size: compact ? 210 : 320,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(compact ? 14 : 24),
                      child: compact
                          ? _mobileIdentityCard(dailyTheme)
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _identityPhoto(dailyTheme),
                                const SizedBox(width: 24),
                                Expanded(child: _identityInformation(dailyTheme)),
                                const SizedBox(width: 20),
                                _identityVerification(),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dashboardIntro() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: TextStyle(
                  color: const Color(0xFF6079A4),
                  fontSize: compact ? 15 : 20,
                ),
              ),
              Text(
                '${employee!.name} 👋',
                style: TextStyle(
                  color: const Color(0xFF08255F),
                  fontSize: compact ? 23 : 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Good to see you again! Here is your employee information and quick access to common features.',
                style: const TextStyle(color: Color(0xFF6079A4), fontSize: 12),
              ),
            ],
          ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
              style: const TextStyle(color: Color(0xFF526C99), fontSize: 11),
            ),
            if (!compact) ...[
              const SizedBox(height: 5),
              Text(
                '“${_dailyTheme.quote}”',
                style: const TextStyle(
                  color: Color(0xFF6079A4),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _mobileIdentityCard(_EmployeeDailyTheme dailyTheme) {
    final branch = employee!.branchId.trim().isEmpty ? '-' : employee!.branchId;
    final active = employee!.isActive;
    final statusColor = active ? const Color(0xFF00A651) : const Color(0xFFED1C24);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _identityPhoto(dailyTheme, radius: 40),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee!.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF08255F),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    employee!.designation.trim().isEmpty
                        ? 'Employee'
                        : employee!.designation,
                    style: TextStyle(color: dailyTheme.accent, fontSize: 12),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      active ? '✓ ACTIVE • VALUED EMPLOYEE' : 'INACTIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final fieldWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _identityField(Icons.badge_outlined, 'Employee ID', employee!.employeeId,
                    width: fieldWidth),
                _identityField(Icons.business_outlined, 'Department',
                    employee!.department.trim().isEmpty ? '-' : employee!.department,
                    width: fieldWidth),
                _identityField(Icons.location_on_outlined, 'Branch', branch,
                    width: fieldWidth),
                _identityField(
                  Icons.calendar_month_outlined,
                  'Joining Date',
                  employee!.joiningDate == null
                      ? '-'
                      : DateFormat('dd MMM yyyy').format(employee!.joiningDate!),
                  width: fieldWidth,
                ),
                _identityField(Icons.email_outlined, 'Email',
                    employee!.email.trim().isEmpty ? '-' : employee!.email,
                    width: constraints.maxWidth, multiline: true),
                _identityField(Icons.phone_outlined, 'Contact',
                    employee!.phone.trim().isEmpty ? '-' : employee!.phone,
                    width: constraints.maxWidth),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _identityPhoto(_EmployeeDailyTheme dailyTheme, {double radius = 66}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dailyTheme.accent, width: 2),
      ),
      child: EmployeePhoto(
        name: employee!.name,
        photoUrl: employee!.photoUrl,
        radius: radius,
        backgroundColor: dailyTheme.accent.withValues(alpha: .14),
        foregroundColor: dailyTheme.accent,
      ),
    );
  }

  Widget _identityInformation(
    _EmployeeDailyTheme dailyTheme, {
    bool centered = false,
  }) {
    final alignment = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;
    final branch = employee!.branchId.trim().isEmpty ? '-' : employee!.branchId;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          employee!.name,
          textAlign: textAlign,
          style: const TextStyle(
            color: Color(0xFF17233C),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          employee!.designation.trim().isEmpty ? 'Employee' : employee!.designation,
          textAlign: textAlign,
          style: TextStyle(color: dailyTheme.accent, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          spacing: 22,
          runSpacing: 10,
          children: [
            _identityField(Icons.badge_outlined, 'Employee ID', employee!.employeeId),
            _identityField(
              Icons.business_outlined,
              'Department',
              employee!.department.trim().isEmpty ? '-' : employee!.department,
            ),
            _identityField(
              Icons.location_on_outlined,
              'Branch',
              branch,
            ),
            _identityField(
              Icons.calendar_month_outlined,
              'Joining Date',
              employee!.joiningDate == null
                  ? '-'
                  : DateFormat('dd MMM yyyy').format(employee!.joiningDate!),
            ),
            _identityField(
              Icons.email_outlined,
              'Email',
              employee!.email.trim().isEmpty ? '-' : employee!.email,
            ),
            _identityField(
              Icons.phone_outlined,
              'Contact',
              employee!.phone.trim().isEmpty ? '-' : employee!.phone,
            ),
          ],
        ),
        const SizedBox(height: 11),
        Text(
          DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
          textAlign: textAlign,
          style: const TextStyle(color: Colors.black45, fontSize: 11),
        ),
      ],
    );
  }

  Widget _identityVerification() {
    final active = employee!.isActive;
    final color = active ? const Color(0xFF00A651) : const Color(0xFFED1C24);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF08255F)),
            ),
            child: const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF08255F)),
          ),
          const SizedBox(height: 6),
          Text(
            employee!.employeeId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF08255F),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 5),
                Text(
                  active ? 'ACTIVE' : 'INACTIVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            active ? 'VALUED EMPLOYEE' : 'NOT ACTIVE',
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _identityField(
    IconData icon,
    String label,
    String value, {
    double width = 185,
    bool multiline = false,
  }) {
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF0B347C), size: 25),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Color(0xFF60759B), fontSize: 10),
                ),
                Text(
                  value,
                  maxLines: multiline ? 2 : 1,
                  overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF08255F),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // SALARY
  // =============================================================

  Widget _salary(
    PayrollRecord payroll,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: tab == 0
            ? Border.all(color: _dailyTheme.accent.withValues(alpha: .38))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(payroll.period),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _pdf(payroll),
                child: const Text(
                  'View Payslip',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Gross Earnings',
                  payroll.totalEarnings,
                  const Color(0xFF08255F),
                ),
              ),
              Expanded(
                child: _metric(
                  'Total Deductions',
                  payroll.totalDeductions,
                  Colors.red,
                ),
              ),
              Expanded(
                child: _metric(
                  'Net Pay',
                  payroll.netPay,
                  const Color(0xFF13B66B),
                  big: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(
    String title,
    double value,
    Color color, {
    bool big = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _moneyText(value),
              style: TextStyle(
                fontSize: big ? 22 : 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =============================================================
  // QUICK ACCESS
  // =============================================================

  Widget _quickAccessPanel() {
    final actions = <({String title, IconData icon, int page})>[
      (title: 'Payslips', icon: Icons.description_outlined, page: 1),
      (title: 'Attendance', icon: Icons.calendar_month_outlined, page: 2),
      (title: 'OT Request', icon: Icons.more_time_outlined, page: 6),
      (title: 'Leave', icon: Icons.flight_takeoff_outlined, page: 3),
      (title: 'Bank Info', icon: Icons.account_balance_outlined, page: 4),
      (title: 'Password', icon: Icons.lock_outline, page: 5),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _dailyTheme.accent.withValues(alpha: .38),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Access',
            style: TextStyle(
            color: Color(0xFF08255F),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 390 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 62,
                ),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return _quick(
                    action.title,
                    action.icon,
                    () => setState(() => tab = action.page),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _quick(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F7FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _dailyTheme.accent.withValues(alpha: .30),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: _dailyTheme.accent,
            ),
            const SizedBox(height: 3),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF08255F),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // PAYSLIP MONTH CARD
  // =============================================================

  Widget _recentPayslipTile(PayrollRecord payroll) {
    return Card(
      color: tab == 0 ? const Color(0xE6102A43) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEAF0FF),
          child: Icon(
            Icons.description_outlined,
            color: Color(0xFF2D55D8),
          ),
        ),
        title: Text(
          DateFormat('MMMM yyyy').format(payroll.period),
          style: TextStyle(
            color: tab == 0 ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _showFinancialDetails
              ? 'Net pay ${_moneyText(payroll.netPay)}'
              : 'Net pay RM ••••••',
          style: TextStyle(
            color: tab == 0 ? Colors.white60 : Colors.black54,
          ),
        ),
        trailing: IconButton(
          onPressed: () => _pdf(payroll),
          tooltip: 'View payslip',
          color: tab == 0 ? Colors.white : null,
          icon: const Icon(Icons.download_outlined),
        ),
      ),
    );
  }

  Widget _payslipMonthCard({
    required int month,
    required int year,
    required PayrollRecord? payroll,
    bool mobileCompact = false,
  }) {
    const colors = [
      Color(0xFF2F6FED),
      Color(0xFFEC4775),
      Color(0xFF1FB874),
      Color(0xFF8B43E6),
      Color(0xFFE5AF13),
      Color(0xFF14AEC5),
    ];
    final accent = colors[(month - 1) % colors.length];
    final available = payroll != null;

    if (mobileCompact) {
      return Material(
        color: available ? accent.withValues(alpha: .08) : Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: available
                ? accent.withValues(alpha: .22)
                : Colors.grey.shade200,
          ),
        ),
        child: InkWell(
          onTap: available ? () => _pdf(payroll) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: available ? accent : Colors.grey,
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        DateFormat('MMM').format(DateTime(year, month)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'Net Pay',
                  style: TextStyle(color: Colors.black54, fontSize: 8),
                ),
                Text(
                  available ? _moneyText(payroll.netPay) : 'Unavailable',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: available ? accent : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      available
                          ? Icons.download_outlined
                          : Icons.block_outlined,
                      color: available ? accent : Colors.grey,
                      size: 15,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: available ? accent.withValues(alpha: .08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              available ? accent.withValues(alpha: .16) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: available
                    ? accent.withValues(alpha: .13)
                    : Colors.grey.shade200,
                child: Icon(
                  Icons.description_outlined,
                  color: available ? accent : Colors.grey,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM').format(DateTime(year, month)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$year',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Net Pay',
            style: TextStyle(color: Colors.black54, fontSize: 9),
          ),
          const SizedBox(height: 1),
          Text(
            available ? _moneyText(payroll.netPay) : 'Not available',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: available ? accent : Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: available ? () => _pdf(payroll) : null,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 31),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              icon: const Icon(Icons.download_outlined, size: 14),
              label: Text(
                available ? 'Download' : 'No payslip',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yearSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
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
                Text(label,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 10)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _yearSummary({
    required int year,
    required double gross,
    required double deductions,
    required double net,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _yearSummaryItem(
                icon: Icons.calendar_today_outlined,
                label: 'Year',
                value: '$year',
                color: const Color(0xFF2D55D8),
              ),
            ),
            SizedBox(
              width: width,
              child: _yearSummaryItem(
                icon: Icons.payments_outlined,
                label: 'Gross',
                value: _moneyText(gross),
                color: const Color(0xFF2563EB),
              ),
            ),
            SizedBox(
              width: width,
              child: _yearSummaryItem(
                icon: Icons.remove_circle_outline,
                label: 'Year Deduction',
                value: _moneyText(deductions),
                color: const Color(0xFFD52B3F),
              ),
            ),
            SizedBox(
              width: width,
              child: _yearSummaryItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Year Net',
                value: _moneyText(net),
                color: const Color(0xFF07833D),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _payslipYearSection(int year, List<PayrollRecord> yearRecords) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final byMonth = <int, PayrollRecord>{
      for (final record in yearRecords) record.period.month: record,
    };
    final gross = yearRecords.fold<double>(
      0,
      (total, record) => total + record.totalEarnings,
    );
    final deductions = yearRecords.fold<double>(
      0,
      (total, record) => total + record.totalDeductions,
    );
    final net = yearRecords.fold<double>(
      0,
      (total, record) => total + record.netPay,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFEAF0FF),
                  child: Icon(
                    Icons.calendar_month_outlined,
                    color: Color(0xFF2D55D8),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$year',
                  style: TextStyle(
                    fontSize: compact ? 20 : 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${yearRecords.length} payslips',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _yearSummary(
              year: year,
              gross: gross,
              deductions: deductions,
              net: net,
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = compact
                    ? 3
                    : constraints.maxWidth >= 1100
                        ? 6
                        : constraints.maxWidth >= 700
                            ? 3
                            : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 12,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: compact ? 6 : 10,
                    mainAxisSpacing: compact ? 6 : 10,
                    mainAxisExtent: compact ? 104 : 144,
                  ),
                  itemBuilder: (context, index) => _payslipMonthCard(
                    month: index + 1,
                    year: year,
                    payroll: byMonth[index + 1],
                    mobileCompact: compact,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // PAYSLIPS
  // =============================================================

  Widget _payslips() {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final recordsByYear = <int, List<PayrollRecord>>{};
    for (final record in records) {
      recordsByYear.putIfAbsent(record.period.year, () => []).add(record);
    }
    final years = recordsByYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final selectedYear = years.contains(_selectedPayslipYear)
        ? _selectedPayslipYear!
        : (years.isEmpty ? null : years.first);

    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 10 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Payslips',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'View your monthly net pay and download payslips by year',
            style: TextStyle(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 18),
          if (records.isEmpty)
            _emptyPayroll()
          else if (compact) ...[
            const Text(
              'Select year',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: years.map((year) {
                final selected = year == selectedYear;
                return ChoiceChip(
                  avatar: Icon(
                    Icons.calendar_month_outlined,
                    size: 17,
                    color: selected ? Colors.white : const Color(0xFF2D55D8),
                  ),
                  label: Text('$year'),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFF2D55D8),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF2D55D8)),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF2D55D8),
                    fontWeight: FontWeight.w800,
                  ),
                  onSelected: (_) => setState(() {
                    _selectedPayslipYear = year;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            if (selectedYear != null)
              _payslipYearSection(
                selectedYear,
                recordsByYear[selectedYear]!,
              ),
          ] else
            ...years.map(
              (year) => _payslipYearSection(year, recordsByYear[year]!),
            ),
        ],
      ),
    );
  }

  // =============================================================
  // ATTENDANCE - READ ONLY
  // =============================================================

  Widget _attendance() {
    final currentEmployee = employee!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Attendance',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Attendance submitted by your branch. This page is read-only.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      EmployeePhoto(
                        name: currentEmployee.name,
                        photoUrl: currentEmployee.photoUrl,
                        radius: 30,
                        backgroundColor:
                            _dailyTheme.accent.withValues(alpha: .20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentEmployee.name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(currentEmployee.employeeId,
                                style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Read Only',
                          style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w700,
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('MMMM yyyy').format(_attendanceMonth),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _attendanceMonth,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            helpText: 'Select Attendance Month',
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              _attendanceMonth =
                                  DateTime(picked.year, picked.month);
                            });
                          }
                        },
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => AttendanceDialog(
                            employee: {
                              'employee_id': currentEmployee.employeeId,
                              'name': currentEmployee.name,
                              'department': currentEmployee.department,
                              'branch_id': currentEmployee.branchId,
                              'photo_url': currentEmployee.photoUrl,
                            },
                            month: _attendanceMonth,
                            branchId: currentEmployee.branchId,
                            editable: false,
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View Attendance'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Attendance appears here after the Branch Portal submits it. The record cannot be edited from the Employee Portal.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // LEAVE
  // =============================================================

  Widget _leavePlaceholder() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD9E6F8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF08255F).withValues(alpha: .08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFF1976E9).withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flight_takeoff_outlined,
                  color: Color(0xFF1976E9),
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Leave Request',
                style: TextStyle(
                  color: Color(0xFF08255F),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The leave application form will be available here soon. It will follow the same request and approval concept as OT requests.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6079A4), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================
  // PROFILE (kept for employee information reuse; not in navigation)
  // =============================================================

  Widget _profile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          EmployeePhoto(
            name: employee!.name,
            photoUrl: employee!.photoUrl,
            radius: 48,
            backgroundColor: const Color(0xFFEAF0FF),
          ),
          const SizedBox(height: 12),
          Text(
            employee!.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            employee!.designation,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          _info(
            'Employee ID',
            employee!.employeeId,
          ),
          _info(
            'Email',
            employee!.email,
          ),
          _info(
            'Designation',
            employee!.designation,
          ),
          _info(
            'Department',
            employee!.department,
          ),
          _info(
            'New IC Number',
            employee!.newIcNo,
          ),
          _info(
            'Phone',
            employee!.phone,
          ),
          _info(
            'Address',
            employee!.address,
          ),
          _info(
            'Joining Date',
            employee!.joiningDate == null
                ? '-'
                : DateFormat('dd MMM yyyy').format(
                    employee!.joiningDate!,
                  ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // BANK INFORMATION
  // =============================================================

  Widget _bankInformation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bank Information',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Salary payment information',
            style: TextStyle(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.account_balance,
                    ),
                    title: const Text('Bank Code'),
                    subtitle: Text(
                      _privateText(employee!.bankCode),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.credit_card,
                    ),
                    title: const Text(
                      'Bank Account Number',
                    ),
                    subtitle: Text(
                      _privateText(employee!.bankAccount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text('Employee ID'),
                    subtitle: Text(
                      employee!.employeeId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
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

  // =============================================================
  // INFO CARD
  // =============================================================

  Widget _info(
    String title,
    String value,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // =============================================================
  // PDF
  // =============================================================

  Future<void> _pdf(
    PayrollRecord payroll,
  ) async {
    if (!_showFinancialDetails) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tap the eye icon to reveal financial details before viewing the payslip.',
          ),
        ),
      );
      return;
    }

    try {
      final bytes = await PdfService.buildPayslip(
        employee: employee!,
        p: payroll,
        history: records,
        attendance: service.employeeAttendance(employeeId),
      );

      if (kIsWeb) {
        final period = DateFormat('yyyy-MM').format(payroll.period);
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'payslip_${payroll.employeeId}_$period.pdf',
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          format: PdfService.payslipPageFormat,
          dynamicLayout: false,
          forceCustomPrintPaper: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to generate payslip: $e',
          ),
        ),
      );
    }
  }
}

class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage();

  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final TextEditingController currentController = TextEditingController();

  final TextEditingController newController = TextEditingController();

  final TextEditingController confirmController = TextEditingController();

  bool hideCurrent = true;
  bool hideNew = true;
  bool hideConfirm = true;

  bool isUpdating = false;

  @override
  void dispose() {
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> updatePassword() async {
    if (isUpdating) return;

    final current = currentController.text.trim();
    final newPassword = newController.text.trim();
    final confirm = confirmController.text.trim();

    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      _message('Please complete all fields.');
      return;
    }

    if (newPassword.length < 6) {
      _message(
        'Password must contain at least 6 characters.',
      );
      return;
    }

    if (newPassword != confirm) {
      _message(
        'New passwords do not match.',
      );
      return;
    }

    if (current == newPassword) {
      _message(
        'New password must be different from your current password.',
      );
      return;
    }

    final service = AppService.instance;
    final user = service.currentUser;

    if (user == null) {
      _message(
        'Your session has expired. Please login again.',
      );
      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      // Actually update the password.
      final success = await service.updatePassword(
        currentPassword: current,
        newPassword: newPassword,
      );

      if (!mounted) return;

      if (success) {
        currentController.clear();
        newController.clear();
        confirmController.clear();

        _message(
          'Password updated successfully.',
        );
      } else {
        _message(
          'Unable to update password.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _message(
        'Failed to update password. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _passwordDecoration({
    required String label,
    required bool hidden,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          hidden ? Icons.visibility : Icons.visibility_off,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: currentController,
              obscureText: hideCurrent,
              decoration: _passwordDecoration(
                label: 'Current Password',
                hidden: hideCurrent,
                onToggle: () {
                  setState(() {
                    hideCurrent = !hideCurrent;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newController,
              obscureText: hideNew,
              decoration: _passwordDecoration(
                label: 'New Password',
                hidden: hideNew,
                onToggle: () {
                  setState(() {
                    hideNew = !hideNew;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: hideConfirm,
              decoration: _passwordDecoration(
                label: 'Confirm New Password',
                hidden: hideConfirm,
                onToggle: () {
                  setState(() {
                    hideConfirm = !hideConfirm;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isUpdating ? null : updatePassword,
                child: isUpdating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Update Password',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeDailyTheme {
  const _EmployeeDailyTheme({
    required this.accent,
    required this.quote,
    required this.sidebar,
    required this.header,
    required this.hero,
    required this.pageBackground,
    required this.surfaceTint,
  });

  final Color accent;
  final String quote;
  final List<Color> sidebar;
  final List<Color> header;
  final List<Color> hero;
  final List<Color> pageBackground;
  final Color surfaceTint;

  static _EmployeeDailyTheme forWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return const _EmployeeDailyTheme(
          accent: Color(0xFF6FFFD8),
          quote: 'A focused mind creates extraordinary days.',
          sidebar: [Color(0xFF061530), Color(0xFF102C55)],
          header: [Color(0xFF0A2148), Color(0xFF183B74)],
          hero: [Color(0xFF152E78), Color(0xFF075D64)],
          pageBackground: [Color(0xFF071A3D), Color(0xFF063C47)],
          surfaceTint: Color(0xFFE9F8F6),
        );
      case DateTime.tuesday:
        return const _EmployeeDailyTheme(
          accent: Color(0xFFFF8B83),
          quote: 'Small steps create great progress.',
          sidebar: [Color(0xFF07162F), Color(0xFF3B2440)],
          header: [Color(0xFF102B52), Color(0xFF633044)],
          hero: [Color(0xFF183C70), Color(0xFF8B4050)],
          pageBackground: [Color(0xFF07162F), Color(0xFF7A2F42)],
          surfaceTint: Color(0xFFFFF0EF),
        );
      case DateTime.wednesday:
        return const _EmployeeDailyTheme(
          accent: Color(0xFFE7C77E),
          quote: 'Halfway there. Keep moving forward.',
          sidebar: [Color(0xFF041D32), Color(0xFF064B53)],
          header: [Color(0xFF062842), Color(0xFF08616A)],
          hero: [Color(0xFF075464), Color(0xFF087765)],
          pageBackground: [Color(0xFF041D32), Color(0xFF075A62)],
          surfaceTint: Color(0xFFE8F8F5),
        );
      case DateTime.thursday:
        return const _EmployeeDailyTheme(
          accent: Color(0xFFE8C778),
          quote: 'Better days are built by consistent effort.',
          sidebar: [Color(0xFF17112F), Color(0xFF402553)],
          header: [Color(0xFF261948), Color(0xFF633451)],
          hero: [Color(0xFF51327A), Color(0xFF74405A)],
          pageBackground: [Color(0xFF17112F), Color(0xFF4B243A)],
          surfaceTint: Color(0xFFF8EEF7),
        );
      case DateTime.friday:
        return const _EmployeeDailyTheme(
          accent: Color(0xFFFFD76A),
          quote: 'Finish strong. You make it happen.',
          sidebar: [Color(0xFF080B12), Color(0xFF252017)],
          header: [Color(0xFF11151D), Color(0xFF40341C)],
          hero: [Color(0xFF171B23), Color(0xFF6A501D)],
          pageBackground: [Color(0xFF080B12), Color(0xFF242018)],
          surfaceTint: Color(0xFFFFF8E7),
        );
      case DateTime.saturday:
        return const _EmployeeDailyTheme(
          accent: Color(0xFFE6C579),
          quote: 'Good energy brings great opportunities.',
          sidebar: [Color(0xFF061C54), Color(0xFF074583)],
          header: [Color(0xFF082769), Color(0xFF0865A2)],
          hero: [Color(0xFF0846A4), Color(0xFF0A7790)],
          pageBackground: [Color(0xFF061C54), Color(0xFF0757BD)],
          surfaceTint: Color(0xFFF1FBE6),
        );
      default:
        return const _EmployeeDailyTheme(
          accent: Color(0xFFEAD39A),
          quote: 'A calm mind is a powerful mind.',
          sidebar: [Color(0xFF071326), Color(0xFF152541)],
          header: [Color(0xFF0A1930), Color(0xFF243B5D)],
          hero: [Color(0xFF152A4A), Color(0xFF344966)],
          pageBackground: [Color(0xFF071326), Color(0xFF172B4A)],
          surfaceTint: Color(0xFFF0F4FA),
        );
    }
  }
}
