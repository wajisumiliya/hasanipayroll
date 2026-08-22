import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payroll.dart';
import '../services/app_service.dart';
import 'login_screen.dart';
import 'supabase_service.dart';

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

  Future<List<Map<String, dynamic>>>? _employeesFuture;
  String? _employeesFutureBranchId;

  String get branchId => service.currentUser?.branchId ?? '';

  Branch? get branch => service.branchById(branchId);

  List<Employee> get employees => service.branchEmployees(branchId);

  List<AttendanceRecord> get attendance =>
      service.branchAttendance(branchId);

  List<AttendanceRecord> get todayAttendance =>
      service.branchTodayAttendance(branchId);

  // ==========================================================================
  // EMPLOYEE FUTURE
  // ==========================================================================

  Future<List<Map<String, dynamic>>> _liveBranchEmployees() {
    if (_employeesFuture == null ||
        _employeesFutureBranchId != branchId) {
      _employeesFutureBranchId = branchId;

      _employeesFuture = SupabaseService.getEmployeesByBranch(
        branchId,
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
            branch?.branchName ?? 'Branch',
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
            branch?.branchName ?? 'Branch',
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
                branch?.branchName ?? 'Branch',
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
    final present = service.presentCount(branchId);
    final late = service.lateCount(branchId);
    final absent = service.absentCount(branchId);

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
            branch?.branchName ?? 'Branch',
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
                '${liveEmployees.length} employees for '
                    '${branch?.branchName ?? branchId}',
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

  // ==========================================================================
  // OPEN ATTENDANCE DIALOG
  // ==========================================================================

  void _openAttendanceSheet(
      Map<String, dynamic> employee,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AttendanceDialog(
          employee: employee,
          month: attendanceMonth,
          branchId: branchId,
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
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

        final liveEmployees =
            snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Branch Employees',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${liveEmployees.length} employees assigned to '
                    '${branch?.branchName ?? branchId}',
                style: const TextStyle(
                  color: Colors.black54,
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
                      'No employees found.',
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
                        trailing: Chip(
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
                              : Colors.black12,
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

// ============================================================================
// ATTENDANCE DIALOG
// ============================================================================

class AttendanceDialog extends StatefulWidget {
  const AttendanceDialog({
    super.key,
    required this.employee,
    required this.month,
    required this.branchId,
  });

  final Map<String, dynamic> employee;
  final DateTime month;
  final String branchId;

  @override
  State<AttendanceDialog> createState() =>
      _AttendanceDialogState();
}

class _AttendanceDialogState
    extends State<AttendanceDialog> {
  late final List<AttendanceDayControllers>
  controllers;

  late final int daysInMonth;

  bool loading = true;
  bool saving = false;
  String? loadError;

  // ==========================================================================
  // INIT / DISPOSE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    daysInMonth = DateUtils.getDaysInMonth(
      widget.month.year,
      widget.month.month,
    );

    controllers = List.generate(
      daysInMonth,
          (_) => AttendanceDayControllers(),
    );

    _loadAttendance();
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // ==========================================================================
  // EMPLOYEE HELPERS
  // ==========================================================================

  String _employeeId() {
    return (
        widget.employee['employee_id'] ??
            widget.employee['id'] ??
            ''
    ).toString();
  }

  String _employeeName() {
    return widget.employee['name']?.toString() ??
        'Employee';
  }

  String _department() {
    return widget.employee['department']
        ?.toString() ??
        '';
  }

  String _section() {
    return widget.employee['section']?.toString() ??
        '';
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() ==
        'true';
  }

  // ==========================================================================
  // LOAD ATTENDANCE
  // ==========================================================================

  Future<void> _loadAttendance() async {
    try {
      final employeeId = _employeeId();

      if (employeeId.trim().isEmpty) {
        throw Exception(
          'Employee ID is missing.',
        );
      }

      final rows =
      await SupabaseService
          .getAttendanceByEmployeeMonth(
        employeeId,
        widget.month.year,
        widget.month.month,
      );

      for (final row in rows) {
        final date = DateTime.tryParse(
          (row['attendance_date'] ?? '')
              .toString(),
        );

        if (date == null) continue;

        if (date.year != widget.month.year ||
            date.month != widget.month.month) {
          continue;
        }

        if (date.day < 1 ||
            date.day > daysInMonth) {
          continue;
        }

        final c = controllers[date.day - 1];

        c.workingIn.text = (
            row['check_in'] ??
                row['working_in'] ??
                ''
        ).toString();

        c.workingOut.text = (
            row['check_out'] ??
                row['working_out'] ??
                ''
        ).toString();

        c.morningIn.text =
            (row['morning_in'] ?? '').toString();

        c.morningOut.text =
            (row['morning_out'] ?? '').toString();

        c.afternoonIn.text =
            (row['afternoon_in'] ?? '').toString();

        c.afternoonOut.text =
            (row['afternoon_out'] ?? '').toString();

        // IMPORTANT:
        // These database columns are kept for compatibility,
        // but the UI treats them as EVENING BREAK.
        c.overtimeIn.text =
            (row['overtime_in'] ?? '').toString();

        c.overtimeOut.text =
            (row['overtime_out'] ?? '').toString();

        c.otAuthorized =
            _toBool(row['ot_authorized']);
      }
    } catch (e) {
      loadError = e.toString();
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Dialog(
        child: SizedBox(
          width: 400,
          height: 250,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (loadError != null) {
      return Dialog(
        child: SizedBox(
          width: 450,
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 55,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Unable to load attendance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  loadError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: saving
                          ? null
                          : () {
                        Navigator.of(
                          context,
                        ).pop();
                      },
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () {
                        setState(() {
                          loading = true;
                          loadError = null;
                        });

                        _loadAttendance();
                      },
                      icon: const Icon(
                        Icons.refresh,
                      ),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      child: SizedBox(
        width: 1250,
        height:
        MediaQuery.of(context).size.height *
            .94,
        child: Column(
          children: [
            _attendanceDialogHeader(),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child:
                      _workingAttendanceCard(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child:
                      _breakAttendanceCard(),
                    ),
                  ],
                ),
              ),
            ),

            // FIXED:
            // No positional arguments are passed.
            _attendanceSummary(),

            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration:
              const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    child: const Text('Close'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed:
                    saving ? null : _saveAttendance,
                    icon: saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.save),
                    label: Text(
                      saving
                          ? 'Saving...'
                          : 'Save Attendance',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SAVE ATTENDANCE
  // ==========================================================================

  Future<void> _saveAttendance() async {
    if (saving) return;

    final employeeId = _employeeId();

    if (employeeId.trim().isEmpty) {
      _showError(
        'Cannot save attendance: employee ID is missing.',
      );
      return;
    }

    final employeeBranchId = (
        widget.employee['branch_id'] ??
            widget.employee['branchId'] ??
            widget.branchId
    ).toString();

    setState(() {
      saving = true;
    });

    var savedRows = 0;

    try {
      for (var day = 1;
      day <= daysInMonth;
      day++) {
        final row = controllers[day - 1];

        if (!row.hasData) {
          continue;
        }

        // ================================================================
        // VALIDATE TIME INPUTS
        // ================================================================

        final timeFields = <String, String>{
          'Working In': row.workingIn.text,
          'Working Out': row.workingOut.text,
          'Morning In': row.morningIn.text,
          'Morning Out': row.morningOut.text,
          'Afternoon In':
          row.afternoonIn.text,
          'Afternoon Out':
          row.afternoonOut.text,

          // Kept as overtime_in/out in database,
          // but used as EVENING BREAK.
          'Evening In': row.overtimeIn.text,
          'Evening Out': row.overtimeOut.text,
        };

        for (final entry
        in timeFields.entries) {
          final value = entry.value.trim();

          if (value.isNotEmpty &&
              parseTimeToMinutes(value) ==
                  null) {
            throw Exception(
              'Invalid ${entry.key} time on '
                  '${DateFormat('dd MMM yyyy').format(
                DateTime(
                  widget.month.year,
                  widget.month.month,
                  day,
                ),
              )}. '
                  'Use HH:MM, e.g. 08:30.',
            );
          }
        }

        // ================================================================
        // CALCULATE WORK
        // ================================================================

        final workMinutes =
        calculateWorkMinutes(row);

        // ================================================================
        // CALCULATE BREAKS
        // ================================================================

        final morningMinutes =
        calculateMinutes(
          row.morningIn.text,
          row.morningOut.text,
        );

        final afternoonMinutes =
        calculateMinutes(
          row.afternoonIn.text,
          row.afternoonOut.text,
        );

        // IMPORTANT:
        // EVENING / OT COLUMN IS A BREAK.
        // It is NOT overtime.
        final eveningBreakMinutes =
        calculateMinutes(
          row.overtimeIn.text,
          row.overtimeOut.text,
        );

        final breakMinutes =
            morningMinutes +
                afternoonMinutes +
                eveningBreakMinutes;

        // ================================================================
        // SAVE
        // ================================================================

        await SupabaseService
            .saveMonthlyAttendanceRow(
          employeeId: employeeId,
          branchId: employeeBranchId,
          date: DateTime(
            widget.month.year,
            widget.month.month,
            day,
          ),

          // WORK
          workingIn:
          row.workingIn.text.trim(),
          workingOut:
          row.workingOut.text.trim(),

          // MORNING BREAK
          morningIn:
          row.morningIn.text.trim(),
          morningOut:
          row.morningOut.text.trim(),

          // AFTERNOON BREAK
          afternoonIn:
          row.afternoonIn.text.trim(),
          afternoonOut:
          row.afternoonOut.text.trim(),

          // EVENING BREAK
          //
          // Database column names remain overtime_in/out
          // for compatibility with the existing schema.
          overtimeIn:
          row.overtimeIn.text.trim(),
          overtimeOut:
          row.overtimeOut.text.trim(),

          // Do NOT treat evening as overtime.
          // Authorization is retained only for compatibility.
          otAuthorized:
          false,

          // CALCULATED
          workMinutes:
          workMinutes,
          breakMinutes:
          breakMinutes,
        );

        savedRows++;
      }

      if (savedRows == 0) {
        throw Exception(
          'Please enter attendance in at least one date row.',
        );
      }

      if (!mounted) return;

      setState(() {
        saving = false;
      });

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      _showError(
        'Attendance was NOT saved:\n$e',
      );
    }
  }

  // ==========================================================================
  // ERROR MESSAGE
  // ==========================================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
        content: Text(message),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _attendanceDialogHeader() {
    final name = _employeeName();
    final id = _employeeId();
    final department = _department();
    final section = _section();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      color: const Color(0xFF15965D),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              color: Color(0xFF15965D),
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    id,
                    department,
                    section,
                  ]
                      .where(
                        (v) => v.isNotEmpty,
                  )
                      .join(' • '),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat(
              'MMMM yyyy',
            ).format(widget.month),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WORK ATTENDANCE
  // ==========================================================================

  Widget _workingAttendanceCard() {
    const blue = Color(0xFF15965D);

    return _attendanceTableCard(
      title: 'WORK ATTENDANCE',
      color: blue,
      child: Column(
        children: [
          _workHeader(blue),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: daysInMonth,
                itemBuilder: (
                    context,
                    index,
                    ) {
                  final day = index + 1;
                  final c = controllers[index];

                  return _workRow(
                    day,
                    c,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workHeader(Color color) {
    return Container(
      height: 42,
      color: const Color(0xFFE7F7EF),
      child: Row(
        children: [
          _headerCell(
            'DATE',
            55,
            color,
          ),
          _headerCell(
            'CHECK IN',
            115,
            color,
          ),
          _headerCell(
            'CHECK OUT',
            115,
            color,
          ),
          _headerCell(
            'TOTAL',
            100,
            color,
          ),
          Expanded(
            child: Container(
              height: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: color,
                  ),
                ),
              ),
              child: const Text(
                'REMARK',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workRow(
      int day,
      AttendanceDayControllers c,
      ) {
    final total = calculateWorkMinutes(c);

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _tableCell(
            day.toString(),
            55,
            bold: true,
          ),
          _timeInput(
            c.workingIn,
            115,
          ),
          _timeInput(
            c.workingOut,
            115,
          ),
          _tableCell(
            formatMinutes(total),
            100,
            bold: true,
            color: total > 0
                ? const Color(0xFF15965D)
                : Colors.black54,
          ),
          Expanded(
            child: Container(
              height: double.infinity,
              alignment: Alignment.center,
              decoration:
              const BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Color(0xFF15965D),
                  ),
                  bottom: BorderSide(
                    color: Color(0xFF15965D),
                  ),
                ),
              ),
              child: Text(
                total > 0 ? 'RECORDED' : '-',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: total > 0
                      ? const Color(0xFF15965D)
                      : Colors.black38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BREAK ATTENDANCE
  // ==========================================================================

  Widget _breakAttendanceCard() {
    const red = Color(0xFF315AD9);

    return _attendanceTableCard(
      title: 'BREAK ATTENDANCE',
      color: red,
      child: Column(
        children: [
          _breakHeader(red),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: daysInMonth,
                itemBuilder: (
                    context,
                    index,
                    ) {
                  final day = index + 1;
                  final c = controllers[index];

                  // FIXED:
                  // _breakRow takes exactly 2 arguments.
                  return _breakRow(
                    day,
                    c,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakHeader(Color color) {
    return Column(
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              _headerCell(
                'DATE',
                45,
                color,
              ),
              Expanded(
                child: _groupHeader(
                  'MORNING',
                  color,
                ),
              ),
              Expanded(
                child: _groupHeader(
                  'AFTERNOON',
                  color,
                ),
              ),
              Expanded(
                child: _groupHeader(
                  'EVENING BREAK',
                  color,
                ),
              ),
              _headerCell(
                'TOTAL',
                80,
                color,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 34,
          child: Row(
            children: [
              _headerCell(
                '',
                45,
                color,
              ),
              Expanded(
                child: _subHeader(
                  'IN',
                  color,
                ),
              ),
              Expanded(
                child: _subHeader(
                  'OUT',
                  color,
                ),
              ),
              Expanded(
                child: _subHeader(
                  'IN',
                  color,
                ),
              ),
              Expanded(
                child: _subHeader(
                  'OUT',
                  color,
                ),
              ),
              Expanded(
                child: _subHeader(
                  'IN',
                  color,
                ),
              ),
              Expanded(
                child: _subHeader(
                  'OUT',
                  color,
                ),
              ),
              _headerCell(
                '',
                80,
                color,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // BREAK ROW
  // ==========================================================================

  Widget _breakRow(
      int day,
      AttendanceDayControllers c,
      ) {
    final morning = calculateMinutes(
      c.morningIn.text,
      c.morningOut.text,
    );

    final afternoon = calculateMinutes(
      c.afternoonIn.text,
      c.afternoonOut.text,
    );

    // IMPORTANT:
    // overtimeIn/out are used for EVENING BREAK.
    // They are NEVER added to overtime.
    final evening = calculateMinutes(
      c.overtimeIn.text,
      c.overtimeOut.text,
    );

    final breakTotal =
        morning +
            afternoon +
            evening;

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _tableCell(
            day.toString(),
            45,
            bold: true,
          ),

          // ==============================================================
          // MORNING BREAK
          // ==============================================================

          Expanded(
            child: _smallTimeInput(
              c.morningIn,
            ),
          ),

          Expanded(
            child: _smallTimeInput(
              c.morningOut,
            ),
          ),

          // ==============================================================
          // AFTERNOON BREAK
          // ==============================================================

          Expanded(
            child: _smallTimeInput(
              c.afternoonIn,
            ),
          ),

          Expanded(
            child: _smallTimeInput(
              c.afternoonOut,
            ),
          ),

          // ==============================================================
          // EVENING BREAK
          //
          // IMPORTANT:
          // These use overtimeIn/overtimeOut because the database already
          // has those columns. They are DISPLAYED as Evening Break and
          // CALCULATED as break time.
          // ==============================================================

          Expanded(
            child: _smallTimeInput(
              c.overtimeIn,
            ),
          ),

          Expanded(
            child: _smallTimeInput(
              c.overtimeOut,
            ),
          ),

          // ==============================================================
          // TOTAL BREAK
          // ==============================================================

          Container(
            width: 80,
            height: double.infinity,
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Color(0xFF315AD9),
                ),
                bottom: BorderSide(
                  color: Color(0xFF315AD9),
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              formatMinutes(breakTotal),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF315AD9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TABLE CARD
  // ==========================================================================

  Widget _attendanceTableCard({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: color,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 44,
            width: double.infinity,
            color: color,
            alignment: Alignment.center,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TABLE HELPERS
  // ==========================================================================

  Widget _headerCell(
      String text,
      double width,
      Color color,
      ) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: color,
          ),
          bottom: BorderSide(
            color: color,
          ),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _groupHeader(
      String text,
      Color color,
      ) {
    return Container(
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        border: Border(
          right: BorderSide(
            color: color,
          ),
          bottom: BorderSide(
            color: color,
          ),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _subHeader(
      String text,
      Color color,
      ) {
    return Container(
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: color,
          ),
          bottom: BorderSide(
            color: color,
          ),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _tableCell(
      String text,
      double width, {
        bool bold = false,
        Color? color,
      }) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration:
      const BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Color(0xFF15965D),
          ),
          bottom: BorderSide(
            color: Color(0xFF15965D),
          ),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: bold
              ? FontWeight.w800
              : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  Widget _timeInput(
      TextEditingController controller,
      double width,
      ) {
    return Container(
      width: width,
      height: double.infinity,
      decoration:
      const BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Color(0xFF15965D),
          ),
          bottom: BorderSide(
            color: Color(0xFF15965D),
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) {
          if (mounted) {
            setState(() {});
          }
        },
        textAlign: TextAlign.center,
        keyboardType: TextInputType.datetime,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        decoration:
        const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding:
          EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 10,
          ),
          hintText: '--:--',
          hintStyle: TextStyle(
            fontSize: 10,
            color: Colors.black26,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SMALL BREAK TIME INPUT
  //
  // FIXED:
  // This accepts ONLY the controller.
  // It rebuilds the dialog on every change so the break total and
  // monthly summary update immediately.
  // ==========================================================================

  Widget _smallTimeInput(
      TextEditingController controller,
      ) {
    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Color(0xFF315AD9),
          ),
          bottom: BorderSide(
            color: Color(0xFF315AD9),
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) {
          if (mounted) {
            setState(() {});
          }
        },
        textAlign: TextAlign.center,
        keyboardType: TextInputType.datetime,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding:
          EdgeInsets.symmetric(
            horizontal: 1,
            vertical: 11,
          ),
          hintText: '--:--',
          hintStyle: TextStyle(
            fontSize: 9,
            color: Colors.black26,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // ATTENDANCE SUMMARY
  // ==========================================================================

  Widget _attendanceSummary() {
    var workTotal = 0;
    var breakTotal = 0;

    for (var i = 0;
    i < daysInMonth;
    i++) {
      final c = controllers[i];

      // WORK
      workTotal += calculateWorkMinutes(c);

      // MORNING BREAK
      breakTotal += calculateMinutes(
        c.morningIn.text,
        c.morningOut.text,
      );

      // AFTERNOON BREAK
      breakTotal += calculateMinutes(
        c.afternoonIn.text,
        c.afternoonOut.text,
      );

      // EVENING BREAK
      //
      // This is intentionally NOT overtime.
      breakTotal += calculateMinutes(
        c.overtimeIn.text,
        c.overtimeOut.text,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        border: Border.all(
          color: Colors.black12,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'MONTHLY TOTAL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 20),
            _summaryChip(
              'WORK',
              formatMinutes(workTotal),
              const Color(0xFF15965D),
            ),
            const SizedBox(width: 10),
            _summaryChip(
              'BREAK',
              formatMinutes(breakTotal),
              const Color(0xFF315AD9),
            ),
            const SizedBox(width: 10),

            // Evening/OT is a break, therefore OT is ZERO.
            _summaryChip(
              'OVERTIME',
              '00:00',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(
      String title,
      String value,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$title: ',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TIME CALCULATIONS
  // ==========================================================================

  int calculateWorkMinutes(
      AttendanceDayControllers c,
      ) {
    return calculateMinutes(
      c.workingIn.text,
      c.workingOut.text,
    );
  }

  int calculateMinutes(
      String start,
      String end,
      ) {
    final startMinutes =
    parseTimeToMinutes(start);

    final endMinutes =
    parseTimeToMinutes(end);

    if (startMinutes == null ||
        endMinutes == null) {
      return 0;
    }

    var difference =
        endMinutes - startMinutes;

    // Overnight shift.
    if (difference < 0) {
      difference += 24 * 60;
    }

    return difference;
  }

  int? parseTimeToMinutes(
      String value,
      ) {
    final text = value.trim();

    if (text.isEmpty) {
      return null;
    }

    final match = RegExp(
      r'^(\d{1,2})\s*[:.]\s*(\d{1,2})$',
    ).firstMatch(text);

    if (match == null) {
      return null;
    }

    final hour = int.tryParse(
      match.group(1)!,
    );

    final minute = int.tryParse(
      match.group(2)!,
    );

    if (hour == null ||
        minute == null) {
      return null;
    }

    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return hour * 60 + minute;
  }

  String formatMinutes(
      int minutes,
      ) {
    if (minutes <= 0) {
      return '00:00';
    }

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${mins.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// ATTENDANCE DAY CONTROLLERS
// ============================================================================

class AttendanceDayControllers {
  final TextEditingController workingIn =
  TextEditingController();

  final TextEditingController workingOut =
  TextEditingController();

  final TextEditingController morningIn =
  TextEditingController();

  final TextEditingController morningOut =
  TextEditingController();

  final TextEditingController afternoonIn =
  TextEditingController();

  final TextEditingController afternoonOut =
  TextEditingController();

  // ==========================================================================
  // IMPORTANT:
  // These names remain "overtime" ONLY because your existing database uses
  // overtime_in / overtime_out.
  //
  // In the Branch Portal they are now treated as:
  //
  //     EVENING BREAK IN
  //     EVENING BREAK OUT
  //
  // They are NOT calculated as overtime.
  // ==========================================================================

  final TextEditingController overtimeIn =
  TextEditingController();

  final TextEditingController overtimeOut =
  TextEditingController();

  bool otAuthorized = false;

  bool get hasData {
    return workingIn.text.trim().isNotEmpty ||
        workingOut.text.trim().isNotEmpty ||
        morningIn.text.trim().isNotEmpty ||
        morningOut.text.trim().isNotEmpty ||
        afternoonIn.text.trim().isNotEmpty ||
        afternoonOut.text.trim().isNotEmpty ||
        overtimeIn.text.trim().isNotEmpty ||
        overtimeOut.text.trim().isNotEmpty;
  }

  void dispose() {
    workingIn.dispose();
    workingOut.dispose();

    morningIn.dispose();
    morningOut.dispose();

    afternoonIn.dispose();
    afternoonOut.dispose();

    overtimeIn.dispose();
    overtimeOut.dispose();
  }
}
