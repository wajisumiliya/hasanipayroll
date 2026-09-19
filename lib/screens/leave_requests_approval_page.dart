import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'supabase_service.dart';

class LeaveRequestsApprovalPage extends StatefulWidget {
  final bool adminMode;
  final String? branchId;
  final Set<String>? employeeIds;

  const LeaveRequestsApprovalPage.admin({super.key})
      : adminMode = true,
        branchId = null,
        employeeIds = null;

  const LeaveRequestsApprovalPage.branch({
    super.key,
    required this.branchId,
    this.employeeIds,
  }) : adminMode = false;

  @override
  State<LeaveRequestsApprovalPage> createState() =>
      _LeaveRequestsApprovalPageState();
}

class _LeaveRequestsApprovalPageState
    extends State<LeaveRequestsApprovalPage> {
  Future<List<Map<String, dynamic>>>? _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    var rows = widget.adminMode
        ? await SupabaseService.getAllLeaveRequests()
        : await SupabaseService.getBranchLeaveRequests(widget.branchId ?? '');
    final visible = widget.employeeIds;
    if (!widget.adminMode && visible != null) {
      rows = rows.where((row) {
        final id = row['employee_id']?.toString().trim().toUpperCase();
        return id != null && visible.contains(id);
      }).toList();
    }
    return rows;
  }

  Future<void> _review(Map<String, dynamic> row, bool approve) async {
    final remarks = TextEditingController();
    final approver = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve leave request?' : 'Reject leave request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.adminMode) ...[
              TextField(
                controller: approver,
                decoration: const InputDecoration(
                  labelText: 'Approver name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: remarks,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: approve ? 'Remarks (optional)' : 'Reason for rejection',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
            ),
            onPressed: () {
              if (!widget.adminMode && approve && approver.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter the branch approver name.')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (widget.adminMode) {
        await SupabaseService.reviewAdminLeaveRequest(
          requestId: row['id'].toString(),
          approve: approve,
          remarks: remarks.text,
        );
      } else {
        await SupabaseService.reviewBranchLeaveRequest(
          requestId: row['id'].toString(),
          approve: approve,
          approverName: approver.text,
          remarks: remarks.text,
        );
      }
      if (!mounted) return;
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Leave request approved.' : 'Leave request rejected.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to review leave request: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(_refresh),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leave Requests',
                        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                    Text('Review employee leave applications and approval progress.',
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              IconButton(onPressed: () => setState(_refresh), icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: ['all', 'pending_branch', 'pending_admin', 'approved', 'rejected']
                .map((status) => ChoiceChip(
                      label: Text(status.replaceAll('_', ' ').toUpperCase()),
                      selected: _filter == status,
                      onSelected: (_) => setState(() => _filter = status),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(50),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                return _empty('Unable to load leave requests: ${snapshot.error}');
              }
              final all = snapshot.data ?? const <Map<String, dynamic>>[];
              final rows = _filter == 'all'
                  ? all
                  : all.where((row) => row['status'] == _filter).toList();
              if (rows.isEmpty) return _empty('No leave requests in this category.');
              return LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 270,
                  ),
                  itemBuilder: (_, index) => _requestCard(rows[index]),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> row) {
    final status = row['status']?.toString() ?? 'pending_branch';
    final actionable = widget.adminMode ? status == 'pending_admin' : status == 'pending_branch';
    final statusColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: statusColor.withValues(alpha: .25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF24F78).withValues(alpha: .10),
                child: const Icon(Icons.flight_takeoff, color: Color(0xFFF24F78)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row['employee_name']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${row['employee_id']} • ${row['branch_id']}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              _status(status, statusColor),
            ]),
            const Divider(height: 24),
            Text(row['leave_type']?.toString() ?? '-',
                style: const TextStyle(color: Color(0xFFF24F78), fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${row['start_date']} to ${row['end_date']}  •  ${row['total_days']} day(s)'),
            const SizedBox(height: 8),
            Text(row['reason']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            if (status == 'pending_admin')
              Text('Branch approved by ${row['branch_approved_name'] ?? '-'}',
                  style: const TextStyle(fontSize: 11, color: Colors.green)),
            if (actionable)
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => _review(row, false),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _review(row, true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.check, size: 17),
                  label: Text(widget.adminMode ? 'Final approve' : 'Forward to admin'),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _status(String status, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(status.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
      );

  Widget _empty(String message) => Container(
        padding: const EdgeInsets.all(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
      );
}
