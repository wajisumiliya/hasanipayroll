import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/payroll.dart';
import '../services/app_service.dart';
import '../screens/supabase_service.dart';
import '../screens/attendance_dialog.dart';
import '../services/pdf_service.dart';
import 'login_screen.dart';

class EmployeePortal extends StatefulWidget {
  const EmployeePortal({super.key});

  @override
  State<EmployeePortal> createState() =>
      _EmployeePortalState();
}

class _EmployeePortalState
    extends State<EmployeePortal> {
  final AppService service =
      AppService.instance;

  int tab = 0;

  DateTime _attendanceMonth = DateTime(DateTime.now().year, DateTime.now().month);

  /// =============================================================
  /// CURRENT EMPLOYEE
  /// =============================================================

  Employee? get employee =>
      service.currentEmployee;

  String get employeeId =>
      service.currentUser?.employeeId ?? '';

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
              const Text(
                'Employee information not found.',
                style: TextStyle(
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
          if (constraints.maxWidth >= 900) {
            return _desktop();
          }

          return _mobile();
        },
      ),
    );
  }

  // =============================================================
  // DESKTOP
  // =============================================================

  Widget _desktop() {
    return Row(
      children: [
        _desktopSidebar(),

        Expanded(
          child: Column(
            children: [
              _desktopTopBar(),

              Expanded(
                child: Container(
                  color: const Color(0xFFF5F7FB),
                  child: _page(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =============================================================
  // DESKTOP SIDEBAR
  // =============================================================

  Widget _desktopSidebar() {
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 25),

          Image.asset(
            'assets/hasani_books_logo.jpg',
            width: 160,
            errorBuilder:
                (context, error, stackTrace) {
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

          const SizedBox(height: 28),

          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'EMPLOYEE PORTAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D55D8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          _side(
            'Dashboard',
            Icons.dashboard_outlined,
            0,
          ),

          _side(
            'My Payslips',
            Icons.receipt_long_outlined,
            1,
          ),

          _side(
            'Attendance',
            Icons.calendar_month_outlined,
            2,
          ),

          _side(
            'Profile',
            Icons.person_outline,
            3,
          ),

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

          const Divider(),

          _side(
            'Logout',
            Icons.logout,
            6,
          ),

          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              '© 2026 Hasani Books',
              style: TextStyle(
                color: Colors.black45,
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
        selectedTileColor:
        const Color(0xFFEAF0FF),
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(10),
        ),
        leading: Icon(
          icon,
          color: selected
              ? const Color(0xFF2D55D8)
              : title == 'Logout'
              ? Colors.red
              : Colors.black54,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected
                ? FontWeight.bold
                : FontWeight.normal,
            color: title == 'Logout'
                ? Colors.red
                : selected
                ? const Color(0xFF2D55D8)
                : Colors.black87,
          ),
        ),
        onTap: () {
          if (index == 6) {
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

          CircleAvatar(
            radius: 18,
            backgroundColor:
            const Color(0xFFEAF0FF),
            child: const Icon(
              Icons.person,
              color: Color(0xFF2D55D8),
            ),
          ),

          const SizedBox(width: 10),

          Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                employee!.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                employee!.employeeId,
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
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // MOBILE
  // =============================================================

  Widget _mobile() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mobileTitle()),
        actions: [
          IconButton(
            onPressed: logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF5F7FB),
        child: _page(),
      ),
      bottomNavigationBar:
      NavigationBar(
        selectedIndex: tab > 3 ? 0 : tab,
        onDestinationSelected:
            (index) {
          setState(() {
            tab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home,
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.receipt_long_outlined,
            ),
            selectedIcon: Icon(
              Icons.receipt_long,
            ),
            label: 'Payslips',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.calendar_month_outlined,
            ),
            selectedIcon: Icon(
              Icons.calendar_month,
            ),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon: Icon(
              Icons.person,
            ),
            label: 'Profile',
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
        return 'Profile';

      case 4:
        return 'Bank Information';

      case 5:
        return 'Change Password';

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
        return 'Profile';

      case 4:
        return 'Bank Information';

      case 5:
        return 'Change Password';

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
        return _profile();

      case 4:
        return _bankInformation();

      case 5:
        return const _ChangePasswordPage();

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
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _welcome(),

            const SizedBox(height: 24),

            _emptyPayroll(),
          ],
        ),
      );
    }

    final payroll = records.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _welcome(),

          const SizedBox(height: 18),

          _salary(payroll),

          const SizedBox(height: 24),

          const Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _quick(
                'Payslips',
                Icons.description,
                    () {
                  setState(() {
                    tab = 1;
                  });
                },
              ),
              _quick(
                'Attendance',
                Icons.calendar_month,
                    () {
                  setState(() {
                    tab = 2;
                  });
                },
              ),
              _quick(
                'Profile',
                Icons.person,
                    () {
                  setState(() {
                    tab = 3;
                  });
                },
              ),
              _quick(
                'Bank Info',
                Icons.account_balance,
                    () {
                  setState(() {
                    tab = 4;
                  });
                },
              ),
              _quick(
                'Password',
                Icons.lock,
                    () {
                  setState(() {
                    tab = 5;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              const Text(
                'Recent Payslips',
                style: TextStyle(
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

          ...records.take(5).map(_tile),
        ],
      ),
    );
  }

  Widget _emptyPayroll() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(14),
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
    final name = employee!.name.trim();

    final parts = name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();

    final initials = parts.isEmpty
        ? '?'
        : parts
        .map(
          (e) => e[0].toUpperCase(),
    )
        .join();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF2D55D8),
        borderRadius:
        BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: Colors.white,
            child: Text(
              initials,
              style: const TextStyle(
                color: Color(0xFF2D55D8),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome,',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  employee!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  employee!.employeeId,
                  style: const TextStyle(
                    color: Colors.white70,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(0.04),
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
                  DateFormat('MMMM yyyy')
                      .format(payroll.period),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),

              FilledButton.tonal(
                onPressed: () =>
                    _pdf(payroll),
                child: const Text(
                  'View Payslip',
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _metric(
                  'Gross Earnings',
                  payroll.totalEarnings,
                  Colors.black,
                ),
              ),

              Expanded(
                child: _metric(
                  'Total Deductions',
                  payroll.totalDeductions,
                  Colors.red,
                ),
              ),
            ],
          ),

          const Divider(height: 30),

          Align(
            alignment:
            Alignment.centerLeft,
            child: _metric(
              'Net Pay',
              payroll.netPay,
              const Color(0xFF139B60),
              big: true,
            ),
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
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          'RM ${NumberFormat('#,##0.00').format(value)}',
          style: TextStyle(
            fontSize: big ? 26 : 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // =============================================================
  // QUICK ACCESS
  // =============================================================

  Widget _quick(
      String title,
      IconData icon,
      VoidCallback onTap,
      ) {
    return SizedBox(
      width: 130,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(12),
            border: Border.all(
              color: Colors.black12,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color:
                const Color(0xFF2D55D8),
              ),

              const SizedBox(height: 8),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================
  // PAYSLIP TILE
  // =============================================================

  Widget _tile(
      PayrollRecord payroll,
      ) {
    return Card(
      margin:
      const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor:
          Color(0xFFEAF0FF),
          child: Icon(
            Icons.description_outlined,
            color: Color(0xFF2D55D8),
          ),
        ),

        title: Text(
          DateFormat('MMMM yyyy')
              .format(payroll.period),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Text(
          'Net pay RM ${payroll.netPay.toStringAsFixed(2)}',
        ),

        trailing: IconButton(
          onPressed: () =>
              _pdf(payroll),
          tooltip: 'View payslip',
          icon: const Icon(
            Icons.download_outlined,
          ),
        ),
      ),
    );
  }

  // =============================================================
  // PAYSLIPS
  // =============================================================

  Widget _payslips() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Payslip History',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '${records.length} payroll records available',
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 18),

          if (records.isEmpty)
            _emptyPayroll()
          else
            ...records.map(_tile),
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
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFEAF0FF),
                        child: Text(
                          currentEmployee.name.isEmpty ? '?' : currentEmployee.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF2D55D8),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentEmployee.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(currentEmployee.employeeId, style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Read Only',
                          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700, fontSize: 11),
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
                              _attendanceMonth = DateTime(picked.year, picked.month);
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
  // PROFILE
  // =============================================================

  Widget _profile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 45,
            backgroundColor:
            Color(0xFFEAF0FF),
            child: Icon(
              Icons.person,
              size: 45,
              color: Color(0xFF2D55D8),
            ),
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
        crossAxisAlignment:
        CrossAxisAlignment.start,
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
              padding:
              const EdgeInsets.all(20),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.account_balance,
                    ),
                    title:
                    const Text('Bank Code'),
                    subtitle: Text(
                      employee!.bankCode,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.bold,
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
                      employee!.bankAccount,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),

                  const Divider(),

                  ListTile(
                    leading:
                    const Icon(Icons.badge),
                    title:
                    const Text('Employee ID'),
                    subtitle: Text(
                      employee!.employeeId,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.bold,
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
      margin:
      const EdgeInsets.only(bottom: 10),
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
    try {
      final bytes =
      await PdfService.buildPayslip(
        employee: employee!,
        p: payroll,
        history: records,
      );

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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
  State<_ChangePasswordPage> createState() =>
      _ChangePasswordPageState();
}

class _ChangePasswordPageState
    extends State<_ChangePasswordPage> {
  final TextEditingController currentController =
      TextEditingController();

  final TextEditingController newController =
      TextEditingController();

  final TextEditingController confirmController =
      TextEditingController();

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

    if (current.isEmpty ||
        newPassword.isEmpty ||
        confirm.isEmpty) {
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

    // Check current password.
    if (user.password != current) {
      _message(
        'Current password is incorrect.',
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
          hidden
              ? Icons.visibility
              : Icons.visibility_off,
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
                onPressed: isUpdating
                    ? null
                    : updatePassword,
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
