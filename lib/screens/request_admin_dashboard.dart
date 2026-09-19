import 'package:flutter/material.dart';

import '../services/app_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_reload_button.dart';
import 'daily_report_page.dart';
import 'leave_requests_approval_page.dart';
import 'login_screen.dart';
import 'supabase_service.dart';

class RequestAdminDashboard extends StatefulWidget {
  const RequestAdminDashboard({super.key});

  @override
  State<RequestAdminDashboard> createState() => _RequestAdminDashboardState();
}

class _RequestAdminDashboardState extends State<RequestAdminDashboard> {
  static const _blue = Color(0xFF123C8C);
  static const _red = Color(0xFFE72D3B);
  int page = 0;

  final _navigation = const [
    ('Leave Requests', Icons.flight_takeoff_outlined, Color(0xFFFFB547)),
    ('OT Requests', Icons.more_time_outlined, Color(0xFF35C6F4)),
    ('Daily Reports', Icons.assignment_outlined, Color(0xFF54D6A3)),
  ];

  String get _title => _navigation[page].$1;
  String get _displayName {
    final name = AppService.instance.currentUser?.displayName?.trim() ?? '';
    return name.isEmpty || name.contains('@') ? 'Request Admin' : name;
  }

  Widget get _content => switch (page) {
        0 => const LeaveRequestsApprovalPage.admin(),
        1 => const _RequestAdminOtPage(),
        _ => const DailyReportPage.admin(),
      };

  Future<void> _logout() async {
    await AppService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _changePage(int value, {bool closeDrawer = false}) {
    setState(() => page = value);
    if (closeDrawer && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: LayoutBuilder(builder: (_, constraints) {
          if (constraints.maxWidth < 850) return _mobileLayout();
          return _desktopLayout();
        }),
      );

  Widget _desktopLayout() => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8FAFF), Color(0xFFEDF2FB)]),
        ),
        child: Row(children: [
          _sidebar(dark: true),
          Expanded(
            child: Column(children: [
              _topBar(),
              Expanded(child: _portalPage()),
            ]),
          ),
        ]),
      );

  Widget _mobileLayout() => Scaffold(
        appBar: AppBar(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(_title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            const AppReloadButton(color: Colors.white),
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
          ],
        ),
        drawer: Drawer(child: SafeArea(child: _sidebar(dark: false))),
        body: _portalPage(),
      );

  Widget _topBar() => Container(
        height: 78,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_blue, Color(0xFF2368C4), _red],
              stops: [0, .55, .55]),
          boxShadow: [
            BoxShadow(
                color: _blue.withValues(alpha: .22),
                blurRadius: 18,
                offset: const Offset(0, 7)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(children: [
            Text(_title.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.25)),
            const Spacer(),
            const AppReloadButton(color: Colors.white),
            const SizedBox(width: 22),
            const Icon(Icons.calendar_today_outlined, color: Colors.white70),
            const SizedBox(width: 9),
            Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(width: 24),
            CircleAvatar(
              radius: 19,
              backgroundColor: Colors.white.withValues(alpha: .22),
              child: const Icon(Icons.admin_panel_settings_outlined,
                  color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                const Text('Request Approval Admin',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 12),
            IconButton(
                tooltip: 'Logout',
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white)),
          ]),
        ),
      );

  Widget _portalPage() => Container(
        color: const Color(0xFFF7F9FD),
        child: Stack(fit: StackFit.expand, children: [
          Positioned(
            right: -80,
            bottom: -80,
            child: IgnorePointer(
              child: Opacity(
                opacity: .035,
                child: Image.asset('assets/hasani_books_logo.jpg', width: 460),
              ),
            ),
          ),
          _content,
        ]),
      );

  Widget _sidebar({required bool dark}) => Container(
        width: dark ? 245 : double.infinity,
        decoration: BoxDecoration(
          gradient: dark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF102F68), Color(0xFF091B40)])
              : null,
          color: dark ? null : Colors.white,
        ),
        child: Column(children: [
          _sidebarHeader(dark),
          Divider(height: 1, color: dark ? Colors.white24 : Colors.black12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                for (var i = 0; i < _navigation.length; i++)
                  _navItem(i, dark: dark),
              ],
            ),
          ),
          Divider(height: 1, color: dark ? Colors.white24 : Colors.black12),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 22),
            leading: const Icon(Icons.logout, color: Color(0xFFE72D3B)),
            title: Text('Logout',
                style: TextStyle(
                    color: dark ? Colors.white : const Color(0xFF303747),
                    fontWeight: FontWeight.w700)),
            onTap: _logout,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('Hasani Books Edar Sdn Bhd',
                style: TextStyle(
                    fontSize: 10, color: dark ? Colors.white54 : Colors.black45)),
          ),
        ]),
      );

  Widget _sidebarHeader(bool dark) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Image.asset('assets/hasani_books_logo.jpg',
              width: 158,
              errorBuilder: (_, __, ___) => const Text('HASANI BOOKS',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900))),
          const SizedBox(height: 20),
          Text('REQUEST PORTAL',
              style: TextStyle(
                  color: dark ? Colors.white : _blue,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
          const SizedBox(height: 5),
          Text('Final approvals only',
              style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12)),
        ]),
      );

  Widget _navItem(int index, {required bool dark}) {
    final item = _navigation[index];
    final selected = page == index;
    final accent = item.$3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => _changePage(index, closeDrawer: !dark),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: dark ? .22 : .12) : null,
              borderRadius: BorderRadius.circular(13),
              border: selected
                  ? Border.all(color: accent.withValues(alpha: .55))
                  : null,
            ),
            child: Row(children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: dark ? .25 : .13),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(item.$2, color: selected && dark ? Colors.white : accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.$1,
                    style: TextStyle(
                        color: dark
                            ? (selected ? Colors.white : Colors.white70)
                            : (selected ? _blue : const Color(0xFF303747)),
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              ),
              if (selected) Icon(Icons.chevron_right_rounded, color: accent),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RequestAdminOtPage extends StatefulWidget {
  const _RequestAdminOtPage();

  @override
  State<_RequestAdminOtPage> createState() => _RequestAdminOtPageState();
}

class _RequestAdminOtPageState extends State<_RequestAdminOtPage> {
  late Future<List<Map<String, dynamic>>> future =
      SupabaseService.getPendingOtRequests();

  Future<void> review(Map<String, dynamic> row, bool approve) async {
    final duration = TextEditingController(
        text: row['requested_minutes']?.toString() ?? '0');
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(approve ? 'Approve OT Request' : 'Reject OT Request'),
              content: approve
                  ? TextField(
                      controller: duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Approved minutes'))
                  : const Text('Confirm rejection of this OT request?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'Approve' : 'Reject')),
              ],
            ));
    if (confirmed == true) {
      await SupabaseService.reviewOtRequest(
          requestId: row['id'].toString(),
          approve: approve,
          approvedOtMinutes: approve ? int.tryParse(duration.text) : null);
      await NotificationService.send(
              title: approve ? 'OT Request Approved' : 'OT Request Rejected',
              body: approve
                  ? 'Your OT request has received final approval.'
                  : 'Your OT request was rejected.',
              audience: 'employee',
              employeeId: row['employee_id']?.toString(),
              type: approve ? 'approval' : 'rejection')
          .catchError((_) {});
      if (mounted) setState(() => future = SupabaseService.getPendingOtRequests());
    }
    duration.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!.where((r) => r['status'] == 'pending_admin').toList();
        if (rows.isEmpty) return const Center(child: Text('No OT requests awaiting final approval.'));
        return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final row = rows[i];
              return Card(
                  child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.more_time)),
                title: Text('${row['employee_name'] ?? row['employee_id']} - ${row['overtime_date'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${row['branch_id'] ?? ''}\nBranch approved by ${row['branch_approved_name'] ?? '-'}'),
                trailing: Wrap(spacing: 6, children: [
                  OutlinedButton(onPressed: () => review(row, false), child: const Text('Reject')),
                  FilledButton(onPressed: () => review(row, true), child: const Text('Approve')),
                ]),
              ));
            });
      });
}
