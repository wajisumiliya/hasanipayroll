import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../services/app_service.dart';
import '../services/daily_report_pdf_service.dart';
import 'supabase_service.dart';

class DailyReportPage extends StatefulWidget {
  final bool adminMode;
  final String? branchId;

  const DailyReportPage.branch({super.key, required this.branchId})
      : adminMode = false;
  const DailyReportPage.admin({super.key})
      : adminMode = true,
        branchId = null;

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  static const blue = Color(0xFF263B97);
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> c = {
    for (final key in [
      'attendance',
      'unpaid_leave',
      'weekly_leave',
      'annual_leave',
      'maintenance_total',
      'working_condition',
      'service_repair',
      'maintenance_report',
      'report_crew',
      'recommendation',
      'reported_by',
      'ors_agama',
      'ors_sk',
      'ors_sm',
      'ors_umum',
      'ors_novel',
      'ors_alat_tulis',
      'ors_tadika',
      'ors_kanak',
      'ors_quran',
      'ors_others'
    ])
      key: TextEditingController(),
  };
  DateTime? date;
  DateTime? reportFilterDate;
  bool saving = false;
  bool _unlocked = false;
  bool _unlocking = false;
  late Future<List<Map<String, dynamic>>> reports;

  @override
  void initState() {
    super.initState();
    reports = _load();
    if (!widget.adminMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  Future<List<Map<String, dynamic>>> _load() => SupabaseService.getDailyReports(
        branchId: widget.adminMode ? null : widget.branchId,
        reportDate: reportFilterDate,
      );

  @override
  void dispose() {
    for (final controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || saving) return;
    if (date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the report date.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await SupabaseService.submitDailyReport({
        'branch_id': widget.branchId,
        'report_date': DateFormat('yyyy-MM-dd').format(date!),
        for (final key in [
          'attendance',
          'unpaid_leave',
          'weekly_leave',
          'annual_leave',
          'maintenance_total',
          'working_condition',
          'service_repair'
        ])
          key: c[key]!.text.trim(),
        'air_conditioner': 'Air Conditioner',
        'maintenance_report': c['maintenance_report']!.text.trim(),
        'report_crew': c['report_crew']!.text.trim(),
        'recommendation': c['recommendation']!.text.trim(),
        'reported_by': c['reported_by']!.text.trim(),
        // The branch stamp is created from the submitting branch, not typed.
        'branch_stamp': _stampValue(widget.branchId),
        'orsanco': {
          for (final key in [
            'agama',
            'sk',
            'sm',
            'umum',
            'novel',
            'alat_tulis',
            'tadika',
            'kanak',
            'quran',
            'others'
          ])
            key: c['ors_$key']!.text.trim(),
        },
      });
      if (!mounted) return;
      setState(() => reports = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily report submitted to admin.')),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to submit report: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickReportDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null && mounted) setState(() => date = picked);
  }

  Future<void> _pickHistoryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: reportFilterDate ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: 'SELECT REPORT DATE',
    );
    if (picked != null && mounted) {
      setState(() {
        reportFilterDate = picked;
        reports = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.adminMode && !_unlocked) {
      return Center(
        child: FilledButton.icon(
          onPressed: _unlocking ? null : _unlock,
          icon: const Icon(Icons.lock_outline),
          label: Text(_unlocking ? 'Checking PIN...' : 'Unlock Daily Report'),
        ),
      );
    }
    return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (!widget.adminMode) _reportForm(),
          if (!widget.adminMode) const SizedBox(height: 24),
          Text(widget.adminMode ? 'Submitted Daily Reports' : 'Report History',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _historyDateFilter(),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: reports,
            builder: (_, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final rows = snapshot.data!;
              if (rows.isEmpty)
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Text('No daily reports yet.')));
              return Column(children: rows.map(_reportTile).toList());
            },
          ),
        ],
      );
  }

  Future<void> _unlock() async {
    if (_unlocking || _unlocked || !mounted) return;
    setState(() => _unlocking = true);
    try {
      final pin = await _requestPin(
        title: 'Daily Report Security',
        label: 'Enter 4-digit PIN',
      );
      if (pin == null || !mounted) return;
      final result = await SupabaseService.verifyDailyReportPin(pin);
      if (result['valid'] != true) {
        _message('Incorrect daily report PIN.');
        return;
      }
      if (result['must_change'] == true) {
        final newPin = await _requestNewPin();
        if (newPin == null || !mounted) return;
        await SupabaseService.changeDailyReportPin(
          currentPin: pin,
          newPin: newPin,
        );
      }
      if (mounted) setState(() => _unlocked = true);
    } catch (_) {
      _message('Unable to unlock Daily Report. Please try again.');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<String?> _requestPin({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.lock_outline, color: blue),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(labelText: label, counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (RegExp(r'^\d{4}$').hasMatch(value)) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _requestNewPin() async {
    final pin = await _requestPin(
      title: 'Change Default PIN',
      label: 'Create a new 4-digit PIN',
    );
    if (pin == null) return null;
    if (pin == '2026') {
      _message('Your new PIN must be different from 2026.');
      return null;
    }
    final confirmation = await _requestPin(
      title: 'Confirm New PIN',
      label: 'Enter the new PIN again',
    );
    if (confirmation != pin) {
      _message('The two PINs do not match.');
      return null;
    }
    return pin;
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _historyDateFilter() => Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFC8D3F4)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(children: [
          IconButton(
            tooltip: 'Choose report date',
            onPressed: _pickHistoryDate,
            icon: const Icon(Icons.calendar_month_outlined, color: blue),
          ),
          Expanded(
            child: Text(
              reportFilterDate == null
                  ? 'All report dates - choose year, month and date'
                  : 'Reports for ${DateFormat('dd MMMM yyyy').format(reportFilterDate!)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (reportFilterDate != null)
            IconButton(
              tooltip: 'Show all dates',
              onPressed: () => setState(() {
                reportFilterDate = null;
                reports = _load();
              }),
              icon: const Icon(Icons.clear),
            ),
        ]),
      );

  Widget _reportForm() => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white, border: Border.all(color: blue, width: 2)),
          child: Form(
            key: _formKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Image.asset(
                          'assets/hasani_books_logo.jpg',
                          height: 65,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 145,
                        child: _branchStamp(
                          widget.branchId,
                          date,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  const Text('MAINTENANCE DAILY REPORT',
                      style: TextStyle(
                          color: blue,
                          fontSize: 21,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickReportDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(date == null
                            ? 'SELECT REPORT DATE'
                            : 'DATE  ${DateFormat('dd/MM/yyyy').format(date!)}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        date == null
                            ? 'DAY  -'
                            : 'DAY  ${DateFormat('EEEE').format(date!)}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _fourFields([
                    'attendance',
                    'unpaid_leave',
                    'weekly_leave',
                    'annual_leave'
                  ], [
                    'Attendance',
                    'Unpaid Leave',
                    'Weekly Leave',
                    'Annual Leave'
                  ]),
                  _bar('MAINTENANCE'),
                  _maintenanceFields(),
                  _bar('MAINTENANCE / ELECTRICAL / EQUIPMENT'),
                  _area('maintenance_report', 'REPORT', required: true),
                  _bar('ORSANO'),
                  _fourFields(
                    [
                      'ors_agama',
                      'ors_sk',
                      'ors_sm',
                      'ors_umum',
                      'ors_novel',
                      'ors_alat_tulis',
                      'ors_tadika',
                      'ors_kanak',
                      'ors_quran',
                      'ors_others'
                    ],
                    [
                      'Agama',
                      'S.K',
                      'S.M',
                      'Umum',
                      'Novel',
                      'Alat Tulis',
                      'Tadika',
                      'Kanak Kanak',
                      'Quran',
                      'Others'
                    ],
                  ),
                  _bar('REPORT CREW'),
                  _area('report_crew', 'CREW', required: true),
                  _bar('RECOMMENDATION / DEMAND / SALES'),
                  _area('recommendation', 'RECOMMENDATION', required: true),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _field('reported_by', 'REPORTED BY',
                            required: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _branchStamp(widget.branchId, date)),
                  ]),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                      onPressed: saving ? null : _submit,
                      icon: const Icon(Icons.send),
                      label: Text(
                          saving ? 'Submitting...' : 'Submit Daily Report')),
                ]),
          ),
        ),
      );

  Widget _bar(String text) => Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(5),
      color: blue,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)));
  Widget _fourFields(List<String> keys, List<String> labels) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (_, box) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              keys.length,
              (i) => SizedBox(
                width: box.maxWidth > 600
                    ? (box.maxWidth - 24) / 4
                    : (box.maxWidth - 8) / 2,
                child: _field(keys[i], labels[i]),
              ),
            ),
          ),
        ),
      );

  Widget _maintenanceFields() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (_, box) {
            final width = box.maxWidth > 600
                ? (box.maxWidth - 24) / 4
                : (box.maxWidth - 8) / 2;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              SizedBox(
                  width: width, child: _categoryHeading('Air Conditioner')),
              SizedBox(
                  width: width, child: _field('maintenance_total', 'Total')),
              SizedBox(
                  width: width,
                  child: _field('working_condition', 'Working Condition')),
              SizedBox(
                  width: width,
                  child: _field('service_repair', 'To Service / Repair')),
            ]);
          },
        ),
      );

  Widget _categoryHeading(String text) => Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6FF),
          border: Border.all(color: const Color(0xFFC8D3F4)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text,
            style: const TextStyle(color: blue, fontWeight: FontWeight.w800)),
      );
  Widget _field(String key, String label,
          {bool number = false, bool required = false}) =>
      TextFormField(
          controller: c[key],
          keyboardType: number ? TextInputType.number : null,
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null,
          decoration: InputDecoration(labelText: label, isDense: true));
  Widget _area(String key, String label, {bool required = false}) => Padding(
      padding: const EdgeInsets.all(8),
      child: TextFormField(
          controller: c[key],
          minLines: 3,
          maxLines: 5,
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null,
          decoration: InputDecoration(labelText: label)));

  String _stampValue(String? branchId) {
    final branch = branchId?.trim();
    return 'HASANI BOOKS | BRANCH: ${branch == null || branch.isEmpty ? '-' : branch}';
  }

  String? _branchStampAsset(dynamic branchId) {
    final name = branchId?.toString().trim().toUpperCase();
    return switch (name) {
      'ALOR SETAR' => 'assets/branch_stamps/ALOR SETAR.png',
      'AMANJAYA' => 'assets/branch_stamps/AMANJAYA.png',
      'ASTANA' => 'assets/branch_stamps/ASTANA.png',
      'GURUN' => 'assets/branch_stamps/GURUN.png',
      'JITRA' => 'assets/branch_stamps/JITRA.png',
      'KULIM' => 'assets/branch_stamps/KULIM.png',
      'LANGKAWI' => 'assets/branch_stamps/LANGKAWI.png',
      'PRAI' || 'PERAI' => 'assets/branch_stamps/PERAI.png',
      _ => null,
    };
  }

  String? _branchNumber(dynamic branchId) {
    final name = branchId?.toString().trim().toUpperCase();
    return switch (name) {
      'JITRA' => '01/08',
      'ASTANA' => '02/08',
      'ALOR SETAR' => '03/08',
      'GURUN' => '04/08',
      'AMANJAYA' => '05/08',
      'PRAI' || 'PERAI' => '06/08',
      'KULIM' => '07/08',
      'LANGKAWI' => '08/08',
      _ => null,
    };
  }

  String? _branchStampCode(dynamic branchId, dynamic reportDate) {
    final parsedDate = reportDate is DateTime
        ? reportDate
        : DateTime.tryParse(reportDate?.toString() ?? '');
    final branchNumber = _branchNumber(branchId);
    if (parsedDate == null || branchNumber == null) return null;
    return '${DateFormat('ddMM').format(parsedDate)} / '
        '${branchNumber.replaceFirst('/', ' / ')}';
  }

  Widget _branchStamp(
    dynamic branchId,
    dynamic reportDate, {
    bool compact = false,
  }) {
    final branch = branchId?.toString().trim();
    final label = branch == null || branch.isEmpty ? '-' : branch.toUpperCase();
    final stampAsset = _branchStampAsset(branchId);
    final stampCode = _branchStampCode(branchId, reportDate);

    if (stampAsset != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: compact ? 48 : 82,
            child: Image.asset(
              stampAsset,
              fit: BoxFit.contain,
              semanticLabel: '$label branch stamp',
            ),
          ),
          if (stampCode != null) ...[
            SizedBox(height: compact ? 2 : 4),
            Text(
              stampCode,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: blue,
                fontSize: compact ? 8 : 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        border: Border.all(color: blue, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('HASANI',
              style: TextStyle(
                  color: blue, fontSize: 14, fontWeight: FontWeight.w900)),
          const Text('BOOKS',
              style: TextStyle(
                  color: Color(0xFFE51B2A),
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          const Text('BRANCH STAMP',
              style: TextStyle(
                  color: blue, fontSize: 8, fontWeight: FontWeight.w800)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: blue, fontSize: 10, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  Widget _reportTile(Map<String, dynamic> row) => Card(
        child: ListTile(
          leading: const CircleAvatar(
              backgroundColor: blue,
              child: Icon(Icons.assignment_outlined, color: Colors.white)),
          title: Text('${row['branch_id']} · ${row['report_date']}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
              'Submitted ${_malaysiaTimestamp(row['submitted_at'])}\nReported by ${row['reported_by']}\n${row['maintenance_report'] ?? ''}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          trailing: widget.adminMode
              ? IconButton(
                  tooltip: 'Review report',
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () => _review(row))
              : Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      tooltip: 'View report',
                      icon: const Icon(Icons.visibility_outlined),
                      onPressed: () => _viewReport(row),
                    ),
                    IconButton(
                      tooltip: 'Print PDF',
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      onPressed: () => _printReport(row),
                    ),
                  ],
                ),
        ),
      );

  Future<void> _viewReport(Map<String, dynamic> row) async {
    final comment = TextEditingController(text: row['hq_comment']?.toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${row['branch_id']} · ${row['report_date']}'),
        content: SizedBox(
          width: 850,
          height: MediaQuery.sizeOf(ctx).height * .68,
          child: SingleChildScrollView(
            child: _adminReportForm(row, comment, commentReadOnly: true),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => _printReport(row),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Print PDF'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    comment.dispose();
  }

  Future<void> _review(Map<String, dynamic> row) async {
    final comment = TextEditingController(text: row['hq_comment']?.toString());
    final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('${row['branch_id']} · ${row['report_date']}'),
              content: SizedBox(
                width: 850,
                height: MediaQuery.sizeOf(ctx).height * .68,
                child: SingleChildScrollView(
                  child: _adminReportForm(row, comment),
                ),
              ),
              actions: [
                OutlinedButton.icon(
                    onPressed: () => _printReport(row),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Print PDF')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Close')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save Review'))
              ],
            ));
    if (save == true) {
      await SupabaseService.reviewDailyReport(
          id: row['id'].toString(),
          comment: comment.text,
          reviewer: _dailyReportReviewerName());
      if (mounted) setState(() => reports = _load());
    }
    comment.dispose();
  }

  Future<void> _printReport(Map<String, dynamic> row) async {
    try {
      final bytes = await DailyReportPdfService.build(row);
      await Printing.layoutPdf(
        name:
            'daily_report_${row['branch_id'] ?? 'branch'}_${row['report_date'] ?? 'report'}.pdf',
        format: PdfPageFormat.a4,
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to create daily report PDF: $error')),
        );
      }
    }
  }

  String _malaysiaTimestamp(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '-';
    final malaysia = parsed.toUtc().add(const Duration(hours: 8));
    return '${DateFormat('dd/MM/yyyy hh:mm a').format(malaysia)} MYT';
  }

  String _dailyReportReviewerName() {
    final user = AppService.instance.currentUser;
    final name = user?.displayName?.trim() ?? '';
    final username = (user?.username ?? '').trim();
    if (name.isNotEmpty &&
        !name.contains('@') &&
        name.toLowerCase() != 'admin') {
      return name;
    }
    if (username.isNotEmpty && username.toLowerCase() != 'admin') {
      return username;
    }
    return 'Nur Muhammad Faizal';
  }

  Widget _adminReportForm(
    Map<String, dynamic> row,
    TextEditingController comment, {
    bool commentReadOnly = false,
  }) {
    final orsanco = row['orsanco'] is Map
        ? Map<String, dynamic>.from(row['orsanco'] as Map)
        : <String, dynamic>{};
    final reportDate = DateTime.tryParse(row['report_date']?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: blue, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Image.asset('assets/hasani_books_logo.jpg',
                height: 65, alignment: Alignment.centerLeft),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 145,
            child: _branchStamp(
              row['branch_id'],
              row['report_date'],
              compact: true,
            ),
          ),
        ]),
        const Text('MAINTENANCE DAILY REPORT',
            style: TextStyle(
                color: blue, fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _readFour([
          (
            'DATE',
            reportDate == null
                ? '-'
                : DateFormat('dd/MM/yyyy').format(reportDate)
          ),
          (
            'DAY',
            reportDate == null ? '-' : DateFormat('EEEE').format(reportDate)
          ),
          ('SUBMITTED AT', _malaysiaTimestamp(row['submitted_at'])),
          ('REVIEWED AT', _malaysiaTimestamp(row['reviewed_at'])),
        ]),
        _readFour([
          ('Attendance', row['attendance']),
          ('Unpaid Leave', row['unpaid_leave']),
          ('Weekly Leave', row['weekly_leave']),
          ('Annual Leave', row['annual_leave']),
        ]),
        _bar('MAINTENANCE'),
        _readFour([
          ('Air Conditioner', row['air_conditioner']),
          ('Total', row['maintenance_total']),
          ('Working Condition', row['working_condition']),
          ('To Service / Repair', row['service_repair']),
        ]),
        _bar('MAINTENANCE / ELECTRICAL / EQUIPMENT'),
        _readArea('REPORT', row['maintenance_report']),
        _bar('ORSANO'),
        _readFour([
          ('Agama', orsanco['agama']),
          ('S.K', orsanco['sk']),
          ('S.M', orsanco['sm']),
          ('Umum', orsanco['umum']),
          ('Novel', orsanco['novel']),
          ('Alat Tulis', orsanco['alat_tulis']),
          ('Tadika', orsanco['tadika']),
          ('Kanak Kanak', orsanco['kanak']),
          ('Quran', orsanco['quran']),
          ('Others', orsanco['others']),
        ]),
        _bar('REPORT CREW'),
        _readArea('CREW', row['report_crew']),
        _bar('RECOMMENDATION / DEMAND / SALES'),
        _readArea('RECOMMENDATION', row['recommendation']),
        Row(children: [
          Expanded(child: _readValue('REPORTED BY', row['reported_by'])),
          const SizedBox(width: 8),
          Expanded(child: _branchStamp(row['branch_id'], row['report_date'])),
        ]),
        _bar('COMMENT BY HQ'),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: comment,
            readOnly: commentReadOnly,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText:
                  commentReadOnly ? 'No HQ comment yet' : 'Enter HQ comment',
            ),
          ),
        ),
        if (row['reviewed_at'] != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
                'Reviewed by ${row['reviewed_by'] ?? '-'} · ${_malaysiaTimestamp(row['reviewed_at'])}'),
          ),
      ]),
    );
  }

  Widget _readFour(List<(String, dynamic)> values) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (_, box) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map((value) => SizedBox(
                      width: box.maxWidth > 600
                          ? (box.maxWidth - 24) / 4
                          : (box.maxWidth - 8) / 2,
                      child: _readValue(value.$1, value.$2),
                    ))
                .toList(),
          ),
        ),
      );

  Widget _readValue(String label, dynamic value) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6FF),
          border: Border.all(color: const Color(0xFFC8D3F4)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: blue, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value == null || value.toString().trim().isEmpty
              ? '-'
              : value.toString()),
        ]),
      );

  Widget _readArea(String label, dynamic value) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 90),
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFC8D3F4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: blue, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(value == null || value.toString().trim().isEmpty
              ? '-'
              : value.toString()),
        ]),
      );
}
