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
  final _search = TextEditingController();
  String _filter = 'all';
  Map<String, dynamic>? _selected;
  @override
  void initState() {
    super.initState();
    _month = widget.month;
    _branch = widget.initialBranchId;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

  static const _gold = Color(0xFFB58A35),
      _ink = Color(0xFF29251F),
      _muted = Color(0xFF756F66),
      _line = Color(0xFFE8E0D3),
      _canvas = Color(0xFFF7F4ED);

  BoxDecoration _card([Color color = Colors.white]) => BoxDecoration(
      color: color,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12)]);

  Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)));

  String _severityName(int count) => count >= 7
      ? 'Critical'
      : count >= 5
          ? 'Warning'
          : 'Watch';
  String _status(Map<String, dynamic> row) {
    final events = row['events'] as List? ?? [];
    return events.isNotEmpty &&
            events.every((e) => (e as Map)['review']?['status'] == 'approved')
        ? 'Approved'
        : 'Pending review';
  }

  Widget _summary(List<Map<String, dynamic>> reports) {
    final approved = reports.where((r) => _status(r) == 'Approved').length;
    final metrics = [
      (
        'Employees flagged',
        reports.length,
        'Monthly exceptions',
        Icons.people_outline,
        _gold
      ),
      (
        'Critical cases',
        reports.where((r) => (r['count'] as num) >= 7).length,
        '7+ total occurrences',
        Icons.warning_amber,
        const Color(0xFFB9473D)
      ),
      (
        'Pending review',
        reports.length - approved,
        'Requires attention',
        Icons.hourglass_top,
        const Color(0xFFD27A12)
      ),
      (
        'Approved',
        approved,
        'Review completed',
        Icons.check_circle_outline,
        const Color(0xFF258761)
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth < 650 ? 2 : 4;
        return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metrics
                .map((m) => SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 10) / columns,
                      child: Container(
                          decoration: _card(),
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: m.$5.withValues(alpha: .1),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Icon(m.$4, color: m.$5, size: 19)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(m.$1,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 11, color: _muted)),
                                      Text('${m.$2}',
                                          style: const TextStyle(
                                              fontSize: 23,
                                              fontWeight: FontWeight.w800)),
                                      Text(m.$3,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 9, color: _muted)),
                                    ]))
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
    final all = _filtered(data['reports']);
    final query = _search.text.trim().toLowerCase();
    final reports = all.where((r) {
      final count = (r['count'] as num).toInt();
      final severity = _filter == 'all' ||
          _filter == 'watch' && count <= 4 ||
          _filter == 'warning' && count >= 5 && count <= 6 ||
          _filter == 'critical' && count >= 7;
      return severity &&
          (query.isEmpty ||
              '${r['name']} ${r['employee_id']} ${_branchName(r['branch_id'])}'
                  .toLowerCase()
                  .contains(query));
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Late Report',
          style: TextStyle(
              fontSize: 25, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 3),
      const Text('Monthly attendance exceptions and review status',
          style: TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(height: 15),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Container(
            height: 42,
            decoration: _card(),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => setState(() {
                        _month = DateTime(_month.year, _month.month - 1);
                        _load();
                      }),
                  icon: const Icon(Icons.chevron_left, size: 18)),
              const Icon(Icons.calendar_today_outlined, size: 14, color: _gold),
              const SizedBox(width: 7),
              Text(DateFormat('MMMM yyyy').format(_month),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              IconButton(
                  tooltip: 'Next month',
                  onPressed: () => setState(() {
                        _month = DateTime(_month.year, _month.month + 1);
                        _load();
                      }),
                  icon: const Icon(Icons.chevron_right, size: 18)),
            ])),
        SizedBox(
            width: 180,
            height: 42,
            child: Container(
                decoration: _card(),
                child: DropdownButtonFormField<String>(
                    initialValue: _branch ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.account_tree_outlined, size: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('All branches')),
                      ...widget.branches.map((b) => DropdownMenuItem(
                          value: '${b['id'] ?? b['branch_id']}',
                          child: Text('${b['name'] ?? b['branch_name']}',
                              overflow: TextOverflow.ellipsis)))
                    ],
                    onChanged: (v) => setState(() {
                          _branch = v == '' ? null : v;
                          _selected = null;
                        })))),
        OutlinedButton.icon(
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh')),
        OutlinedButton.icon(
            onPressed: _exporting ? null : () => _export('pdf', data),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: const Text('Export PDF')),
        OutlinedButton.icon(
            onPressed: _exporting ? null : () => _export('xlsx', data),
            icon: const Icon(Icons.table_view_outlined, size: 16),
            label: const Text('Export Excel')),
      ]),
      const SizedBox(height: 18),
      _summary(all),
      const SizedBox(height: 12),
      _filterBar(all),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 1050;
        final list = _reportTable(reports);
        if (!wide || _selected == null) {
          return Column(children: [
            list,
            if (_selected != null) ...[
              const SizedBox(height: 12),
              _details(_selected!)
            ]
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: list),
          const SizedBox(width: 12),
          SizedBox(width: 390, child: _details(_selected!))
        ]);
      }),
    ]);
  }

  Widget _filterBar(List<Map<String, dynamic>> rows) => Container(
      padding: const EdgeInsets.all(9),
      decoration: _card(),
      child: LayoutBuilder(builder: (context, box) {
        int n(String f) => rows.where((r) {
              final c = (r['count'] as num).toInt();
              return f == 'all' ||
                  f == 'watch' && c <= 4 ||
                  f == 'warning' && c >= 5 && c <= 6 ||
                  f == 'critical' && c >= 7;
            }).length;
        final chips = Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              ('all', 'All'),
              ('watch', 'Watch 3–4'),
              ('warning', 'Warning 5–6'),
              ('critical', 'Critical 7+')
            ]
                .map((f) => InkWell(
                    onTap: () => setState(() => _filter = f.$1),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 9),
                        decoration: BoxDecoration(
                            color: _filter == f.$1 ? _gold : Colors.transparent,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${f.$2} (${n(f.$1)})',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color:
                                    _filter == f.$1 ? Colors.white : _muted)))))
                .toList());
        final search = SizedBox(
            width: box.maxWidth < 700 ? box.maxWidth : 275,
            height: 38,
            child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    hintText: 'Search employee, staff ID or branch',
                    prefixIcon: const Icon(Icons.search, size: 17),
                    filled: true,
                    fillColor: _canvas,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none))));
        return box.maxWidth < 700
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [chips, const SizedBox(height: 8), search])
            : Row(children: [Expanded(child: chips), search]);
      }));

  Widget _reportTable(List<Map<String, dynamic>> rows) => Container(
      decoration: _card(),
      clipBehavior: Clip.antiAlias,
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                  'No employees with 3 or more occurrences in this period.'))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                  headingTextStyle: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700, color: _muted),
                  dataRowMinHeight: 58,
                  dataRowMaxHeight: 58,
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('EMPLOYEE')),
                    DataColumn(label: Text('BRANCH')),
                    DataColumn(label: Text('LATE ARRIVALS')),
                    DataColumn(label: Text('BREAK EXCEEDED')),
                    DataColumn(label: Text('TOTAL')),
                    DataColumn(label: Text('SEVERITY')),
                    DataColumn(label: Text('REVIEW STATUS')),
                    DataColumn(label: Text('ACTION'))
                  ],
                  rows: rows.map((r) {
                    final c = (r['count'] as num).toInt();
                    final color = _severity(c);
                    return DataRow(
                        color: WidgetStatePropertyAll(
                            _selected?['employee_id'] == r['employee_id']
                                ? const Color(0xFFF9F1DF)
                                : Colors.transparent),
                        cells: [
                          DataCell(
                              Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${r['name']}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                    Text('${r['employee_id']}',
                                        style: const TextStyle(
                                            fontSize: 9, color: _muted))
                                  ]),
                              onTap: () => setState(() => _selected = r)),
                          DataCell(Text(_branchName(r['branch_id']),
                              style: const TextStyle(fontSize: 10))),
                          DataCell(Text('${r['arrival_count']}')),
                          DataCell(Text('${r['break_count']}')),
                          DataCell(Text('$c',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                          DataCell(_pill(_severityName(c), color)),
                          DataCell(_pill(
                              _status(r),
                              _status(r) == 'Approved'
                                  ? const Color(0xFF258761)
                                  : _gold)),
                          DataCell(IconButton(
                              tooltip: 'View details',
                              onPressed: () => setState(() => _selected = r),
                              icon: const Icon(Icons.arrow_forward_ios,
                                  size: 13, color: _gold)))
                        ]);
                  }).toList())));

  Widget _details(Map<String, dynamic> person) {
    final events = person['events'] as List? ?? [];
    final c = (person['count'] as num).toInt();
    return Container(
        decoration: _card(),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8EFDC),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('${person['name']}'.trim().substring(0, 1),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: _gold))),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${person['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                          '${person['employee_id']}  |  ${_branchName(person['branch_id'])}',
                          style: const TextStyle(fontSize: 9, color: _muted))
                    ])),
                IconButton(
                    tooltip: 'Close details',
                    onPressed: () => setState(() => _selected = null),
                    icon: const Icon(Icons.close, size: 18))
              ])),
          const Divider(height: 1, color: _line),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Summary (month)',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _metric(
                              'Late arrivals', '${person['arrival_count']}'),
                          _metric('Break exceeded', '${person['break_count']}'),
                          _metric('Total', '$c'),
                          _pill(_severityName(c), _severity(c))
                        ]),
                    const SizedBox(height: 16),
                    const Text('Attendance details',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (events.isEmpty)
                      const Text('No recorded occurrences.',
                          style: TextStyle(color: _muted)),
                    ...events.map((e) => _event(person, e))
                  ]))
        ]));
  }

  Widget _metric(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 8, color: _muted)),
        Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _canvas,
        appBar: widget.embedded
            ? null
            : AppBar(
                backgroundColor: Colors.white,
                foregroundColor: _ink,
                elevation: 0,
                title: const Text('Late Report',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
