import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/payroll.dart';
import '../services/app_service.dart';
import '../services/ot_request_pdf_service.dart';
import '../services/attendance_payroll_service.dart';
import 'login_screen.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:excel/excel.dart' as xls;
import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';
import '../screens/supabase_service.dart';
import '../screens/attendance_dialog.dart';
import 'monthly_roster_page.dart';

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
  DateTime selectedAttendanceMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedPayrollMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedReportMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  String? selectedPayrollBranchId;
  String? selectedLogBranchId;
  DateTime? selectedLogDate;
  Future<List<Map<String, dynamic>>>? _branchLogsFuture;
  Future<List<Map<String, dynamic>>>? _adminEmployeesFuture;
  Future<List<Map<String, dynamic>>>? _employeeRequestsFuture;
  Future<List<Map<String, dynamic>>>? _otRequestsFuture;
  final TextEditingController _adminEmployeeSearchController =
      TextEditingController();
  final TextEditingController _attendanceEmployeeSearchController =
      TextEditingController();
  String _adminEmployeeSearch = '';
  String _attendanceEmployeeSearch = '';
  final Map<String, String> _approvedOtInputs = {};

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
    _adminEmployeeSearchController.dispose();
    _attendanceEmployeeSearchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;

    setState(() {
      _adminEmployeesFuture = null;
    });
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void changePage(int page) {
    // RHB Layout is an export action, not a normal page.
    if (page == 8) {
      _exportRhbLayout();
      return;
    }

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
      case 8:
        return 'RHB Layout';
      case 9:
        return 'Branch Logs';
      case 10:
        return 'Employee Requests';
      case 11:
        return 'OT Requests';
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

      case 8:
        return _rhbLayoutPage();

      case 9:
        return _branchLogsPage();

      case 10:
        return _employeeRequestsPage();

      case 11:
        return _otRequestsPage();

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
                      'RHB Layout',
                      Icons.account_balance_outlined,
                      8,
                    ),
                    _drawerItem(
                      'Attendance',
                      Icons.access_time,
                      3,
                    ),
                    _drawerItem(
                      'Branch Logs',
                      Icons.manage_history_outlined,
                      9,
                    ),
                    _drawerItem(
                      'Employee Requests',
                      Icons.how_to_reg_outlined,
                      10,
                    ),
                    _drawerItem(
                      'OT Requests',
                      Icons.more_time_outlined,
                      11,
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
                  'RHB Layout',
                  Icons.account_balance_outlined,
                  8,
                ),
                _sidebarItem(
                  'Attendance',
                  Icons.access_time,
                  3,
                ),
                _sidebarItem(
                  'Branch Logs',
                  Icons.manage_history_outlined,
                  9,
                ),
                _sidebarItem(
                  'Employee Requests',
                  Icons.how_to_reg_outlined,
                  10,
                ),
                _sidebarItem(
                  'OT Requests',
                  Icons.more_time_outlined,
                  11,
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

  Widget _sidebarItem(
    String title,
    IconData icon,
    int page,
  ) {
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
          color: selected ? const Color(0xFF2D55D8) : Colors.black54,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? const Color(0xFF2D55D8) : Colors.black87,
          ),
        ),
        onTap: () {
          changePage(page);
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
      selectedTileColor: const Color(0xFFEAF0FF),
      leading: Icon(
        icon,
        color: selectedPage == page ? const Color(0xFF2D55D8) : Colors.black54,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight:
              selectedPage == page ? FontWeight.bold : FontWeight.normal,
          color:
              selectedPage == page ? const Color(0xFF2D55D8) : Colors.black87,
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
    final employeeId = employee['employee_id'] ?? employee['id'];
    if (employeeId == null) {
      throw Exception('Employee ID was not found.');
    }

    await SupabaseService.updateEmployeeStatus(
      employeeId: employeeId,
      isActive: isActive,
    );

    if (!mounted) return;
    employee['is_active'] = isActive;
    setState(() => _adminEmployeesFuture = null);
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
    var showActive = true;
    var showInactive = true;
    var search = '';
    final searchController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = search.toLowerCase();
          final list = employees.where((employee) {
            final active = _isActive(employee);
            if ((active && !showActive) || (!active && !showInactive))
              return false;
            if (query.isEmpty) return true;
            return [
              'name',
              'employee_id',
              'department',
              'designation',
              'branch_id'
            ].any((key) => (employee[key]?.toString().toLowerCase() ?? '')
                .contains(query));
          }).toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .86,
              child: Column(children: [
                ListTile(
                  title: Text(title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) =>
                        setSheetState(() => search = value.trim()),
                    decoration: InputDecoration(
                      hintText:
                          'Search name, Employee ID, department or branch',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                searchController.clear();
                                setSheetState(() => search = '');
                              },
                            ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 10, children: [
                  FilterChip(
                    selected: showActive,
                    label: const Text('Active'),
                    avatar: const Icon(Icons.check_circle, size: 18),
                    onSelected: (value) =>
                        setSheetState(() => showActive = value),
                  ),
                  FilterChip(
                    selected: showInactive,
                    label: const Text('Inactive'),
                    avatar: const Icon(Icons.person_off, size: 18),
                    onSelected: (value) =>
                        setSheetState(() => showInactive = value),
                  ),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text('No employees found.'))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, index) {
                            final employee = list[index];
                            final active = _isActive(employee);
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 5),
                              child: ListTile(
                                onTap: () => _showSupabaseEmployee(employee),
                                title: Text(
                                    employee['name']?.toString() ?? 'Employee',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text([
                                  employee['employee_id']?.toString() ?? '-',
                                  employee['department']?.toString() ?? '',
                                  employee['branch_id']?.toString() ?? '',
                                ]
                                    .where((value) => value.isNotEmpty)
                                    .join(' • ')),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: active,
                                        onChanged: (value) async {
                                          if (value == null) return;
                                          try {
                                            await _changeEmployeeStatus(
                                                employee, value);
                                            if (sheetContext.mounted)
                                              setSheetState(() {});
                                          } catch (error) {
                                            if (sheetContext.mounted)
                                              ScaffoldMessenger.of(sheetContext)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Status update failed: $error')),
                                              );
                                          }
                                        },
                                      ),
                                      Text(active ? 'Active' : 'Inactive'),
                                    ]),
                              ),
                            );
                          },
                        ),
                ),
              ]),
            ),
          );
        },
      ),
    ).whenComplete(searchController.dispose);
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
              title: const Text('Departments',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              subtitle: Text('${names.length} department(s)'),
              trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ),
            const Divider(height: 1),
            Expanded(
                child: names.isEmpty
                    ? const Center(child: Text('No departments found.'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 260,
                                mainAxisExtent: 130,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12),
                        itemCount: names.length,
                        itemBuilder: (_, index) {
                          final name = names[index];
                          final list = groups[name]!;
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(context);
                              _showEmployeeDetails(name, list);
                            },
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.business_center_outlined,
                                          color: Color(0xFF8B5CF6)),
                                      const Spacer(),
                                      Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
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
    final value = employee['branch_name'] ??
        employee['branch'] ??
        employee['branch_id'] ??
        'Unassigned';
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
              title: const Text('Branches',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              subtitle: Text('${names.length} branch(es)'),
              trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ),
            const Divider(height: 1),
            Expanded(
                child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisExtent: 130,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12),
              itemCount: names.length,
              itemBuilder: (_, index) {
                final name = names[index];
                final list = groups[name]!;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(context);
                    _showEmployeeDetails(name, list);
                  },
                  child: Card(
                      child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.account_tree_outlined,
                              color: Color(0xFFEF4444)),
                          const Spacer(),
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('${list.length} employee(s)'),
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
          final years =
              List<int>.generate(now.year - 2022 + 1, (i) => now.year - i);
          final branchEmployees = selectedBranch == null
              ? <Map<String, dynamic>>[]
              : employees
                  .where((e) => _branchLabel(e) == selectedBranch)
                  .toList();
          return SafeArea(
              child: SizedBox(
            height: MediaQuery.of(context).size.height * .88,
            child: Column(children: [
              ListTile(
                title: Text(title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                subtitle: const Text(
                    'Select Year â†’ Month â†’ Branch â†’ Employees'),
                trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext)),
              ),
              const Divider(height: 1),
              Expanded(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Select Year',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: years
                              .map((year) => ChoiceChip(
                                    label: Text(year.toString()),
                                    selected: selectedYear == year,
                                    onSelected: (_) => setSheetState(() {
                                      selectedYear = year;
                                      selectedMonth = null;
                                      selectedBranch = null;
                                    }),
                                  ))
                              .toList()),
                      if (selectedYear != null) ...[
                        const SizedBox(height: 24),
                        const Text('2. Select Month',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: List.generate(
                                12,
                                (i) => ChoiceChip(
                                      label: Text(DateFormat('MMMM').format(
                                          DateTime(selectedYear!, i + 1))),
                                      selected: selectedMonth == i + 1,
                                      onSelected: (_) => setSheetState(() {
                                        selectedMonth = i + 1;
                                        selectedBranch = null;
                                      }),
                                    ))),
                      ],
                      if (selectedMonth != null) ...[
                        const SizedBox(height: 24),
                        const Text('3. Select Branch',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: branches
                                .map((branch) => ChoiceChip(
                                      label: Text(branch),
                                      selected: selectedBranch == branch,
                                      onSelected: (_) => setSheetState(
                                          () => selectedBranch = branch),
                                    ))
                                .toList()),
                      ],
                      if (selectedBranch != null) ...[
                        const SizedBox(height: 24),
                        Text('4. Employees â€” $selectedBranch',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        if (branchEmployees.isEmpty)
                          const Text('No employees found for this branch.')
                        else
                          ...branchEmployees.map((employee) {
                            final name =
                                (employee['name'] ?? 'Employee').toString();
                            final code = (employee['employee_id'] ??
                                    employee['id'] ??
                                    '')
                                .toString();
                            return Card(
                                child: ListTile(
                              leading:
                                  const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(name),
                              subtitle: Text(code),
                              trailing: metric == 'generate'
                                  ? ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                        changePage(2);
                                      },
                                      child: const Text('Generate'))
                                  : Text(metric == 'net' ? 'Net' : 'Gross',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
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
        final payroll = data['payroll'] as List<Map<String, dynamic>>? ?? [];

        final activeEmployees = employees.where(_isActive).length;
        final inactiveEmployees = employees.length - activeEmployees;

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
          (sum, p) =>
              sum +
              _number(p['total_earnings'] ??
                  p['gross_salary'] ??
                  p['gross_pay'] ??
                  p['totalGross']),
        );

        final totalNet = payroll.fold<double>(
          0,
          (sum, p) =>
              sum +
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
                    _statCard(
                        'Employees',
                        employees.length.toString(),
                        Icons.people,
                        const Color(0xFF315AD9),
                        () => _showEmployeeDetails('All Employees', employees)),
                    _statCard(
                        'Active Employees',
                        activeEmployees.toString(),
                        Icons.verified_user,
                        const Color(0xFF15965D),
                        () => _showEmployeeDetails('Active Employees',
                            employees.where(_isActive).toList())),
                    _statCard(
                        'Inactive Employees',
                        inactiveEmployees.toString(),
                        Icons.person_off,
                        Colors.orange,
                        () => _showEmployeeDetails('Inactive Employees',
                            employees.where((e) => !_isActive(e)).toList())),
                    _statCard(
                        'Departments',
                        departments.toString(),
                        Icons.business_center_outlined,
                        const Color(0xFF8B5CF6),
                        () => _showDepartmentFlow(employees)),
                    _statCard(
                        'Branches',
                        branches.toString(),
                        Icons.account_tree_outlined,
                        const Color(0xFFEF4444),
                        () => _showBranchFlow(employees)),
                    _statCard(
                        'Payroll Records',
                        payroll.length.toString(),
                        Icons.receipt_long,
                        const Color(0xFF8B5CF6),
                        () => _showPayrollFlow(employees, payroll,
                            title: 'Payroll Records', metric: 'generate')),
                    _statCard(
                        'Net Payroll',
                        _money(totalNet),
                        Icons.payments,
                        const Color(0xFF15965D),
                        () => _showPayrollFlow(employees, payroll,
                            title: 'Net Payroll', metric: 'net')),
                    _statCard(
                        'Gross Payroll',
                        _money(totalGross),
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
                      _actionButton(
                          'Employees', Icons.people, () => changePage(1)),
                      _actionButton(
                          'Payroll', Icons.payments, () => changePage(2)),
                      _actionButton(
                          'Attendance', Icons.access_time, () => changePage(3)),
                      _actionButton(
                          'Import CSV', Icons.upload_file, () => changePage(4)),
                      _actionButton(
                          'Reports', Icons.bar_chart, () => changePage(6)),
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
                      _reportRow(
                          'Active Employees', activeEmployees.toString()),
                      _reportRow(
                          'Inactive Employees', inactiveEmployees.toString()),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                  selected ? Icons.keyboard_arrow_up : Icons.chevron_right,
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

  List<Employee> _employeesForDepartment(
    String department,
  ) {
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

      return !dateOnly.isBefore(sixMonthsAgo) && !dateOnly.isAfter(today);
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
          emptyText: 'No employees joined within the last 6 months.',
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

    final departments = departmentEmployees.keys.toList()..sort();

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
                final employees = departmentEmployees[department]!;

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
                          backgroundColor: Colors.white,
                          child: Text(
                            employee.name.isEmpty
                                ? '?'
                                : employee.name.substring(0, 1).toUpperCase(),
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
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Color(0xFFEAF8F1),
                                side: BorderSide.none,
                              )
                            : const Chip(
                                label: Text(
                                  'Inactive',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Color(0xFFFFEEEE),
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
                final employees = service.employeesDemo.where((employee) {
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
                                backgroundColor: Colors.white,
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
                                    color: Color(0xFF8B5CF6),
                                    fontWeight: FontWeight.bold,
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
                final employeeLeaves = leaveRecords.where((record) {
                  return record.employeeId == employee.employeeId;
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
                      backgroundColor: color.withOpacity(0.10),
                      child: Text(
                        employee.name.isEmpty
                            ? '?'
                            : employee.name.substring(0, 1).toUpperCase(),
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
      future: _adminEmployeesFuture ??= SupabaseService.getEmployees(),
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
        final allEmployees = snapshot.data ?? [];
        final search = _adminEmployeeSearch.trim().toLowerCase();
        final employees = search.isEmpty
            ? allEmployees
            : allEmployees.where((employee) {
                return [
                  employee['employee_id'],
                  employee['name'],
                  employee['department'],
                  employee['designation'],
                  employee['email'],
                  employee['branch_id'],
                  employee['branch_name'],
                ].any((value) =>
                    value?.toString().toLowerCase().contains(search) == true);
              }).toList();

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
              TextField(
                controller: _adminEmployeeSearchController,
                onChanged: (value) =>
                    setState(() => _adminEmployeeSearch = value),
                decoration: InputDecoration(
                  hintText: 'Search employee, department or branch',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _adminEmployeeSearch.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _adminEmployeeSearchController.clear();
                            setState(() => _adminEmployeeSearch = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _panel(
                'Employee List',
                employees.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(
                          child: Text(
                            'No employees match your search.',
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
                                backgroundColor: const Color(0xFFEAF0FF),
                                child: Text(
                                  name.isEmpty
                                      ? '?'
                                      : name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF2D55D8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                name.isEmpty ? 'Unnamed Employee' : name,
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
                                  IconButton(
                                    tooltip: 'Transfer staff',
                                    icon: const Icon(Icons.swap_horiz,
                                        color: Colors.orange),
                                    onPressed: () =>
                                        _showTransferEmployee(employee),
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
        service.branches.isNotEmpty ? service.branches.first.id : '';

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
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                          ),
                          items: service.branches.map(
                            (branch) {
                              return DropdownMenuItem<String>(
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
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Joining Date',
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy').format(joiningDate),
                        ),
                        trailing: const Icon(
                          Icons.calendar_month,
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
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
                        contentPadding: EdgeInsets.zero,
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
                    final employeeName = name.text.trim();

                    if (id.isEmpty || employeeName.isEmpty) {
                      _message(
                        'Employee ID and name are required.',
                      );
                      return;
                    }

                    if (service.findEmployee(id) != null) {
                      _message(
                        'Employee ID already exists.',
                      );
                      return;
                    }

                    service.addEmployee(
                      Employee(
                        employeeId: id,
                        name: employeeName,
                        designation: designation.text.trim(),
                        department: department.text.trim(),
                        email: email.text.trim(),
                        newIcNo: ic.text.trim(),
                        bankCode: bank.text.trim(),
                        bankAccount: account.text.trim(),
                        phone: phone.text.trim(),
                        address: address.text.trim(),
                        joiningDate: joiningDate,
                        isActive: active,
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

    DateTime joiningDate = employee.joiningDate ?? DateTime.now();

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
                        controller: TextEditingController(
                          text: employee.employeeId,
                        ),
                        decoration: const InputDecoration(
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
                            (branch) => branch.id == branchId,
                          )
                              ? branchId
                              : service.branches.first.id,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                          ),
                          items: service.branches.map(
                            (branch) {
                              return DropdownMenuItem<String>(
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
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Joining Date',
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy').format(joiningDate),
                        ),
                        trailing: const Icon(
                          Icons.calendar_month,
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
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
                        contentPadding: EdgeInsets.zero,
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
                    final updated = employee.copyWith(
                      name: name.text.trim(),
                      designation: designation.text.trim(),
                      department: department.text.trim(),
                      email: email.text.trim(),
                      newIcNo: ic.text.trim(),
                      bankCode: bank.text.trim(),
                      bankAccount: account.text.trim(),
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

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Employee deleted successfully.',
                      ),
                    ),
                  );

                  setState(() {});
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  employee.isActive ? 'Active' : 'Inactive',
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
                    employee['is_active'] == true ? 'Yes' : 'No',
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

  void _showTransferEmployee(Map<String, dynamic> employee) {
    final employeeId = employee['employee_id']?.toString().trim() ?? '';
    final name = employee['name']?.toString().trim() ?? 'Employee';
    final currentBranch = employee['branch_id']?.toString().trim() ?? '';
    final destinations = service.branches
        .where((branch) =>
            branch.id.trim().toLowerCase() != currentBranch.toLowerCase())
        .toList();
    String? destination = destinations.isEmpty ? null : destinations.first.id;
    DateTime effectiveDate = DateTime.now();
    final reason = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Transfer $name'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Current branch: ${currentBranch.isEmpty ? '-' : currentBranch}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: destination,
                  decoration: const InputDecoration(
                    labelText: 'Transfer to branch',
                    border: OutlineInputBorder(),
                  ),
                  items: destinations
                      .map((branch) => DropdownMenuItem(
                            value: branch.id,
                            child: Text(branch.name),
                          ))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) => setDialogState(() => destination = value),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Effective date'),
                  subtitle:
                      Text(DateFormat('dd MMM yyyy').format(effectiveDate)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: saving
                      ? null
                      : () async {
                          final value = await showDatePicker(
                            context: dialogContext,
                            initialDate: effectiveDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (value != null) {
                            setDialogState(() => effectiveDate = value);
                          }
                        },
                ),
                TextField(
                  controller: reason,
                  enabled: !saving,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: SupabaseService.getStaffTransferHistory(employeeId),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    return Text('Previous transfers: $count');
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: Text(saving ? 'Transferring...' : 'Transfer Staff'),
              onPressed: saving || destination == null
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await SupabaseService.transferStaff(
                          employeeId: employeeId,
                          toBranchId: destination!,
                          effectiveDate: effectiveDate,
                          reason: reason.text,
                        );
                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        setState(() => _adminEmployeesFuture = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Staff transferred successfully.')),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Transfer failed: $error')),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    ).whenComplete(reason.dispose);
  }

  void _showSupabaseEmployeeEdit(Map<String, dynamic> employee) {
    TextEditingController make(String key) =>
        TextEditingController(text: employee[key]?.toString() ?? '');
    final fields = <String, TextEditingController>{
      'Name': make('name'),
      'Designation': make('designation'),
      'Department': make('department'),
      'Email': make('email'),
      'IC No.': make('new_ic_no'),
      'Bank Code': make('bank_code'),
      'Bank Account': make('bank_account'),
      'Phone': make('phone'),
      'Address': make('address'),
    };
    DateTime? joiningDate =
        DateTime.tryParse(employee['joining_date']?.toString() ?? '');
    var active = _isActive(employee);
    var saving = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Employee - All Information'),
          content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      initialValue: employee['employee_id']?.toString() ?? '',
                      enabled: false,
                      decoration:
                          const InputDecoration(labelText: 'Employee ID')),
                  ...fields.entries.map((field) => Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextField(
                            controller: field.value,
                            enabled: !saving,
                            maxLines: field.key == 'Address' ? 2 : 1,
                            decoration: InputDecoration(
                                labelText: field.key,
                                border: const OutlineInputBorder())),
                      )),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Joining Date'),
                      subtitle: Text(joiningDate == null
                          ? 'Not set'
                          : DateFormat('dd MMM yyyy').format(joiningDate!)),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: saving
                          ? null
                          : () async {
                              final value = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: joiningDate ?? DateTime.now(),
                                  firstDate: DateTime(1950),
                                  lastDate: DateTime(2100));
                              if (value != null)
                                setDialogState(() => joiningDate = value);
                            }),
                  TextFormField(
                      initialValue: employee['branch_id']?.toString() ?? '',
                      enabled: false,
                      decoration: const InputDecoration(
                          labelText: 'Branch',
                          helperText:
                              'Use Transfer Staff to change branch and retain history.')),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      title: const Text('Active employee'),
                      onChanged: saving
                          ? null
                          : (value) =>
                              setDialogState(() => active = value ?? false)),
                ]),
              )),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          await SupabaseService.updateEmployee(
                              employee['employee_id'], {
                            'name': fields['Name']!.text.trim(),
                            'designation': fields['Designation']!.text.trim(),
                            'department': fields['Department']!.text.trim(),
                            'email': fields['Email']!.text.trim(),
                            'new_ic_no': fields['IC No.']!.text.trim(),
                            'bank_code': fields['Bank Code']!.text.trim(),
                            'bank_account': fields['Bank Account']!.text.trim(),
                            'phone': fields['Phone']!.text.trim(),
                            'address': fields['Address']!.text.trim(),
                            'joining_date':
                                joiningDate?.toIso8601String().split('T').first,
                            'is_active': active,
                          });
                          if (!mounted) return;
                          Navigator.pop(dialogContext);
                          setState(() => _adminEmployeesFuture = null);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Employee updated successfully.')));
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Failed to update employee: $error')));
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Save All Information')),
          ],
        ),
      ),
    ).whenComplete(() {
      for (final item in fields.values) {
        item.dispose();
      }
    });
  }

  // ===========================================================================  // OT REQUEST APPROVAL
  // ===========================================================================

  Future<List<Map<String, dynamic>>> _loadOtRequests() {
    return _otRequestsFuture ??= SupabaseService.getPendingOtRequests();
  }

  void _refreshOtRequests() {
    setState(() => _otRequestsFuture = null);
  }

  Future<void> _showOtRequestForm(Map<String, dynamic> request) async {
    final employeeId = request['employee_id']?.toString() ?? '-';
    final name = request['employee_name']?.toString() ?? employeeId;
    final branch = request['branch_id']?.toString() ?? '-';
    final department = request['department']?.toString() ?? '-';
    final date = request['overtime_date']?.toString() ?? '-';
    final status = request['status']?.toString() ?? 'pending_branch';
    String stamp(dynamic value) {
      final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
      return parsed == null
          ? 'Waiting'
          : DateFormat('dd/MM/yyyy hh:mm a').format(parsed);
    }

    final requested =
        int.tryParse(request['requested_minutes'].toString()) ?? 0;
    final key = '$employeeId|$date';
    final approved = TextEditingController(
      text: _approvedOtInputs[key] ??
          _otMinutesText(
              int.tryParse(request['approved_minutes']?.toString() ?? '') ??
                  requested),
    );

    Widget cell(String text,
            {bool header = false,
            Alignment alignment = Alignment.center,
            double height = 40}) =>
        Container(
          height: height,
          alignment: alignment,
          padding: const EdgeInsets.all(6),
          color: header ? const Color(0xFF3155A4) : null,
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: header ? Colors.white : const Color(0xFF263B73),
                  fontSize: header ? 10 : 12,
                  fontWeight: header ? FontWeight.w800 : FontWeight.w600)),
        );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 1120,
          height: MediaQuery.sizeOf(dialogContext).height * .92,
          color: const Color(0xFFFFFCED),
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    color: const Color(0xFF3155A4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: const Text('BORANG TUNTUTAN\nKERJA LEBIH MASA',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 16),
                  const Text('hasani BOOKS',
                      style: TextStyle(
                          color: Color(0xFF3155A4),
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(
                      color: const Color(0xFF3155A4), width: 1.1),
                  columnWidths: const {
                    0: FixedColumnWidth(90),
                    1: FlexColumnWidth(),
                    2: FixedColumnWidth(105),
                    3: FlexColumnWidth(),
                  },
                  children: [
                    TableRow(children: [
                      cell('NAMA'),
                      cell(name, alignment: Alignment.centerLeft),
                      cell('CAWANGAN'),
                      cell(branch, alignment: Alignment.centerLeft),
                    ]),
                    TableRow(children: [
                      cell('BAHAGIAN'),
                      cell(department, alignment: Alignment.centerLeft),
                      cell('NO. PEKERJA'),
                      cell(employeeId, alignment: Alignment.centerLeft),
                    ]),
                  ],
                ),
                const SizedBox(height: 10),
                Table(
                  border: TableBorder.all(
                      color: const Color(0xFF3155A4), width: 1.1),
                  columnWidths: const {
                    0: FixedColumnWidth(42),
                    1: FixedColumnWidth(110),
                    2: FixedColumnWidth(105),
                    3: FixedColumnWidth(115),
                    4: FixedColumnWidth(105),
                    5: FixedColumnWidth(130),
                    6: FlexColumnWidth(),
                    7: FixedColumnWidth(130),
                  },
                  children: [
                    TableRow(children: [
                      cell('NO', header: true),
                      cell('TARIKH', header: true),
                      cell('MASA\nMASUK', header: true),
                      cell('KELUAR\nSEBENAR', header: true),
                      cell('KELUAR', header: true),
                      cell('JUMLAH LEBIH MASA\n(JAM:MINIT)', header: true),
                      cell('SEBAB\nLEBIH MASA', header: true),
                      cell('DISAHKAN\nOLEH', header: true),
                    ]),
                    TableRow(children: [
                      cell('1'),
                      cell(date),
                      cell(_shortTime(request['shift_start'])),
                      cell(_shortTime(request['overtime_start'])),
                      cell(_shortTime(request['overtime_end'])),
                      cell(_otMinutesText(requested)),
                      cell(request['reason']?.toString() ?? '-'),
                      cell(status.toUpperCase()),
                    ]),
                    for (var row = 2; row <= 8; row++)
                      TableRow(children: [
                        cell('$row'),
                        cell(''),
                        cell(''),
                        cell(''),
                        cell(''),
                        cell(''),
                        cell(''),
                        cell(''),
                      ]),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    'Tuntutan kerja lebih masa tidak sah sekiranya tiada kelulusan oleh pengurus cawangan dengan sebab yang munasabah.',
                    style: TextStyle(color: Color(0xFF3155A4), fontSize: 11),
                  ),
                ),
                Row(children: [
                  Expanded(
                      child: cell(
                          'DIMOHON OLEH\n$name\n${stamp(request['submitted_at'])}',
                          header: true,
                          height: 80)),
                  Expanded(
                      child: cell(
                          'DISEMAK OLEH\n$branch\n${stamp(request['branch_approved_at'])}',
                          header: true,
                          height: 80)),
                  Expanded(
                      child: cell(
                          'DISAHKAN OLEH\nADMIN\n${stamp(request['admin_approved_at'])}',
                          header: true,
                          height: 80)),
                ]),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final bytes = await OtRequestPdfService.build(request);
                        await Printing.layoutPdf(onLayout: (_) async => bytes);
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                              content: Text('Unable to print OT form: $error')),
                        );
                      }
                    },
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print'),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: approved,
                      enabled:
                          status == 'pending_admin' || status == 'approved',
                      decoration: const InputDecoration(
                          labelText: 'Approved HH:MM',
                          border: OutlineInputBorder(),
                          isDense: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (status == 'pending_admin') ...[
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await _reviewOtRequest(request, false);
                      },
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (status == 'pending_admin' || status == 'approved')
                    FilledButton(
                      onPressed: () async {
                        _approvedOtInputs[key] = approved.text;
                        Navigator.pop(dialogContext);
                        await _reviewOtRequest(request, true,
                            approvedText: approved.text);
                      },
                      child: Text(
                          status == 'approved' ? 'Update Approval' : 'Approve'),
                    ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
    approved.dispose();
  }

  Widget _otRequestsPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OT Requests',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text(
                        'Review overtime requests separately from employee requests.',
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              IconButton(
                  onPressed: _refreshOtRequests,
                  tooltip: 'Refresh OT requests',
                  icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadOtRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          'Unable to load OT requests:\n${snapshot.error}',
                          textAlign: TextAlign.center));
                }
                final requests =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                if (requests.isEmpty) {
                  return const Center(child: Text('No pending OT requests.'));
                }
                return ListView.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final employeeId =
                        request['employee_id']?.toString() ?? '-';
                    final employee = service.employeeById(employeeId);
                    final employeeName = employee?.name ?? employeeId;
                    final branchId = request['branch_id']?.toString() ?? '-';
                    final date = request['overtime_date']?.toString() ?? '-';
                    final minutes =
                        request['requested_minutes']?.toString() ?? '0';
                    final approvedMinutes =
                        request['approved_minutes']?.toString();
                    final requestKey = '$employeeId|$date';
                    _approvedOtInputs.putIfAbsent(
                        requestKey,
                        () => _otMinutesText(
                            int.tryParse(approvedMinutes ?? minutes) ?? 0));
                    final shiftStart = _shortTime(request['shift_start']);
                    final shiftEnd = _shortTime(request['shift_end']);
                    final actualStart =
                        (request['overtime_start'] ?? '-').toString();
                    final actualEnd =
                        (request['overtime_end'] ?? '-').toString();
                    final reason = request['reason']?.toString() ?? '-';
                    final status = request['status']?.toString() ?? 'pending';
                    final canAdminApprove = status == 'pending_admin';
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        onTap: () => _showOtRequestForm(request),
                        leading:
                            const CircleAvatar(child: Icon(Icons.more_time)),
                        title: Text(employeeName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('$employeeId • $branchId • $date'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _otInfo('Shift', '$shiftStart–$shiftEnd'),
                            const SizedBox(width: 12),
                            _otInfo('Actual', '$actualStart–$actualEnd'),
                            const SizedBox(width: 12),
                            _otInfo('Reason', reason),
                            const SizedBox(width: 12),
                            _otInfo('Requested',
                                _otMinutesText(int.tryParse(minutes) ?? 0)),
                            const SizedBox(width: 12),
                            SizedBox(
                                width: 135,
                                child: TextFormField(
                                  initialValue: _approvedOtInputs[requestKey],
                                  enabled:
                                      canAdminApprove || status == 'approved',
                                  decoration: const InputDecoration(
                                      labelText: 'Approved HH:MM',
                                      isDense: true),
                                  onChanged: (value) =>
                                      _approvedOtInputs[requestKey] = value,
                                )),
                            const SizedBox(width: 10),
                            if (canAdminApprove) ...[
                              OutlinedButton(
                                onPressed: () =>
                                    _reviewOtRequest(request, false),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () => _reviewOtRequest(request, true,
                                    approvedText:
                                        _approvedOtInputs[requestKey]),
                                child: const Text('Approve'),
                              ),
                            ] else if (status == 'approved') ...[
                              _statusChip(status),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: () => _reviewOtRequest(request, true,
                                    approvedText:
                                        _approvedOtInputs[requestKey]),
                                child: const Text('Update approval'),
                              ),
                            ] else
                              _statusChip(status),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewOtRequest(
    Map<String, dynamic> request,
    bool approve, {
    String? approvedText,
  }) async {
    try {
      if (approve && request['status']?.toString() == 'pending_branch') {
        throw Exception('Branch approval is required before admin approval.');
      }
      final approvedMinutes =
          approve ? _parseOtMinutes(approvedText ?? '') : null;
      if (approve && approvedMinutes == null) {
        throw Exception('Enter approved OT as HH:MM, for example 01:30.');
      }
      await SupabaseService.reviewOtRequest(
        requestId: request['id'].toString(),
        approve: approve,
        approvedOtMinutes: approvedMinutes,
      );
      _refreshOtRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  approve ? 'OT request approved.' : 'OT request rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to review OT request: $e')));
      }
    }
  }

  Widget _otInfo(String label, String value) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.black54)),
          Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
        ],
      );

  String _shortTime(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length >= 5 ? text.substring(0, 5) : 'Not assigned';
  }

  String _otMinutesText(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  int? _parseOtMinutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hours = int.tryParse(match.group(1)!);
    final minutes = int.tryParse(match.group(2)!);
    if (hours == null || minutes == null || minutes > 59) return null;
    final total = hours * 60 + minutes;
    return total <= 1440 ? total : null;
  }

  // EMPLOYEE REQUEST APPROVAL
  // ===========================================================================

  Future<List<Map<String, dynamic>>> _loadEmployeeRequests() {
    return _employeeRequestsFuture ??=
        SupabaseService.getEmployeeRequests(status: 'PENDING');
  }

  void _refreshEmployeeRequests() {
    setState(() => _employeeRequestsFuture = null);
  }

  Widget _employeeRequestsPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Employee Requests',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text(
                        'Verify branch submissions, assign an Employee ID, then approve.',
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refreshEmployeeRequests,
                tooltip: 'Refresh requests',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadEmployeeRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          'Unable to load employee requests:\n${snapshot.error}',
                          textAlign: TextAlign.center));
                }
                final requests =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                if (requests.isEmpty) {
                  return const Center(
                      child: Text('No pending employee requests.'));
                }
                return ListView.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final name =
                        request['name']?.toString() ?? 'Unnamed employee';
                    final branch = request['branch_id']?.toString() ?? '-';
                    final requestedAt = _logDateText(request['requested_at']);
                    final details = <String>[
                      if (request['designation']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true)
                        'Designation: ${request['designation']}',
                      if (request['department']?.toString().trim().isNotEmpty ==
                          true)
                        'Department: ${request['department']}',
                      if (request['new_ic_no']?.toString().trim().isNotEmpty ==
                          true)
                        'IC: ${request['new_ic_no']}',
                      if (request['email']?.toString().trim().isNotEmpty ==
                          true)
                        'Email: ${request['email']}',
                      if (request['phone']?.toString().trim().isNotEmpty ==
                          true)
                        'Phone: ${request['phone']}',
                      if (request['joining_date']
                              ?.toString()
                              .trim()
                              .isNotEmpty ==
                          true)
                        'Joining: ${request['joining_date']}',
                      if (request['bank_code']?.toString().trim().isNotEmpty ==
                          true)
                        'Bank: ${request['bank_code']} ${request['bank_account'] ?? ''}',
                      if (request['address']?.toString().trim().isNotEmpty ==
                          true)
                        'Address: ${request['address']}',
                    ];
                    return Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                                child: Icon(Icons.person_outline)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text('$branch • Requested $requestedAt',
                                      style: const TextStyle(
                                          color: Colors.black54, fontSize: 12)),
                                  if (details.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 14,
                                      runSpacing: 5,
                                      children: details
                                          .map((detail) => Text(detail,
                                              style: const TextStyle(
                                                  fontSize: 12)))
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () => _editEmployeeRequest(request),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _rejectEmployeeRequest(request),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => _approveEmployeeRequest(request),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editEmployeeRequest(Map<String, dynamic> request) async {
    const labels = <String, String>{
      'name': 'Name',
      'designation': 'Designation',
      'department': 'Department',
      'email': 'Email',
      'new_ic_no': 'IC No.',
      'bank_code': 'Bank Code',
      'bank_account': 'Bank Account',
      'phone': 'Phone',
      'address': 'Address',
      'joining_date': 'Joining Date (YYYY-MM-DD)',
    };
    final fields = {
      for (final item in labels.entries)
        item.key:
            TextEditingController(text: request[item.key]?.toString() ?? '')
    };
    var branchId = request['branch_id']?.toString() ?? '';
    var saving = false;
    await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: Text('Edit ${request['name'] ?? 'Employee Request'}'),
                content: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...labels.entries.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TextField(
                                  controller: fields[item.key],
                                  enabled: !saving,
                                  maxLines: item.key == 'address' ? 2 : 1,
                                  decoration: InputDecoration(
                                      labelText: item.value,
                                      border: const OutlineInputBorder())),
                            )),
                        DropdownButtonFormField<String>(
                          initialValue: service.branches
                                  .any((branch) => branch.id == branchId)
                              ? branchId
                              : null,
                          decoration: const InputDecoration(
                              labelText: 'Branch',
                              border: OutlineInputBorder()),
                          items: service.branches
                              .map((branch) => DropdownMenuItem(
                                  value: branch.id, child: Text(branch.name)))
                              .toList(),
                          onChanged: saving
                              ? null
                              : (value) => setDialogState(
                                  () => branchId = value ?? branchId),
                        ),
                      ],
                    ))),
                actions: [
                  TextButton(
                      onPressed:
                          saving ? null : () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setDialogState(() => saving = true);
                              try {
                                await SupabaseService.updateEmployeeRequest(
                                  requestId: request['id'].toString(),
                                  changes: {
                                    for (final item in fields.entries)
                                      item.key: item.value.text.trim(),
                                    'branch_id': branchId
                                  },
                                );
                                if (!mounted) return;
                                Navigator.pop(dialogContext);
                                _refreshEmployeeRequests();
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Employee request updated. You can now approve it.')));
                              } catch (error) {
                                if (!dialogContext.mounted) return;
                                setDialogState(() => saving = false);
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(SnackBar(
                                        content: Text(
                                            'Unable to update request: $error')));
                              }
                            },
                      child: Text(saving ? 'Saving...' : 'Save Changes')),
                ],
              ),
            ));
    for (final field in fields.values) {
      field.dispose();
    }
  }

  Future<void> _approveEmployeeRequest(Map<String, dynamic> request) async {
    final employeeId = TextEditingController();
    String? error;
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Approve ${request['name'] ?? 'Employee'}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Branch: ${request['branch_id'] ?? '-'}'),
                const SizedBox(height: 14),
                TextField(
                  controller: employeeId,
                  enabled: !saving,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Assign Employee ID *',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final id = employeeId.text.trim().toUpperCase();
                      if (id.isEmpty) {
                        setDialogState(
                            () => error = 'Employee ID is required.');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await SupabaseService.approveEmployeeRequest(
                          requestId: request['id'].toString(),
                          employeeId: id,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        setState(() {
                          _employeeRequestsFuture = null;
                          _adminEmployeesFuture = null;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Employee approved with ID $id.')),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            error = 'Approval failed: $e';
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Approving...' : 'Approve Employee'),
            ),
          ],
        ),
      ),
    );
    employeeId.dispose();
  }

  Future<void> _rejectEmployeeRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Employee Request?'),
        content: Text(
            'Reject the request for ${request['name'] ?? 'this employee'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.rejectEmployeeRequest(
          requestId: request['id'].toString());
      _refreshEmployeeRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to reject request: $e')));
      }
    }
  }

  // BRANCH ACTIVITY LOGS
  // ===========================================================================

  Future<List<Map<String, dynamic>>> _loadBranchLogs() {
    return _branchLogsFuture ??= SupabaseService.getBranchActivityLogs(
      branchId: selectedLogBranchId,
      date: selectedLogDate,
    );
  }

  void _refreshBranchLogs() {
    setState(() {
      _branchLogsFuture = null;
    });
  }

  DateTime? _logDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _logDateText(dynamic value) {
    final date = _logDate(value);
    return date == null
        ? 'Still open'
        : DateFormat('dd MMM yyyy, hh:mm:ss a').format(date);
  }

  String _logDuration(Map<String, dynamic> log) {
    final opened = _logDate(log['opened_at']);
    final closed = _logDate(log['closed_at']);
    if (opened == null || closed == null) return '-';
    final duration = closed.difference(opened);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${hours}h ${minutes}m ${seconds}s'
        : '${minutes}m ${seconds}s';
  }

  String _logAction(dynamic value) {
    switch (value?.toString()) {
      case 'BRANCH_LOGIN':
        return 'Branch login session';
      case 'ATTENDANCE_OPENED':
        return 'Attendance opened';
      case 'ROSTER_ASSIGNED':
        return 'Roster assigned';
      default:
        return value?.toString().replaceAll('_', ' ') ?? 'Activity';
    }
  }

  String _logDetails(dynamic value) {
    if (value is! Map || value.isEmpty) return '';
    const labels = <String, String>{
      'username': 'User',
      'month': 'Month',
      'week': 'Week',
      'shift': 'Shift',
      'shift_start': 'Start',
      'shift_end': 'End',
      'break_minutes': 'Break',
      'off_day': 'OFF',
      'employee_count': 'Employees',
      'employee_ids': 'IDs',
    };
    final parts = <String>[];
    for (final entry in value.entries) {
      final item = entry.value;
      if (item == null || item.toString().trim().isEmpty) continue;
      var text = item is List ? item.join(', ') : item.toString();
      if (entry.key == 'break_minutes') text = '$text min';
      parts.add('${labels[entry.key] ?? entry.key}: $text');
    }
    return parts.join(' • ');
  }

  Future<void> _showRosterAssignment(Map<String, dynamic> log) async {
    final branchId = log['branch_id']?.toString().trim() ?? '';
    final rawDetails = log['details'];
    final details = rawDetails is Map
        ? Map<String, dynamic>.from(rawDetails)
        : <String, dynamic>{};
    final period = details['month']?.toString() ?? '';
    final parts = period.split('-');
    final year = parts.isNotEmpty ? int.tryParse(parts.first) : null;
    final month = parts.length > 1 ? int.tryParse(parts[1]) : null;

    if (branchId.isEmpty || year == null || month == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This log does not contain a valid roster period.'),
      ));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 1100,
          height: 720,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$branchId roster - ${DateFormat('MMMM yyyy').format(DateTime(year, month))}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: MonthlyRosterPage(
                  branchId: branchId,
                  initialMonth: DateTime(year, month),
                  readOnly: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _branchLogsPage() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Branch Activity Logs',
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Monitor branch login and employee attendance access.',
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedLogDate ?? DateTime.now(),
                    firstDate: DateTime(2022),
                    lastDate: DateTime(DateTime.now().year + 2),
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      selectedLogDate = picked;
                      _branchLogsFuture = null;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(selectedLogDate == null
                    ? 'All dates'
                    : DateFormat('dd MMM yyyy').format(selectedLogDate!)),
              ),
              if (selectedLogDate != null)
                IconButton(
                  tooltip: 'Show all dates',
                  onPressed: () => setState(() {
                    selectedLogDate = null;
                    _branchLogsFuture = null;
                  }),
                  icon: const Icon(Icons.close, size: 18),
                ),
              const SizedBox(width: 10),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: selectedLogBranchId,
                  decoration: const InputDecoration(
                      labelText: 'Branch', border: OutlineInputBorder()),
                  hint: const Text('All branches'),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('All branches')),
                    ...service.branches
                        .map((branch) => DropdownMenuItem<String>(
                              value: branch.id,
                              child: Text(branch.name),
                            )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedLogBranchId = value;
                      _branchLogsFuture = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                  onPressed: _refreshBranchLogs,
                  tooltip: 'Refresh logs',
                  icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadBranchLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          'Unable to load branch logs:\n${snapshot.error}',
                          textAlign: TextAlign.center));
                }
                final logs = snapshot.data ?? const <Map<String, dynamic>>[];
                if (logs.isEmpty) {
                  return const Center(
                      child: Text('No branch activity has been recorded yet.'));
                }
                return ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final employeeName =
                        log['employee_name']?.toString().trim() ?? '';
                    final employeeId =
                        log['employee_id']?.toString().trim() ?? '';
                    final isOpen = log['closed_at'] == null;
                    final isRoster =
                        log['action']?.toString() == 'ROSTER_ASSIGNED';
                    final detailsText = _logDetails(log['details']);
                    final employeeText = employeeName.isEmpty
                        ? employeeId
                        : '$employeeName${employeeId.isEmpty ? '' : ' ($employeeId)'}';
                    return Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isOpen
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          child: Icon(
                              isOpen
                                  ? Icons.visibility_outlined
                                  : Icons.history,
                              color: isOpen ? Colors.orange : Colors.green),
                        ),
                        title: Text(
                            '${log['branch_id'] ?? '-'} • ${_logAction(log['action'])}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${employeeText.isEmpty ? '' : '$employeeText • '}'
                              '${_logDateText(log['opened_at'])} → ${_logDateText(log['closed_at'])}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                            if (detailsText.isNotEmpty)
                              Text(
                                detailsText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black54),
                              ),
                          ],
                        ),
                        trailing: isRoster
                            ? OutlinedButton.icon(
                                onPressed: () => _showRosterAssignment(log),
                                icon: const Icon(Icons.calendar_view_month,
                                    size: 17),
                                label: const Text('View roster'),
                              )
                            : Text(_logDuration(log),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ATTENDANCE
  // ===========================================================================

  // ===========================================================================
// ATTENDANCE
// ===========================================================================

  Widget _monthYearSelector({
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    final currentYear = DateTime.now().year;
    final years =
        List<int>.generate(currentYear - 2019 + 2, (index) => 2020 + index);
    if (!years.contains(value.year)) years.add(value.year);
    years.sort((a, b) => b.compareTo(a));

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 145,
          child: DropdownButtonFormField<int>(
            initialValue: value.month,
            isDense: true,
            decoration: const InputDecoration(
                labelText: 'Month',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: List.generate(
                12,
                (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(
                        DateFormat.MMMM().format(DateTime(2000, index + 1))))),
            onChanged: (month) {
              if (month != null) onChanged(DateTime(value.year, month));
            },
          ),
        ),
        SizedBox(
          width: 115,
          child: DropdownButtonFormField<int>(
            initialValue: value.year,
            isDense: true,
            decoration: const InputDecoration(
                labelText: 'Year',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: years
                .map((year) =>
                    DropdownMenuItem(value: year, child: Text('$year')))
                .toList(),
            onChanged: (year) {
              if (year != null) onChanged(DateTime(year, value.month));
            },
          ),
        ),
      ],
    );
  }

  bool _mapRecordMatchesMonth(Map<String, dynamic> record, DateTime month) {
    final raw = record['date'] ?? record['attendance_date'] ?? record['period'];
    final date =
        raw is DateTime ? raw : DateTime.tryParse(raw?.toString() ?? '');
    return date != null && date.year == month.year && date.month == month.month;
  }

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
                const SizedBox(height: 14),
                _monthYearSelector(
                  value: selectedAttendanceMonth,
                  onChanged: (value) =>
                      setState(() => selectedAttendanceMonth = value),
                ),
                const SizedBox(height: 16),
                if (branches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No branches found.')),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      mainAxisExtent: 132,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: branches.length,
                    itemBuilder: (context, index) {
                      final branch = branches[index];
                      final id = (branch['id'] ?? branch['branch_id'] ?? '')
                          .toString();
                      final name =
                          (branch['name'] ?? branch['branch_name'] ?? id)
                              .toString();
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: id.isEmpty
                            ? null
                            : () =>
                                setState(() => selectedAttendanceBranchId = id),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                                color: Colors.blueGrey.withOpacity(.20)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 20,
                                  child: Icon(Icons.store_outlined, size: 21),
                                ),
                                const Spacer(),
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                const Row(
                                  children: [
                                    Text('View Attendance',
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12)),
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
              child: Text('Unable to load attendance:\n${snapshot.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }

        final data = snapshot.data ?? const [[], [], []];
        final branches = List<Map<String, dynamic>>.from(data[0] as List);
        final employees = List<Map<String, dynamic>>.from(data[1] as List);
        final attendance = List<Map<String, dynamic>>.from(data[2] as List)
            .where((record) =>
                _mapRecordMatchesMonth(record, selectedAttendanceMonth))
            .toList();
        final search = _attendanceEmployeeSearch.trim().toLowerCase();
        final filteredEmployees = employees.where((employee) {
          if (search.isEmpty) return true;
          final id = (employee['employee_id'] ?? employee['id'] ?? '')
              .toString()
              .toLowerCase();
          final name = (employee['name'] ?? employee['full_name'] ?? '')
              .toString()
              .toLowerCase();
          return id.contains(search) || name.contains(search);
        }).toList();

        final branch = branches.firstWhere(
          (item) =>
              (item['id'] ?? item['branch_id'] ?? '').toString() == branchId,
          orElse: () => <String, dynamic>{},
        );
        final branchName =
            (branch['name'] ?? branch['branch_name'] ?? branchId).toString();

        final employeeMap = <String, Map<String, dynamic>>{};
        for (final employee in employees) {
          final id =
              (employee['employee_id'] ?? employee['id'] ?? '').toString();
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
                  onPressed: () =>
                      setState(() => selectedAttendanceBranchId = null),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('All Branches'),
                ),
                const SizedBox(height: 8),
                Text(branchName,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    '${filteredEmployees.length} of ${employees.length} employee(s)',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    _monthYearSelector(
                      value: selectedAttendanceMonth,
                      onChanged: (value) =>
                          setState(() => selectedAttendanceMonth = value),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _attendanceEmployeeSearchController,
                        onSubmitted: (value) =>
                            setState(() => _attendanceEmployeeSearch = value),
                        decoration: InputDecoration(
                          labelText: 'Search employee',
                          hintText: 'Name or employee ID',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: IconButton(
                            tooltip: 'Search',
                            icon: const Icon(Icons.search),
                            onPressed: () => setState(() =>
                                _attendanceEmployeeSearch =
                                    _attendanceEmployeeSearchController.text),
                          ),
                        ),
                      ),
                    ),
                    if (_attendanceEmployeeSearch.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _attendanceEmployeeSearchController.clear();
                          setState(() => _attendanceEmployeeSearch = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (filteredEmployees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No matching employees found.')),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250,
                      mainAxisExtent: 112,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: filteredEmployees.length,
                    itemBuilder: (context, index) {
                      final employee = filteredEmployees[index];
                      final employeeId =
                          (employee['employee_id'] ?? employee['id'] ?? '')
                              .toString();
                      final name = (employee['name'] ??
                              employee['full_name'] ??
                              employeeId)
                          .toString();
                      final records = byEmployee[employeeId] ??
                          const <Map<String, dynamic>>[];
                      final submitted = records
                          .any((r) => _attendanceBool(r['is_submitted']));

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openAdminAttendance(
                          employee,
                          branchId,
                        ),
                        child: Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: Colors.blueGrey.withOpacity(.20),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundColor: const Color(0xFFE7F7EF),
                                      child: Text(
                                        name.isEmpty
                                            ? '?'
                                            : name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFF15965D),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: submitted
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        submitted ? 'SUBMITTED' : 'PENDING',
                                        style: TextStyle(
                                          color: submitted
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Employee ID: $employeeId',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      submitted
                                          ? Icons.edit_outlined
                                          : Icons.lock_outline,
                                      size: 14,
                                      color: submitted
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        submitted
                                            ? 'Branch submitted • Admin can edit'
                                            : 'Waiting for Branch submission',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
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

  bool _attendanceBool(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().toLowerCase().trim() ?? '';
    return text == 'true' || text == '1' || text == 'yes';
  }

  void _openAdminAttendance(
    Map<String, dynamic> employee,
    String branchId,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AttendanceDialog(
        employee: employee,
        month: selectedAttendanceMonth,
        branchId: branchId,

        // Same attendance sheet as Branch Portal.
        editable: true,

        // Admin does NOT submit attendance.
        showSubmitButton: false,

        // Admin can edit only after Branch has submitted.
        adminOnlyAfterSubmit: true,
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

// ============================================================================
// EMPLOYEE CSV IMPORT
// ============================================================================

  Future<void> _importEmployeesCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to read the selected CSV file.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final csvText = utf8.decode(
        bytes,
        allowMalformed: true,
      );

      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(csvText);

      if (rows.isEmpty) {
        throw Exception('The CSV file is empty.');
      }

      final headers = rows.first
          .map(
            (value) => value.toString().replaceFirst('\uFEFF', '').trim(),
          )
          .toList();

      if (headers.isEmpty) {
        throw Exception('The CSV file has no headers.');
      }

      const requiredHeaders = [
        'employeeId',
        'name',
        'designation',
        'department',
        'email',
        'newIcNo',
        'bankCode',
        'bankAccount',
        'phone',
        'address',
        'joiningDate',
        'isActive',
        'branchId',
      ];

      final missingHeaders =
          requiredHeaders.where((header) => !headers.contains(header)).toList();

      if (missingHeaders.isNotEmpty) {
        throw Exception(
          'Missing required CSV columns:\n'
          '${missingHeaders.join(', ')}',
        );
      }

      String valueAt(
        List<dynamic> row,
        String header,
      ) {
        final index = headers.indexOf(header);

        if (index < 0 || index >= row.length) {
          return '';
        }

        return row[index].toString().trim();
      }

      bool parseBool(String value) {
        final normalized = value.toLowerCase().trim();

        return normalized == 'true' ||
            normalized == '1' ||
            normalized == 'yes' ||
            normalized == 'active' ||
            normalized == 'y';
      }

      final employeeRows = <Map<String, dynamic>>[];

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];

        if (row.isEmpty) {
          continue;
        }

        final employeeId = valueAt(
          row,
          'employeeId',
        );

        if (employeeId.isEmpty) {
          continue;
        }

        employeeRows.add({
          'employee_id': employeeId,
          'name': valueAt(row, 'name'),
          'designation': valueAt(row, 'designation'),
          'department': valueAt(row, 'department'),
          'email': valueAt(row, 'email'),
          'new_ic_no': valueAt(row, 'newIcNo'),
          'bank_code': valueAt(row, 'bankCode'),
          'bank_account': valueAt(row, 'bankAccount'),
          'phone': valueAt(row, 'phone'),
          'address': valueAt(row, 'address'),
          'joining_date': valueAt(
            row,
            'joiningDate',
          ).isEmpty
              ? null
              : valueAt(
                  row,
                  'joiningDate',
                ),
          'is_active': parseBool(
            valueAt(row, 'isActive'),
          ),
          'branch_id': valueAt(
            row,
            'branchId',
          ).isEmpty
              ? null
              : valueAt(
                  row,
                  'branchId',
                ),
        });
      }

      if (employeeRows.isEmpty) {
        throw Exception(
          'No valid employee records were found in the CSV file.',
        );
      }

      if (!mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Importing employees...',
                ),
              ),
            ],
          ),
        ),
      );

      try {
        await SupabaseService.client.from('employees').upsert(
              employeeRows,
              onConflict: 'employee_id',
            );

        if (!mounted) return;

        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${employeeRows.length} employee record(s) imported successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {});
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
        }

        rethrow;
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Employee CSV import failed: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// ============================================================================
// EMPLOYEE CSV IMPORT PAGE
// ============================================================================

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
                  'Existing employees are updated using employee_id.',
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

// ============================================================================
// PAYROLL GENERATION DIALOG
// ============================================================================

  Future<void> _showGenerateAttendancePayrollDialog() async {
    DateTime selectedMonth = selectedPayrollMonth;

    final branchesFuture = SupabaseService.getBranches();
    final employeesFuture = SupabaseService.client
        .from('employees')
        .select(
          'employee_id,name,branch_id,is_active',
        )
        .eq('is_active', true)
        .order('employee_id');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return FutureBuilder<List<dynamic>>(
              future: Future.wait([
                branchesFuture,
                employeesFuture,
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AlertDialog(
                    title: Text('Generate Payroll'),
                    content: SizedBox(
                      width: 500,
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return AlertDialog(
                    title: const Text('Generate Payroll'),
                    content: Text(
                      'Unable to load branches/employees:\n\n${snapshot.error}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                }

                final data = snapshot.data ?? const [[], []];
                final branches = List<Map<String, dynamic>>.from(
                  data[0] as List,
                );
                final employees = List<Map<String, dynamic>>.from(
                  data[1] as List,
                );

                final branchGroups = <String, List<Map<String, dynamic>>>{};
                final branchNames = <String, String>{};

                for (final branch in branches) {
                  final id = _branchIdFromMap(branch);
                  final name = _branchNameFromMap(branch, id);
                  if (id.isNotEmpty) {
                    branchGroups.putIfAbsent(id, () => []);
                    branchNames[id] = name;
                  }
                }

                for (final employee in employees) {
                  final branchId = _normalizeBranchValue(
                    employee['branch_id'],
                  );
                  if (branchId.isEmpty) continue;
                  branchGroups.putIfAbsent(branchId, () => []).add(employee);
                  branchNames.putIfAbsent(
                    branchId,
                    () => branchId,
                  );
                }

                final branchIds = branchGroups.keys.toList()
                  ..sort(
                    (a, b) => (branchNames[a] ?? a).toLowerCase().compareTo(
                          (branchNames[b] ?? b).toLowerCase(),
                        ),
                  );

                return AlertDialog(
                  title: const Text('Generate Payroll'),
                  content: SizedBox(
                    width: 900,
                    height: 650,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Payroll Month: ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            OutlinedButton(
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
                                    selectedMonth = DateTime(
                                      picked.year,
                                      picked.month,
                                    );
                                  });
                                }
                              },
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Select a branch first. Then select the employees whose payroll you want to generate.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: branchIds.isEmpty
                              ? const Center(
                                  child: Text('No branches found.'),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 280,
                                    mainAxisExtent: 145,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                  ),
                                  itemCount: branchIds.length,
                                  itemBuilder: (context, index) {
                                    final branchId = branchIds[index];
                                    final branchEmployees =
                                        branchGroups[branchId] ?? [];

                                    return Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color:
                                              Colors.blueGrey.withOpacity(.20),
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () async {
                                          await _showPayrollEmployeeSelection(
                                            branchName: branchNames[branchId] ??
                                                branchId,
                                            employees: branchEmployees,
                                            month: selectedMonth,
                                          );

                                          if (mounted) {
                                            setDialogState(() {});
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const CircleAvatar(
                                                radius: 24,
                                                child: Icon(
                                                  Icons.account_tree_outlined,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                branchNames[branchId] ??
                                                    branchId,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${branchEmployees.length} employee(s) • Select to generate',
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
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
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showPayrollEmployeeSelection({
    required String branchName,
    required List<Map<String, dynamic>> employees,
    required DateTime month,
  }) async {
    final selectedIds = <String>{};
    bool selectAll = false;
    bool overwriteExisting = true;

    await showDialog<void>(
      context: context,
      builder: (selectionContext) {
        return StatefulBuilder(
          builder: (context, setSelectionState) {
            final allIds = employees
                .map((e) => _normalizeBranchValue(e['employee_id']))
                .where((id) => id.isNotEmpty)
                .toSet();

            return AlertDialog(
              title: Text('Generate Payroll • $branchName'),
              content: SizedBox(
                width: 760,
                height: 620,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMMM yyyy').format(month),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text('${employees.length} employee(s)'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Select only the employees you want to generate payroll for.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: selectAll,
                          onChanged: (value) {
                            setSelectionState(() {
                              selectAll = value ?? false;
                              selectedIds
                                ..clear()
                                ..addAll(
                                  selectAll ? allIds : <String>{},
                                );
                            });
                          },
                        ),
                        const Text(
                          'Select all employees',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text('${selectedIds.length} selected'),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: employees.isEmpty
                          ? const Center(
                              child: Text('No employees in this branch.'),
                            )
                          : ListView.separated(
                              itemCount: employees.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final employee = employees[index];
                                final employeeId = _normalizeBranchValue(
                                  employee['employee_id'],
                                );
                                final name =
                                    (employee['name'] ?? employeeId).toString();
                                final checked =
                                    selectedIds.contains(employeeId);

                                return CheckboxListTile(
                                  value: checked,
                                  onChanged: (value) {
                                    setSelectionState(() {
                                      if (value == true) {
                                        selectedIds.add(employeeId);
                                      } else {
                                        selectedIds.remove(employeeId);
                                        selectAll = false;
                                      }

                                      if (selectedIds.length == allIds.length &&
                                          allIds.isNotEmpty) {
                                        selectAll = true;
                                      }
                                    });
                                  },
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(employeeId),
                                  secondary: const Icon(Icons.person_outline),
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: overwriteExisting,
                      title: const Text('Replace existing payroll'),
                      subtitle: const Text(
                        'Update the selected employee payroll if it already exists for this month.',
                      ),
                      onChanged: (value) {
                        setSelectionState(() {
                          overwriteExisting = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(selectionContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () async {
                          final ids = selectedIds.toList();
                          Navigator.of(selectionContext).pop();
                          await _generateSelectedPayroll(
                            month: month,
                            employeeIds: ids,
                            overwriteExisting: overwriteExisting,
                            branchName: branchName,
                          );
                        },
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(
                    'Generate ${selectedIds.length} Payroll',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateSelectedPayroll({
    required DateTime month,
    required List<String> employeeIds,
    required bool overwriteExisting,
    required String branchName,
  }) async {
    if (employeeIds.isEmpty || !mounted) return;

    selectedPayrollMonth = DateTime(month.year, month.month);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Generating Payroll'),
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                'Generating ${employeeIds.length} selected employee(s) for ${DateFormat('MMMM yyyy').format(month)}...',
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await AttendancePayrollService.generateMonthlyPayroll(
        month: month,
        employeeIds: employeeIds,
        overwriteExisting: overwriteExisting,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      setState(() {});

      await _showPayrollGenerationResult(
        result,
        branchName: branchName,
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payroll generation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPayrollGenerationResult(
    PayrollGenerationResult result, {
    required String branchName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Payroll Generation Complete'),
          content: SizedBox(
            width: 820,
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branchName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM yyyy').format(result.month),
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    Text('Generated: ${result.generatedCount}'),
                    Text('Skipped: ${result.skippedCount}'),
                    Text(
                      'Approved OT duration: ${result.totalOvertimeDuration.toStringAsFixed(2)}',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      ...result.generated.map(
                        (item) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          title: Text(
                            item.employeeName.isEmpty
                                ? item.employeeId
                                : item.employeeName,
                          ),
                          subtitle: Text(
                            '${item.employeeId} • '
                            'Basic RM ${item.basicSalary.toStringAsFixed(2)} • '
                            'FW RM ${item.fwSalary.toStringAsFixed(2)} • '
                            'Kedatangan RM ${item.elaunKedatangan.toStringAsFixed(2)} • '
                            'Perkhidmatan RM ${item.elaunPerkhidmatan.toStringAsFixed(2)} • '
                            'Kerajinan RM ${item.elaunKerajinan.toStringAsFixed(2)} • '
                            'Approved OT ${item.overtimeDuration.toStringAsFixed(2)} hours / '
                            'RM ${item.overtimeAmount.toStringAsFixed(2)} • '
                            'Cuti Umum RM ${item.cutiUmum.toStringAsFixed(2)} • '
                            'Unpaid ${item.unpaidDays} day(s) / '
                            'RM ${item.unpaidDeduction.toStringAsFixed(2)}',
                          ),
                        ),
                      ),
                      ...result.skipped.map(
                        (item) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.error_outline,
                            color: Colors.orange,
                          ),
                          title: Text(
                            item.employeeName.isEmpty
                                ? item.employeeId
                                : item.employeeName,
                          ),
                          subtitle: Text(item.message),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  String _branchIdFromMap(Map<String, dynamic> branch) {
    return _normalizeBranchValue(
      branch['id'] ?? branch['branch_id'],
    );
  }

  String _branchNameFromMap(
    Map<String, dynamic> branch,
    String fallback,
  ) {
    final value = branch['name'] ??
        branch['branch_name'] ??
        branch['location'] ??
        fallback;
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _normalizeBranchValue(dynamic value) {
    return value?.toString().trim().toUpperCase() ?? '';
  }

// ============================================================================
// PAYROLL PAGE
// ============================================================================

  Widget _payrollPage() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        SupabaseService.getBranches(),
        SupabaseService.client
            .from('employees')
            .select()
            .eq('is_active', true)
            .order('employee_id'),
        SupabaseService.client
            .from('payroll')
            .select()
            .order('period', ascending: false),
      ]),
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
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'Unable to load payroll page.\n\n${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data ?? const [[], [], []];
        final branches = List<Map<String, dynamic>>.from(data[0] as List);
        final employees = List<Map<String, dynamic>>.from(data[1] as List);
        final rawPayrollRecords =
            List<Map<String, dynamic>>.from(data[2] as List);

        final employeeBranchById = <String, String>{};
        for (final employee in employees) {
          final employeeId = _normalizeBranchValue(employee['employee_id']);
          final branchId = _normalizeBranchValue(employee['branch_id']);
          if (employeeId.isNotEmpty) employeeBranchById[employeeId] = branchId;
        }

        final branchGroups = <String, List<Map<String, dynamic>>>{};
        final branchNames = <String, String>{};

        for (final branch in branches) {
          final id = _branchIdFromMap(branch);
          final name = _branchNameFromMap(branch, id);
          if (id.isNotEmpty) {
            branchGroups.putIfAbsent(id, () => []);
            branchNames[id] = name;
          }
        }

        for (final employee in employees) {
          final branchId = _normalizeBranchValue(employee['branch_id']);
          if (branchId.isEmpty) continue;
          branchGroups.putIfAbsent(branchId, () => []).add(employee);
          branchNames.putIfAbsent(branchId, () => branchId);
        }

        final branchIds = branchGroups.keys.toList()
          ..sort(
            (a, b) => (branchNames[a] ?? a)
                .toLowerCase()
                .compareTo((branchNames[b] ?? b).toLowerCase()),
          );

        final payrollRecords = rawPayrollRecords.map((record) {
          final copy = Map<String, dynamic>.from(record);
          final employeeId = _normalizeBranchValue(record['employee_id']);
          final branchId = _normalizeBranchValue(
            record['branch_id'] ?? employeeBranchById[employeeId],
          );
          if (branchId.isNotEmpty) {
            copy['branch_id'] = branchId;
            copy['branch_name'] = branchNames[branchId] ?? branchId;
          }
          return copy;
        }).toList();

        final visiblePayrollRecords = payrollRecords.where((record) {
          final branchMatches = selectedPayrollBranchId == null ||
              _normalizeBranchValue(record['branch_id']) ==
                  selectedPayrollBranchId;

          final monthMatches = _payrollPeriodMatchesMonth(
            record['period'],
            selectedPayrollMonth,
          );

          return branchMatches && monthMatches;
        }).toList();

        double totalPayroll = 0;
        for (final payroll in visiblePayrollRecords) {
          totalPayroll += _payrollTotalEarnings(payroll);
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  'Select a branch, select employees, then generate payroll for the selected month.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _showGenerateAttendancePayrollDialog,
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Generate Payroll'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedPage = 5;
                        });
                      },
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Import Payroll CSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedPayrollMonth,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          helpText: 'Select Payroll Month',
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            selectedPayrollMonth = DateTime(
                              picked.year,
                              picked.month,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        DateFormat('MMMM yyyy').format(selectedPayrollMonth),
                      ),
                    ),
                    DropdownButton<String>(
                      value: selectedPayrollBranchId,
                      hint: const Text('All Branches'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Branches'),
                        ),
                        ...branchIds.map(
                          (id) => DropdownMenuItem<String>(
                            value: id,
                            child: Text(branchNames[id] ?? id),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => selectedPayrollBranchId = value);
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: visiblePayrollRecords.isEmpty
                          ? null
                          : () {
                              if (selectedPayrollBranchId == null) {
                                _exportPayrollAllBranchesExcel(
                                  visiblePayrollRecords,
                                  branchNames,
                                );
                              } else {
                                _exportPayrollBranchExcel(
                                  visiblePayrollRecords,
                                  selectedPayrollBranchId!,
                                  branchNames[selectedPayrollBranchId!] ??
                                      selectedPayrollBranchId!,
                                );
                              }
                            },
                      icon: const Icon(Icons.table_view_outlined),
                      label: Text(
                        selectedPayrollBranchId == null
                            ? 'Export All Branches Excel'
                            : 'Export Branch Excel',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Branches',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Click a branch to choose the employees for payroll generation.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 18),
                      if (branchIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(
                            child: Text('No branches found.'),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 290,
                            mainAxisExtent: 155,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: branchIds.length,
                          itemBuilder: (context, index) {
                            final branchId = branchIds[index];
                            final branchEmployees =
                                branchGroups[branchId] ?? [];

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.blueGrey.withOpacity(.20),
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await _showPayrollEmployeeSelection(
                                    branchName:
                                        branchNames[branchId] ?? branchId,
                                    employees: branchEmployees,
                                    month: selectedPayrollMonth,
                                  );
                                  if (mounted) setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const CircleAvatar(
                                        radius: 24,
                                        child: Icon(
                                          Icons.account_tree_outlined,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        branchNames[branchId] ?? branchId,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${branchEmployees.length} employee(s)',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
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
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 32) / 3;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _payrollSummaryCard(
                            'Total Payroll',
                            'RM ${totalPayroll.toStringAsFixed(2)}',
                            Icons.account_balance_wallet_outlined,
                            const Color(0xFF2D55D8),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _payrollSummaryCard(
                            'Employees',
                            employees.length.toString(),
                            Icons.people_outline,
                            const Color(0xFF16A34A),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _payrollSummaryCard(
                            'Payroll Records',
                            visiblePayrollRecords.length.toString(),
                            Icons.pending_actions_outlined,
                            const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        'Payroll records stored in Supabase.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 20),
                      if (payrollRecords.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 40,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _supabasePayrollTable(visiblePayrollRecords),
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

// ============================================================================
// PAYROLL SUMMARY CARD
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
                  overflow: TextOverflow.ellipsis,
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
// PAYROLL TOTAL
// ============================================================================

  double _payrollTotalEarnings(
    Map<String, dynamic> payroll,
  ) {
    return _payrollNumber(
          payroll['basic_salary'],
        ) +
        _payrollNumber(
          payroll['fw_salary'],
        ) +
        _payrollNumber(
          payroll['elaun_kedatangan'],
        ) +
        _payrollNumber(
          payroll['elaun_perkhidmatan'],
        ) +
        _payrollNumber(
          payroll['elaun_kerajinan'],
        ) +
        _payrollNumber(
          payroll['overtime'],
        ) +
        _payrollNumber(
          payroll['bonus'],
        ) +
        _payrollNumber(
          payroll['commission'],
        ) +
        _payrollNumber(
          payroll['other_earnings'],
        ) +
        _payrollNumber(
          payroll['cuti_umum'],
        );
  }

// ============================================================================
// PAYROLL CSV IMPORT
// ============================================================================

  Future<void> _importPayrollCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw Exception(
          'Unable to read the selected CSV file.',
        );
      }

      final csvText = utf8.decode(
        bytes,
        allowMalformed: true,
      );

      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(csvText);

      if (rows.isEmpty) {
        throw Exception(
          'The CSV file is empty.',
        );
      }

      final headers = rows.first
          .map(
            (value) => value.toString().replaceFirst('\uFEFF', '').trim(),
          )
          .toList();

      if (headers.isEmpty) {
        throw Exception(
          'The CSV file has no headers.',
        );
      }

      String databaseColumnName(
        String header,
      ) {
        final value = header.trim();

        const mappings = {
          'id': 'id',
          'employeeId': 'employee_id',
          'employeeID': 'employee_id',
          'employee_id': 'employee_id',
          'period': 'period',
          'month': 'period',
          'basicSalary': 'basic_salary',
          'basic_salary': 'basic_salary',
          'fwSalary': 'fw_salary',
          'fw_salary': 'fw_salary',
          'FW_salary': 'fw_salary',
          'FW SALARY': 'fw_salary',
          'elaunKedatangan': 'elaun_kedatangan',
          'elaun_kedatangan': 'elaun_kedatangan',
          'elaunPerkhidmatan': 'elaun_perkhidmatan',
          'elaun_perkhidmatan': 'elaun_perkhidmatan',
          'elaunKerajinan': 'elaun_kerajinan',
          'elaun_kerajinan': 'elaun_kerajinan',
          'overtime': 'overtime',
          'bonus': 'bonus',
          'commission': 'commission',
          'otherEarnings': 'other_earnings',
          'other_earnings': 'other_earnings',
          'cutiUmum': 'cuti_umum',
          'cuti_umum': 'cuti_umum',
          'epfEmployee': 'epf_employee',
          'epf_employee': 'epf_employee',
          'socsoEmployee': 'socso_employee',
          'socso_employee': 'socso_employee',
          'eisEmployee': 'eis_employee',
          'eis_employee': 'eis_employee',
          'pcb': 'pcb',
          'zakat': 'zakat',
          'epfEmployer': 'epf_employer',
          'epf_employer': 'epf_employer',
          'socsoEmployer': 'socso_employer',
          'socso_employer': 'socso_employer',
          'eisEmployer': 'eis_employer',
          'eis_employer': 'eis_employer',
          'newIcNo': 'new_ic_no',
          'new_ic_no': 'new_ic_no',
          'bankCode': 'bank_code',
          'bank_code': 'bank_code',
          'bankAccount': 'bank_account',
          'bank_account': 'bank_account',
          'remarks': 'remarks',
        };

        if (mappings.containsKey(value)) {
          return mappings[value]!;
        }

        return value
            .replaceAllMapped(
              RegExp(
                r'([a-z0-9])([A-Z])',
              ),
              (match) => '${match.group(1)}_'
                  '${match.group(2)}',
            )
            .toLowerCase();
      }

      double parseNumber(
        String value,
      ) {
        if (value.trim().isEmpty) {
          return 0;
        }

        final cleaned = value
            .replaceAll(',', '')
            .replaceAll('RM', '')
            .replaceAll('rm', '')
            .trim();

        return double.tryParse(
              cleaned,
            ) ??
            0;
      }

      const numericColumns = {
        'basic_salary',
        'elaun_kedatangan',
        'elaun_perkhidmatan',
        'elaun_kerajinan',
        'overtime',
        'bonus',
        'commission',
        'other_earnings',
        'cuti_umum',
        'epf_employee',
        'socso_employee',
        'eis_employee',
        'pcb',
        'zakat',
        'epf_employer',
        'socso_employer',
        'eis_employer',
      };

      final payrollRows = <Map<String, dynamic>>[];

      final usedIds = <String>{};

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];

        if (row.isEmpty) {
          continue;
        }

        final record = <String, dynamic>{};

        for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
          if (columnIndex >= row.length) {
            continue;
          }

          final originalHeader = headers[columnIndex];

          if (originalHeader.isEmpty) {
            continue;
          }

          final column = databaseColumnName(
            originalHeader,
          );

          if (column.isEmpty) {
            continue;
          }

          final rawValue = row[columnIndex].toString().trim();

          if (numericColumns.contains(
            column,
          )) {
            record[column] = parseNumber(rawValue);
          } else if (rawValue.isNotEmpty) {
            record[column] = rawValue;
          }
        }

        final employeeId = (record['employee_id'] ?? '').toString().trim();

        if (employeeId.isEmpty) {
          continue;
        }

        final period = (record['period'] ?? '').toString().trim();

        if (period.isEmpty) {
          throw Exception(
            'Missing period for employee $employeeId '
            'on CSV row ${i + 1}.',
          );
        }

        // payroll.id is required by your schema.
        //
        // If the CSV does not provide an ID, generate one.
        String payrollId = (record['id'] ?? '').toString().trim();

        if (payrollId.isEmpty) {
          payrollId = '${employeeId}_$period';
        }

        // Prevent duplicate IDs inside the same CSV.
        if (usedIds.contains(payrollId)) {
          throw Exception(
            'Duplicate payroll ID "$payrollId" '
            'found in CSV row ${i + 1}.',
          );
        }

        usedIds.add(payrollId);

        record['id'] = payrollId;
        record['employee_id'] = employeeId;
        record['period'] = period;

        payrollRows.add(record);
      }

      if (payrollRows.isEmpty) {
        throw Exception(
          'No valid payroll records were found in the CSV file.\n'
          'employeeId/employee_id and period are required.',
        );
      }

      // ------------------------------------------------------------------------
      // Verify employee IDs.
      // ------------------------------------------------------------------------

      final employeeIds = payrollRows
          .map(
            (row) => row['employee_id'].toString(),
          )
          .where(
            (id) => id.isNotEmpty,
          )
          .toSet()
          .toList();

      final existingEmployees = await SupabaseService.client
          .from('employees')
          .select(
            'employee_id',
          )
          .inFilter(
            'employee_id',
            employeeIds,
          );

      final existingIds = existingEmployees
          .map<String>(
            (row) => row['employee_id'].toString(),
          )
          .toSet();

      final missingEmployees = employeeIds
          .where(
            (id) => !existingIds.contains(
              id,
            ),
          )
          .toList();

      if (missingEmployees.isNotEmpty) {
        throw Exception(
          'These employee IDs do not exist:\n'
          '${missingEmployees.join(', ')}',
        );
      }

      if (!mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Importing payroll records...',
                ),
              ),
            ],
          ),
        ),
      );

      try {
        // IMPORTANT:
        //
        // Your table has:
        // UNIQUE(employee_id, period)
        //
        // Therefore UPSERT is safer than INSERT.
        //
        // It allows an imported CSV to update the payroll
        // for an employee/month instead of failing with
        // duplicate employee + period.
        await SupabaseService.client.from('payroll').upsert(
              payrollRows,
              onConflict: 'employee_id,period',
            );

        if (!mounted) return;

        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${payrollRows.length} payroll record(s) imported successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {});
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
        }

        rethrow;
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payroll CSV import failed: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            'Upload a CSV file to import or update payroll records.',
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
                    borderRadius: BorderRadius.circular(
                      40,
                    ),
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
                  'Select a CSV file containing payroll data.',
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
                    backgroundColor: const Color(
                      0xFF2D55D8,
                    ),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(
                    16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supported CSV columns',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      SelectableText(
                        'id,employeeId,period,basicSalary,'
                        'elaunKedatangan,elaunPerkhidmatan,'
                        'elaunKerajinan,overtime,bonus,commission,'
                        'otherEarnings,cutiUmum,epfEmployee,'
                        'socsoEmployee,eisEmployee,pcb,zakat,'
                        'epfEmployer,socsoEmployer,eisEmployer,'
                        'newIcNo,bankCode,bankAccount,remarks',
                        style: TextStyle(
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Required:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'employeeId and period',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'If id is not supplied, the application generates '
                        'one using employeeId_period.',
                        style: TextStyle(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Existing employee + period records are updated '
                        'automatically.',
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
// REPORTS
// ============================================================================

  Widget _reportsPage() {
    final reportPayroll = service.payroll
        .where((record) =>
            record.period.year == selectedReportMonth.year &&
            record.period.month == selectedReportMonth.month)
        .toList();
    final reportAttendance = service.attendance
        .where((record) =>
            record.date.year == selectedReportMonth.year &&
            record.date.month == selectedReportMonth.month)
        .toList();
    final reportNewJoiners = service.employeesDemo.where((employee) {
      final date = employee.joiningDate;
      return date != null &&
          date.year == selectedReportMonth.year &&
          date.month == selectedReportMonth.month;
    }).length;
    final vacationEmployees = reportAttendance
        .where((record) => record.status.trim().toLowerCase() == 'leave')
        .map((record) => record.employeeId)
        .toSet()
        .length;
    final double gross = reportPayroll.fold<double>(
      0,
      (
        sum,
        p,
      ) =>
          sum + p.totalEarnings,
    );

    final double net = reportPayroll.fold<double>(
      0,
      (
        sum,
        p,
      ) =>
          sum + p.netPay,
    );

    final double deductions = reportPayroll.fold<double>(
      0,
      (
        sum,
        p,
      ) =>
          sum + p.totalDeductions,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 14),
          _monthYearSelector(
            value: selectedReportMonth,
            onChanged: (value) => setState(() => selectedReportMonth = value),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _panel(
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
                        .where(
                          (e) => e.isActive,
                        )
                        .length
                        .toString(),
                  ),
                  _reportRow(
                    'Payroll Records',
                    reportPayroll.length.toString(),
                  ),
                  _reportRow(
                    'Attendance Records',
                    reportAttendance.length.toString(),
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
                    vacationEmployees.toString(),
                  ),
                  _reportRow(
                    'New Joiners',
                    reportNewJoiners.toString(),
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
          ),
        ],
      ),
    );
  }

// ============================================================================
// SETTINGS
// ============================================================================

  Widget _settingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _panel(
        'Settings',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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

// ============================================================================
// PAYROLL DETAIL
// ============================================================================

  void _showPayroll(
    PayrollRecord payroll,
  ) {
    final employee = service.findEmployee(
      payroll.employeeId,
    );

    showDialog<void>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: Text(
            '${employee?.name ?? payroll.employeeId} Payroll',
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee ID: '
                    '${payroll.employeeId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Period: '
                    '${DateFormat('MMMM yyyy').format(payroll.period)}',
                  ),
                  const Divider(
                    height: 25,
                  ),
                  _detail(
                    'Basic Salary',
                    _money(
                      payroll.basicSalary,
                    ),
                  ),
                  _detail(
                    'FW Salary',
                    _money(
                      payroll.fwSalary,
                    ),
                  ),
                  _detail(
                    'Food Allowance',
                    _money(
                      payroll.foodAllowance,
                    ),
                  ),
                  _detail(
                    'Other Allowance',
                    _money(
                      payroll.otherAllowance,
                    ),
                  ),
                  _detail(
                    'Overtime',
                    _money(
                      payroll.overtime,
                    ),
                  ),
                  _detail(
                    'Bonus',
                    _money(
                      payroll.bonus,
                    ),
                  ),
                  const Divider(),
                  _detail(
                    'EPF Employee',
                    _money(
                      payroll.epfEmployee,
                    ),
                  ),
                  _detail(
                    'SOCSO Employee',
                    _money(
                      payroll.socsoEmployee,
                    ),
                  ),
                  _detail(
                    'EIS Employee',
                    _money(
                      payroll.eisEmployee,
                    ),
                  ),
                  const Divider(),
                  _detail(
                    'Gross',
                    _money(
                      payroll.totalEarnings,
                    ),
                  ),
                  _detail(
                    'Deductions',
                    _money(
                      payroll.totalDeductions,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFEAF8F1,
                      ),
                      borderRadius: BorderRadius.circular(
                        10,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'NET PAY',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(
                                0xFF15965D,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _money(
                            payroll.netPay,
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(
                              0xFF15965D,
                            ),
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
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

// ============================================================================
// PAYROLL TABLE FROM SUPABASE
// ============================================================================

  Widget _supabasePayrollTable(
    List<Map<String, dynamic>> records,
  ) {
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No payroll records found.',
            style: TextStyle(
              color: Colors.black54,
            ),
          ),
        ),
      );
    }

    // ============================================================
    // COLUMNS TO HIDE
    // ============================================================

    const hiddenColumns = {
      'id',
      'bonus',
      'commission',
      'other_earnings',
      'new_ic_no',
      'bank_code',
      'bank_account',
      'remarks',
      'created_at',
      'updated_at',
    };

    // ============================================================
    // GET COLUMNS FROM SUPABASE
    // BUT EXCLUDE HIDDEN COLUMNS
    // ============================================================

    final columns = <String>[];

    for (final record in records) {
      for (final key in record.keys) {
        if (hiddenColumns.contains(key)) {
          continue;
        }

        if (!columns.contains(key)) {
          columns.add(key);
        }
      }
    }

    // ============================================================
    // FRIENDLY COLUMN NAMES
    // ============================================================

    String columnTitle(String column) {
      const titles = {
        'employee_id': 'Employee ID',
        'branch_id': 'Branch ID',
        'branch_name': 'Branch',
        'period': 'Period',
        'basic_salary': 'Basic Salary',
        'fw_salary': 'FW Salary',
        'elaun_kedatangan': 'Elaun Kedatangan',
        'elaun_perkhidmatan': 'Elaun Perkhidmatan',
        'elaun_kerajinan': 'Elaun Kerajinan',
        'overtime': 'Overtime',
        'cuti_umum': 'Cuti Umum',
        'late_deduction': 'Late Deduction',
        'unpaid_deduction': 'Unpaid Deduction',
        'epf_employee': 'EPF Employee',
        'socso_employee': 'SOCSO Employee',
        'eis_employee': 'EIS Employee',
        'pcb': 'PCB',
        'zakat': 'Zakat',
        'epf_employer': 'EPF Employer',
        'socso_employer': 'SOCSO Employer',
        'eis_employer': 'EIS Employer',
      };

      if (titles.containsKey(column)) {
        return titles[column]!;
      }

      return column.replaceAll('_', ' ').split(' ').map(
        (word) {
          if (word.isEmpty) {
            return word;
          }

          return word[0].toUpperCase() + word.substring(1);
        },
      ).join(' ');
    }

    // ============================================================
    // MONEY COLUMNS
    // ============================================================

    const moneyColumns = {
      'basic_salary',
      'fw_salary',
      'elaun_kedatangan',
      'elaun_perkhidmatan',
      'elaun_kerajinan',
      'overtime',
      'cuti_umum',
      'late_deduction',
      'unpaid_deduction',
      'epf_employee',
      'socso_employee',
      'eis_employee',
      'pcb',
      'zakat',
      'epf_employer',
      'socso_employer',
      'eis_employer',
    };

    // ============================================================
    // FORMAT VALUES
    // ============================================================

    String displayValue(
      String column,
      dynamic value,
    ) {
      if (value == null) {
        return '';
      }

      if (value is bool) {
        return value ? 'Yes' : 'No';
      }

      if (column == 'period') {
        return _formatPayrollPeriod(value);
      }

      if (moneyColumns.contains(column)) {
        final amount = _payrollNumber(value);
        return _money(amount);
      }

      return value.toString();
    }

    // ============================================================
    // DATA TABLE
    // ============================================================

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.blueGrey.withOpacity(.15),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFFF8FAFC),
          ),

          headingRowHeight: 52,

          dataRowMinHeight: 48,
          dataRowMaxHeight: 60,

          columnSpacing: 28,

          horizontalMargin: 20,

          border: TableBorder(
            horizontalInside: BorderSide(
              color: Colors.blueGrey.withOpacity(.12),
            ),
          ),

          // ========================================================
          // HEADERS
          // ========================================================

          columns: columns.map(
            (column) {
              return DataColumn(
                label: Text(
                  columnTitle(column),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ).toList(),

          // ========================================================
          // ROWS
          // ========================================================

          rows: records.map(
            (record) {
              return DataRow(
                cells: columns.map(
                  (column) {
                    final value = record[column];

                    final text = displayValue(
                      column,
                      value,
                    );

                    TextStyle? style;

                    if (column == 'employee_id') {
                      style = const TextStyle(
                        fontWeight: FontWeight.w600,
                      );
                    }

                    if (column == 'period') {
                      style = const TextStyle(
                        fontWeight: FontWeight.w500,
                      );
                    }

                    return DataCell(
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    );
                  },
                ).toList(),
              );
            },
          ).toList(),
        ),
      ),
    );
  }
// ============================================================================
// PAYROLL EXCEL EXPORT
// ============================================================================

  Future<void> _exportPayrollBranchExcel(
    List<Map<String, dynamic>> records,
    String branchId,
    String branchName,
  ) async {
    if (records.isEmpty) {
      _message('No payroll records for the selected branch and month.');
      return;
    }

    try {
      // --------------------------------------------------------------------------
      // 1. Load the user's exact Excel template.
      // --------------------------------------------------------------------------
      // Copy the supplied 111111.xlsx into the Flutter project's assets folder as:
      //     assets/payroll_export_template.xlsx
      // The template contains the original logo, merged cells, colours, borders,
      // column widths, footer and page layout.
      final ByteData templateData = await rootBundle.load(
        'assets/payroll_export_template.xlsx',
      );

      final templateBytes = templateData.buffer.asUint8List(
        templateData.offsetInBytes,
        templateData.lengthInBytes,
      );

      final compatibleTemplateBytes = _normalizeExcelTemplate(templateBytes);
      final excel = xls.Excel.decodeBytes(compatibleTemplateBytes);
      final sheet = excel['Sheet1'];

      // --------------------------------------------------------------------------
      // 2. Load employee information and salary-default information.
      // --------------------------------------------------------------------------
      final employeeIds = records
          .map((row) => _normalizeBranchValue(row['employee_id']))
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final employeeResponse = await SupabaseService.client
          .from('employees')
          .select()
          .inFilter('employee_id', employeeIds);

      final employeeMap = <String, Map<String, dynamic>>{};
      for (final row in List<Map<String, dynamic>>.from(employeeResponse)) {
        final id = _normalizeBranchValue(row['employee_id']);
        if (id.isNotEmpty) {
          employeeMap[id] = Map<String, dynamic>.from(row);
        }
      }

      final salaryResponse = await SupabaseService.client
          .from('employee_salary_defaults')
          .select()
          .inFilter('employee_id', employeeIds);

      final salaryMap = <String, Map<String, dynamic>>{};
      for (final row in List<Map<String, dynamic>>.from(salaryResponse)) {
        final id = _normalizeBranchValue(row['employee_id']);
        if (id.isNotEmpty) {
          salaryMap[id] = Map<String, dynamic>.from(row);
        }
      }

      // --------------------------------------------------------------------------
      // 3. Helpers for the report template.
      // --------------------------------------------------------------------------
      dynamic firstValue(
        Map<String, dynamic> row,
        List<String> keys,
      ) {
        for (final key in keys) {
          final value = row[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value;
          }
        }
        return null;
      }

      String textValue(dynamic value) {
        if (value == null) return '';
        return value.toString().trim();
      }

      String dateText(dynamic value) {
        if (value == null) return '';

        if (value is DateTime) {
          return DateFormat('dd/MM/yyyy').format(value);
        }

        final text = value.toString().trim();
        if (text.isEmpty) return '';

        final parsed = DateTime.tryParse(text);
        if (parsed != null) {
          return DateFormat('dd/MM/yyyy').format(parsed);
        }

        return text;
      }

      double money(dynamic value) => _payrollNumber(value);

      // --------------------------------------------------------------------------
      // 4. Put the selected branch/month into the template header.
      // --------------------------------------------------------------------------
      final monthText = DateFormat('MMM-yyyy').format(selectedPayrollMonth);

      sheet.cell(xls.CellIndex.indexByString('A1')).value =
          xls.TextCellValue('PENYATA GAJI');
      sheet.cell(xls.CellIndex.indexByString('L2')).value = xls.TextCellValue(
        '${branchName.toUpperCase()} (PEKERJA TEMPATAN)',
      );
      sheet.cell(xls.CellIndex.indexByString('A3')).value =
          xls.TextCellValue(monthText);

      // --------------------------------------------------------------------------
      // 5. Make enough formatted employee rows.
      // --------------------------------------------------------------------------
      // Original template has data rows 5..52. If a branch has more than 48
      // employees, insert additional rows immediately before TOTAL AMOUNT.
      const firstDataRow = 5;
      const templateDataRows = 48;
      final extraRows = records.length > templateDataRows
          ? records.length - templateDataRows
          : 0;

      // Save the style of the last normal data row before inserting rows.
      final sourceStyles = <xls.CellStyle?>[];
      for (var column = 0; column < 20; column++) {
        sourceStyles.add(
          sheet
              .cell(
                xls.CellIndex.indexByColumnRow(
                  columnIndex: column,
                  rowIndex: firstDataRow - 1 + templateDataRows - 1,
                ),
              )
              .cellStyle,
        );
      }

      for (var i = 0; i < extraRows; i++) {
        // Excel row 53 is index 52 (zero-based) in the supplied template.
        sheet.insertRow(52);

        for (var column = 0; column < 20; column++) {
          final newCell = sheet.cell(
            xls.CellIndex.indexByColumnRow(
              columnIndex: column,
              rowIndex: 52,
            ),
          );

          final style = sourceStyles[column];
          if (style != null) {
            newCell.cellStyle = style.copyWith();
          }
        }
      }

      // If the branch has fewer employees than the template's 48 data rows,
      // remove the unused rows so TOTAL AMOUNT and the footer sit immediately
      // after the actual branch employee list.
      final rowsToRemove = records.length < templateDataRows
          ? templateDataRows - records.length
          : 0;

      for (var i = 0; i < rowsToRemove; i++) {
        // lastDataRow is still based on the final employee row. The row directly
        // after it is the first unused template row.
        final removeIndex = firstDataRow + records.length - 1;
        sheet.removeRow(removeIndex);
      }

      // --------------------------------------------------------------------------
      // 6. Clear the template's old employee values.
      // --------------------------------------------------------------------------
      final lastDataRow = firstDataRow + records.length - 1;
      for (var row = firstDataRow; row <= lastDataRow; row++) {
        for (var column = 0; column < 20; column++) {
          sheet
              .cell(
                xls.CellIndex.indexByColumnRow(
                  columnIndex: column,
                  rowIndex: row - 1,
                ),
              )
              .value = null;
        }
      }

      // --------------------------------------------------------------------------
      // 7. Write branch payroll rows using the exact template columns.
      // --------------------------------------------------------------------------
      final sortedRecords = List<Map<String, dynamic>>.from(records)
        ..sort((a, b) => _normalizeBranchValue(a['employee_id'])
            .compareTo(_normalizeBranchValue(b['employee_id'])));

      for (var index = 0; index < sortedRecords.length; index++) {
        final payroll = sortedRecords[index];
        final rowNumber = firstDataRow + index;
        final employeeId = _normalizeBranchValue(payroll['employee_id']);
        final employee = employeeMap[employeeId] ?? <String, dynamic>{};
        final salary = salaryMap[employeeId] ?? <String, dynamic>{};

        final basicSalary = money(payroll['basic_salary']);
        final fwSalary = money(payroll['fw_salary']);
        final totalSalary = basicSalary + fwSalary;

        final elaunKedatangan = money(payroll['elaun_kedatangan']);
        final elaunPerkhidmatan = money(payroll['elaun_perkhidmatan']);
        final elaunKerajinan = money(payroll['elaun_kerajinan']);
        final overtime = money(payroll['overtime']);
        final cutiUmum = money(payroll['cuti_umum']);

        // The template calls this column "JUMLAH". It is the earnings total.
        final jumlah = totalSalary +
            elaunKedatangan +
            elaunPerkhidmatan +
            elaunKerajinan +
            overtime +
            cutiUmum;

        final unpaidDeduction = money(
          firstValue(
            payroll,
            const [
              'unpaid_deduction',
              'cuti_tanpa_gaji',
              'cuti_tanpa_gaji_deduction',
            ],
          ),
        );

        final epf = money(payroll['epf_employee']);
        final socso = money(payroll['socso_employee']);
        final eis = money(payroll['eis_employee']);

        // M01 / CUTI TANPA GAJI contains BOTH unpaid and late deduction.
        final lateDeduction = money(payroll['late_deduction']);
        final cutiTanpaGaji = unpaidDeduction + lateDeduction;

        // POTONGAN contains only PCB + Zakat. Late deduction is already in M01.
        final otherDeductions = money(payroll['pcb']) + money(payroll['zakat']);

        final net =
            jumlah - cutiTanpaGaji - epf - socso - eis - otherDeductions;

        final lastIncrement = firstValue(
              salary,
              const [
                'last_increment',
                'last_increament',
                'last_increment_date',
                'last_increament_date',
              ],
            ) ??
            firstValue(
              employee,
              const [
                'last_increment',
                'last_increament',
                'last_increment_date',
                'last_increament_date',
              ],
            );

        final nextIncrement = firstValue(
              salary,
              const [
                'next_increment',
                'next_increament',
                'next_increment_date',
                'next_increament_date',
                'month',
              ],
            ) ??
            firstValue(
              employee,
              const [
                'next_increment',
                'next_increament',
                'next_increment_date',
                'next_increament_date',
                'month',
              ],
            );

        final values = <dynamic>[
          index + 1,
          employeeId,
          dateText(firstValue(employee, const [
            'joining_date',
            'joiningDate',
            'date_joined',
            'dateJoined',
            'tarikh_masuk_kerja',
            'tarikh_masuk',
          ])),
          dateText(lastIncrement),
          dateText(nextIncrement),
          textValue(firstValue(employee, const ['name'])),
          textValue(
            firstValue(
                  employee,
                  const ['new_ic_no', 'newIcNo'],
                ) ??
                payroll['new_ic_no'],
          ),
          totalSalary,
          elaunKedatangan,
          elaunPerkhidmatan,
          elaunKerajinan,
          overtime,
          cutiUmum,
          jumlah,
          cutiTanpaGaji,
          epf,
          socso,
          eis,
          otherDeductions,
          net,
        ];

        for (var column = 0; column < values.length; column++) {
          final cell = sheet.cell(
            xls.CellIndex.indexByColumnRow(
              columnIndex: column,
              rowIndex: rowNumber - 1,
            ),
          );

          final value = values[column];
          if (value is num) {
            cell.value = xls.DoubleCellValue(value.toDouble());
          } else {
            cell.value = xls.TextCellValue(value?.toString() ?? '');
          }
        }
      }

      // --------------------------------------------------------------------------
      // 8. Rebuild TOTAL AMOUNT formulas at the new end of the employee table.
      // --------------------------------------------------------------------------
      final totalRow = lastDataRow + 1;

      sheet.cell(xls.CellIndex.indexByString('A$totalRow')).value =
          xls.TextCellValue('TOTAL AMOUNT');

      final totalColumns = <String>[
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
        'P',
        'Q',
        'R',
        'S',
        'T',
      ];

      for (final column in totalColumns) {
        sheet.cell(xls.CellIndex.indexByString('$column$totalRow')).value =
            xls.FormulaCellValue(
                'SUM($column$firstDataRow:$column$lastDataRow)');
      }

      // Keep the original footer area as a visual part of the template, but
      // update its TOTAL formula to the selected branch/month.
      final footerTotalRow = totalRow + 5;
      sheet.cell(xls.CellIndex.indexByString('R$footerTotalRow')).value =
          xls.FormulaCellValue('SUM(T$firstDataRow:T$lastDataRow)');

      // --------------------------------------------------------------------------
      // 9. Filename: branch + selected month.
      // --------------------------------------------------------------------------
      final safeBranch = branchName
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');

      final fileName =
          'Penyata_Gaji_${safeBranch.isEmpty ? 'Branch' : safeBranch}_'
          '${DateFormat('yyyy_MM').format(selectedPayrollMonth)}.xlsx';

      final output = excel.encode();

      if (output == null || output.isEmpty) {
        throw Exception('Excel file could not be generated.');
      }

      await FileSaver.instance.saveFile(
        name: fileName.replaceFirst(RegExp(r'\.xlsx$'), ''),
        bytes: Uint8List.fromList(output),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      _message('$fileName exported successfully.');
    } catch (e) {
      _message('Excel export failed: $e');
    }
  }

  Future<void> _exportPayrollAllBranchesExcel(
    List<Map<String, dynamic>> records,
    Map<String, String> branchNames,
  ) async {
    if (records.isEmpty) {
      _message('No payroll records for the selected month.');
      return;
    }

    try {
      _message('Preparing one Excel file for all branches...');

      final employeeIds = records
          .map((r) => _normalizeBranchValue(r['employee_id']))
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final employeeResponse = await SupabaseService.client
          .from('employees')
          .select()
          .inFilter('employee_id', employeeIds);

      final employeeMap = <String, Map<String, dynamic>>{};
      for (final row in List<Map<String, dynamic>>.from(employeeResponse)) {
        final id = _normalizeBranchValue(row['employee_id']);
        if (id.isNotEmpty) employeeMap[id] = Map<String, dynamic>.from(row);
      }

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final row in records) {
        final employeeId = _normalizeBranchValue(row['employee_id']);
        final employee = employeeMap[employeeId];
        final branchId = _normalizeBranchValue(
          row['branch_id'] ?? employee?['branch_id'],
        );
        if (branchId.isEmpty) continue;
        grouped.putIfAbsent(branchId, () => []).add(row);
      }

      if (grouped.isEmpty) {
        _message('No branch information found for the selected payroll.');
        return;
      }

      final excel = xls.Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();

      final headers = <String>[
        'NO',
        'EMPLOYEE ID',
        'JOINING DATE',
        'LAST INCREMENT',
        'NEXT INCREMENT',
        'NAME',
        'NEW_IC_NO',
        'BASIC + FW',
        'ELAUN KEDATANGAN',
        'ELAUN PERKHIDMATAN',
        'ELAUN KERAJINAN',
        'OVERTIME',
        'CUTI UMUM',
        'JUMLAH',
        'M01 CUTI TANPA GAJI',
        'EPF',
        'SOCSO',
        'EIS',
        'POTONGAN',
        'NET SALARY',
      ];

      String safeSheetName(String name, Set<String> used) {
        var base = name.trim().isEmpty ? 'Branch' : name.trim();
        base = base.replaceAll(RegExp(r'[\\/:*?\[\]]'), '_');
        if (base.length > 31) base = base.substring(0, 31);
        var result = base;
        var n = 2;
        while (used.contains(result.toLowerCase())) {
          final suffix = ' ($n)';
          final max = 31 - suffix.length;
          result =
              '${base.substring(0, base.length > max ? max : base.length)}$suffix';
          n++;
        }
        used.add(result.toLowerCase());
        return result;
      }

      final usedNames = <String>{};
      final sortedBranchIds = grouped.keys.toList()
        ..sort((a, b) => (branchNames[a] ?? a)
            .toLowerCase()
            .compareTo((branchNames[b] ?? b).toLowerCase()));

      double money(dynamic value) => _payrollNumber(value);

      String dateText(dynamic value) {
        if (value == null) return '';
        if (value is DateTime) return DateFormat('dd/MM/yyyy').format(value);
        final text = value.toString().trim();
        final parsed = DateTime.tryParse(text);
        return parsed == null ? text : DateFormat('dd/MM/yyyy').format(parsed);
      }

      dynamic firstValue(Map<String, dynamic> row, List<String> keys) {
        for (final key in keys) {
          final v = row[key];
          if (v != null && v.toString().trim().isNotEmpty) return v;
        }
        return null;
      }

      var isFirstSheet = true;
      for (final branchId in sortedBranchIds) {
        final branchName = branchNames[branchId] ?? branchId;
        final sheetName = safeSheetName(branchName, usedNames);

        xls.Sheet sheet;
        if (isFirstSheet && defaultSheet != null) {
          excel.rename(defaultSheet, sheetName);
          sheet = excel[sheetName];
          isFirstSheet = false;
        } else {
          sheet = excel[sheetName];
        }
        final branchRecords =
            List<Map<String, dynamic>>.from(grouped[branchId]!)
              ..sort((a, b) => _normalizeBranchValue(a['employee_id'])
                  .compareTo(_normalizeBranchValue(b['employee_id'])));

        sheet.cell(xls.CellIndex.indexByString('A1')).value =
            xls.TextCellValue('PENYATA GAJI - ${branchName.toUpperCase()}');
        sheet.cell(xls.CellIndex.indexByString('A2')).value = xls.TextCellValue(
            DateFormat('MMM-yyyy').format(selectedPayrollMonth));

        for (var c = 0; c < headers.length; c++) {
          final cell = sheet.cell(xls.CellIndex.indexByColumnRow(
            columnIndex: c,
            rowIndex: 3,
          ));
          cell.value = xls.TextCellValue(headers[c]);
        }

        for (var i = 0; i < branchRecords.length; i++) {
          final payroll = branchRecords[i];
          final row = i + 4;
          final employeeId = _normalizeBranchValue(payroll['employee_id']);
          final employee = employeeMap[employeeId] ?? <String, dynamic>{};

          final basic = money(payroll['basic_salary']);
          final fw = money(payroll['fw_salary']);
          final elaunKedatangan = money(payroll['elaun_kedatangan']);
          final elaunPerkhidmatan = money(payroll['elaun_perkhidmatan']);
          final elaunKerajinan = money(payroll['elaun_kerajinan']);
          final overtime = money(payroll['overtime']);
          final cutiUmum = money(payroll['cuti_umum']);
          final jumlah = basic +
              fw +
              elaunKedatangan +
              elaunPerkhidmatan +
              elaunKerajinan +
              overtime +
              cutiUmum;
          final unpaid = money(payroll['unpaid_deduction']);
          final late = money(payroll['late_deduction']);
          final cutiTanpaGaji = unpaid + late;
          final epf = money(payroll['epf_employee']);
          final socso = money(payroll['socso_employee']);
          final eis = money(payroll['eis_employee']);
          final potongan = money(payroll['pcb']) + money(payroll['zakat']);
          final net = jumlah - cutiTanpaGaji - epf - socso - eis - potongan;

          final lastIncrement = firstValue(employee, [
            'last_increment',
            'last_increament',
            'last_increment_date',
            'last_increament_date',
          ]);
          final nextIncrement = firstValue(employee, [
            'next_increment',
            'next_increament',
            'next_increment_date',
            'next_increament_date',
            'month',
          ]);

          final values = <dynamic>[
            i + 1,
            employeeId,
            dateText(employee['joining_date']),
            dateText(lastIncrement),
            dateText(nextIncrement),
            employee['name'] ?? payroll['name'] ?? '',
            employee['new_ic_no'] ?? payroll['new_ic_no'] ?? '',
            basic + fw,
            elaunKedatangan,
            elaunPerkhidmatan,
            elaunKerajinan,
            overtime,
            cutiUmum,
            jumlah,
            cutiTanpaGaji,
            epf,
            socso,
            eis,
            potongan,
            net,
          ];

          for (var c = 0; c < values.length; c++) {
            final cell = sheet.cell(xls.CellIndex.indexByColumnRow(
              columnIndex: c,
              rowIndex: row,
            ));
            final value = values[c];
            cell.value = value is num
                ? xls.DoubleCellValue(value.toDouble())
                : xls.TextCellValue(value.toString());
          }
        }
      }

      final monthFile = DateFormat('yyyy_MM').format(selectedPayrollMonth);
      final fileName = 'Penyata_Gaji_All_Branches_$monthFile.xlsx';
      final output = excel.encode();
      if (output == null || output.isEmpty) {
        throw Exception('Excel file could not be generated.');
      }

      await FileSaver.instance.saveFile(
        name: fileName.replaceFirst(RegExp(r'\.xlsx$'), ''),
        bytes: Uint8List.fromList(output),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      _message(
          '$fileName exported successfully with ${sortedBranchIds.length} branch sheets.');
    } catch (e) {
      _message('All branches Excel export failed: $e');
    }
  }

  Uint8List _normalizeExcelTemplate(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final normalized = Archive();

    for (final file in archive) {
      if (file.name != 'xl/styles.xml') {
        normalized.addFile(file);
        continue;
      }

      final styles = String.fromCharCodes(file.content as List<int>);
      final updatedStyles = styles.replaceAll(
        'numFmtId="43"',
        'numFmtId="167"',
      );
      normalized.addFile(
        ArchiveFile(file.name, updatedStyles.length, updatedStyles),
      );
    }

    final encoded = ZipEncoder().encode(normalized);
    if (encoded == null) {
      throw Exception('Excel template could not be prepared.');
    }
    return Uint8List.fromList(encoded);
  }

// ============================================================================
// RHB / STATUTORY LAYOUT EXPORTS
// One click generates four separate Excel files for the selected payroll month.

  Future<void> _exportRhbLayout() async {
    try {
      _message(
        'Preparing RHB, EPF, EIS and SOCSO layouts...',
      );

      final selectedMonth =
          DateFormat('MMMM yyyy').format(selectedPayrollMonth);

      final monthFile = DateFormat('yyyy_MM').format(selectedPayrollMonth);

      // ============================================================
      // LOAD PAYROLL
      // ============================================================

      final response = await SupabaseService.client
          .from('payroll')
          .select()
          .order('employee_id');

      final payrollRows = List<Map<String, dynamic>>.from(response)
          .where(
            (row) => _payrollPeriodMatchesMonth(
              row['period'],
              selectedPayrollMonth,
            ),
          )
          .toList();

      if (payrollRows.isEmpty) {
        _message(
          'No generated payroll found for $selectedMonth.',
        );
        return;
      }

      // ============================================================
      // LOAD EMPLOYEES
      // ============================================================

      final employeeIds = payrollRows
          .map(
            (row) => _normalizeBranchValue(
              row['employee_id'],
            ),
          )
          .where(
            (id) => id.isNotEmpty,
          )
          .toSet()
          .toList();

      final employeeResponse =
          await SupabaseService.client.from('employees').select().inFilter(
                'employee_id',
                employeeIds,
              );

      final employeeMap = <String, Map<String, dynamic>>{};

      for (final employee in List<Map<String, dynamic>>.from(
        employeeResponse,
      )) {
        final id = _normalizeBranchValue(
          employee['employee_id'],
        );

        if (id.isNotEmpty) {
          employeeMap[id] = employee;
        }
      }

      // ============================================================
      // MONEY HELPER
      // ============================================================

      double money(dynamic value) {
        if (value == null) {
          return 0.0;
        }

        if (value is num) {
          return value.toDouble();
        }

        final cleaned = value
            .toString()
            .replaceAll(',', '')
            .replaceAll(
              RegExp(r'RM', caseSensitive: false),
              '',
            )
            .trim();

        return double.tryParse(cleaned) ?? 0.0;
      }

      // ============================================================
      // TEXT VALUE HELPER
      // ============================================================

      String value(
        Map<String, dynamic> row,
        List<String> keys,
      ) {
        for (final key in keys) {
          final raw = row[key];

          if (raw == null) {
            continue;
          }

          final text = raw.toString().trim();

          if (text.isNotEmpty) {
            return text;
          }
        }

        return '';
      }

      // ============================================================
      // JUMLAH / GROSS SALARY
      //
      // First use an existing gross field if available.
      // Otherwise calculate gross from payroll components.
      // ============================================================

      double jumlah(
        Map<String, dynamic> row,
      ) {
        // Existing calculated gross amount.
        for (final key in const [
          'gross_pay',
          'gross_salary',
          'total_gross',
          'grossPay',
          'jumlah',
          'total_earnings',
          'totalEarnings',
        ]) {
          if (row[key] != null) {
            return money(row[key]);
          }
        }

        // Calculate gross manually when the database
        // does not contain a gross amount.

        final gross = money(row['basic_salary']) +
            money(row['basicSalary']) +
            money(row['fw_salary']) +
            money(row['fwSalary']) +
            money(row['food_allowance']) +
            money(row['foodAllowance']) +
            money(row['other_allowance']) +
            money(row['otherAllowance']) +
            money(row['elaun_kedatangan']) +
            money(row['elaun_perkhidmatan']) +
            money(row['elaun_kerajinan']) +
            money(row['overtime']) +
            money(row['bonus']) +
            money(row['commission']) +
            money(row['other_earnings']) +
            money(row['otherEarnings']) +
            money(row['cuti_umum']);

        return gross;
      }

      // ============================================================
      // NET SALARY
      // ============================================================

      double netSalary(
        Map<String, dynamic> row,
      ) {
        // Prefer an existing calculated net amount.
        for (final key in const [
          'net_pay',
          'net_salary',
          'total_net',
          'netPay',
          'net',
        ]) {
          if (row[key] != null) {
            return money(row[key]);
          }
        }

        // Otherwise calculate:
        //
        // GROSS - EMPLOYEE DEDUCTIONS

        final gross = jumlah(row);

        final deductions = money(row['epf_employee']) +
            money(row['epfEmployee']) +
            money(row['socso_employee']) +
            money(row['socsoEmployee']) +
            money(row['eis_employee']) +
            money(row['eisEmployee']) +
            money(row['pcb']) +
            money(row['zakat']) +
            money(row['late_deduction']) +
            money(row['lateDeduction']) +
            money(row['unpaid_deduction']) +
            money(row['unpaidDeduction']) +
            money(row['other_deductions']) +
            money(row['otherDeduction']);

        return gross - deductions;
      }

      // ============================================================
      // EXCEL ROW WRITER
      // ============================================================

      void writeRow(
        xls.Sheet sheet,
        int row,
        List<dynamic> values,
      ) {
        for (var c = 0; c < values.length; c++) {
          final cell = sheet.cell(
            xls.CellIndex.indexByColumnRow(
              columnIndex: c,
              rowIndex: row,
            ),
          );

          final item = values[c];

          if (item is num) {
            cell.value = xls.DoubleCellValue(
              item.toDouble(),
            );
          } else {
            cell.value = xls.TextCellValue(
              item?.toString() ?? '',
            );
          }
        }
      }

      // ============================================================
      // SAVE EXCEL
      // ============================================================

      void saveExcel(
        String fileName,
        String sheetName,
        List<String> headers,
        List<List<dynamic>> rows,
      ) {
        final excel = xls.Excel.createExcel();

        final defaultSheet = excel.getDefaultSheet();

        if (defaultSheet != null && defaultSheet != sheetName) {
          excel.rename(
            defaultSheet,
            sheetName,
          );
        }

        final sheet = excel[sheetName];

        writeRow(
          sheet,
          0,
          headers,
        );

        for (var r = 0; r < rows.length; r++) {
          writeRow(
            sheet,
            r + 1,
            rows[r],
          );
        }

        final bytes = excel.save(
          fileName: fileName,
        );

        if (bytes == null || bytes.isEmpty) {
          throw Exception(
            '$fileName could not be generated.',
          );
        }
      }

      // ============================================================
      // OUTPUT ROWS
      // ============================================================

      final rhb = <List<dynamic>>[];

      final epf = <List<dynamic>>[];

      final eis = <List<dynamic>>[];

      final socso = <List<dynamic>>[];

      // ============================================================
      // BUILD EXPORT DATA
      // ============================================================

      for (final payroll in payrollRows) {
        final id = _normalizeBranchValue(
          payroll['employee_id'],
        );

        final employee = employeeMap[id] ?? <String, dynamic>{};

        // ----------------------------------------------------------
        // EMPLOYEE NAME
        // ----------------------------------------------------------

        final employeeName = value(
          employee,
          const [
            'name',
            'employee_name',
          ],
        );

        final payrollName = value(
          payroll,
          const [
            'name',
            'employee_name',
          ],
        );

        final name = employeeName.isNotEmpty ? employeeName : payrollName;

        // ----------------------------------------------------------
        // IC
        // ----------------------------------------------------------

        final employeeIc = value(
          employee,
          const [
            'new_ic_no',
            'newIcNo',
          ],
        );

        final payrollIc = value(
          payroll,
          const [
            'new_ic_no',
            'newIcNo',
          ],
        );

        final ic = employeeIc.isNotEmpty ? employeeIc : payrollIc;

        // ----------------------------------------------------------
        // BANK ACCOUNT
        // ----------------------------------------------------------

        final employeeBank = value(
          employee,
          const [
            'bank_account',
            'bankAccount',
          ],
        );

        final payrollBank = value(
          payroll,
          const [
            'bank_account',
            'bankAccount',
          ],
        );

        final bankAccount =
            employeeBank.isNotEmpty ? employeeBank : payrollBank;

        // ----------------------------------------------------------
        // EPF NUMBER
        // ----------------------------------------------------------

        final employeeEpfNo = value(
          employee,
          const [
            'epf_no',
            'epfNo',
            'kwsp_no',
            'kwspNo',
          ],
        );

        final payrollEpfNo = value(
          payroll,
          const [
            'epf_no',
            'epfNo',
            'kwsp_no',
            'kwspNo',
          ],
        );

        final epfNo = employeeEpfNo.isNotEmpty ? employeeEpfNo : payrollEpfNo;

        // ----------------------------------------------------------
        // CALCULATE AMOUNTS
        // ----------------------------------------------------------

        final gross = jumlah(payroll);

        final net = netSalary(payroll);

        final epfEmployee = money(
          payroll['epf_employee'] ?? payroll['epfEmployee'],
        );

        final epfEmployer = money(
          payroll['epf_employer'] ?? payroll['epfEmployer'],
        );

        final eisEmployee = money(
          payroll['eis_employee'] ?? payroll['eisEmployee'],
        );

        final eisEmployer = money(
          payroll['eis_employer'] ?? payroll['eisEmployer'],
        );

        final socsoEmployee = money(
          payroll['socso_employee'] ?? payroll['socsoEmployee'],
        );

        final socsoEmployer = money(
          payroll['socso_employer'] ?? payroll['socsoEmployer'],
        );

        // ----------------------------------------------------------
        // TOTAL STATUTORY AMOUNTS
        // ----------------------------------------------------------

        final eisTotal = eisEmployee + eisEmployer;

        final socsoTotal = socsoEmployee + socsoEmployer;

        // ----------------------------------------------------------
        // RHB
        //
        // JUMLAH = NET SALARY
        // ----------------------------------------------------------

        rhb.add([
          name,
          ic,
          bankAccount,
          net,
          selectedMonth,
        ]);

        // ----------------------------------------------------------
        // EPF
        //
        // JUMLAH = GROSS SALARY
        // ----------------------------------------------------------

        epf.add([
          name,
          ic,
          epfNo,
          epfEmployee,
          epfEmployer,
          gross,
        ]);

        // ----------------------------------------------------------
        // EIS
        // ----------------------------------------------------------

        eis.add([
          name,
          ic,
          eisTotal,
        ]);

        // ----------------------------------------------------------
        // SOCSO
        // ----------------------------------------------------------

        socso.add([
          name,
          ic,
          socsoTotal,
        ]);
      }

      // ============================================================
      // CREATE RHB EXCEL
      // ============================================================

      saveExcel(
        'RHB_Layout_$monthFile.xlsx',
        'RHB Layout',
        const [
          'NAME',
          'NEW_IC_NO',
          'BANK_ACCOUNT',
          'JUMLAH',
          'SELECTED PAYROLL MONTH',
        ],
        rhb,
      );

      // ============================================================
      // CREATE EPF EXCEL
      // ============================================================

      saveExcel(
        'EPF_$monthFile.xlsx',
        'EPF',
        const [
          'NAME',
          'NEW_IC_NO',
          'EPF_NO',
          'EMPLOYEE EPF AMOUNT',
          'EMPLOYER EPF AMOUNT',
          'JUMLAH',
        ],
        epf,
      );

      // ============================================================
      // CREATE EIS EXCEL
      // ============================================================

      saveExcel(
        'EIS_$monthFile.xlsx',
        'EIS',
        const [
          'NAME',
          'NEW_IC_NO',
          'EIS TOTAL AMOUNT',
        ],
        eis,
      );

      // ============================================================
      // CREATE SOCSO EXCEL
      // ============================================================

      saveExcel(
        'SOCSO_$monthFile.xlsx',
        'SOCSO',
        const [
          'NAME',
          'NEW_IC_NO',
          'SOCSO TOTAL AMOUNT',
        ],
        socso,
      );

      // ============================================================
      // SUCCESS
      // ============================================================

      _message(
        'Generated 4 Excel files for $selectedMonth: '
        'RHB Layout, EPF, EIS and SOCSO.',
      );
    } catch (e) {
      _message(
        'RHB / statutory Excel export failed: $e',
      );
    }
  }

  Widget _rhbLayoutPage() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance, size: 56),
          const SizedBox(height: 12),
          const Text(
            'RHB Layout',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Salary month: ${DateFormat('MMMM yyyy').format(selectedPayrollMonth)}',
          ),
        ],
      ),
    );
  }

// ============================================================================
// PAYROLL PERIOD MATCHER
// ============================================================================

  bool _payrollPeriodMatchesMonth(
    dynamic value,
    DateTime month,
  ) {
    if (value == null) return false;

    final text = value.toString().trim();
    if (text.isEmpty) return false;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return parsed.year == month.year && parsed.month == month.month;
    }

    final normalized = text.toLowerCase();
    final monthNames = const [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];

    for (var i = 0; i < monthNames.length; i++) {
      if (normalized.contains(monthNames[i]) &&
          normalized.contains(month.year.toString())) {
        return i + 1 == month.month;
      }
    }

    final yearMonth = RegExp(r'^(\d{4})[-/]([0-9]{1,2})$').firstMatch(text);
    if (yearMonth != null) {
      return int.tryParse(yearMonth.group(1) ?? '') == month.year &&
          int.tryParse(yearMonth.group(2) ?? '') == month.month;
    }

    final monthYear = RegExp(r'^([0-9]{1,2})[-/](\d{4})$').firstMatch(text);
    if (monthYear != null) {
      return int.tryParse(monthYear.group(1) ?? '') == month.month &&
          int.tryParse(monthYear.group(2) ?? '') == month.year;
    }

    return false;
  }

// ============================================================================
// PAYROLL PERIOD FORMATTER
// ============================================================================

  String _formatPayrollPeriod(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final text = value.toString();

    if (text.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(text);

    if (parsed == null) {
      return text;
    }

    return DateFormat(
      'MMM yyyy',
    ).format(parsed);
  }

// ============================================================================
// PAYROLL NUMBER
// ============================================================================

  double _payrollNumber(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    final text = value
        .toString()
        .replaceAll(',', '')
        .replaceAll('RM', '')
        .replaceAll('rm', '')
        .trim();

    return double.tryParse(text) ?? 0;
  }

// ============================================================================
// HELPERS
// ============================================================================

  Widget _dialogField(
    TextEditingController controller,
    String label,
  ) {
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

  Widget _detail(
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color, [
    VoidCallback? onTap,
  ]) {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          14,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              14,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
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

  Widget _actionButton(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        12,
      ),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(
            12,
          ),
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

  Widget _reportRow(
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _money(
    double value,
  ) {
    return 'RM ${NumberFormat('#,##0.00').format(value)}';
  }

  void _message(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
