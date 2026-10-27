import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/app_service.dart';
import '../services/late_report_export_service.dart';

class LateReportPage extends StatefulWidget {
  const LateReportPage(
      {super.key,
      required this.month,
      required this.branches,
      this.loader,
      this.embedded = false,
      this.initialBranchId,
      this.reviewSaver,
      this.exporter});
  final bool embedded;
  final String? initialBranchId;
  final DateTime month;
  final List<Map<String, dynamic>> branches;
  final Future<Map<String, dynamic>> Function(DateTime)? loader;
  final Future<void> Function(Map<String, dynamic>)? reviewSaver;
  final Future<void> Function(String, LateReportExportData)? exporter;
  @override
  State<LateReportPage> createState() => _LateReportPageState();
}

class _LateReportPageState extends State<LateReportPage> {
  late DateTime _month;
  late Future<Map<String, dynamic>> _report;
  String? _branch;
  bool _exporting = false;
  @override
  void initState() {
    super.initState();
    _month = widget.month;
    _branch = widget.initialBranchId;
    _load();
  }

  void _load() {
    _report = (widget.loader ?? AppService.instance.loadLateReport)(_month);
  }

  String _branchName(dynamic id) {
    for (final b in widget.branches) {
      if ('${b['id'] ?? b['branch_id']}'.toUpperCase() == '$id'.toUpperCase()) {
        return '${b['name'] ?? b['branch_name'] ?? id}';
      }
    }
    return '$id';
  }

  List<Map<String, dynamic>> _filtered(dynamic rows) => (rows as List? ?? [])
      .map((r) => Map<String, dynamic>.from(r as Map))
      .where((r) =>
          _branch == null ||
          '${r['branch_id']}'.toUpperCase() == _branch!.toUpperCase())
      .toList();
  Color _severity(int count) => count >= 7
      ? const Color(0xFFB42318)
      : count >= 5
          ? const Color(0xFFAC4B00)
          : const Color(0xFF806000);

  Future<void> _review(
      Map<String, dynamic> person, Map<String, dynamic> event) async {
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LateReviewDialog(
            person: person,
            event: event,
            save: widget.reviewSaver ??
                AppService.instance.saveLateReportReview));
    if (saved == true && mounted) setState(_load);
  }

  Future<void> _export(String format, Map<String, dynamic> data) async {
    if (_exporting) return;
    final payload = LateReportExportData(
        month: _month,
        branchLabel: _branch == null ? 'All branches' : _branchName(_branch),
        branchId: _branch,
        reports: _filtered(data['reports']));
    setState(() => _exporting = true);
    try {
      if (widget.exporter != null) {
        await widget.exporter!(format, payload);
      } else {
        final bytes = await AppService.instance.loadLateReportExport(
            month: payload.month, branchId: payload.branchId, format: format);
        final scope =
            payload.branchLabel.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        await FileSaver.instance.saveFile(
            name:
                'Late_Report_${DateFormat('yyyy_MM').format(payload.month)}_$scope',
            bytes: bytes,
            ext: format,
            mimeType: format == 'pdf' ? MimeType.pdf : MimeType.microsoftExcel);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Report exported.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to export report. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _summary(List<Map<String, dynamic>> reports) {
    int total(String field) =>
        reports.fold(0, (sum, r) => sum + (r[field] as num).toInt());
    final metrics = [
      ('Employees flagged', reports.length, Icons.people_outline),
      ('Late arrivals', total('arrival_count'), Icons.schedule),
      ('Exceeded breaks', total('break_count'), Icons.free_breakfast_outlined),
      ('Excess minutes', total('total_minutes'), Icons.timer_outlined),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Selected month · flagged employees only',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth < 650 ? 2 : 4;
        return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metrics
                .map((m) => SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 10) / columns,
                      child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(m.$3, color: const Color(0xFF1A4264)),
                                    Text('${m.$2}',
                                        style: const TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.bold)),
                                    Text(m.$1),
                                  ]))),
                    ))
                .toList());
      }),
    ]);
  }

  Widget _event(Map<String, dynamic> person, dynamic value) {
    final e = Map<String, dynamic>.from(value as Map);
    final review = e['review'] as Map?;
    final history = e['review_history'] as List? ?? [];
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(e['type'] == 'arrival'
                  ? Icons.schedule
                  : Icons.free_breakfast_outlined),
              title: Text(
                  '${DateFormat('EEE, dd MMM').format(DateTime.parse(e['date']))} · ${e['type'] == 'arrival' ? 'Late arrival' : 'Break exceeded'}'),
              subtitle: Text(e['type'] == 'arrival'
                  ? 'Scheduled ${e['scheduled']} · arrived ${e['actual']}'
                  : 'Allowed ${e['allocated_minutes']} min · used ${e['actual_minutes']} min'),
              trailing: Text('+${e['minutes']} min',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                    label: Text(e['review_outdated'] == true
                        ? 'Needs re-review'
                        : lateReviewStatus(review?['status']))),
                TextButton.icon(
                    onPressed: () => _review(person, e),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Review event')),
              ]),
          if (review != null) ...[
            Text(
                '${lateReasonLabel(review['reason_code'])}: ${review['reason']}'),
            Text(
                '${review['reviewed_by']} · ${lateLocalReviewTime(review['reviewed_at'])}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
          if (e['review_outdated'] == true)
            const Text(
                'Attendance timing changed after the last review. Please review again.'),
          if (history.isNotEmpty)
            ExpansionTile(
                key: PageStorageKey(
                    'history-${person['branch_id']}-${person['employee_id']}-${e['date']}-${e['type']}'),
                tilePadding: EdgeInsets.zero,
                title: Text('Review history (${history.length})'),
                children: history
                    .map((h) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              '${lateReviewStatus(h['status'])} · ${lateReasonLabel(h['reason_code'])}'),
                          subtitle: Text(
                              '${h['reason']}\n${h['reviewed_by']} · ${lateLocalReviewTime(h['reviewed_at'])}${h['event_fingerprint'] != e['fingerprint'] ? ' · Previous attendance timing' : ''}'),
                        ))
                    .toList()),
          const Divider(),
        ]));
  }

  Widget _results(Map<String, dynamic> data) {
    final reports = _filtered(data['reports']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
            onPressed: _exporting ? null : () => _export('pdf', data),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Export PDF')),
        OutlinedButton.icon(
            onPressed: _exporting ? null : () => _export('xlsx', data),
            icon: const Icon(Icons.table_view),
            label: const Text('Export Excel')),
        if (_exporting)
          const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
      ]),
      const SizedBox(height: 16),
      _summary(reports),
      const SizedBox(height: 12),
      const Text(
          'Severity: Low 3–4 · Medium 5–6 · High 7+. Reviews and approvals retain the recorded totals. Comparisons use saved records; the current month may still be in progress.'),
      const SizedBox(height: 12),
      Text('${reports.length} employee(s) meet the monthly threshold',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      if (reports.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'No employees with 3 or more occurrences in this period.')),
      ...reports.asMap().entries.expand((entry) {
        final r = entry.value;
        final count = (r['count'] as num).toInt();
        final previous = (r['previous_count'] as num? ?? 0).toInt();
        final change = count - previous;
        return <Widget>[
          if (entry.key == 0 ||
              reports[entry.key - 1]['branch_id'] != r['branch_id'])
            Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(_branchName(r['branch_id']),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold))),
          Card(
              child: ExpansionTile(
            key: PageStorageKey(
                '${_month.year}-${_month.month}-${r['branch_id']}-${r['employee_id']}'),
            title: Text('${r['name']} · ${r['employee_id']}'),
            subtitle:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${_branchName(r['branch_id'])}\n${r['arrival_count']} late arrivals + ${r['break_count']} exceeded breaks = $count occurrences · ${r['total_minutes']} min total'),
              const SizedBox(height: 6),
              Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                        backgroundColor:
                            _severity(count).withValues(alpha: .12),
                        label: Text('${lateSeverityLabel(count)} severity',
                            style: TextStyle(
                                color: _severity(count),
                                fontWeight: FontWeight.bold))),
                    Text('$count this month · $previous last month'),
                  ]),
              Text(change == 0
                  ? 'Unchanged from last month'
                  : change < 0
                      ? '${-change} fewer than last month'
                      : '$change more than last month'),
            ]),
            children: (r['events'] as List).map((e) => _event(r, e)).toList(),
          )),
        ];
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(title: const Text('Late Report'), actions: [
                IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => setState(_load),
                    icon: const Icon(Icons.refresh))
              ]),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.embedded)
                Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                        tooltip: 'Refresh report',
                        onPressed: () => setState(_load),
                        icon: const Icon(Icons.refresh))),
              Row(children: [
                IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => setState(() {
                          _month = DateTime(_month.year, _month.month - 1);
                          _load();
                        }),
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                    child: Text(DateFormat('MMMM yyyy').format(_month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18))),
                IconButton(
                    tooltip: 'Next month',
                    onPressed: () => setState(() {
                          _month = DateTime(_month.year, _month.month + 1);
                          _load();
                        }),
                    icon: const Icon(Icons.chevron_right)),
              ]),
              const Text(
                  'Employees with 3 or more combined occurrences: late arrivals + days exceeding allocated break minutes.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  initialValue: _branch ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Branch', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('All branches')),
                    ...widget.branches.map((b) => DropdownMenuItem(
                        value: '${b['id'] ?? b['branch_id']}',
                        child: Text('${b['name'] ?? b['branch_name']}')))
                  ],
                  onChanged: (v) =>
                      setState(() => _branch = v == '' ? null : v)),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, dynamic>>(
                  future: _report,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                          child: Column(children: [
                        const Text('Unable to load late report.'),
                        TextButton(
                            onPressed: () => setState(_load),
                            child: const Text('Retry'))
                      ]));
                    }
                    return _results(snap.data!);
                  }),
            ])),
      );
}

class _LateReviewDialog extends StatefulWidget {
  const _LateReviewDialog(
      {required this.person, required this.event, required this.save});
  final Map<String, dynamic> person, event;
  final Future<void> Function(Map<String, dynamic>) save;
  @override
  State<_LateReviewDialog> createState() => _LateReviewDialogState();
}

class _LateReviewDialogState extends State<_LateReviewDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _reason;
  late String _status, _category;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final review = widget.event['review'] as Map?;
    _reason = TextEditingController(text: review?['reason'] ?? '');
    _status = review?['status'] ?? 'noted';
    _category = review?['reason_code'] ?? 'other';
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save({
        'branch_id': widget.person['branch_id'],
        'employee_id': widget.person['employee_id'],
        'date': widget.event['date'],
        'type': widget.event['type'],
        'fingerprint': widget.event['fingerprint'],
        'status': _status,
        'reason_code': _category,
        'reason': _reason.text.trim()
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to save. Refresh if attendance changed, then retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text('Review ${widget.person['name']}'),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${widget.event['date']} · ${widget.event['type'] == 'arrival' ? 'Late arrival' : 'Break exceeded'} · +${widget.event['minutes']} min'),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Review status'),
                              items: [
                                'noted',
                                'approved',
                                'correction_required',
                                'pending'
                              ]
                                  .map((v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(lateReviewStatus(v))))
                                  .toList(),
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _status = v!)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                              initialValue: _category,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Reason category'),
                              items: [
                                'transport',
                                'approved_late',
                                'attendance_error',
                                'other'
                              ]
                                  .map((v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(lateReasonLabel(v))))
                                  .toList(),
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _category = v!)),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: _reason,
                              enabled: !_saving,
                              maxLength: 1000,
                              minLines: 2,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                  labelText: 'Reason / admin note',
                                  border: OutlineInputBorder()),
                              validator: (v) => (v?.trim().length ?? 0) < 3
                                  ? 'Enter at least 3 characters.'
                                  : null),
                          const Text(
                              'The original attendance and occurrence totals stay unchanged. Each saved review is retained in history.'),
                          if (_error != null)
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                        ])))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save review'))
        ],
      ));
}
