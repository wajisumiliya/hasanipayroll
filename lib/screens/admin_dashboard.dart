import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/payroll.dart';
import '../services/app_service.dart';
import '../services/attendance_payroll_service.dart';
import 'login_screen.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import '../screens/supabase_service.dart';
import '../screens/attendance_dialog.dart';




class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AppService service = AppService.instance;

  int selectedPage = 0;

  /// Dashboard flashcard currently selected.
  ///
  /// null = no flashcard filter selected.
  /// departments
  /// branches
  /// vacation
  /// active
  /// new_joiner
  String? selectedDashboardCard;

  String? selectedAttendanceBranchId;
  DateTime selectedAttendanceMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final List<String> months = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    service.addListener(_refresh);
  }

  @override
  void dispose() {
    service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;

    setState(() {});
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void changePage(int page) {
    setState(() {
      selectedPage = page;

      if (page != 0) {
        selectedDashboardCard = null;
      }
    });
  }

  String _pageTitle() {
    switch (selectedPage) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Employees';
      case 2:
        return 'Payroll';
      case 3:
        return 'Attendance';
      case 4:
        return 'Import CSV';
      case 5:
        return 'Import Payroll';
      case 6:
        return 'Reports';
      case 7:
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }


Widget _statusChip(String status) {
  final normalizedStatus = status.trim().toLowerCase();

  Color backgroundColor;
  Color textColor;

  switch (normalizedStatus) {
    case 'active':
    case 'approved':
    case 'present':
      backgroundColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      break;

    case 'inactive':
    case 'rejected':
    case 'absent':
      backgroundColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      break;

    case 'pending':
    case 'leave':
      backgroundColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
      break;

    default:
      backgroundColor = Colors.grey.shade100;
      textColor = Colors.grey.shade700;
  }

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 5,
    ),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status.isEmpty ? 'Unknown' : status,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}


  Widget _currentPage() {
    switch (selectedPage) {
      case 0:
        return _dashboardPage();

      case 1:
        return _employeesPage();

      case 2:
        return _payrollPage();

      case 3:
        return _attendancePage();

      case 4:
        return _importPage();

      case 5:
        return _importPayrollPage();

      case 6:
        return _reportsPage();

      case 7:
        return _settingsPage();

      default:
        return _dashboardPage();
    }
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

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

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 850) {
            return _desktopLayout();
          }

          return _mobileLayout();
        },
      ),
    );
  }

  // ===========================================================================
  // DESKTOP LAYOUT
  // ===========================================================================

  Widget _desktopLayout() {
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

  // ===========================================================================
  // MOBILE LAYOUT
  // ===========================================================================

  Widget _mobileLayout() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          _pageTitle(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              _drawerHeader(),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _drawerItem(
                      'Dashboard',
                      Icons.dashboard_outlined,
                      0,
                    ),
                    _drawerItem(
                      'Employees',
                      Icons.people_outline,
                      1,
                    ),
                    _drawerItem(
                      'Payroll',
                      Icons.payments_outlined,
                      2,
                    ),
                    _drawerItem(
                      'Attendance',
                      Icons.access_time,
                      3,
                    ),
                    _drawerItem(
                      'Import CSV',
                      Icons.upload_file_outlined,
                      4,
                    ),
                    _drawerItem(
                        'Import Payroll',
                        Icons.upload_file_outlined,
                        5
                    ),
                    _drawerItem(
                      'Reports',
                      Icons.bar_chart_outlined,
                      6,
                    ),
                    _drawerItem(
                      'Settings',
                      Icons.settings_outlined,
                      7,
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

  // ===========================================================================
  // SIDEBAR
  // ===========================================================================

  Widget _sidebar() {
    return Container(
      width: 245,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Column(
        children: [
          _drawerHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _sidebarItem(
                  'Dashboard',
                  Icons.dashboard_outlined,
                  0,
                ),
                _sidebarItem(
                  'Employees',
                  Icons.people_outline,
                  1,
                ),
                _sidebarItem(
                  'Payroll',
                  Icons.payments_outlined,
                  2,
                ),
                _sidebarItem(
                  'Attendance',
                  Icons.access_time,
                  3,
                ),
                _sidebarItem(
                  'Import CSV',
                  Icons.upload_file_outlined,
                  4,
                ),
                _sidebarItem(
                  'Import Payroll',
                  Icons.upload_file_outlined,
                  5,
                ),
                _sidebarItem(
                  'Reports',
                  Icons.bar_chart_outlined,
                  6,
                ),
                _sidebarItem(
                  'Settings',
                  Icons.settings_outlined,
                  7,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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
          const SizedBox(height: 8),
          const Text(
            'Â© Hasani Books Edar Sdn Bhd - 2026',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _drawerHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/hasani_books_logo.jpg',
            width: 160,
            errorBuilder: (context, error, stackTrace) {
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
            'PAYROLL PORTAL',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D55D8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Administrator',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(String title,
      IconData icon,
      int page,) {
    final bool selected = selectedPage == page;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 2,
      ),
      child: ListTile(
        selected: selected,
        selectedTileColor: const Color(0xFFEAF0FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: Icon(
          icon,
          color: selected
              ? const Color(0xFF2D55D8)
              : Colors.black54,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight:
            selected ? FontWeight.bold : FontWeight.normal,
            color: selected
                ? const Color(0xFF2D55D8)
                : Colors.black87,
          ),
        ),
        onTap: () {
          changePage(page);
        },
      ),
    );
  }

  Widget _drawerItem(String title,
      IconData icon,
      int page,) {
    return ListTile(
      selected: selectedPage == page,
      selectedTileColor: const Color(0xFFEAF0FF),
      leading: Icon(
        icon,
        color: selectedPage == page
            ? const Color(0xFF2D55D8)
            : Colors.black54,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selectedPage == page
              ? FontWeight.bold
              : FontWeight.normal,
          color: selectedPage == page
              ? const Color(0xFF2D55D8)
              : Colors.black87,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        changePage(page);
      },
    );
  }

  // ===========================================================================
  // TOP BAR
  // ===========================================================================

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
            backgroundColor: Color(0xFFEAF0FF),
            child: Icon(
              Icons.admin_panel_settings,
              color: Color(0xFF2D55D8),
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin User',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Administrator',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DASHBOARD
  // ===========================================================================

  Future<void> _changeEmployeeStatus(
    Map<String, dynamic> employee,
    bool isActive,
  ) async {
    final employeeId = employee['id'] ?? employee['employee_id'];
    if (employeeId == null) {
      throw Exception('Employee ID was not found.');
    }

    await SupabaseService.updateEmployeeStatus(
      employeeId: employeeId,
      isActive: isActive,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${employee['name'] ?? 'Employee'} is now '
          '${isActive ? 'Active' : 'Inactive'}',
        ),
      ),
    );
  }

  void _showEmployeeDetails(
    String title,
    List<Map<String, dynamic>> employees,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            String filter = 'all';
            List<Map<String, dynamic>> filtered() {
              if (filter == 'active') {
                return employees.where(_isActive).toList();
              }
              if (filter == 'inactive') {
                return employees.where((e) => !_isActive(e)).toList();
              }
              return employees;
            }

            final list = filtered();
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .82,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'all',
                            label: Text('All'),
                            icon: Icon(Icons.people),
                          ),
                          ButtonSegment(
                            value: 'active',
                            label: Text('Active'),
                            icon: Icon(Icons.check_circle),
                          ),
                          ButtonSegment(
                            value: 'inactive',
                            label: Text('Inactive'),
                            icon: Icon(Icons.person_off),
                          ),
                        ],
                        selected: {filter},
                        onSelectionChanged: (value) {
                          setSheetState(() => filter = value.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(child: Text('No employees found.'))
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (_, index) {
                                final employee = list[index];
                                final active = _isActive(employee);
                                final name =
                                    employee['name']?.toString() ?? 'Employee';
                                final employeeCode =
                                    employee['employee_id']?.toString() ?? '-';
                                final department =
                                    employee['department']?.toString() ?? '';
                                final branch =
                                    employee['branch_id']?.toString() ??
                                    employee['branch']?.toString() ??
                                    '';

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 5,
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        employeeCode,
                                        department,
                                        branch,
                                      ].where((v) => v.isNotEmpty).join(' • '),
                                    ),
                                    trailing: PopupMenuButton<bool>(
                                      tooltip: 'Change status',
                                      onSelected: (value) async {
                                        if (value == active) return;
                                        try {
                                          await _changeEmployeeStatus(
                                            employee,
                                            value,
                                          );
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Status update failed: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: true,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: active
                                                    ? Colors.green
                                                    : Colors.grey,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Set Active'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: false,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.person_off,
                                                color: !active
                                                    ? Colors.orange
                                                    : Colors.grey,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Set Inactive'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      child: Chip(
                                        label: Text(
                                          active ? 'Active' : 'Inactive',
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadDashboardData() async {
    final results = await Future.wait([
      SupabaseService.getEmployees(),
      SupabaseService.getPayroll(),
    ]);

    return {
      'employees': results[0] as List<Map<String, dynamic>>,
      'payroll': results[1] as List<Map<String, dynamic>>,
    };
  }

  bool _isActive(Map<String, dynamic> employee) {
    final value = employee['is_active'];
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  double _number(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }

  void _showDepartmentFlow(List<Map<String, dynamic>> employees) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final employee in employees) {
      final name = (employee['department'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      groups.putIfAbsent(name, () => []).add(employee);
    }
    final names = groups.keys.toList()..sort();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .82,
          child: Column(children: [
            ListTile(
              title: const Text('Departments', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              subtitle: Text('${names.length} department(s)'),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            const Divider(height: 1),
            Expanded(child: names.isEmpty
                ? const Center(child: Text('No departments found.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 130, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    itemCount: names.length,
                    itemBuilder: (_, index) {
                      final name = names[index];
                      final list = groups[name]!;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () { Navigator.pop(context); _showEmployeeDetails(name, list); },
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.business_center_outlined, color: Color(0xFF8B5CF6)),
                              const Spacer(),
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('${list.length} staff'),
                            ]),
                          ),
                        ),
                      );
                    },
                  )),
          ]),
        ),
      ),
    );
  }

  String _branchLabel(Map<String, dynamic> employee) {
    final value = employee['branch_name'] ?? employee['branch'] ?? employee['branch_id'] ?? 'Unassigned';
    final text = value.toString().trim();
    return text.isEmpty ? 'Unassigned' : text;
  }

  void _showBranchFlow(List<Map<String, dynamic>> employees) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final employee in employees) {
      final name = _branchLabel(employee);
      groups.putIfAbsent(name, () => []).add(employee);
    }
    final names = groups.keys.toList()..sort();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .82,
          child: Column(children: [
            ListTile(
              title: const Text('Branches', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              subtitle: Text('${names.length} branch(es)'),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            const Divider(height: 1),
            Expanded(child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 130, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: names.length,
              itemBuilder: (_, index) {
                final name = names[index]; final list = groups[name]!;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () { Navigator.pop(context); _showEmployeeDetails(name, list); },
                  child: Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.account_tree_outlined, color: Color(0xFFEF4444)),
                      const Spacer(),
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4), Text('${list.length} employee(s)'),
                    ]),
                  )),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  void _showPayrollFlow(
    List<Map<String, dynamic>> employees,
    List<Map<String, dynamic>> payroll, {
    required String title,
    required String metric,
  }) {
    final now = DateTime.now();
    int? selectedYear;
    int? selectedMonth;
    String? selectedBranch;
    final branches = employees.map(_branchLabel).toSet().toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final years = List<int>.generate(now.year - 2022 + 1, (i) => now.year - i);
          final branchEmployees = selectedBranch == null
              ? <Map<String, dynamic>>[]
              : employees.where((e) => _branchLabel(e) == selectedBranch).toList();
          return SafeArea(child: SizedBox(
            height: MediaQuery.of(context).size.height * .88,
            child: Column(children: [
              ListTile(
                title: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                subtitle: const Text('Select Year â†’ Month â†’ Branch â†’ Employees'),
                trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
              ),
              const Divider(height: 1),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('1. Select Year', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: years.map((year) => ChoiceChip(
                    label: Text(year.toString()), selected: selectedYear == year,
                    onSelected: (_) => setSheetState(() { selectedYear = year; selectedMonth = null; selectedBranch = null; }),
                  )).toList()),
                  if (selectedYear != null) ...[
                    const SizedBox(height: 24), const Text('2. Select Month', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 10, children: List.generate(12, (i) => ChoiceChip(
                      label: Text(DateFormat('MMMM').format(DateTime(selectedYear!, i + 1))), selected: selectedMonth == i + 1,
                      onSelected: (_) => setSheetState(() { selectedMonth = i + 1; selectedBranch = null; }),
                    ))),
                  ],
                  if (selectedMonth != null) ...[
                    const SizedBox(height: 24), const Text('3. Select Branch', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 10, children: branches.map((branch) => ChoiceChip(
                      label: Text(branch), selected: selectedBranch == branch,
                      onSelected: (_) => setSheetState(() => selectedBranch = branch),
                    )).toList()),
                  ],
                  if (selectedBranch != null) ...[
                    const SizedBox(height: 24), Text('4. Employees â€” $selectedBranch', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 10),
                    if (branchEmployees.isEmpty) const Text('No employees found for this branch.') else
                    ...branchEmployees.map((employee) {
                      final name = (employee['name'] ?? 'Employee').toString();
                      final code = (employee['employee_id'] ?? employee['id'] ?? '').toString();
                      return Card(child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(name), subtitle: Text(code),
                        trailing: metric == 'generate'
                            ? ElevatedButton(onPressed: () { Navigator.pop(sheetContext); changePage(2); }, child: const Text('Generate'))
                            : Text(metric == 'net' ? 'Net' : 'Gross', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ));
                    }),
                  ],
                ]),
              )),
            ]),
          ));
        },
      ),
    );
  }

  Widget _dashboardPage() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadDashboardData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Unable to load dashboard: ${snapshot.error}'),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final employees =
            data['employees'] as List<Map<String, dynamic>>? ?? [];
        final payroll =
            data['payroll'] as List<Map<String, dynamic>>? ?? [];

        final activeEmployees =
            employees.where(_isActive).length;
        final inactiveEmployees =
            employees.length - activeEmployees;

        final departments = employees
            .map((e) => e['department']?.toString().trim() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .length;

        final branches = employees
            .map((e) => e['branch_id']?.toString().trim() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .length;

        final totalGross = payroll.fold<double>(
          0,
          (sum, p) => sum +
              _number(p['total_earnings'] ??
                  p['gross_salary'] ??
                  p['gross_pay'] ??
                  p['totalGross']),
        );

        final totalNet = payroll.fold<double>(
          0,
          (sum, p) => sum +
              _number(p['net_pay'] ??
                  p['net_salary'] ??
                  p['total_net'] ??
                  p['netPay']),
        );

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payroll Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Live data from Supabase',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _statCard('Employees', employees.length.toString(),
                        Icons.people, const Color(0xFF315AD9), () => _showEmployeeDetails('All Employees', employees)),
                    _statCard('Active Employees',
                        activeEmployees.toString(), Icons.verified_user,
                        const Color(0xFF15965D), () => _showEmployeeDetails('Active Employees', employees.where(_isActive).toList())),
                    _statCard('Inactive Employees',
                        inactiveEmployees.toString(), Icons.person_off,
                        Colors.orange, () => _showEmployeeDetails('Inactive Employees', employees.where((e) => !_isActive(e)).toList())),
                    _statCard('Departments', departments.toString(),
                        Icons.business_center_outlined,
                        const Color(0xFF8B5CF6),
                        () => _showDepartmentFlow(employees)),
                    _statCard('Branches', branches.toString(),
                        Icons.account_tree_outlined,
                        const Color(0xFFEF4444),
                        () => _showBranchFlow(employees)),
                    _statCard('Payroll Records', payroll.length.toString(),
                        Icons.receipt_long, const Color(0xFF8B5CF6),
                        () => _showPayrollFlow(employees, payroll,
                            title: 'Payroll Records', metric: 'generate')),
                    _statCard('Net Payroll', _money(totalNet),
                        Icons.payments, const Color(0xFF15965D),
                        () => _showPayrollFlow(employees, payroll,
                            title: 'Net Payroll', metric: 'net')),
                    _statCard('Gross Payroll', _money(totalGross),
                        Icons.account_balance_wallet,
                        const Color(0xFF315AD9),
                        () => _showPayrollFlow(employees, payroll,
                            title: 'Gross Payroll', metric: 'gross')),
                  ],
                ),
                const SizedBox(height: 25),
                _panel(
                  'Administrator Actions',
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _actionButton('Employees', Icons.people,
                          () => changePage(1)),
                      _actionButton('Payroll', Icons.payments,
                          () => changePage(2)),
                      _actionButton('Attendance', Icons.access_time,
                          () => changePage(3)),
                      _actionButton('Import CSV', Icons.upload_file,
                          () => changePage(4)),
                      _actionButton('Reports', Icons.bar_chart,
                          () => changePage(6)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _panel(
                  'Payroll Summary',
                  Column(
                    children: [
                      _reportRow('Total Gross', _money(totalGross)),
                      _reportRow('Total Net', _money(totalNet)),
                      _reportRow('Employees', employees.length.toString()),
                      _reportRow('Active Employees',
                          activeEmployees.toString()),
                      _reportRow('Inactive Employees',
                          inactiveEmployees.toString()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // ADMIN FLASHCARD
  // ===========================================================================

  Widget _dashboardFlashCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String cardKey,
    required double width,
  }) {
    final bool selected = selectedDashboardCard == cardKey;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              if (selectedDashboardCard == cardKey) {
                selectedDashboardCard = null;
              } else {
                selectedDashboardCard = cardKey;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color : Colors.transparent,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? color.withOpacity(0.15)
                      : const Color(0x08000000),
                  blurRadius: selected ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.keyboard_arrow_up
                      : Icons.chevron_right,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FLASHCARD DATA CALCULATIONS
  // ===========================================================================

  int _departmentCount() {
    final Set<String> departments = {};

    for (final employee in service.employeesDemo) {
      final department = employee.department.trim();

      if (department.isNotEmpty) {
        departments.add(department.toLowerCase());
      }
    }

    return departments.length;
  }

  List<Employee> _employeesForDepartment(String department,) {
    return service.employeesDemo.where((employee) {
      return employee.department.trim().toLowerCase() ==
          department.trim().toLowerCase();
    }).toList();
  }

  List<Employee> _newJoiners() {
    final now = DateTime.now();

    final sixMonthsAgo = DateTime(
      now.year,
      now.month - 6,
      now.day,
    );

    return service.employeesDemo.where((employee) {
      final joiningDate = employee.joiningDate;

      if (joiningDate == null) {
        return false;
      }

      final dateOnly = DateTime(
        joiningDate.year,
        joiningDate.month,
        joiningDate.day,
      );

      final today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      return !dateOnly.isBefore(sixMonthsAgo) &&
          !dateOnly.isAfter(today);
    }).toList()
      ..sort((a, b) {
        final aDate = a.joiningDate;
        final bDate = b.joiningDate;

        if (aDate == null && bDate == null) {
          return 0;
        }

        if (aDate == null) {
          return 1;
        }

        if (bDate == null) {
          return -1;
        }

        return bDate.compareTo(aDate);
      });
  }

  Set<String> _vacationEmployeeIds() {
    final Set<String> ids = {};

    for (final record in service.attendance) {
      if (record.status.trim().toLowerCase() == 'vacation') {
        ids.add(record.employeeId);
      }
    }

    return ids;
  }

  List<Employee> _vacationEmployees() {
    final ids = _vacationEmployeeIds();

    return service.employeesDemo.where((employee) {
      return ids.contains(employee.employeeId);
    }).toList();
  }

  List<Employee> _activeEmployees() {
    return service.employeesDemo
        .where((employee) => employee.isActive)
        .toList();
  }

  // ===========================================================================
  // FLASHCARD RESULT PANEL
  // ===========================================================================

  Widget _dashboardFilterResult() {
    switch (selectedDashboardCard) {
      case 'departments':
        return _departmentResultPanel();

      case 'branches':
        return _branchResultPanel();

      case 'vacation':
        return _vacationResultPanel();

      case 'active':
        return _employeeResultPanel(
          title: 'Active Employees',
          employees: _activeEmployees(),
          emptyText: 'No active employees found.',
          color: const Color(0xFF15965D),
        );

      case 'new_joiner':
        return _employeeResultPanel(
          title: 'New Joiners - Last 6 Months',
          employees: _newJoiners(),
          emptyText:
          'No employees joined within the last 6 months.',
          color: const Color(0xFFEF4444),
          showJoiningDate: true,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _departmentResultPanel() {
    final Map<String, List<Employee>> departmentEmployees = {};

    for (final employee in service.employeesDemo) {
      final department = employee.department.trim();

      if (department.isEmpty) {
        continue;
      }

      departmentEmployees.putIfAbsent(
        department,
            () => [],
      );

      departmentEmployees[department]!.add(employee);
    }

    final departments = departmentEmployees.keys.toList()
      ..sort();

    return _panel(
      'Departments',
      departments.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No departments found.',
          ),
        ),
      )
          : Column(
        children: departments.map((department) {
          final employees =
          departmentEmployees[department]!;

          return Card(
            elevation: 0,
            color: const Color(0xFFF5F7FB),
            margin: const EdgeInsets.only(
              bottom: 10,
            ),
            child: ExpansionTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEAF0FF),
                child: Icon(
                  Icons.business_center_outlined,
                  color: Color(0xFF315AD9),
                ),
              ),
              title: Text(
                department,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${employees.length} employee'
                    '${employees.length == 1 ? '' : 's'}',
              ),
              children: employees.map((employee) {
                return ListTile(
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor:
                    Colors.white,
                    child: Text(
                      employee.name.isEmpty
                          ? '?'
                          : employee.name
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF315AD9),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(employee.name),
                  subtitle: Text(
                    '${employee.employeeId} • '
                        '${employee.designation}',
                  ),
                  trailing: employee.isActive
                      ? const Chip(
                    label: Text(
                      'Active',
                      style: TextStyle(
                        color: Color(
                          0xFF15965D,
                        ),
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    backgroundColor:
                    Color(0xFFEAF8F1),
                    side: BorderSide.none,
                  )
                      : const Chip(
                    label: Text(
                      'Inactive',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    backgroundColor:
                    Color(0xFFFFEEEE),
                    side: BorderSide.none,
                  ),
                  onTap: () {
                    _showEmployee(employee);
                  },
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _branchResultPanel() {
    final branches = [...service.branches];

    return _panel(
      'Branches',
      branches.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No branches found.',
          ),
        ),
      )
          : Column(
        children: branches.map((branch) {
          final employees =
          service.employeesDemo.where((employee) {
            return employee.branchId == branch.id;
          }).toList();

          return Card(
            elevation: 0,
            color: const Color(0xFFF5F7FB),
            margin: const EdgeInsets.only(
              bottom: 10,
            ),
            child: ExpansionTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF0EAFF),
                child: Icon(
                  Icons.account_tree_outlined,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              title: Text(
                branch.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${employees.length} employee'
                    '${employees.length == 1 ? '' : 's'}',
              ),
              children: employees.isEmpty
                  ? const [
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No employees assigned to this branch.',
                  ),
                ),
              ]
                  : employees.map((employee) {
                return ListTile(
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor:
                    Colors.white,
                    child: Text(
                      employee.name.isEmpty
                          ? '?'
                          : employee.name
                          .substring(
                        0,
                        1,
                      )
                          .toUpperCase(),
                      style: const TextStyle(
                        color:
                        Color(0xFF8B5CF6),
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(employee.name),
                  subtitle: Text(
                    '${employee.employeeId} • '
                        '${employee.department}',
                  ),
                  onTap: () {
                    _showEmployee(employee);
                  },
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _vacationResultPanel() {
    final employees = _vacationEmployees();

    final leaveRecords = service.attendance.where((record) {
      return record.status.trim().toLowerCase() == 'leave';
    }).toList()
      ..sort(
            (a, b) => b.date.compareTo(a.date),
      );

    return _panel(
      'Vacation / Leave Employees',
      employees.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No vacation / leave records found.',
          ),
        ),
      )
          : Column(
        children: employees.map((employee) {
          final employeeLeaves =
          leaveRecords.where((record) {
            return record.employeeId ==
                employee.employeeId;
          }).toList();

          return Card(
            elevation: 0,
            color: const Color(0xFFF5F7FB),
            margin: const EdgeInsets.only(
              bottom: 10,
            ),
            child: ExpansionTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(
                  Icons.beach_access_outlined,
                  color: Colors.orange,
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
                    '${employee.department}',
              ),
              children: employeeLeaves.isEmpty
                  ? const []
                  : employeeLeaves.map((record) {
                return ListTile(
                  leading: const Icon(
                    Icons.event_busy,
                    color: Colors.orange,
                  ),
                  title: Text(
                    DateFormat(
                      'dd MMM yyyy',
                    ).format(record.date),
                  ),
                  subtitle: Text(
                    '${record.checkIn} - '
                        '${record.checkOut}',
                  ),
                  trailing: _statusChip(
                    record.status,
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _employeeResultPanel({
    required String title,
    required List<Employee> employees,
    required String emptyText,
    required Color color,
    bool showJoiningDate = false,
  }) {
    return _panel(
      title,
      employees.isEmpty
          ? Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(emptyText),
        ),
      )
          : Column(
        children: employees.map((employee) {
          return Card(
            elevation: 0,
            color: const Color(0xFFF5F7FB),
            margin: const EdgeInsets.only(
              bottom: 8,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                color.withOpacity(0.10),
                child: Text(
                  employee.name.isEmpty
                      ? '?'
                      : employee.name
                      .substring(0, 1)
                      .toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
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
                    '${employee.department} • '
                    '${employee.branchId}',
              ),
              trailing: showJoiningDate
                  ? Text(
                employee.joiningDate == null
                    ? '-'
                    : DateFormat(
                  'dd MMM yyyy',
                ).format(
                  employee.joiningDate!,
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              )
                  : null,
              onTap: () {
                _showEmployee(employee);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // EMPLOYEES
  // ===========================================================================

  Widget _employeesPage() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.getEmployees(),
      builder: (context, snapshot) {
        // ----------------------------------------------------------
        // LOADING
        // ----------------------------------------------------------
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ----------------------------------------------------------
        // ERROR
        // ----------------------------------------------------------
        if (snapshot.hasError) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Employees',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _showAddEmployee,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Employee'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _panel(
                  'Employee List',
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 45,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Unable to load employees.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {});
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        Widget _employeeDetail(
            String label,
            dynamic value,
            ) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: 10,
            ),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value?.toString() ?? '',
                  ),
                ),
              ],
            ),
          );
        }


        // ----------------------------------------------------------
        // DATA
        // ----------------------------------------------------------
        final employees = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Employees',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  FilledButton.icon(
                    onPressed: _showAddEmployee,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Employee'),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const Text(
                'Add, edit, delete and manage employee records.',
                style: TextStyle(
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 20),

              _panel(
                'Employee List',
                employees.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'No employees found.',
                    ),
                  ),
                )
                    : Column(
                  children: employees.map((employee) {
                    final String employeeId =
                        employee['employee_id']?.toString() ?? '';

                    final String name =
                        employee['name']?.toString() ?? '';

                    final String department =
                        employee['department']?.toString() ?? '';

                    final String branchId =
                        employee['branch_id']?.toString() ?? '';

                    final String designation =
                        employee['designation']?.toString() ?? '';

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(
                        bottom: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                          const Color(0xFFEAF0FF),
                          child: Text(
                            name.isEmpty
                                ? '?'
                                : name
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF2D55D8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        title: Text(
                          name.isEmpty
                              ? 'Unnamed Employee'
                              : name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        subtitle: Text(
                          '$employeeId • '
                              '$department • '
                              '$branchId'
                              '${designation.isEmpty ? '' : ' • $designation'}',
                        ),

                        trailing: Wrap(
                          children: [
                            // VIEW
                            IconButton(
                              tooltip: 'View',
                              icon: const Icon(
                                Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                _showSupabaseEmployee(
                                  employee,
                                );
                              },
                            ),

                            // EDIT
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                _showSupabaseEmployeeEdit(employee);
                              },
                            ),

                            // DELETE
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                _confirmSupabaseEmployeeDelete(
                                  employeeId,
                                  name,
                                );
                              },
                            ),
                          ],
                        ),

                        onTap: () {
                          _showSupabaseEmployee(
                            employee,
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // ADD EMPLOYEE
  // ===========================================================================

  void _showAddEmployee() {
    final employeeId = TextEditingController();
    final name = TextEditingController();
    final designation = TextEditingController();
    final department = TextEditingController();
    final email = TextEditingController();
    final ic = TextEditingController();
    final bank = TextEditingController();
    final account = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();

    String branchId =
    service.branches.isNotEmpty
        ? service.branches.first.id
        : '';

    DateTime joiningDate = DateTime.now();
    bool active = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Employee'),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _dialogField(
                        employeeId,
                        'Employee ID',
                      ),
                      _dialogField(
                        name,
                        'Full Name',
                      ),
                      _dialogField(
                        designation,
                        'Designation',
                      ),
                      _dialogField(
                        department,
                        'Department',
                      ),
                      _dialogField(
                        email,
                        'Email',
                      ),
                      _dialogField(
                        ic,
                        'New IC No',
                      ),
                      _dialogField(
                        bank,
                        'Bank Code',
                      ),
                      _dialogField(
                        account,
                        'Bank Account',
                      ),
                      _dialogField(
                        phone,
                        'Phone',
                      ),
                      _dialogField(
                        address,
                        'Address',
                      ),
                      if (service.branches.isNotEmpty)
                        DropdownButtonFormField<String>(
                          value: branchId,
                          decoration:
                          const InputDecoration(
                            labelText: 'Branch',
                          ),
                          items: service.branches.map(
                                (branch) {
                              return DropdownMenuItem<
                                  String>(
                                value: branch.id,
                                child: Text(
                                  branch.name,
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            setDialogState(() {
                              branchId = value;
                            });
                          },
                        ),
                      const SizedBox(height: 15),
                      ListTile(
                        contentPadding:
                        EdgeInsets.zero,
                        title: const Text(
                          'Joining Date',
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy')
                              .format(joiningDate),
                        ),
                        trailing: const Icon(
                          Icons.calendar_month,
                        ),
                        onTap: () async {
                          final picked =
                          await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDate: joiningDate,
                          );

                          if (picked != null) {
                            setDialogState(() {
                              joiningDate = picked;
                            });
                          }
                        },
                      ),
                      SwitchListTile(
                        contentPadding:
                        EdgeInsets.zero,
                        title: const Text(
                          'Active Employee',
                        ),
                        value: active,
                        onChanged: (value) {
                          setDialogState(() {
                            active = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final id = employeeId.text.trim();
                    final employeeName =
                    name.text.trim();

                    if (id.isEmpty ||
                        employeeName.isEmpty) {
                      _message(
                        'Employee ID and name are required.',
                      );
                      return;
                    }

                    if (service.findEmployee(id) !=
                        null) {
                      _message(
                        'Employee ID already exists.',
                      );
                      return;
                    }

                    service.addEmployee(
                      Employee(
                        employeeId: id,
                        name: employeeName,
                        designation:
                        designation.text.trim(),
                        department:
                        department.text.trim(),
                        email: email.text.trim(),
                        newIcNo: ic.text.trim(),
                        bankCode: bank.text.trim(),
                        bankAccount:
                        account.text.trim(),
                        phone: phone.text.trim(),
                        address: address.text.trim(),
                        joiningDate: joiningDate,
                        isActive: active,
                        branchId: branchId,
                      ),
                      branchId: branchId,
                    );

                    Navigator.pop(dialogContext);

                    _message(
                      'Employee added successfully.',
                    );
                  },
                  child: const Text(
                    'Save Employee',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // EDIT EMPLOYEE
  // ===========================================================================

  void _showEditEmployee(Employee employee) {
    final name = TextEditingController(
      text: employee.name,
    );
    final designation = TextEditingController(
      text: employee.designation,
    );
    final department = TextEditingController(
      text: employee.department,
    );
    final email = TextEditingController(
      text: employee.email,
    );
    final ic = TextEditingController(
      text: employee.newIcNo,
    );
    final bank = TextEditingController(
      text: employee.bankCode,
    );
    final account = TextEditingController(
      text: employee.bankAccount,
    );
    final phone = TextEditingController(
      text: employee.phone,
    );
    final address = TextEditingController(
      text: employee.address,
    );

    String branchId = employee.branchId;

    DateTime joiningDate =
        employee.joiningDate ?? DateTime.now();

    bool active = employee.isActive;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Edit ${employee.employeeId}',
              ),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        enabled: false,
                        controller:
                        TextEditingController(
                          text: employee.employeeId,
                        ),
                        decoration:
                        const InputDecoration(
                          labelText: 'Employee ID',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _dialogField(
                        name,
                        'Full Name',
                      ),
                      _dialogField(
                        designation,
                        'Designation',
                      ),
                      _dialogField(
                        department,
                        'Department',
                      ),
                      _dialogField(
                        email,
                        'Email',
                      ),
                      _dialogField(
                        ic,
                        'New IC No',
                      ),
                      _dialogField(
                        bank,
                        'Bank Code',
                      ),
                      _dialogField(
                        account,
                        'Bank Account',
                      ),
                      _dialogField(
                        phone,
                        'Phone',
                      ),
                      _dialogField(
                        address,
                        'Address',
                      ),
                      if (service.branches.isNotEmpty)
                        DropdownButtonFormField<String>(
                          value: service.branches.any(
                                (branch) =>
                            branch.id == branchId,
                          )
                              ? branchId
                              : service
                              .branches
                              .first
                              .id,
                          decoration:
                          const InputDecoration(
                            labelText: 'Branch',
                          ),
                          items: service.branches.map(
                                (branch) {
                              return DropdownMenuItem<
                                  String>(
                                value: branch.id,
                                child: Text(
                                  branch.name,
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            setDialogState(() {
                              branchId = value;
                            });
                          },
                        ),
                      ListTile(
                        contentPadding:
                        EdgeInsets.zero,
                        title: const Text(
                          'Joining Date',
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy')
                              .format(joiningDate),
                        ),
                        trailing: const Icon(
                          Icons.calendar_month,
                        ),
                        onTap: () async {
                          final picked =
                          await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDate: joiningDate,
                          );

                          if (picked != null) {
                            setDialogState(() {
                              joiningDate = picked;
                            });
                          }
                        },
                      ),
                      SwitchListTile(
                        contentPadding:
                        EdgeInsets.zero,
                        title: const Text('Active'),
                        value: active,
                        onChanged: (value) {
                          setDialogState(() {
                            active = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final updated =
                    employee.copyWith(
                      name: name.text.trim(),
                      designation:
                      designation.text.trim(),
                      department:
                      department.text.trim(),
                      email: email.text.trim(),
                      newIcNo: ic.text.trim(),
                      bankCode: bank.text.trim(),
                      bankAccount:
                      account.text.trim(),
                      phone: phone.text.trim(),
                      address: address.text.trim(),
                      joiningDate: joiningDate,
                      isActive: active,
                      branchId: branchId,
                    );

                    service.updateEmployee(updated);

                    Navigator.pop(dialogContext);

                    _message(
                      'Employee updated successfully.',
                    );
                  },
                  child: const Text(
                    'Update Employee',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // DELETE EMPLOYEE
  // ===========================================================================

  void _confirmDelete(Employee employee) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Employee?',
          ),
          content: Text(
            'Are you sure you want to delete '
                '${employee.name} (${employee.employeeId})?\n\n'
                'This will also remove the employee login, '
                'attendance records and payroll records from '
                'the current application data.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                service.deleteEmployee(
                  employee.employeeId,
                );

                Navigator.pop(dialogContext);

                _message(
                  'Employee deleted successfully.',
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _confirmSupabaseEmployeeDelete(
      String employeeId,
      String employeeName,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Employee',
          ),
          content: Text(
            'Are you sure you want to delete '
                '"$employeeName"?\n\n'
                'This will also delete the employee payroll '
                'records because of the database relationship.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  await SupabaseService.deleteEmployee(
                    employeeId,
                  );

                  if (!mounted) return;

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Employee deleted successfully.',
                      ),
                    ),
                  );

                  setState(() {});
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Delete failed: $e',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );
  }



  // ===========================================================================
  // VIEW EMPLOYEE
  // ===========================================================================

  void _showEmployee(Employee employee) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(employee.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _detail(
                  'Employee ID',
                  employee.employeeId,
                ),
                _detail(
                  'Branch',
                  employee.branchId,
                ),
                _detail(
                  'Designation',
                  employee.designation,
                ),
                _detail(
                  'Department',
                  employee.department,
                ),
                _detail(
                  'Email',
                  employee.email,
                ),
                _detail(
                  'IC',
                  employee.newIcNo,
                ),
                _detail(
                  'Phone',
                  employee.phone,
                ),
                _detail(
                  'Address',
                  employee.address,
                ),
                _detail(
                  'Bank',
                  employee.bankCode,
                ),
                _detail(
                  'Account',
                  employee.bankAccount,
                ),
                _detail(
                  'Joining Date',
                  employee.joiningDate == null
                      ? '-'
                      : DateFormat(
                    'dd MMM yyyy',
                  ).format(
                    employee.joiningDate!,
                  ),
                ),
                _detail(
                  'Status',
                  employee.isActive
                      ? 'Active'
                      : 'Inactive',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showEditEmployee(employee);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  void _showSupabaseEmployee(
      Map<String, dynamic> employee,
      ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            employee['name']?.toString().isEmpty ?? true
                ? 'Employee'
                : employee['name'].toString(),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _employeeDetail(
                    'Employee ID',
                    employee['employee_id'],
                  ),
                  _employeeDetail(
                    'Name',
                    employee['name'],
                  ),
                  _employeeDetail(
                    'Designation',
                    employee['designation'],
                  ),
                  _employeeDetail(
                    'Department',
                    employee['department'],
                  ),
                  _employeeDetail(
                    'Email',
                    employee['email'],
                  ),
                  _employeeDetail(
                    'IC No.',
                    employee['new_ic_no'],
                  ),
                  _employeeDetail(
                    'Bank Code',
                    employee['bank_code'],
                  ),
                  _employeeDetail(
                    'Bank Account',
                    employee['bank_account'],
                  ),
                  _employeeDetail(
                    'Phone',
                    employee['phone'],
                  ),
                  _employeeDetail(
                    'Address',
                    employee['address'],
                  ),
                  _employeeDetail(
                    'Joining Date',
                    employee['joining_date'],
                  ),
                  _employeeDetail(
                    'Branch',
                    employee['branch_id'],
                  ),
                  _employeeDetail(
                    'Active',
                    employee['is_active'] == true
                        ? 'Yes'
                        : 'No',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }


  Widget _employeeDetail(
      String label,
      dynamic value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }





  void _showSupabaseEmployeeEdit(Map<String, dynamic> employee) {
    final nameController = TextEditingController(
      text: employee['name']?.toString() ?? '',
    );

    final designationController = TextEditingController(
      text: employee['designation']?.toString() ?? '',
    );

    final departmentController = TextEditingController(
      text: employee['department']?.toString() ?? '',
    );

    final emailController = TextEditingController(
      text: employee['email']?.toString() ?? '',
    );

    final phoneController = TextEditingController(
      text: employee['phone']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Employee'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: designationController,
                    decoration: const InputDecoration(
                      labelText: 'Designation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final id = employee['id'];

                  if (id == null) {
                    throw Exception('Employee ID is missing');
                  }

                  await SupabaseService.client
                      .from('employees')
                      .update({
                    'name': nameController.text.trim(),
                    'designation': designationController.text.trim(),
                    'department': departmentController.text.trim(),
                    'email': emailController.text.trim(),
                    'phone': phoneController.text.trim(),
                  })
                      .eq('id', id);

                  if (!mounted) return;

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Employee updated successfully.',
                      ),
                    ),
                  );

                  setState(() {});
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to update employee: $e',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // ATTENDANCE
  // ===========================================================================

  // ===========================================================================
// ATTENDANCE
// ===========================================================================

Widget _attendancePage() {
  if (selectedAttendanceBranchId != null) {
    return _branchAttendanceEmployeesPage(selectedAttendanceBranchId!);
  }

  return FutureBuilder<List<Map<String, dynamic>>>(
    future: SupabaseService.getBranches(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Text(
            'Unable to load branches:\n${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        );
      }

      final branches = snapshot.data ?? [];
      return RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a branch to view submitted employee attendance. Admin can edit submitted attendance.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (branches.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No branches found.')),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 175,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: branches.length,
                  itemBuilder: (context, index) {
                    final branch = branches[index];
                    final id = (branch['id'] ?? branch['branch_id'] ?? '').toString();
                    final name = (branch['name'] ?? branch['branch_name'] ?? id).toString();
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: id.isEmpty ? null : () => setState(() => selectedAttendanceBranchId = id),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: Colors.blueGrey.withOpacity(.20)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 26,
                                child: Icon(Icons.store_outlined, size: 28),
                              ),
                              const Spacer(),
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              const Row(
                                children: [
                                  Text('View Attendance', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                  Spacer(),
                                  Icon(Icons.arrow_forward, size: 17),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _branchAttendanceEmployeesPage(String branchId) {
  return FutureBuilder<List<dynamic>>(
    future: Future.wait([
      SupabaseService.getBranches(),
      SupabaseService.getEmployeesByBranch(branchId),
      SupabaseService.getAttendanceByBranch(branchId),
    ]),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to load attendance:\n${snapshot.error}', textAlign: TextAlign.center),
          ),
        );
      }

      final data = snapshot.data ?? const [[], [], []];
      final branches = List<Map<String, dynamic>>.from(data[0] as List);
      final employees = List<Map<String, dynamic>>.from(data[1] as List);
      final attendance = List<Map<String, dynamic>>.from(data[2] as List);

      final branch = branches.firstWhere(
        (item) => (item['id'] ?? item['branch_id'] ?? '').toString() == branchId,
        orElse: () => <String, dynamic>{},
      );
      final branchName = (branch['name'] ?? branch['branch_name'] ?? branchId).toString();

      final employeeMap = <String, Map<String, dynamic>>{};
      for (final employee in employees) {
        final id = (employee['employee_id'] ?? employee['id'] ?? '').toString();
        if (id.isNotEmpty) employeeMap[id] = employee;
      }

      final byEmployee = <String, List<Map<String, dynamic>>>{};
      for (final record in attendance) {
        final id = (record['employee_id'] ?? '').toString();
        if (id.isEmpty) continue;
        byEmployee.putIfAbsent(id, () => []).add(record);
      }

      return RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => selectedAttendanceBranchId = null),
                icon: const Icon(Icons.arrow_back),
                label: const Text('All Branches'),
              ),
              const SizedBox(height: 8),
              Text(branchName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${employees.length} employee(s)', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              if (employees.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No employees assigned to this branch.')),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 180,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    final employeeId = (employee['employee_id'] ?? employee['id'] ?? '').toString();
                    final name = (employee['name'] ?? employee['full_name'] ?? employeeId).toString();
                    final records = byEmployee[employeeId] ?? const <Map<String, dynamic>>[];
                    final submitted = records.any((r) => _attendanceBool(r['is_submitted']));

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openAdminAttendance(employee, branchId, submitted),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: Colors.blueGrey.withOpacity(.20)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: submitted ? Colors.green.shade50 : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      submitted ? 'Submitted' : 'Pending',
                                      style: TextStyle(
                                        color: submitted ? Colors.green.shade700 : Colors.orange.shade700,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('Employee ID: $employeeId', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 3),
                              Text(
                                submitted ? 'Submitted attendance • Admin can edit' : 'Waiting for Branch submission',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

bool _attendanceBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase().trim() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

void _openAdminAttendance(
  Map<String, dynamic> employee,
  String branchId,
  bool submitted,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AttendanceDialog(
      employee: employee,
      month: selectedAttendanceMonth,
      branchId: branchId,
      editable: true,
      adminOnlyAfterSubmit: true,
    ),
  ).then((_) {
    if (mounted) setState(() {});
  });
}

// ===========================================================================
// EMPLOYEE CSV IMPORT PAGE
// ===========================================================================

  Widget _importPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import Employees',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Import employee details directly from a CSV file.',
            style: TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 24),

          _panel(
            'Employee CSV Import',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 70,
                    color: Color(0xFF2D55D8),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Import employee records',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Select your employee CSV file. '
                      'The application will read the employee details '
                      'from the CSV and add/update the records.',
                ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.black12,
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Required CSV columns',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 10),

                      SelectableText(
                        'employeeId,name,designation,department,email,'
                            'newIcNo,bankCode,bankAccount,phone,address,'
                            'joiningDate,isActive,branchId',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _importEmployeesCsv,
                    icon: const Icon(
                      Icons.upload_file,
                    ),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      child: Text(
                        'SELECT CSV FILE & IMPORT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


// ===========================================================================
// PAYROLL PAGE
// ===========================================================================

  // ============================================================================
// PAYROLL PAGE
// ============================================================================


  Future<void> _showGenerateAttendancePayrollDialog() async {
    DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    bool overwriteExisting = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generate Payroll From Attendance'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Payroll Month'),
                  subtitle: Text(DateFormat('MMMM yyyy').format(selectedMonth)),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedMonth,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        helpText: 'Select Payroll Month',
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedMonth = DateTime(picked.year, picked.month);
                        });
                      }
                    },
                    child: const Text('Change'),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: overwriteExisting,
                  title: const Text('Replace Existing Payroll'),
                  subtitle: const Text('Update an existing payroll record for the selected month.'),
                  onChanged: (value) => setDialogState(() => overwriteExisting = value),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rules: approved OT is included; unauthorized OT is omitted. '
                  'Attendance deductions are calculated from the monthly attendance records.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Generate'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _generateAttendancePayroll(
                  month: selectedMonth,
                  overwriteExisting: overwriteExisting,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAttendancePayroll({
    required DateTime month,
    required bool overwriteExisting,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator()),
            SizedBox(width: 20),
            Expanded(child: Text('Generating payroll from attendance...')),
          ],
        ),
      ),
    );

    try {
      final result = await AttendancePayrollService.generateMonthlyPayroll(
        month: month,
        overwriteExisting: overwriteExisting,
      );
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      setState(() {});
      await _showPayrollGenerationResult(result);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payroll generation failed: $e')),
      );
    }
  }

  Future<void> _showPayrollGenerationResult(
    PayrollGenerationResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Payroll Generation Complete'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(result.month),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Generated: ${result.generatedCount}'),
                Text('Skipped: ${result.skippedCount}'),
                Text('Approved OT: RM ${result.totalOvertime.toStringAsFixed(2)}'),
                Text('Attendance deductions: RM ${result.totalAttendanceDeduction.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                ...result.generated.map((item) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(item.employeeName.isEmpty ? item.employeeId : item.employeeName),
                  subtitle: Text(
                    'Present: ${item.presentDays} | Absent: ${item.absentDays} | '
                    'Approved OT: ${item.approvedOtHours.toStringAsFixed(2)} hrs | '
                    'Unauthorized OT omitted: ${item.unauthorizedOtHours.toStringAsFixed(2)} hrs',
                  ),
                )),
                ...result.skipped.map((item) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.error_outline, color: Colors.orange),
                  title: Text(item.employeeName.isEmpty ? item.employeeId : item.employeeName),
                  subtitle: Text(item.message),
                )),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _payrollPage() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.client
          .from('payroll')
          .select()
          .order('period', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payroll',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.shade200,
                    ),
                  ),
                  child: Text(
                    'Unable to load payroll records.\n\n'
                        '${snapshot.error}',
                    style: TextStyle(
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final payrollRecords =
            snapshot.data ?? <Map<String, dynamic>>[];

        double totalPayroll = 0;

        for (final payroll in payrollRecords) {
          totalPayroll +=
              _payrollNumber(payroll['basic_salary']) +
                  _payrollNumber(payroll['elaun_kedatangan']) +
                  _payrollNumber(payroll['elaun_perkhidmatan']) +
                  _payrollNumber(payroll['elaun_kerajinan']) +
                  _payrollNumber(payroll['overtime']) +
                  _payrollNumber(payroll['bonus']) +
                  _payrollNumber(payroll['commission']) +
                  _payrollNumber(payroll['other_earnings']) +
                  _payrollNumber(payroll['cuti_umum']);
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: SupabaseService.client
              .from('employees')
              .select('employee_id, name')
              .eq('is_active', true),
          builder: (context, employeeSnapshot) {
            final employeeCount =
                employeeSnapshot.data?.length ?? 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payroll',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF172033),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Manage employee payroll and salary information.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _showGenerateAttendancePayrollDialog,
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Generate Payroll From Attendance'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _payrollSummaryCard(
                          'Total Payroll',
                          'RM ${totalPayroll.toStringAsFixed(2)}',
                          Icons.account_balance_wallet_outlined,
                          const Color(0xFF2D55D8),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: _payrollSummaryCard(
                          'Employees',
                          employeeCount.toString(),
                          Icons.people_outline,
                          const Color(0xFF16A34A),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: _payrollSummaryCard(
                          'Payroll Records',
                          payrollRecords.length.toString(),
                          Icons.pending_actions_outlined,
                          const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payroll Management',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Manage payroll records stored in Supabase.',
                          style: TextStyle(
                            color: Colors.black54,
                          ),
                        ),

                        const SizedBox(height: 20),

                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedPage = 5;
                            });
                          },
                          icon: const Icon(
                            Icons.upload_file_outlined,
                          ),
                          label: const Text(
                            'Import Payroll',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF2D55D8),
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        if (payrollRecords.isEmpty)
                          Container(
                            width: double.infinity,
                            padding:
                            const EdgeInsets.symmetric(
                              vertical: 40,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color:
                              const Color(0xFFF8FAFC),
                              borderRadius:
                              BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.payments_outlined,
                                  size: 48,
                                  color: Colors.black38,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No payroll records yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Import payroll data or add payroll records.',
                                  style: TextStyle(
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          _supabasePayrollTable(
                            payrollRecords,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// ============================================================================
// PAYROLL SUMMARY
// ============================================================================

  Widget _payrollSummaryCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// ============================================================================
// TOTAL PAYROLL
// ============================================================================

  String _totalPayrollText() {
    double total = 0;

    for (final record in service.payroll) {
      total += record.basicSalary;
      total += record.elaunKedatangan;
      total += record.elaunPerkhidmatan;
      total += record.elaunKerajinan;
      total += record.overtime;
      total += record.bonus;
      total += record.commission;
      total += record.otherEarnings;
      total += record.cutiUmum;
    }

    return 'RM ${total.toStringAsFixed(2)}';
  }

// ============================================================================
// PAYROLL TABLE
// ============================================================================

  Widget _payrollRecordsTable() {
    final records = List<PayrollRecord>.from(
      service.payroll,
    );

    records.sort(
          (a, b) => b.period.compareTo(a.period),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(
              label: Text('Employee'),
            ),
            DataColumn(
              label: Text('Period'),
            ),
            DataColumn(
              label: Text('Basic Salary'),
            ),
            DataColumn(
              label: Text('Gross'),
            ),
            DataColumn(
              label: Text('EPF'),
            ),
            DataColumn(
              label: Text('SOCSO'),
            ),
            DataColumn(
              label: Text('Actions'),
            ),
          ],
          rows: records.map((record) {
            final employee = service.findEmployee(
              record.employeeId,
            );

            final gross =
                record.basicSalary +
                    record.elaunKedatangan +
                    record.elaunPerkhidmatan +
                    record.elaunKerajinan +
                    record.overtime +
                    record.bonus +
                    record.commission +
                    record.otherEarnings +
                    record.cutiUmum;

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    employee?.name ??
                        record.employeeId,
                  ),
                ),

                DataCell(
                  Text(
                    '${record.period.year}-'
                        '${record.period.month.toString().padLeft(2, '0')}',
                  ),
                ),

                DataCell(
                  Text(
                    'RM ${record.basicSalary.toStringAsFixed(2)}',
                  ),
                ),

                DataCell(
                  Text(
                    'RM ${gross.toStringAsFixed(2)}',
                  ),
                ),

                DataCell(
                  Text(
                    'RM ${record.epfEmployee.toStringAsFixed(2)}',
                  ),
                ),

                DataCell(
                  Text(
                    'RM ${record.socsoEmployee.toStringAsFixed(2)}',
                  ),
                ),

                DataCell(
                  IconButton(
                    tooltip: 'Delete payroll',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      _deletePayroll(record);
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

// ============================================================================
// DELETE PAYROLL
// ============================================================================

  Future<void> _deletePayroll(
      PayrollRecord record,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Payroll',
          ),
          content: Text(
            'Delete payroll record ${record.id}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final message = await service.deletePayroll(
      record.id,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );

    setState(() {});
  }

// ============================================================================
// PAYROLL CSV IMPORT PAGE
// ============================================================================

  Widget _importPayrollPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import Payroll',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172033),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Upload a CSV file to import payroll records.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 28),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.upload_file_outlined,
                    size: 40,
                    color: Color(0xFF2D55D8),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Import Payroll CSV',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Select a CSV file containing your payroll data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _importPayrollCsv,
                  icon: const Icon(
                    Icons.folder_open_outlined,
                  ),
                  label: const Text(
                    'Choose CSV File',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D55D8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CSV format',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        'Your CSV should contain the employee and payroll '
                            'information required by your payroll system.',
                        style: TextStyle(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),

                      SizedBox(height: 12),

                      Text(
                        'Important: Employee IDs in the payroll CSV must '
                            'already exist in the Employee database.',
                        style: TextStyle(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// ============================================================================
// ACTUAL PAYROLL IMPORT HANDLER
// ============================================================================

  /*Future<void> _importPayrollCsv() async {
    // Prevent multiple file-picker calls.
    if (!mounted) {
      return;
    }

    // Show progress dialog.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(),
              ),

              SizedBox(width: 20),

              Expanded(
                child: Text(
                  'Opening payroll CSV importer...',
                ),
              ),
            ],
          ),
        );
      },
    );

    String result;

    try {
      result = await service.importPayrollCsv();
    } catch (e) {
      result = 'Payroll CSV import failed: $e';
    }

    if (!mounted) {
      return;
    }

    // Close progress dialog.
    Navigator.of(context).pop();

    // Show import result.
    await showDialog<void>(
      context: context,
      builder: (context) {
        final success =
            result.contains('Imported:') &&
                !result.toLowerCase().contains(
                  'failed',
                ) &&
                !result.toLowerCase().contains(
                  'invalid payroll csv',
                );

        return AlertDialog(
          title: Text(
            success
                ? 'Payroll Import Result'
                : 'Payroll Import',
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              result,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    // Refresh dashboard so imported payroll appears immediately.
    setState(() {});
  }*/

// ===========================================================================
// REPORTS
// ===========================================================================

  Widget _reportsPage() {
    final double gross =
    service.payroll.fold<double>(
      0,
          (sum, p) => sum + p.totalEarnings,
    );

    final double net =
    service.payroll.fold<double>(
      0,
          (sum, p) => sum + p.netPay,
    );

    final double deductions =
    service.payroll.fold<double>(
      0,
          (sum, p) => sum + p.totalDeductions,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Summary of employees, attendance and payroll data.',
            style: TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 20),

          _panel(
            'Payroll Report',
            Column(
              children: [
                _reportRow(
                  'Employees',
                  service.employeesDemo.length.toString(),
                ),

                _reportRow(
                  'Active Employees',
                  service.employeesDemo
                      .where((e) => e.isActive)
                      .length
                      .toString(),
                ),

                _reportRow(
                  'Payroll Records',
                  service.payroll.length.toString(),
                ),

                _reportRow(
                  'Attendance Records',
                  service.attendance.length.toString(),
                ),

                _reportRow(
                  'Departments',
                  _departmentCount().toString(),
                ),

                _reportRow(
                  'Branches',
                  service.branches.length.toString(),
                ),

                _reportRow(
                  'Vacation Employees',
                  _vacationEmployeeIds().length.toString(),
                ),

                _reportRow(
                  'New Joiners',
                  _newJoiners().length.toString(),
                ),

                _reportRow(
                  'Gross Payroll',
                  _money(gross),
                ),

                _reportRow(
                  'Total Deductions',
                  _money(deductions),
                ),

                _reportRow(
                  'Net Payroll',
                  _money(net),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


// ===========================================================================
// SETTINGS
// ===========================================================================

  Widget _settingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _panel(
        'Settings',
        Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              'Hasani Books Payroll Portal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Administrator has full access to employee, attendance '
                  'and payroll data.',
            ),

            const SizedBox(height: 20),

            const Divider(),

            const SizedBox(height: 10),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEAF0FF),
                child: Icon(
                  Icons.admin_panel_settings,
                  color: Color(0xFF2D55D8),
                ),
              ),
              title: const Text(
                'Administrator Access',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Full system access',
              ),
            ),
          ],
        ),
      ),
    );
  }


// ===========================================================================
// PAYROLL DETAIL
// ===========================================================================

  void _showPayroll(PayrollRecord payroll,) {
    final employee =
    service.findEmployee(payroll.employeeId);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${employee?.name ?? payroll.employeeId} Payroll',
          ),

          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee ID: ${payroll.employeeId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Period: '
                        '${DateFormat('MMMM yyyy').format(payroll.period)}',
                  ),

                  const Divider(height: 25),

                  _detail(
                    'Basic Salary',
                    _money(payroll.basicSalary),
                  ),

                  _detail(
                    'Food Allowance',
                    _money(payroll.foodAllowance),
                  ),

                  _detail(
                    'Other Allowance',
                    _money(payroll.otherAllowance),
                  ),

                  _detail(
                    'Overtime',
                    _money(payroll.overtime),
                  ),

                  _detail(
                    'Bonus',
                    _money(payroll.bonus),
                  ),

                  const Divider(),

                  _detail(
                    'EPF Employee',
                    _money(payroll.epfEmployee),
                  ),

                  _detail(
                    'SOCSO Employee',
                    _money(payroll.socsoEmployee),
                  ),

                  _detail(
                    'EIS Employee',
                    _money(payroll.eisEmployee),
                  ),

                  const Divider(),

                  _detail(
                    'Gross',
                    _money(payroll.totalEarnings),
                  ),

                  _detail(
                    'Deductions',
                    _money(payroll.totalDeductions),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF8F1),
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'NET PAY',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.w800,
                              color:
                              Color(0xFF15965D),
                            ),
                          ),
                        ),

                        Text(
                          _money(payroll.netPay),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight.w900,
                            color:
                            Color(0xFF15965D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }


// ===========================================================================
// HELPERS
// ===========================================================================

  Widget _dialogField(TextEditingController controller,
      String label,) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }


  Widget _detail(String title,
      String value,) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _panel(String title,
      Widget child,) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
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




  Widget _statCard(String title,
      String value,
      IconData icon,
      Color color, [VoidCallback? onTap]) {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),

            const SizedBox(height: 18),

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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }


  Widget _actionButton(String title,
      IconData icon,
      VoidCallback onTap,) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
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
              color: const Color(0xFF2D55D8),
            ),

            const SizedBox(height: 8),

            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _reportRow(String title,
      String value,) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  String _money(double value) {
    return 'RM ${NumberFormat('#,##0.00').format(value)}';
  }


  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

double _payrollNumber(dynamic value) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}

Widget _supabasePayrollTable(
    List<Map<String, dynamic>> records,
    ) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowColor: WidgetStateProperty.all(
        const Color(0xFFF8FAFC),
      ),
      columns: const [
        DataColumn(
          label: Text('Employee ID'),
        ),
        DataColumn(
          label: Text('Period'),
        ),
        DataColumn(
          label: Text('Basic Salary'),
        ),
        DataColumn(
          label: Text('Allowances'),
        ),
        DataColumn(
          label: Text('Overtime'),
        ),
        DataColumn(
          label: Text('Bonus'),
        ),
        DataColumn(
          label: Text('Commission'),
        ),
        DataColumn(
          label: Text('Total Earnings'),
        ),
      ],
      rows: records.map((payroll) {
        final basic =
        _payrollNumber(payroll['basic_salary']);

        final allowances =
            _payrollNumber(
              payroll['elaun_kedatangan'],
            ) +
                _payrollNumber(
                  payroll['elaun_perkhidmatan'],
                ) +
                _payrollNumber(
                  payroll['elaun_kerajinan'],
                );

        final overtime =
        _payrollNumber(payroll['overtime']);

        final bonus =
        _payrollNumber(payroll['bonus']);

        final commission =
        _payrollNumber(payroll['commission']);

        final other =
        _payrollNumber(
          payroll['other_earnings'],
        );

        final cutiUmum =
        _payrollNumber(
          payroll['cuti_umum'],
        );

        final total =
            basic +
                allowances +
                overtime +
                bonus +
                commission +
                other +
                cutiUmum;

        return DataRow(
          cells: [
            DataCell(
              Text(
                payroll['employee_id']?.toString() ?? '',
              ),
            ),
            DataCell(
              Text(
                payroll['period']?.toString() ?? '',
              ),
            ),
            DataCell(
              Text(
                'RM ${basic.toStringAsFixed(2)}',
              ),
            ),
            DataCell(
              Text(
                'RM ${allowances.toStringAsFixed(2)}',
              ),
            ),
            DataCell(
              Text(
                'RM ${overtime.toStringAsFixed(2)}',
              ),
            ),
            DataCell(
              Text(
                'RM ${bonus.toStringAsFixed(2)}',
              ),
            ),
            DataCell(
              Text(
                'RM ${commission.toStringAsFixed(2)}',
              ),
            ),
            DataCell(
              Text(
                'RM ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );

  
}