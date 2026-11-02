import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/app_service.dart';

class EarlyOutPage extends StatefulWidget {
  const EarlyOutPage({super.key, this.loader, this.decisionSaver});
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? loader;
  final Future<void> Function(Map<String, dynamic>)? decisionSaver;
  @override
  State<EarlyOutPage> createState() => _EarlyOutPageState();
}

class _EarlyOutPageState extends State<EarlyOutPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String status = 'ALL', branch = '', employee = '', search = '';
  int page = 1;
  late Future<Map<String, dynamic>> result;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    result = widget.loader != null
        ? widget.loader!({
            'month': month,
            'status': status,
            'branch': branch,
            'employee': employee,
            'search': search,
            'page': page
          })
        : AppService.instance.loadEarlyOutList(
            month: month,
            status: status,
            branch: branch,
            employee: employee,
            search: search,
            page: page);
  }

  void _refresh({bool reset = false}) {
    setState(() {
      if (reset) page = 1;
      _load();
    });
  }

  String time(dynamic n) {
    final m = (n as num?)?.toInt() ?? 0;
    return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
  }

  String requestId() {
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> review(Map<String, dynamic> record) async {
    final duration =
        TextEditingController(text: '${record['eligible_early_minutes']}');
    final remarks = TextEditingController();
    String? error;
    bool saving = false;
    final id = requestId();
    Future<dynamic>? routeClosed;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) {
          routeClosed = ModalRoute.of(dialog)?.completed;
          return StatefulBuilder(builder: (context, update) {
            Future<void> save(String state) async {
              final minutes = int.tryParse(duration.text);
              if (remarks.text.trim().length < 3 ||
                  (state == 'APPROVED' &&
                      (minutes == null ||
                          minutes < 1 ||
                          minutes >
                              (record['eligible_early_minutes'] as num)))) {
                update(() => error =
                    'Enter a valid duration and remarks (at least 3 characters).');
                return;
              }
              update(() {
                saving = true;
                error = null;
              });
              try {
                await (widget.decisionSaver ??
                    AppService.instance.saveEarlyOutDecision)({
                  'request_id': id,
                  'employee_id': record['employee_id'],
                  'attendance_date': record['attendance_date'],
                  'fingerprint': record['fingerprint'],
                  'expected_revision': record['revision'],
                  'status': state,
                  'approved_minutes': state == 'APPROVED' ? minutes : 0,
                  'remarks': remarks.text.trim()
                });
                if (dialog.mounted) Navigator.pop(dialog);
                if (mounted) {
                  _refresh();
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
                      content: Text(
                          'Decision saved. Existing payroll is unchanged. Review/regenerate draft payroll; locked payroll needs an authorized adjustment.')));
                }
              } catch (e) {
                update(() {
                  saving = false;
                  error = '$e';
                });
              }
            }

            return AlertDialog(
                title: Text('Early Out • ${record['employee_id']}'),
                scrollable: true,
                content: SizedBox(
                    width: 440,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${record['name']} • ${record['attendance_date']}\nScheduled out: ${record['shift_end']} • Actual out: ${record['check_out']}\nRequired: ${time(record['required_minutes'])} • Worked: ${time(record['worked_minutes'])}\nEligible Early Out shortfall after existing grace: ${time(record['eligible_early_minutes'])}'),
                          const SizedBox(height: 12),
                          TextField(
                              controller: duration,
                              enabled: !saving,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Approved duration (minutes)')),
                          TextField(
                              controller: remarks,
                              enabled: !saving,
                              maxLength: 1000,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Remarks / reason')),
                          if (error != null)
                            Text(error!,
                                style: const TextStyle(color: Colors.red)),
                        ])),
                actions: [
                  TextButton(
                      onPressed: saving ? null : () => Navigator.pop(dialog),
                      child: const Text('Cancel')),
                  OutlinedButton(
                      onPressed: saving ? null : () => save('REJECTED'),
                      child: const Text('Reject')),
                  FilledButton(
                      onPressed: saving || record['eligible_early_minutes'] == 0
                          ? null
                          : () => save('APPROVED'),
                      child: Text(saving ? 'Saving...' : 'Approve'))
                ]);
          });
        });
    if (routeClosed != null) await routeClosed;
    duration.dispose();
    remarks.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Early Out Approvals',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text(
            'Approve only the Early Out shortfall. Other unapproved short hours remain deductible. Existing saved payroll is never changed automatically.'),
        const SizedBox(height: 12),
        Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<int>(
                      initialValue: month.month,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(DateFormat.MMMM()
                                  .format(DateTime(2000, i + 1))))),
                      onChanged: (v) {
                        month = DateTime(month.year, v!);
                        _refresh(reset: true);
                      })),
              SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int>(
                      initialValue: month.year,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items:
                          List.generate(12, (i) => DateTime.now().year + 1 - i)
                              .map((y) =>
                                  DropdownMenuItem(value: y, child: Text('$y')))
                              .toList(),
                      onChanged: (v) {
                        month = DateTime(v!, month.month);
                        _refresh(reset: true);
                      })),
              SizedBox(
                  width: 150,
                  child: TextField(
                      decoration: const InputDecoration(labelText: 'Branch ID'),
                      onSubmitted: (v) {
                        branch = v.trim();
                        _refresh(reset: true);
                      })),
              SizedBox(
                  width: 160,
                  child: TextField(
                      decoration:
                          const InputDecoration(labelText: 'Employee ID'),
                      onSubmitted: (v) {
                        employee = v.trim();
                        _refresh(reset: true);
                      })),
              SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                      initialValue: status,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ['ALL', 'PENDING', 'APPROVED', 'REJECTED']
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        status = v!;
                        _refresh(reset: true);
                      })),
              SizedBox(
                  width: 240,
                  child: TextField(
                      decoration: const InputDecoration(
                          labelText: 'Search name / ID / branch',
                          prefixIcon: Icon(Icons.search)),
                      onSubmitted: (v) {
                        search = v.trim();
                        _refresh(reset: true);
                      })),
              IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => _refresh(),
                  icon: const Icon(Icons.refresh)),
            ]),
        const SizedBox(height: 12),
        Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
                future: result,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: SelectableText('${snapshot.error}'));
                  }
                  final data = snapshot.data!,
                      rows = (data['records'] as List)
                          .map((r) => Map<String, dynamic>.from(r))
                          .toList();
                  return Column(children: [
                    Expanded(
                        child: rows.isEmpty
                            ? const Center(
                                child: Text(
                                    'No Early Out records match these filters.'))
                            : SingleChildScrollView(
                                child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                        columns: [
                                          for (final label in [
                                            'Employee ID',
                                            'Employee Name',
                                            'Branch',
                                            'Date',
                                            'Scheduled Out',
                                            'Actual Out',
                                            'Required Hours',
                                            'Worked Hours',
                                            'Short Hours',
                                            'Early Out Eligible',
                                            'Status',
                                            'Approved Duration',
                                            'Approved By',
                                            'Approval Date',
                                            'Remarks',
                                            'Action'
                                          ])
                                            DataColumn(label: Text(label))
                                        ],
                                        rows: rows
                                            .map((r) => DataRow(cells: [
                                                  for (final value in [
                                                    r['employee_id'],
                                                    r['name'],
                                                    r['branch_id'],
                                                    r['attendance_date'],
                                                    r['shift_end'],
                                                    r['check_out'],
                                                    time(r['required_minutes']),
                                                    time(r['worked_minutes']),
                                                    time(r['short_hours_minutes'] ??
                                                        r['shortage_minutes']),
                                                    time(r[
                                                        'eligible_early_minutes']),
                                                    r['approval_status'],
                                                    time(r['approved_minutes']),
                                                    r['approved_by'] ?? '—',
                                                    r['approval_date'] ?? '—',
                                                    (r['remarks'] ?? '')
                                                            .toString()
                                                            .isNotEmpty
                                                        ? r['remarks']
                                                        : r['review_blocked_reason'] ??
                                                            ''
                                                  ])
                                                    DataCell(Text('$value')),
                                                  DataCell(TextButton(
                                                      onPressed:
                                                          r['is_submitted'] ==
                                                                  true
                                                              ? () => review(r)
                                                              : null,
                                                      child:
                                                          const Text('Review')))
                                                ]))
                                            .toList())))),
                    Row(children: [
                      Text('${data['total']} records • Page $page'),
                      const Spacer(),
                      IconButton(
                          tooltip: 'Previous',
                          onPressed: page > 1
                              ? () {
                                  page--;
                                  _refresh();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left)),
                      IconButton(
                          tooltip: 'Next',
                          onPressed: page * 20 < (data['total'] as num)
                              ? () {
                                  page++;
                                  _refresh();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right))
                    ])
                  ]);
                }))
      ]));
}
