import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payroll.dart';
import '../services/app_service.dart';
import 'login_screen.dart';
import 'supabase_service.dart';
import 'attendance_dialog.dart';

// ============================================================================
// BRANCH PORTAL
// ============================================================================

class BranchPortal extends StatefulWidget {
  const BranchPortal({super.key});

  @override
  State<BranchPortal> createState() => _BranchPortalState();
}

class _BranchPortalState extends State<BranchPortal> {
  final AppService service = AppService.instance;

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

  @override
  void dispose() {
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

  List<Employee> get employees => service.branchEmployees(branchId).where((employee) {
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
    return Row(
      children: [
        _sidebar(),
        Expanded(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F7FB),
                  child: _currentPage(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // MOBILE
  // ==========================================================================

  Widget _mobile() {
    return Scaffold(
      appBar: AppBar(
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
      body: Container(
        color: const Color(0xFFF5F7FB),
        child: _currentPage(),
      ),
    );
  }

  // ==========================================================================
  // SIDEBAR
  // ==========================================================================

  Widget _sidebar() {
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          _sidebarHeader(),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: 10,
              ),
              children: [
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
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/hasani_books_logo.jpg',
            width: 160,
            errorBuilder: (
                context,
                error,
                stackTrace,
                ) {
              return const Text(
                'HASANI BOOKS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D55D8),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'BRANCH PORTAL',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF15965D),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            branchDisplayName,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
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
        horizontal: 10,
        vertical: 2,
      ),
      child: ListTile(
        selected: selected,
        selectedTileColor: const Color(0xFFE7F7EF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: Icon(
          icon,
          color: selected
              ? const Color(0xFF15965D)
              : Colors.black54,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected
                ? FontWeight.bold
                : FontWeight.normal,
            color: selected
                ? const Color(0xFF15965D)
                : Colors.black87,
          ),
        ),
        onTap: () {
          setState(() {
            selectedPage = page;
          });
        },
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
      selectedTileColor: const Color(0xFFE7F7EF),
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
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 28,
      ),
      child: Row(
        children: [
          Text(
            _pageTitle().toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFE7F7EF),
            child: Icon(
              Icons.business,
              color: Color(0xFF15965D),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                branchId,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
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
      default:
        return _dashboardPage();
    }
  }

  // ==========================================================================
  // DASHBOARD
  // ==========================================================================

  Widget _dashboardPage() {
    final totalEmployees = employees.length;
    final present = todayAttendance
        .where((record) => record.status.trim().toLowerCase() == 'present')
        .length;
    final late = todayAttendance
        .where((record) => record.status.trim().toLowerCase() == 'late')
        .length;
    final absent = todayAttendance
        .where((record) => record.status.trim().toLowerCase() == 'absent')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Branch Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            branchDisplayName,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _statCard(
                'Employees',
                totalEmployees.toString(),
                Icons.people,
                const Color(0xFF315AD9),
              ),
              _statCard(
                'Present',
                present.toString(),
                Icons.check_circle,
                const Color(0xFF15965D),
              ),
              _statCard(
                'Late',
                late.toString(),
                Icons.schedule,
                Colors.orange,
              ),
              _statCard(
                'Absent',
                absent.toString(),
                Icons.cancel,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _panel(
            'Quick Actions',
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _actionButton(
                  'Record Attendance',
                  Icons.fact_check,
                      () {
                    setState(() {
                      selectedPage = 1;
                    });
                  },
                ),
                _actionButton(
                  'Employees',
                  Icons.people,
                      () {
                    setState(() {
                      selectedPage = 2;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _panel(
            "Today's Attendance",
            _todayAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _todayAttendanceList() {
    if (todayAttendance.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No attendance recorded today.',
          ),
        ),
      );
    }

    return Column(
      children: todayAttendance
          .map(
            (record) => _attendanceTile(record),
      )
          .toList(),
    );
  }

  // ==========================================================================
  // LIVE EMPLOYEES
  // ==========================================================================

  String _liveEmployeeId(
      Map<String, dynamic> employee,
      ) {
    return (
        employee['employee_id'] ??
            employee['id'] ??
            ''
    ).toString();
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
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
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
            crossAxisAlignment:
            CrossAxisAlignment.start,
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
                      final picked =
                      await showDatePicker(
                        context: context,
                        initialDate: attendanceMonth,
                        firstDate: DateTime(2022),
                        lastDate: DateTime(
                          DateTime.now().year + 2,
                        ),
                        helpText:
                        'Select any date in the attendance month',
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
                    label: Text(DateFormat('dd MMM yyyy').format(selectedAttendanceDate)),
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
                  padding:
                  const EdgeInsets.all(24),
                  child: Text(
                    'No employees matched branch: '
                        '$branchId',
                  ),
                )
                    : Column(
                  children:
                  liveEmployees.map(
                        (employee) {
                      final name =
                          employee['name']
                              ?.toString() ??
                              'Employee';

                      final id =
                      _liveEmployeeId(
                        employee,
                      );

                      final department =
                          employee['department']
                              ?.toString() ??
                              '';

                      final active =
                      _liveIsActive(
                        employee,
                      );

                      return ListTile(
                        leading:
                        CircleAvatar(
                          backgroundColor:
                          const Color(
                            0xFFE7F7EF,
                          ),
                          child: Text(
                            name.isEmpty
                                ? '?'
                                : name[0]
                                .toUpperCase(),
                            style:
                            const TextStyle(
                              color: Color(
                                0xFF15965D,
                              ),
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          [
                            id,
                            department,
                          ]
                              .where(
                                (v) =>
                            v.isNotEmpty,
                          )
                              .join(' • '),
                        ),
                        trailing: Row(
                          mainAxisSize:
                          MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(
                                active
                                    ? 'Active'
                                    : 'Inactive',
                              ),
                              backgroundColor:
                              active
                                  ? const Color(
                                0xFFE7F7EF,
                              )
                                  : Colors
                                  .black12,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            const Icon(
                              Icons
                                  .edit_calendar_outlined,
                            ),
                          ],
                        ),
                        onTap: () =>
                            _openAttendanceSheet(
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
          final hasWork = row['working_in']?.toString().trim().isNotEmpty == true &&
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
            Expanded(child: _summaryCard('Present', presentIds.length, const Color(0xFF15965D))),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Absent', absent, Colors.red)),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard('Late', lateIds.length, Colors.orange)),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        children: [
          Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
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
          backgroundColor: color.withOpacity(.12),
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
            color: color.withOpacity(.10),
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
    return FutureBuilder<
        List<Map<String, dynamic>>>(
      future: _liveBranchEmployees(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
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
        final liveEmployees = search.isEmpty
            ? allEmployees
            : allEmployees.where((employee) {
                return [
                  employee['employee_id'],
                  employee['name'],
                  employee['department'],
                  employee['designation'],
                  employee['email'],
                ].any((value) =>
                    value?.toString().toLowerCase().contains(search) == true);
              }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
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
                  hintText: 'Search employee by name, ID, department or designation',
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
                  children:
                  liveEmployees.map(
                        (employee) {
                      final name =
                          employee['name']
                              ?.toString() ??
                              'Employee';

                      final id =
                      _liveEmployeeId(
                        employee,
                      );

                      final department =
                          employee['department']
                              ?.toString() ??
                              '';

                      final active =
                      _liveIsActive(
                        employee,
                      );

                      return ListTile(
                        leading:
                        CircleAvatar(
                          backgroundColor:
                          const Color(
                            0xFFE7F7EF,
                          ),
                          child: Text(
                            name.isEmpty
                                ? '?'
                                : name[0]
                                .toUpperCase(),
                            style:
                            const TextStyle(
                              color: Color(
                                0xFF15965D,
                              ),
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          [
                            id,
                            department,
                          ]
                              .where(
                                (v) =>
                            v.isNotEmpty,
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
                              onPressed: () => _showEditBranchEmployee(employee),
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
                      decoration: const InputDecoration(labelText: 'Employee ID'),
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
                  _branchEmployeeField(designation, 'Designation', enabled: !saving),
                  _branchEmployeeField(department, 'Department', enabled: !saving),
                  _branchEmployeeField(email, 'Email', enabled: !saving),
                  _branchEmployeeField(newIcNo, 'New IC No.', enabled: !saving),
                  _branchEmployeeField(bankCode, 'Bank Code', enabled: !saving),
                  _branchEmployeeField(bankAccount, 'Bank Account', enabled: !saving),
                  _branchEmployeeField(phone, 'Phone', enabled: !saving),
                  _branchEmployeeField(address, 'Address', enabled: !saving),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Joining Date'),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(joiningDate)),
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
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
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
                        'joining_date': DateFormat('yyyy-MM-dd').format(joiningDate),
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
                : employee.name
                .trim()
                .substring(0, 1)
                .toUpperCase(),
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
              itemBuilder:
                  (context, index) {
                final record =
                records[index];

                return Card(
                  margin:
                  const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.all(
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              DateFormat(
                                'dd MMM yyyy',
                              ).format(
                                record.date,
                              ),
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              record.status,
                              style: TextStyle(
                                color:
                                record.status ==
                                    'Present'
                                    ? Colors.blue
                                    : record.status ==
                                    'Late'
                                    ? Colors.orange
                                    : Colors.red,
                                fontWeight:
                                FontWeight.bold,
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
      Color color,
      ) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          child,
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
          color: const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.black12,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: const Color(0xFF15965D),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
