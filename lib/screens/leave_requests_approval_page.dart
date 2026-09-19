import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'supabase_service.dart';
import '../services/notification_service.dart';

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

class _LeaveRequestsApprovalPageState extends State<LeaveRequestsApprovalPage> {
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
        title:
            Text(approve ? 'Approve leave request?' : 'Reject leave request?'),
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
                labelText:
                    approve ? 'Remarks (optional)' : 'Reason for rejection',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
            ),
            onPressed: () {
              if (!widget.adminMode &&
                  approve &&
                  approver.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Enter the branch approver name.')),
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
      await NotificationService.send(
        title: widget.adminMode
            ? (approve ? 'Leave Approved' : 'Leave Rejected')
            : (approve ? 'Leave Forwarded to Admin' : 'Leave Rejected'),
        body: widget.adminMode
            ? (approve
                ? 'Your ${row['leave_type']} request has received final approval.'
                : 'Your ${row['leave_type']} request was rejected by admin.')
            : (approve
                ? 'Your ${row['leave_type']} request was approved by your branch and sent to admin.'
                : 'Your ${row['leave_type']} request was rejected by your branch.'),
        audience: 'employee',
        employeeId: row['employee_id']?.toString(),
        type: approve ? 'approval' : 'rejection',
      ).catchError(
        (error) => debugPrint('Leave notification error: $error'),
      );
      if (!mounted) return;
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(approve
                ? 'Leave request approved.'
                : 'Leave request rejected.')),
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
                        style: TextStyle(
                            fontSize: 27, fontWeight: FontWeight.w900)),
                    Text(
                        'Review employee leave applications and approval progress.',
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              IconButton(
                  onPressed: () => setState(_refresh),
                  icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              'all',
              'pending_branch',
              'pending_admin',
              'approved',
              'rejected'
            ]
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
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(50),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                return _empty(
                    'Unable to load leave requests: ${snapshot.error}');
              }
              final all = snapshot.data ?? const <Map<String, dynamic>>[];
              final rows = _filter == 'all'
                  ? all
                  : all.where((row) => row['status'] == _filter).toList();
              if (rows.isEmpty) {
                return _empty('No leave requests in this category.');
              }
              return Column(
                children: [
                  for (final row in rows) ...[
                    _requestCard(row),
                    const SizedBox(height: 18),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> row) {
    final status = row['status']?.toString() ?? 'pending_branch';
    final actionable = widget.adminMode
        ? status == 'pending_admin'
        : status == 'pending_branch';
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
                child:
                    const Icon(Icons.flight_takeoff, color: Color(0xFFF24F78)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row['employee_name']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${row['employee_id']} • ${row['branch_id']}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              _status(status, statusColor),
            ]),
            const Divider(height: 24),
            Text(row['leave_type']?.toString() ?? '-',
                style: const TextStyle(
                    color: Color(0xFFF24F78), fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
                '${row['start_date']} to ${row['end_date']}  •  ${row['total_days']} day(s)'),
            const SizedBox(height: 8),
            Text(row['reason']?.toString() ?? '-',
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            if (status == 'pending_admin')
              Text('Branch approved by ${row['branch_approved_name'] ?? '-'}',
                  style: const TextStyle(fontSize: 11, color: Colors.green)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => _showApplicationForm(row),
              icon: const Icon(Icons.description_outlined, size: 17),
              label: const Text('View application form'),
            ),
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
                  label: Text(
                      widget.adminMode ? 'Final approve' : 'Forward to admin'),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Future<void> _showApplicationForm(Map<String, dynamic> row) async {
    const pink = Color(0xFFF24F78);
    final status = row['status']?.toString() ?? 'pending_branch';
    final actionable = widget.adminMode
        ? status == 'pending_admin'
        : status == 'pending_branch';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    color: const Color(0xFFFFFEF1),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 14, 12, 12),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/hasani_books_logo.jpg',
                                width: 150,
                                height: 55,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Text(
                                  'hasani BOOKS',
                                  style: TextStyle(
                                      color: pink,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                              const Spacer(),
                              Text('BRANCH: ${row['branch_id'] ?? '-'}',
                                  style: const TextStyle(
                                      color: pink,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                              IconButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        _formBar('LEAVE APPLICATION FORM'),
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  'Annual Leave',
                                  'Unpaid Leave',
                                  'Emergency Leave',
                                  'Replacement Leave',
                                ]
                                    .map((type) => _leaveTypeBox(type,
                                        row['leave_type']?.toString() == type))
                                    .toList(),
                              ),
                              const SizedBox(height: 20),
                              _formFields([
                                ('Name', row['employee_name']),
                                ('Employee ID', row['employee_id']),
                                ('Designation', row['designation']),
                                ('Department', row['department']),
                                ('From date', _displayDate(row['start_date'])),
                                ('Until', _displayDate(row['end_date'])),
                                (
                                  'Number of days',
                                  '${row['total_days'] ?? '-'} day(s)'
                                ),
                                (
                                  'Submitted',
                                  _displayDate(row['submitted_at'])
                                ),
                              ]),
                              const SizedBox(height: 15),
                              _formField('Reason for leave', row['reason']),
                              const SizedBox(height: 12),
                              _formField('Address during leave',
                                  row['address_during_leave']),
                              const SizedBox(height: 12),
                              _formField('Emergency contact number',
                                  row['emergency_phone']),
                            ],
                          ),
                        ),
                        _formBar('BRANCH MANAGER SUPPORT AND COMMENTS'),
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              _formField(
                                  'Branch comments', row['branch_remarks']),
                              const SizedBox(height: 12),
                              _formFields([
                                ('Approved by', row['branch_approved_name']),
                                (
                                  'Approval date',
                                  _displayDate(row['branch_approved_at'])
                                ),
                              ]),
                            ],
                          ),
                        ),
                        _formBar('FOR OFFICIAL USE'),
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              Wrap(
                                spacing: 24,
                                runSpacing: 8,
                                children: [
                                  _checkLabel(
                                      'Leave approved', status == 'approved'),
                                  _checkLabel('Leave not approved',
                                      status == 'rejected'),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _formField('Admin remarks', row['admin_remarks']),
                              const SizedBox(height: 12),
                              _formFields([
                                (
                                  'Final approval date',
                                  _displayDate(row['admin_approved_at'])
                                ),
                                ('Current stage', status.replaceAll('_', ' ')),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (actionable)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: pink)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _review(row, false);
                        },
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _review(row, true);
                        },
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.green),
                        icon: const Icon(Icons.check),
                        label: Text(widget.adminMode
                            ? 'Final approve'
                            : 'Support and forward'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formBar(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 7),
        color: const Color(0xFFF24F78),
        child: Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: .4)),
      );

  Widget _leaveTypeBox(String label, bool selected) => Container(
        width: 195,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF24F78).withValues(alpha: .10)
              : Colors.transparent,
          border: Border.all(color: const Color(0xFFF24F78)),
        ),
        child: Row(children: [
          Expanded(
            child: Text(label.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFF24F78),
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
          Icon(selected ? Icons.check_circle : Icons.circle_outlined,
              size: 19, color: const Color(0xFFF24F78)),
        ]),
      );

  Widget _formFields(List<(String, dynamic)> fields) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 620
              ? (constraints.maxWidth - 18) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 18,
            runSpacing: 12,
            children: fields
                .map((field) => SizedBox(
                    width: width, child: _formField(field.$1, field.$2)))
                .toList(),
          );
        },
      );

  Widget _formField(String label, dynamic value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFFF24F78), fontSize: 10)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 25),
            padding: const EdgeInsets.only(bottom: 5),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF24F78))),
            ),
            child: Text(value == null || value.toString().trim().isEmpty
                ? '-'
                : value.toString()),
          ),
        ],
      );

  Widget _checkLabel(String label, bool checked) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(checked ? Icons.check_box : Icons.check_box_outline_blank,
              color: const Color(0xFFF24F78)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFFF24F78))),
        ],
      );

  String _displayDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? '-'
        : DateFormat('dd/MM/yyyy').format(parsed.toLocal());
  }

  Widget _status(String status, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(status.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
                color: color, fontSize: 8, fontWeight: FontWeight.w900)),
      );

  Widget _empty(String message) => Container(
        padding: const EdgeInsets.all(45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54)),
      );
}
