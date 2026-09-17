// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payroll.dart';
import '../services/app_service.dart';
import '../theme/daily_portal_theme.dart';
import 'login_screen.dart';
import 'supabase_service.dart';
import 'attendance_dialog.dart';
import 'branch_ot_requests_page.dart';

// ============================================================================
// BRANCH PORTAL
// ============================================================================

class BranchPortal extends StatefulWidget {
  const BranchPortal({super.key});

  @override
  State<BranchPortal> createState() => _BranchPortalState();
}

class _BranchPortalState extends State<BranchPortal>
    with SingleTickerProviderStateMixin {
  final AppService service = AppService.instance;

  DailyPortalTheme get _portalTheme => DailyPortalTheme.today();

  int selectedPage = 0;

  DateTime attendanceMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime selectedAttendanceDate = DateTime.now();

  Future<List<Map<String, dynamic>>>? _employeesFuture;
  String? _employeesFutureBranchId;
  final TextEditingController _employeeSearchController =
      TextEditingController();
  String _employeeSearch = '';
  late final AnimationController _celebrationController;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _employeeSearchController.dispose();
    super.dispose();
  }

  String get branchId {
    final user = service.currentUser;
    final assignedBranch = user?.branchId?.trim() ?? '';

    if (assignedBranch.isNotEmpty) {
      return assignedBranch;
    }

    return user?.username.trim() ?? '';
  }

  Branch? get branch => service.branchById(branchId);

  bool get isFrnSession {
    final user = service.currentUser;
    return [user?.branchId, user?.username].any(
      (value) => value?.trim().toUpperCase().endsWith('FRN') == true,
    );
  }

  String get branchDisplayName => isFrnSession
      ? '${branch?.branchName ?? 'SUNGAI PETANI'} FRN'
      : branch?.branchName ?? branchId;

  List<Employee> get employees =>
      service.branchEmployees(branchId).where((employee) {
        if (!employee.isActive) return false;
        final isFrn = employee.address.toUpperCase().contains('FRN');
        return isFrnSession ? isFrn : !isFrn;
      }).toList();

  Set<String> get _visibleEmployeeIds => employees
      .map((employee) => employee.employeeId.trim().toUpperCase())
      .toSet();

  List<AttendanceRecord> get attendance => service
      .branchAttendance(branchId)
      .where((record) =>
          _visibleEmployeeIds.contains(record.employeeId.trim().toUpperCase()))
      .toList();

  List<AttendanceRecord> get todayAttendance => service
      .branchTodayAttendance(branchId)
      .where((record) =>
          _visibleEmployeeIds.contains(record.employeeId.trim().toUpperCase()))
      .toList();

  // ==========================================================================
  // EMPLOYEE FUTURE
  // ==========================================================================

  Future<List<Map<String, dynamic>>> _liveBranchEmployees() {
    final resolvedBranchId = branch?.branchId ?? branchId;

    if (_employeesFuture == null ||
        _employeesFutureBranchId != resolvedBranchId) {
      _employeesFutureBranchId = resolvedBranchId;

      _employeesFuture = SupabaseService.getEmployeesByBranch(
        resolvedBranchId,
        frnOnly: isFrnSession,
        activeOnly: true,
        aliases: [
          branch?.branchName,
          service.currentUser?.displayName,
          service.currentUser?.username,
        ],
      );
    }

    return _employeesFuture!;
  }

  void _refreshEmployees() {
    _employeesFuture = null;
    _employeesFutureBranchId = null;

    if (mounted) {
      setState(() {});
    }
  }

  // ==========================================================================
  // LOGOUT
  // ==========================================================================

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

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 850) {
                return _desktop();
              }

              return _mobile();
            },
          ),
        );
      },
    );
  }

  // ==========================================================================
  // DESKTOP
  // ==========================================================================

  Widget _desktop() {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF7F8FC)),
      child: Row(
        children: [
          _sidebar(),
          Expanded(
            child: Column(
              children: [
                _topBar(),
                Expanded(child: _portalPage(_currentPage())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _portalPage(Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFF7F8FC)),
        ),
        Center(
          child: IgnorePointer(
            child: Opacity(
              opacity: .025,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image(
                    image: AssetImage('assets/hasani_books_logo.jpg'),
                    width: 540,
                  ),
                  SizedBox(height: 16),
                  Text(
                    branchDisplayName.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF243B8F),
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  // ==========================================================================
  // MOBILE
  // ==========================================================================

  Widget _mobile() {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _portalTheme.header),
          ),
        ),
        title: Text(_pageTitle()),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              _mobileHeader(),
              Expanded(
                child: ListView(
                  children: [
                    _drawerItem(
                      'Dashboard',
                      Icons.dashboard_outlined,
                      0,
                    ),
                    _drawerItem(
                      'Attendance',
                      Icons.fact_check_outlined,
                      1,
                    ),
                    _drawerItem(
                      'Employees',
                      Icons.people_outline,
                      2,
                    ),
                    _drawerItem('OT Requests', Icons.more_time_outlined, 3),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: logout,
              ),
            ],
          ),
        ),
      ),
      body: _portalPage(_currentPage()),
    );
  }

  // ==========================================================================
  // SIDEBAR
  // ==========================================================================

  Widget _sidebar() {
    return Container(
      width: 264,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFD7DDEA))),
        boxShadow: [
          BoxShadow(
            color: Color(0x100D1B3E),
            blurRadius: 18,
            offset: Offset(5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _sidebarHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    'WORKSPACE',
                    style: TextStyle(
                      color: Color(0xFF98A2B3),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                _sidebarItem(
                  'Dashboard',
                  Icons.dashboard_outlined,
                  0,
                ),
                _sidebarItem(
                  'Attendance',
                  Icons.fact_check_outlined,
                  1,
                ),
                _sidebarItem(
                  'Employees',
                  Icons.people_outline,
                  2,
                ),
                _sidebarItem('OT Requests', Icons.more_time_outlined, 3),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            decoration: BoxDecoration(
              color: const Color(0xFFED1C24).withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFED1C24).withValues(alpha: .22),
              ),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(Icons.logout, color: Color(0xFFED1C24)),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFED1C24),
                  fontWeight: FontWeight.w800,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: Color(0xFFED1C24)),
              onTap: logout,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '© 2026 Hasani Books',
              style: TextStyle(
                fontSize: 11,
                color: Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7F9FF), Colors.white],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFE4E7EC))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFDDE3F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset(
              'assets/hasani_books_logo.jpg',
              width: 158,
              errorBuilder: (context, error, stackTrace) => const Text(
                'HASANI BOOKS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF243B8F),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF15965D).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF15965D).withValues(alpha: .25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined,
                    color: Color(0xFF15965D), size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BRANCH PORTAL',
                        style: TextStyle(
                          color: Color(0xFF15965D),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        branchDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF344054),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.circle, color: Color(0xFF73D6AE), size: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF15965D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.business,
            color: Colors.white,
            size: 35,
          ),
          const SizedBox(height: 10),
          const Text(
            'BRANCH PORTAL',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            branchDisplayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    String title,
    IconData icon,
    int page,
  ) {
    final selected = selectedPage == page;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 2,
        vertical: 4,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF243B8F), Color(0xFF315AD9)],
                )
              : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x26243B8F),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: .16)
                  : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 19,
              color: selected ? Colors.white : const Color(0xFF667085),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF344054),
            ),
          ),
          trailing: selected
              ? const Icon(Icons.chevron_right, color: Colors.white, size: 18)
              : null,
          onTap: () => setState(() => selectedPage = page),
        ),
      ),
    );
  }

  Widget _drawerItem(
    String title,
    IconData icon,
    int page,
  ) {
    return ListTile(
      selected: selectedPage == page,
      selectedTileColor: _portalTheme.accent.withValues(alpha: .18),
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);

        setState(() {
          selectedPage = page;
        });
      },
    );
  }

  // ==========================================================================
  // TOP BAR
  // ==========================================================================

  Widget _topBar() {
    final theme = _portalTheme;
    return Container(
      height: 78,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          stops: [0, .48, .58, 1],
          colors: [
            Color(0xFF123C8C),
            Color(0xFF2368C4),
            Color(0xFFE72D3B),
            Color(0xFFB9152A),
          ],
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border(
          bottom: const BorderSide(color: Color(0x22FFFFFF)),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 28,
      ),
      child: Row(
        children: [
          Text(
            _pageTitle().toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          PortalDayIndicator(theme: theme),
          const SizedBox(width: 24),
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.accent.withValues(alpha: .16),
            child: Icon(
              Icons.business,
              color: theme.accent,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                branchDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                branchId,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          IconButton(
            onPressed: logout,
            icon: Icon(Icons.logout, color: theme.mutedText),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PAGE
  // ==========================================================================

  String _pageTitle() {
    switch (selectedPage) {
      case 1:
        return 'Attendance';
      case 2:
        return 'Employees';
      case 3:
        return 'OT Requests';
      default:
        return 'Dashboard';
    }
  }

  Widget _currentPage() {
    switch (selectedPage) {
      case 1:
        return _attendancePage();
      case 2:
        return _employeesPage();
      case 3:
        return BranchOtRequestsPage(branchId: branchId);
      default:
        return _dashboardPage();
    }
  }

  // ==========================================================================
  // DASHBOARD
  // ==========================================================================

  Widget _dashboardPage() {
    final totalEmployees = employees.length;
    final monthlyAttendance = attendance
        .where((record) =>
            record.date.year == attendanceMonth.year &&
            record.date.month == attendanceMonth.month)
        .toList();
    final lateRecords = monthlyAttendance
        .where((record) => record.status.trim().toLowerCase() == 'late')
        .toList();
    final absentRecords = monthlyAttendance
        .where((record) => record.status.trim().toLowerCase() == 'absent')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF243B8F), width: 1.6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Branch Operations',
                  style: TextStyle(
                    color: Color(0xFF20242D),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$branchDisplayName · Live attendance overview',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                _branchPeriodSelector(),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
              _statCard(
                'Employees',
                totalEmployees.toString(),
                Icons.people,
                const Color(0xFF315AD9),
              ),
              _statCard(
                'Late',
                lateRecords.length.toString(),
                Icons.schedule,
                Colors.orange,
                onTap: () => _showMonthlyAttendanceDetails(
                  title: 'Late Employees',
                  records: lateRecords,
                  late: true,
                ),
              ),
              _statCard(
                'Absent',
                absentRecords.length.toString(),
                Icons.cancel,
                Colors.red,
                onTap: () => _showMonthlyAttendanceDetails(
                  title: 'Absent Employees',
                  records: absentRecords,
                  late: false,
                ),
              ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _branchCelebrationPanels(),
          const SizedBox(height: 24),
          _dashboardAttendanceRegister(),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _branchUpcomingEvents({
    required bool birthday,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = <Map<String, dynamic>>[];
    for (final employee in employees) {
      final original = birthday ? employee.birthday : employee.joiningDate;
      if (original == null || (!birthday && !original.isBefore(today))) {
        continue;
      }
      DateTime occurrence(int year) {
        final lastDay = DateTime(year, original.month + 1, 0).day;
        return DateTime(
            year, original.month, original.day.clamp(1, lastDay).toInt());
      }

      var next = occurrence(today.year);
      if (next.isBefore(today)) next = occurrence(today.year + 1);
      final days = next.difference(today).inDays;
      if (days <= 3) {
        events.add({
          'employee': employee,
          'date': next,
          'days': days,
          'years': birthday ? null : next.year - original.year,
        });
      }
    }
    events.sort((a, b) => (a['date'] as DateTime).compareTo(b['date']));
    return events;
  }

  Widget _branchCelebrationPanels() {
    final birthdays = _branchUpcomingEvents(birthday: true);
    final anniversaries = _branchUpcomingEvents(birthday: false);
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 760;
      final birthdayPanel = _celebrationPanel(
        title: 'Upcoming Birthdays',
        subtitle: 'Celebrations in the next 3 days',
        icon: Icons.cake_outlined,
        color: const Color(0xFFED1C24),
        events: birthdays,
        birthday: true,
      );
      final anniversaryPanel = _celebrationPanel(
        title: 'Work Anniversaries',
        subtitle: 'Milestones in the next 3 days',
        icon: Icons.workspace_premium_outlined,
        color: const Color(0xFF243B8F),
        events: anniversaries,
        birthday: false,
      );
      if (stacked) {
        return Column(children: [
          birthdayPanel,
          const SizedBox(height: 14),
          anniversaryPanel,
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: birthdayPanel),
        const SizedBox(width: 16),
        Expanded(child: anniversaryPanel),
      ]);
    });
  }

  Widget _celebrationPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> events,
    required bool birthday,
  }) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 154),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withValues(alpha: .07)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .45), width: 1.3),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
          ),
          if (events.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('${events.length}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ),
        ]),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const Text('No upcoming celebrations',
              style: TextStyle(color: Colors.black54))
        else
          ...events.map((event) {
            final employee = event['employee'] as Employee;
            final days = event['days'] as int;
            final timing = days == 0
                ? 'Today'
                : days == 1
                    ? 'Tomorrow'
                    : 'In $days days';
            return InkWell(
              onTap: () => _showCelebrationPopup(event, birthday: birthday),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Text(birthday ? '🎂' : '🎉',
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(employee.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text(timing,
                      style: TextStyle(
                          color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ),
            );
          }),
      ]),
    );
    if (events.isEmpty) return content;
    return AnimatedBuilder(
      animation: _celebrationController,
      child: content,
      builder: (context, child) => Transform.scale(
        scale: .995 + (_celebrationController.value * .005),
        child: child,
      ),
    );
  }

  Future<void> _showCelebrationPopup(
    Map<String, dynamic> event, {
    required bool birthday,
  }) {
    final employee = event['employee'] as Employee;
    final years = event['years'] as int?;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Celebration',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 390,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(birthday ? '🎈  🎂  🎈' : '🎊  🏆  🎊',
                  style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 18),
              Text(
                birthday ? 'Happy Birthday!' : 'Work Anniversary!',
                style: TextStyle(
                  color: birthday ? const Color(0xFFED1C24) : const Color(0xFF243B8F),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(employee.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                birthday
                    ? 'Wishing you a wonderful celebration from everyone at Hasani Books.'
                    : 'Congratulations on ${years ?? ''} wonderful year${years == 1 ? '' : 's'} with Hasani Books!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, height: 1.45),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Celebrate'),
              ),
            ]),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.elasticOut);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  Widget _branchPeriodSelector() {
    final currentYear = DateTime.now().year;
    final years = List.generate(8, (index) => currentYear + 1 - index);
    if (!years.contains(attendanceMonth.year)) years.add(attendanceMonth.year);
    years.sort((a, b) => b.compareTo(a));
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<int>(
            initialValue: attendanceMonth.month,
            decoration: const InputDecoration(
              labelText: 'Month',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: List.generate(
              12,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text(DateFormat('MMMM').format(DateTime(2000, index + 1))),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => attendanceMonth =
                    DateTime(attendanceMonth.year, value));
              }
            },
          ),
        ),
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<int>(
            initialValue: attendanceMonth.year,
            decoration: const InputDecoration(
              labelText: 'Year',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: years
                .map((year) => DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => attendanceMonth =
                    DateTime(value, attendanceMonth.month));
              }
            },
          ),
        ),
      ],
    );
  }

  int? _branchClockMinutes(String value) {
    final parts = value.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  String _durationText(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours hr' : '$hours hr $remainder min';
  }

  Future<void> _showMonthlyAttendanceDetails({
    required String title,
    required List<AttendanceRecord> records,
    required bool late,
  }) async {
    final rosterByEmployeeDate = <String, Map<String, dynamic>>{};
    if (late && records.isNotEmpty) {
      final ids = records.map((record) => record.employeeId).toSet();
      final start = DateTime(attendanceMonth.year, attendanceMonth.month);
      final end = DateTime(attendanceMonth.year, attendanceMonth.month + 1);
      final results = await Future.wait(ids.map((id) =>
          SupabaseService.getDailyRosters(
              branchId: branch?.branchId ?? branchId,
              employeeId: id,
              start: start,
              end: end)));
      for (final rows in results) {
        for (final row in rows) {
          final key = '${row['employee_id'].toString().toUpperCase()}|'
              '${row['roster_date'].toString().split('T').first}';
          rosterByEmployeeDate[key] = row;
        }
      }
    }
    if (!mounted) return;

    final grouped = <String, List<AttendanceRecord>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.employeeId, () => []).add(record);
    }
    final ids = grouped.keys.toList()
      ..sort((a, b) {
        final aName = service.findEmployee(a)?.name ?? a;
        final bName = service.findEmployee(b)?.name ?? b;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .72,
        minChildSize: .45,
        maxChildSize: .94,
        builder: (context, controller) => Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Icon(late ? Icons.schedule : Icons.cancel_outlined,
                  color: late ? Colors.orange : Colors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$title · ${DateFormat('MMMM yyyy').format(attendanceMonth)}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close),
              ),
            ]),
            const SizedBox(height: 10),
            Expanded(
              child: ids.isEmpty
                  ? const Center(child: Text('No attendance records found.'))
                  : ListView.separated(
                      controller: controller,
                      itemCount: ids.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final id = ids[index];
                        final employeeRecords = grouped[id]!
                          ..sort((a, b) => a.date.compareTo(b.date));
                        final name = service.findEmployee(id)?.name ?? id;
                        return ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                          title: Text(name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(late
                              ? '${employeeRecords.length} late occurrence${employeeRecords.length == 1 ? '' : 's'}'
                              : '${employeeRecords.length} absent day${employeeRecords.length == 1 ? '' : 's'}'),
                          children: employeeRecords.map((record) {
                            String detail;
                            if (late) {
                              final key = '${record.employeeId.toUpperCase()}|'
                                  '${DateFormat('yyyy-MM-dd').format(record.date)}';
                              final shiftStart = _branchClockMinutes(
                                  rosterByEmployeeDate[key]?['shift_start']
                                          ?.toString() ??
                                      '');
                              final actual =
                                  _branchClockMinutes(record.effectiveCheckIn);
                              final minutes = actual != null && shiftStart != null
                                  ? (actual - shiftStart).clamp(0, 1440)
                                  : null;
                              detail = minutes == null
                                  ? 'Check-in ${record.effectiveCheckIn.isEmpty ? 'not recorded' : record.effectiveCheckIn} · late duration unavailable'
                                  : 'Check-in ${record.effectiveCheckIn} · ${_durationText(minutes)} late';
                            } else {
                              detail = 'Absent';
                            }
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.calendar_today_outlined,
                                  size: 18),
                              title: Text(
                                  DateFormat('EEE, dd MMM yyyy').format(record.date)),
                              trailing: Text(detail,
                                  style: TextStyle(
                                      color: late ? Colors.orange : Colors.red,
                                      fontWeight: FontWeight.w700)),
                            );
                          }).toList(),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // ==========================================================================
  // LIVE EMPLOYEES
  // ==========================================================================

  Widget _dashboardAttendanceRegister() {
    final resolvedBranchId = branch?.branchId ?? branchId;
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([
        _liveBranchEmployees(),
        SupabaseService.getAttendanceByBranch(resolvedBranchId)
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 280, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _panel(
              'Monthly Attendance Register',
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Unable to load register: ${snapshot.error}')));
        }
        final staff = List<Map<String, dynamic>>.from(snapshot.data![0] as List)
          ..sort(
            (a, b) => _liveEmployeeId(a)
                .trim()
                .toUpperCase()
                .compareTo(_liveEmployeeId(b).trim().toUpperCase()),
          );
        final ids = staff
            .map(_liveEmployeeId)
            .map((id) => id.trim().toUpperCase())
            .toSet();
        final rows = List<Map<String, dynamic>>.from(snapshot.data![1] as List)
            .where((row) {
          final date =
              DateTime.tryParse(row['attendance_date']?.toString() ?? '');
          final id = row['employee_id']?.toString().trim().toUpperCase() ?? '';
          return date != null &&
              date.year == attendanceMonth.year &&
              date.month == attendanceMonth.month &&
              ids.contains(id);
        }).toList();
        return _panel(
            'Monthly Attendance Register',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(
                        '${DateFormat('MMMM yyyy').format(attendanceMonth)} • ${staff.length} employees',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: attendanceMonth,
                          firstDate: DateTime(2022),
                          lastDate: DateTime(DateTime.now().year + 2),
                          helpText: 'Select register month');
                      if (picked != null && mounted) {
                        setState(() => attendanceMonth =
                            DateTime(picked.year, picked.month));
                      }
                    },
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('Change Month')),
              ]),
              const SizedBox(height: 8),
              const Wrap(spacing: 12, runSpacing: 4, children: [
                Text('✓ = Present', style: TextStyle(fontSize: 10)),
                Text('L = Late', style: TextStyle(fontSize: 10)),
                Text('O = Off', style: TextStyle(fontSize: 10)),
                Text('MC = Medical', style: TextStyle(fontSize: 10)),
                Text('AL/PL/EL = Leave', style: TextStyle(fontSize: 10)),
                Text('PH = Public Holiday', style: TextStyle(fontSize: 10))
              ]),
              const SizedBox(height: 10),
              SizedBox(height: 350, child: _dashboardRegisterGrid(staff, rows)),
            ]));
      },
    );
  }

  Widget _dashboardRegisterGrid(
      List<Map<String, dynamic>> staff, List<Map<String, dynamic>> rows) {
    final days =
        DateUtils.getDaysInMonth(attendanceMonth.year, attendanceMonth.month);
    final records = <String, Map<int, Map<String, dynamic>>>{};
    for (final row in rows) {
      final id = row['employee_id']?.toString().trim().toUpperCase() ?? '';
      final date = DateTime.tryParse(row['attendance_date']?.toString() ?? '');
      if (id.isNotEmpty && date != null) {
        records.putIfAbsent(id, () => {})[date.day] = row;
      }
    }
    Widget cell(String value, double width,
            {bool header = false, Color? color}) =>
        Container(
            width: width,
            height: header ? 43 : 34,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
                color: header ? const Color(0xFFF0F1F3) : Colors.white,
                border: const Border(
                    right: BorderSide(color: Colors.black54, width: .5),
                    bottom: BorderSide(color: Colors.black54, width: .5))),
            child: Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: header ? 8 : 9,
                    fontWeight: header ? FontWeight.w800 : FontWeight.w700,
                    color: color)));
    final header = Row(mainAxisSize: MainAxisSize.min, children: [
      cell('NAME', 155, header: true),
      cell('ID', 72, header: true),
      for (var day = 1; day <= days; day++)
        cell(
            '${DateFormat('E').format(DateTime(attendanceMonth.year, attendanceMonth.month, day))[0]}\n$day',
            28,
            header: true),
      cell('✓', 30, header: true),
      cell('L', 30, header: true),
      cell('O', 30, header: true),
      cell('LV', 30, header: true),
      cell('DS', 30, header: true)
    ]);
    return Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.black87)),
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
                height: 348,
                child: Column(children: [
                  header,
                  Expanded(
                      child: SingleChildScrollView(
                          child: Column(
                              children: staff.map((employee) {
                    final id = _liveEmployeeId(employee).trim().toUpperCase();
                    final employeeRows =
                        records[id] ?? const <int, Map<String, dynamic>>{};
                    final codes = <String>[
                      for (var day = 1; day <= days; day++)
                        _dashboardStatusCode(employeeRows[day])
                    ];
                    final p = codes.where((c) => c == '✓').length;
                    final l = codes.where((c) => c == 'L' || c == 'L/E').length;
                    final o = codes.where((c) => c == 'O').length;
                    final lv = codes
                        .where((c) => const {'MC', 'AL', 'PL', 'EL', 'PH', 'U'}
                            .contains(c))
                        .length;
                    return InkWell(
                        onTap: () => setState(() => selectedPage = 1),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          cell(employee['name']?.toString() ?? id, 155),
                          cell(id, 72),
                          for (final code in codes)
                            cell(
                              code,
                              28,
                              color: code.isEmpty
                                  ? null
                                  : code == '✓'
                                      ? const Color(0xFF15965D)
                                      : const Color(0xFFD32F2F),
                            ),
                          cell('$p', 30),
                          cell('$l', 30),
                          cell('$o', 30),
                          cell('$lv', 30),
                          cell('${p + l}', 30)
                        ]));
                  }).toList())))
                ]))));
  }

  String _dashboardStatusCode(Map<String, dynamic>? row) {
    final status = row?['status']?.toString().trim().toUpperCase() ?? '';
    return const {
          'PRESENT': '✓',
          'LATE': 'L',
          'LATE + EARLY OUT': 'L/E',
          'EARLY OUT': 'EO',
          'OFF': 'O',
          'UNPAID': 'U'
        }[status] ??
        status;
  }

  String _liveEmployeeId(
    Map<String, dynamic> employee,
  ) {
    return (employee['employee_id'] ?? employee['id'] ?? '').toString();
  }

  bool _liveIsActive(
    Map<String, dynamic> employee,
  ) {
    final value = employee['is_active'];

    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  // ==========================================================================
  // ATTENDANCE PAGE
  // ==========================================================================

  Widget _attendancePage() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _liveBranchEmployees(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 45,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load employees:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    onPressed: _refreshEmployees,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final liveEmployees = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${liveEmployees.length} employees for $branchDisplayName',
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    'Attendance Month: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: attendanceMonth,
                        firstDate: DateTime(2022),
                        lastDate: DateTime(
                          DateTime.now().year + 2,
                        ),
                        helpText: 'Select any date in the attendance month',
                      );

                      if (picked != null && mounted) {
                        setState(() {
                          attendanceMonth = DateTime(
                            picked.year,
                            picked.month,
                          );
                        });
                      }
                    },
                    icon: const Icon(
                      Icons.calendar_month,
                    ),
                    label: Text(
                      DateFormat(
                        'MMMM yyyy',
                      ).format(attendanceMonth),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Daily Summary: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedAttendanceDate,
                        firstDate: DateTime(2022),
                        lastDate: DateTime(DateTime.now().year + 2),
                      );
                      if (picked != null && mounted) {
                        setState(() => selectedAttendanceDate = picked);
                      }
                    },
                    icon: const Icon(Icons.today_outlined),
                    label: Text(DateFormat('dd MMM yyyy')
                        .format(selectedAttendanceDate)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _dailyAttendanceSummary(liveEmployees),
              const SizedBox(height: 12),
              _panel(
                'Select Employee',
                liveEmployees.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No employees matched branch: '
                          '$branchId',
                        ),
                      )
                    : Column(
                        children: liveEmployees.map(
                          (employee) {
                            final name =
                                employee['name']?.toString() ?? 'Employee';

                            final id = _liveEmployeeId(
                              employee,
                            );

                            final department =
                                employee['department']?.toString() ?? '';

                            final active = _liveIsActive(
                              employee,
                            );

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(
                                  0xFFE7F7EF,
                                ),
                                child: Text(
                                  name.isEmpty ? '?' : name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(
                                      0xFF15965D,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  id,
                                  department,
                                ]
                                    .where(
                                      (v) => v.isNotEmpty,
                                    )
                                    .join(' • '),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(
                                      active ? 'Active' : 'Inactive',
                                    ),
                                    backgroundColor: active
                                        ? const Color(
                                            0xFFE7F7EF,
                                          )
                                        : Colors.black12,
                                  ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  const Icon(
                                    Icons.edit_calendar_outlined,
                                  ),
                                ],
                              ),
                              onTap: () => _openAttendanceSheet(
                                employee,
                              ),
                            );
                          },
                        ).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dailyAttendanceSummary(List<Map<String, dynamic>> employees) {
    final resolvedBranchId = branch?.branchId ?? branchId;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.getAttendanceByBranchDate(
        branchId: resolvedBranchId,
        date: selectedAttendanceDate,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final visibleIds = employees
            .where(_liveIsActive)
            .map(_liveEmployeeId)
            .map((id) => id.trim().toUpperCase())
            .toSet();
        final rows = (snapshot.data ?? const <Map<String, dynamic>>[])
            .where((row) => visibleIds.contains(
                  row['employee_id']?.toString().trim().toUpperCase(),
                ))
            .toList();
        final presentIds = <String>{};
        final lateIds = <String>{};
        for (final row in rows) {
          final id = row['employee_id']?.toString().trim().toUpperCase() ?? '';
          final status = row['status']?.toString().trim().toLowerCase() ?? '';
          final hasWork =
              row['working_in']?.toString().trim().isNotEmpty == true &&
                  row['working_out']?.toString().trim().isNotEmpty == true;
          if (status == 'late') {
            lateIds.add(id);
          } else if (status == 'present' || (status.isEmpty && hasWork)) {
            presentIds.add(id);
          }
        }
        final activeCount = employees.where(_liveIsActive).length;
        final absent = (activeCount - presentIds.length - lateIds.length)
            .clamp(0, activeCount);
        return Row(
          children: [
            Expanded(
                child: _summaryCard(
                    'Present', presentIds.length, const Color(0xFF15965D))),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Absent', absent, Colors.red)),
            const SizedBox(width: 10),
            Expanded(
                child: _summaryCard('Late', lateIds.length, Colors.orange)),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ==========================================================================
  // OPEN ATTENDANCE DIALOG
  // ==========================================================================

  Future<void> _openAttendanceSheet(
    Map<String, dynamic> employee,
  ) async {
    final employeeId = _liveEmployeeId(employee);
    final employeeName = employee['name']?.toString() ?? 'Employee';
    final resolvedBranchId = branch?.branchId ?? branchId;
    final activityId = await SupabaseService.startBranchActivity(
      branchId: isFrnSession
          ? service.currentUser?.branchId ??
              service.currentUser?.username ??
              '$resolvedBranchId FRN'
          : resolvedBranchId,
      action: 'ATTENDANCE_OPENED',
      employeeId: employeeId,
      employeeName: employeeName,
      details: {
        'month': DateFormat('yyyy-MM').format(attendanceMonth),
      },
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AttendanceDialog(
          employee: employee,
          month: attendanceMonth,
          branchId: branchId,
          editable: true,
          showSubmitButton: true,
        );
      },
    );

    await SupabaseService.closeBranchActivity(activityId);

    if (mounted) {
      setState(() {});
    }
  }

  // ==========================================================================
  // ATTENDANCE TILE
  // ==========================================================================

  Widget _attendanceTile(
    AttendanceRecord record,
  ) {
    final employee = service.employeeById(
      record.employeeId,
    );

    Color color;

    switch (record.status) {
      case 'Present':
        color = const Color(0xFF15965D);
        break;
      case 'Late':
        color = Colors.orange;
        break;
      case 'Absent':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(
            record.status == 'Present'
                ? Icons.check
                : record.status == 'Late'
                    ? Icons.schedule
                    : Icons.close,
            color: color,
          ),
        ),
        title: Text(
          employee?.name ?? record.employeeId,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${record.employeeId}\n'
          '${DateFormat('dd MMM yyyy').format(record.date)} • '
          '${record.checkIn} - ${record.checkOut}',
        ),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(
              20,
            ),
          ),
          child: Text(
            record.status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // EMPLOYEES
  // ==========================================================================

  Widget _employeesPage() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _liveBranchEmployees(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 45,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load employees:\n'
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    onPressed: _refreshEmployees,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final allEmployees = snapshot.data ?? [];
        final search = _employeeSearch.trim().toLowerCase();
        final liveEmployees = (search.isEmpty
            ? List<Map<String, dynamic>>.from(allEmployees)
            : allEmployees.where((employee) {
                return [
                  employee['employee_id'],
                  employee['name'],
                  employee['department'],
                  employee['designation'],
                  employee['email'],
                ].any((value) =>
                    value?.toString().toLowerCase().contains(search) == true);
              }).toList())
          ..sort(
            (a, b) => _liveEmployeeId(a)
                .trim()
                .toUpperCase()
                .compareTo(_liveEmployeeId(b).trim().toUpperCase()),
          );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Branch Employees',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _refreshEmployees,
                    tooltip: 'Refresh approved employees',
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: _showAddBranchEmployee,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Request Employee'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${allEmployees.length} employees assigned to $branchDisplayName',
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _employeeSearchController,
                onChanged: (value) => setState(() => _employeeSearch = value),
                decoration: InputDecoration(
                  hintText:
                      'Search employee by name, ID, department or designation',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _employeeSearch.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _employeeSearchController.clear();
                            setState(() => _employeeSearch = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _panel(
                'Employee List',
                liveEmployees.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No employees match your search.',
                          ),
                        ),
                      )
                    : Column(
                        children: liveEmployees.map(
                          (employee) {
                            final name =
                                employee['name']?.toString() ?? 'Employee';

                            final id = _liveEmployeeId(
                              employee,
                            );

                            final department =
                                employee['department']?.toString() ?? '';

                            final active = _liveIsActive(
                              employee,
                            );

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(
                                  0xFFE7F7EF,
                                ),
                                child: Text(
                                  name.isEmpty ? '?' : name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(
                                      0xFF15965D,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  id,
                                  department,
                                ]
                                    .where(
                                      (v) => v.isNotEmpty,
                                    )
                                    .join(' • '),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(active ? 'Active' : 'Inactive'),
                                    backgroundColor: active
                                        ? const Color(0xFFE7F7EF)
                                        : Colors.black12,
                                  ),
                                  IconButton(
                                    tooltip: 'Edit employee',
                                    onPressed: () =>
                                        _showEditBranchEmployee(employee),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ],
                              ),
                            );
                          },
                        ).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddBranchEmployee() async {
    await _showBranchEmployeeEditor();
  }

  Future<void> _showEditBranchEmployee(
    Map<String, dynamic> employee,
  ) async {
    await _showBranchEmployeeEditor(employee: employee);
  }

  Future<void> _showBranchEmployeeEditor({
    Map<String, dynamic>? employee,
  }) async {
    final editing = employee != null;
    final employeeId = TextEditingController(
      text: employee?['employee_id']?.toString() ?? '',
    );
    final name = TextEditingController(
      text: employee?['name']?.toString() ?? '',
    );
    final designation = TextEditingController(
      text: employee?['designation']?.toString() ?? '',
    );
    final department = TextEditingController(
      text: employee?['department']?.toString() ?? '',
    );
    final email = TextEditingController(
      text: employee?['email']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: employee?['phone']?.toString() ?? '',
    );
    final newIcNo = TextEditingController(
      text: employee?['new_ic_no']?.toString() ?? '',
    );
    final bankCode = TextEditingController(
      text: employee?['bank_code']?.toString() ?? '',
    );
    final bankAccount = TextEditingController(
      text: employee?['bank_account']?.toString() ?? '',
    );
    final address = TextEditingController(
      text: employee?['address']?.toString() ?? '',
    );
    var active = employee == null || _liveIsActive(employee);
    var joiningDate = DateTime.tryParse(
          employee?['joining_date']?.toString() ?? '',
        ) ??
        DateTime.now();
    var saving = false;
    String? error;
    final resolvedBranchId = branch?.branchId ?? branchId;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editing ? 'Edit Employee' : 'Request New Employee'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (editing) ...[
                    TextFormField(
                      controller: employeeId,
                      enabled: false,
                      decoration:
                          const InputDecoration(labelText: 'Employee ID'),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const Text(
                      'Admin will verify this information and assign the Employee ID after approval.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _branchEmployeeField(name, 'Full Name *', enabled: !saving),
                  _branchEmployeeField(designation, 'Designation',
                      enabled: !saving),
                  _branchEmployeeField(department, 'Department',
                      enabled: !saving),
                  _branchEmployeeField(email, 'Email', enabled: !saving),
                  _branchEmployeeField(newIcNo, 'New IC No.', enabled: !saving),
                  _branchEmployeeField(bankCode, 'Bank Code', enabled: !saving),
                  _branchEmployeeField(bankAccount, 'Bank Account',
                      enabled: !saving),
                  _branchEmployeeField(phone, 'Phone', enabled: !saving),
                  _branchEmployeeField(address, 'Address', enabled: !saving),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Joining Date'),
                    subtitle:
                        Text(DateFormat('dd MMM yyyy').format(joiningDate)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: saving
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDate: joiningDate,
                            );
                            if (picked != null) {
                              setDialogState(() => joiningDate = picked);
                            }
                          },
                  ),
                  if (editing)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active employee'),
                      subtitle: Text(active
                          ? 'Employee is visible as active'
                          : 'Employee is marked inactive'),
                      value: active,
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => active = value),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final id = employeeId.text.trim().toUpperCase();
                      final employeeName = name.text.trim();
                      if ((editing && id.isEmpty) || employeeName.isEmpty) {
                        setDialogState(() {
                          error = editing
                              ? 'Employee ID and full name are required.'
                              : 'Full name is required.';
                        });
                        return;
                      }

                      setDialogState(() {
                        saving = true;
                        error = null;
                      });

                      final values = <String, dynamic>{
                        'name': employeeName,
                        'designation': designation.text.trim(),
                        'department': department.text.trim(),
                        'email': email.text.trim(),
                        'new_ic_no': newIcNo.text.trim(),
                        'bank_code': bankCode.text.trim(),
                        'bank_account': bankAccount.text.trim(),
                        'phone': phone.text.trim(),
                        'address': address.text.trim(),
                        'joining_date':
                            DateFormat('yyyy-MM-dd').format(joiningDate),
                        'is_active': active,
                      };

                      try {
                        if (editing) {
                          await SupabaseService.updateEmployeeForBranch(
                            employeeId: id,
                            branchId: resolvedBranchId,
                            changes: values,
                          );
                        } else {
                          await SupabaseService.submitEmployeeRequest(
                            branchId: resolvedBranchId,
                            employee: values,
                          );
                        }

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        _refreshEmployees();
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(editing
                                  ? 'Employee updated successfully.'
                                  : 'Employee request sent to admin for approval.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            error = 'Unable to save employee: $e';
                          });
                        }
                      }
                    },
              child: Text(saving
                  ? 'Saving...'
                  : editing
                      ? 'Update Employee'
                      : 'Send Request'),
            ),
          ],
        ),
      ),
    );

    employeeId.dispose();
    name.dispose();
    designation.dispose();
    department.dispose();
    email.dispose();
    phone.dispose();
    newIcNo.dispose();
    bankCode.dispose();
    bankAccount.dispose();
    address.dispose();
  }

  Widget _branchEmployeeField(
    TextEditingController controller,
    String label, {
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  // ==========================================================================
  // OLD EMPLOYEE TILE
  // ==========================================================================

  Widget _employeeTile(
    Employee employee,
  ) {
    final records = service.employeeAttendance(
      employee.employeeId,
    );

    final present = records
        .where(
          (r) => r.status == 'Present',
        )
        .length;

    final late = records
        .where(
          (r) => r.status == 'Late',
        )
        .length;

    final absent = records
        .where(
          (r) => r.status == 'Absent',
        )
        .length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            employee.name.trim().isEmpty
                ? '?'
                : employee.name.trim().substring(0, 1).toUpperCase(),
          ),
        ),
        title: Text(
          employee.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${employee.employeeId} • '
          '${employee.designation}\n'
          'Present: $present • '
          'Late: $late • '
          'Absent: $absent',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(
            Icons.visibility_outlined,
          ),
          onPressed: () {
            _showEmployeeAttendance(
              employee,
            );
          },
        ),
        onTap: () {
          _showEmployeeAttendance(
            employee,
          );
        },
      ),
    );
  }

  // ==========================================================================
  // EMPLOYEE ATTENDANCE
  // ==========================================================================

  void _showEmployeeAttendance(
    Employee employee,
  ) {
    final records = service.employeeAttendance(
      employee.employeeId,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(employee.name),
          content: SizedBox(
            width: 650,
            height: 500,
            child: records.isEmpty
                ? const Center(
                    child: Text(
                      'No attendance records.',
                    ),
                  )
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];

                      return Card(
                        margin: const EdgeInsets.only(
                          bottom: 10,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(
                                      record.date,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    record.status,
                                    style: TextStyle(
                                      color: record.status == 'Present'
                                          ? Colors.blue
                                          : record.status == 'Late'
                                              ? Colors.orange
                                              : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              _attendanceInfoRow(
                                'Work Check In',
                                record.checkIn,
                                Icons.login,
                              ),
                              _attendanceInfoRow(
                                'Work Check Out',
                                record.checkOut,
                                Icons.logout,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _attendanceInfoRow(
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 3,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.black54,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STAT CARD
  // ==========================================================================

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 220,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: .65)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 11),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF20242D),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6,
                      ),
                    ),
                  ],
                ),
              if (onTap != null) ...[
                const Spacer(),
                Icon(Icons.arrow_outward, size: 15, color: color),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PANEL
  // ==========================================================================

  Widget _panel(
    String title,
    Widget child,
  ) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FAFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF243B8F).withValues(alpha: .3)),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 32,
            top: 34,
            bottom: 34,
            child: Opacity(
              opacity: .035,
              child: Image.asset(
                'assets/hasani_books_logo.jpg',
                width: 420,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 10,
            child: IgnorePointer(
              child: Text(
                branchDisplayName.toUpperCase(),
                style: const TextStyle(
                  color: Color(0x0D243B8F),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF243B8F), Color(0xFFED1C24)],
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF20242D),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF243B8F).withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storefront_outlined,
                              size: 14, color: Color(0xFF243B8F)),
                          const SizedBox(width: 6),
                          Text(
                            branchDisplayName,
                            style: const TextStyle(
                              color: Color(0xFF243B8F),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ACTION BUTTON
  // ==========================================================================

  Widget _actionButton(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF243B8F).withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF243B8F).withValues(alpha: .55),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: const Color(0xFFED1C24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF20242D),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
