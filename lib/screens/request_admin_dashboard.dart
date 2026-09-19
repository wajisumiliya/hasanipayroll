import 'package:flutter/material.dart';

import '../services/app_service.dart';
import '../services/notification_service.dart';
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
  int page = 0;

  Widget get content => switch (page) {
        0 => const LeaveRequestsApprovalPage.admin(),
        1 => const _RequestAdminOtPage(),
        _ => const DailyReportPage.admin(),
      };

  Future<void> logout() async {
    await AppService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 800;
    final nav = [
      ('Leave Requests', Icons.flight_takeoff_outlined),
      ('OT Requests', Icons.more_time_outlined),
      ('Daily Reports', Icons.assignment_outlined),
    ];
    final menu = ListView(children: [
      const DrawerHeader(
          child: Text('HASANI BOOKS\nREQUEST APPROVAL',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
      for (var i = 0; i < nav.length; i++)
        ListTile(
            selected: page == i,
            leading: Icon(nav[i].$2),
            title: Text(nav[i].$1),
            onTap: () {
              setState(() => page = i);
              if (mobile) Navigator.pop(context);
            }),
      const Divider(),
      ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout'),
          onTap: logout),
    ]);
    return Scaffold(
      appBar: AppBar(title: Text(nav[page].$1)),
      drawer: mobile ? Drawer(child: menu) : null,
      body: Row(children: [
        if (!mobile)
          SizedBox(
              width: 250, child: Material(color: Colors.white, child: menu)),
        Expanded(child: content),
      ]),
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
                      decoration:
                          const InputDecoration(labelText: 'Approved minutes'))
                  : const Text('Confirm rejection of this OT request?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(approve ? 'Approve' : 'Reject'))
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
      if (mounted)
        setState(() => future = SupabaseService.getPendingOtRequests());
    }
    duration.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (_, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data!
                .where((r) => r['status'] == 'pending_admin')
                .toList();
            if (rows.isEmpty)
              return const Center(
                  child: Text('No OT requests awaiting final approval.'));
            return ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final row = rows[i];
                  return Card(
                      child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.more_time)),
                    title: Text(
                        '${row['employee_name'] ?? row['employee_id']} · ${row['overtime_date'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                        '${row['branch_id'] ?? ''}\nBranch approved by ${row['branch_approved_name'] ?? '-'}'),
                    trailing: Wrap(spacing: 6, children: [
                      OutlinedButton(
                          onPressed: () => review(row, false),
                          child: const Text('Reject')),
                      FilledButton(
                          onPressed: () => review(row, true),
                          child: const Text('Approve'))
                    ]),
                  ));
                });
          });
}
