import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import '../services/qr_attendance_service.dart';
import '../widgets/qr_attendance/employee_photo.dart';
import 'supabase_service.dart';

class LiveQrAttendancePage extends StatefulWidget {
  const LiveQrAttendancePage({super.key, required this.admin});
  final bool admin;
  @override
  State<LiveQrAttendancePage> createState() => _LiveQrAttendancePageState();
}

class _LiveQrAttendancePageState extends State<LiveQrAttendancePage>
    with WidgetsBindingObserver {
  DateTime date = DateTime.now().toUtc().add(const Duration(hours: 8));
  final search = TextEditingController();
  String? branchId, error;
  List<Map<String, dynamic>> branches = [], corrections = [];
  Map<String, dynamic>? data;
  Timer? poll, debounce;
  bool busy = false, saving = false, foreground = true;
  int revision = 0;
  String get day => DateFormat('yyyy-MM-dd').format(date);
  Map<String, String> get query => {
        'date': day,
        if (branchId != null) 'branch_id': branchId!,
        if (search.text.trim().isNotEmpty) 'q': search.text.trim()
      };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadBranches();
    load();
    poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (foreground &&
          !busy &&
          !saving &&
          ModalRoute.of(context)?.isCurrent != false) {
        load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    poll?.cancel();
    debounce?.cancel();
    search.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> loadBranches() async {
    if (!widget.admin) return;
    try {
      final rows = await SupabaseService.getBranches();
      if (mounted) setState(() => branches = rows);
    } catch (_) {/* Main data reports its own error. */}
  }

  Future<void> load() async {
    final request = ++revision, selected = Map<String, String>.from(query);
    setState(() => busy = true);
    try {
      final result = await Future.wait([
        QrAttendanceService.get('/dashboard', selected),
        QrAttendanceService.get('/corrections', selected)
      ]);
      if (mounted && request == revision) {
        setState(() {
          data = result[0];
          corrections =
              List<Map<String, dynamic>>.from(result[1]['corrections'] as List);
          error = null;
        });
      }
    } catch (e) {
      if (mounted && request == revision) setState(() => error = '$e');
    } finally {
      if (mounted && request == revision) setState(() => busy = false);
    }
  }

  Future<void> export(String format) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final result = await QrAttendanceService.get(
          '/export', {...query, 'format': format});
      final bytes = base64Decode(result['file_base64'] as String);
      if (format == 'pdf') {
        await Printing.layoutPdf(
            name: 'qr_attendance_$day.pdf', onLayout: (_) async => bytes);
      } else {
        await FileSaver.instance.saveFile(
            name: 'qr_attendance_$day',
            bytes: bytes,
            ext: 'xlsx',
            mimeType: MimeType.microsoftExcel);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> review(Map<String, dynamic> employee) async {
    setState(() => saving = true);
    try {
      final result = await QrAttendanceService.get('/reconciliation', {
        'employee_id': '${employee['employee_id']}',
        'date': '${employee['work_date']}'
      });
      if (!mounted) return;
      final proposal = Map<String, dynamic>.from(result['proposal'] as Map),
          current = result['current'] as Map?;
      final locked = current?['is_submitted'] == true ||
          current?['ot_authorized'] == true ||
          current?['approved_ot_minutes'] != null;
      final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(
                      'Reconcile ${employee['employee_id']} · ${employee['work_date']}'),
                  content: SizedBox(
                      width: 650,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text(
                                'Review the raw punches and proposed Attendance Sheet values. This saves a draft; it does not submit attendance or authorize OT.'),
                            for (final event in result['events'] as List)
                              ListTile(
                                  dense: true,
                                  title: Text(
                                      '${event['action']} · ${QrAttendanceService.malaysiaTime(event['scanned_at'])} MYT'),
                                  subtitle: Text(
                                      'Original: ${event['raw_id'] ?? 'manual correction'} · correction ${event['correction_id'] ?? 'none'}')),
                            if (proposal['fields'] is Map)
                              for (final field
                                  in (proposal['fields'] as Map).entries)
                                Text('${field.key}: ${field.value ?? '—'}'),
                            for (final issue in proposal['issues'] as List)
                              Text('$issue',
                                  style: const TextStyle(color: Colors.red)),
                            if (locked)
                              const Text(
                                  'Submitted or OT-approved attendance is locked.',
                                  style: TextStyle(color: Colors.red)),
                            if (current != null)
                              Text(
                                  'Current status: ${current['status']} · IN ${current['check_in']} · OUT ${current['check_out']}'),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: proposal['valid'] != true || locked
                            ? null
                            : () => Navigator.pop(context, true),
                        child: const Text('Approve draft mapping'))
                  ]));
      if (approved == true) {
        await QrAttendanceService.post('/reconcile', {
          'employee_id': employee['employee_id'],
          'date': employee['work_date'],
          'fingerprint': proposal['fingerprint']
        });
        await load();
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> correction(Map<String, dynamic> employee) async {
    final reason = TextEditingController(),
        time = TextEditingController(text: '${employee['work_date']}T18:00');
    String action = 'OUT', eventId = '';
    final events = (data?['events'] as List? ?? [])
        .where((event) =>
            event['employee_id'] == employee['employee_id'] &&
            event['raw_id'] != null)
        .toList();
    final body = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                    title:
                        Text('Correction request · ${employee['employee_id']}'),
                    content: SizedBox(
                        width: 520,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              const Text(
                                  'Original punches remain unchanged. An administrator must approve this request.'),
                              DropdownButtonFormField<String>(
                                  initialValue: eventId,
                                  decoration: const InputDecoration(
                                      labelText: 'Original event'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '',
                                        child: Text('Add a missing punch')),
                                    for (final event in events)
                                      DropdownMenuItem(
                                          value: '${event['raw_id']}',
                                          child: Text(
                                              '#${event['raw_id']} ${event['action']} ${QrAttendanceService.malaysiaTime(event['scanned_at'])}'))
                                  ],
                                  onChanged: (value) =>
                                      setDialog(() => eventId = value ?? '')),
                              DropdownButtonFormField<String>(
                                  initialValue: action,
                                  decoration: const InputDecoration(
                                      labelText: 'Correct action'),
                                  items: ['IN', 'OUT', 'VOID']
                                      .map((value) => DropdownMenuItem(
                                          value: value, child: Text(value)))
                                      .toList(),
                                  onChanged: (value) =>
                                      setDialog(() => action = value ?? 'OUT')),
                              TextField(
                                  controller: time,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'Malaysia timestamp: YYYY-MM-DDTHH:MM')),
                              TextField(
                                  controller: reason,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                      labelText: 'Reason (5–1000 characters)')),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () {
                            final timestamp =
                                DateTime.tryParse('${time.text.trim()}+08:00');
                            if (timestamp == null ||
                                reason.text.trim().length < 5) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Enter a valid Malaysia timestamp and a reason.')));
                              return;
                            }
                            Navigator.pop(context, {
                              'employee_id': employee['employee_id'],
                              'date': employee['work_date'],
                              'action': action,
                              'corrected_at':
                                  timestamp.toUtc().toIso8601String(),
                              'reason': reason.text.trim(),
                              'branch_id': employee['branch_id'],
                              if (eventId.isNotEmpty) 'event_id': eventId
                            });
                          },
                          child: const Text('Request correction'))
                    ])));
    reason.dispose();
    time.dispose();
    if (body == null || !mounted) return;
    setState(() => saving = true);
    try {
      await QrAttendanceService.post('/corrections', body);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> approveCorrection(Map<String, dynamic> c, bool approved,
      {bool together = false}) async {
    setState(() => saving = true);
    try {
      await QrAttendanceService.post('/corrections/review', {
        if (together)
          'ids': corrections
              .where((row) =>
                  row['employee_id'] == c['employee_id'] &&
                  row['status'] == 'PENDING')
              .take(20)
              .map((row) => row['id'])
              .toList()
        else
          'id': c['id'],
        'approved': approved
      });
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> audit() async {
    try {
      final result = await QrAttendanceService.get('/audit', query);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('QR audit history'),
                  content: SizedBox(
                      width: 700,
                      child: SingleChildScrollView(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final row in result['audit'] as List)
                          ListTile(
                              title: Text(
                                  '${row['action']} · ${row['employee_id'] ?? row['branch_id'] ?? ''}'),
                              subtitle: Text(
                                  '${QrAttendanceService.malaysiaTime(row['created_at'])} MYT · ${row['operator']}\n${row['details']}')),
                        if ((result['audit'] as List).isEmpty)
                          const Text('No audit history for this selection.'),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = data?['employees'] as List? ?? [],
        totals = data?['totals'] as Map? ?? {};
    return RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(widget.admin ? 'Live QR Attendance' : 'Branch QR Attendance',
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
              'Refreshes every 15 seconds while visible. IN/OUT reflect the last punch for each work date. Today also includes older unmatched IN sessions. No automatic check-out or OT approval.'),
          const SizedBox(height: 16),
          Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 1)));
                      if (picked != null && mounted) {
                        setState(() => date = picked);
                        await load();
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(DateFormat('dd MMM yyyy').format(date))),
                if (widget.admin)
                  SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String>(
                          initialValue: branchId,
                          decoration:
                              const InputDecoration(labelText: 'Branch'),
                          items: [
                            const DropdownMenuItem<String>(
                                value: null, child: Text('All branches')),
                            for (final b in branches)
                              DropdownMenuItem(
                                  value: '${b['id']}',
                                  child: Text('${b['name'] ?? b['id']}',
                                      overflow: TextOverflow.ellipsis))
                          ],
                          onChanged: (value) {
                            setState(() => branchId = value);
                            load();
                          })),
                OutlinedButton.icon(
                    onPressed: saving ? null : () => export('pdf'),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('PDF')),
                OutlinedButton.icon(
                    onPressed: saving ? null : () => export('xlsx'),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Excel')),
                TextButton(
                    onPressed: saving ? null : audit,
                    child: const Text('Audit history')),
              ]),
          const SizedBox(height: 12),
          TextField(
              controller: search,
              decoration: const InputDecoration(
                  labelText: 'Search employee ID or name',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (_) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 450), load);
              }),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 8, children: [
            for (final item in [
              ('in', 'Currently IN'),
              ('out', 'OUT'),
              ('punches', 'Punches'),
              ('missing', 'Missing OUT'),
              ('late', 'Late arrivals'),
              ('rejected', 'Rejected scans')
            ])
              Chip(label: Text('${item.$2}: ${totals[item.$1] ?? 0}'))
          ]),
          if (busy || saving) const LinearProgressIndicator(),
          if (error != null)
            Card(
                color: const Color(0xFFFFE8E8),
                child: Padding(
                    padding: const EdgeInsets.all(16), child: Text(error!))),
          if (data != null && employees.isEmpty)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No QR attendance records for this selection.')),
          for (final raw in employees)
            Builder(builder: (context) {
              final employee = Map<String, dynamic>.from(raw as Map);
              return Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              QrEmployeePhoto(
                                  employeeId: '${employee['employee_id']}'),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(
                                      '${employee['name']} · ${employee['employee_id']}\n${employee['branch_id']} · ${employee['work_date']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))),
                              Chip(label: Text('${employee['action']}'))
                            ]),
                            const SizedBox(height: 8),
                            Text(
                                'First IN: ${QrAttendanceService.malaysiaTime(employee['first_in'])} MYT\nLast: ${QrAttendanceService.malaysiaTime(employee['last_punch'])} MYT\nNet: ${employee['net_minutes'] ?? 'Review'} min · Late: ${employee['late_minutes'] ?? 'Not established'} min · Early departure: ${employee['early_minutes'] ?? 'Not established'} min'),
                            if ((employee['issues'] as List).isNotEmpty)
                              Text((employee['issues'] as List).join(' · '),
                                  style: const TextStyle(
                                      color: Colors.deepOrange)),
                            Wrap(spacing: 12, children: [
                              if (widget.admin)
                                TextButton(
                                    onPressed:
                                        saving ? null : () => review(employee),
                                    child: const Text(
                                        'Review Attendance Sheet mapping')),
                              TextButton(
                                  onPressed: saving
                                      ? null
                                      : () => correction(employee),
                                  child: const Text('Request correction'))
                            ]),
                          ])));
            }),
          if (corrections.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Correction requests',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            for (final c in corrections)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '#${c['id']} · ${c['employee_id']} · ${c['action']} · ${c['status']}'),
                            Text(
                                '${QrAttendanceService.malaysiaTime(c['corrected_at'])} MYT · ${c['reason']}'),
                            if (widget.admin && c['status'] == 'PENDING')
                              Wrap(spacing: 10, children: [
                                TextButton(
                                    onPressed: saving
                                        ? null
                                        : () => approveCorrection(c, true),
                                    child: const Text('Approve correction')),
                                if (corrections
                                        .where((row) =>
                                            row['employee_id'] ==
                                                c['employee_id'] &&
                                            row['status'] == 'PENDING')
                                        .length >
                                    1)
                                  TextButton(
                                      onPressed: saving
                                          ? null
                                          : () => approveCorrection(c, true,
                                              together: true),
                                      child: const Text(
                                          'Approve related requests together')),
                                TextButton(
                                    onPressed: saving
                                        ? null
                                        : () => approveCorrection(c, false),
                                    child: const Text('Reject'))
                              ]),
                          ])))
          ],
          const SizedBox(height: 18),
          const Text('Scan history (latest 200; search or export for more)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          for (final event
              in (data?['events'] as List? ?? []).reversed.take(200))
            ListTile(
                dense: true,
                title: Text(
                    '${event['employee_id']} · ${event['action']} · ${QrAttendanceService.malaysiaTime(event['scanned_at'])} MYT'),
                subtitle: Text(
                    '${event['branch_id']} · raw #${event['raw_id'] ?? 'correction'} · work date ${event['work_date']}')),
          const SizedBox(height: 18),
          const Text('Scan attempts (latest 100 displayed)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          for (final attempt in (data?['attempts'] as List? ?? []).take(100))
            ListTile(
                dense: true,
                title: Text(
                    '${attempt['employee_id'] ?? 'Unknown card'} · ${attempt['status']} · ${attempt['code']}'),
                subtitle: Text(
                    '${QrAttendanceService.malaysiaTime(attempt['attempted_at'])} MYT · ${attempt['message']}')),
        ]));
  }
}
