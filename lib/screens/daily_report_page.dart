import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_service.dart';
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
      'air_conditioner',
      'maintenance_total',
      'working_condition',
      'service_repair',
      'maintenance_report',
      'report_crew',
      'recommendation',
      'reported_by',
      'branch_stamp',
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
  DateTime date = DateTime.now();
  bool saving = false;
  late Future<List<Map<String, dynamic>>> reports;

  @override
  void initState() {
    super.initState();
    reports = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => widget.adminMode
      ? SupabaseService.getDailyReports()
      : SupabaseService.getDailyReports(branchId: widget.branchId);

  @override
  void dispose() {
    for (final controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || saving) return;
    setState(() => saving = true);
    try {
      await SupabaseService.submitDailyReport({
        'branch_id': widget.branchId,
        'report_date': DateFormat('yyyy-MM-dd').format(date),
        for (final key in [
          'attendance',
          'unpaid_leave',
          'weekly_leave',
          'annual_leave',
          'air_conditioner',
          'maintenance_total',
          'working_condition',
          'service_repair'
        ])
          key: int.tryParse(c[key]!.text.trim()) ?? 0,
        'maintenance_report': c['maintenance_report']!.text.trim(),
        'report_crew': c['report_crew']!.text.trim(),
        'recommendation': c['recommendation']!.text.trim(),
        'reported_by': c['reported_by']!.text.trim(),
        'branch_stamp': c['branch_stamp']!.text.trim(),
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
            key: int.tryParse(c['ors_$key']!.text.trim()) ?? 0,
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

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (!widget.adminMode) _reportForm(),
          if (!widget.adminMode) const SizedBox(height: 24),
          Text(widget.adminMode ? 'Submitted Daily Reports' : 'Report History',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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
                  Image.asset('assets/hasani_books_logo.jpg',
                      height: 65, alignment: Alignment.centerLeft),
                  const Text('MAINTENANCE DAILY REPORT',
                      style: TextStyle(
                          color: blue,
                          fontSize: 21,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: Text(
                            'DATE  ${DateFormat('dd/MM/yyyy').format(date)}')),
                    Expanded(
                        child: Text('DAY  ${DateFormat('EEEE').format(date)}')),
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
                  _fourFields([
                    'air_conditioner',
                    'maintenance_total',
                    'working_condition',
                    'service_repair'
                  ], [
                    'Air Conditioner',
                    'Total',
                    'Working Condition',
                    'To Service / Repair'
                  ]),
                  _bar('MAINTENANCE / ELECTRICAL / EQUIPMENT'),
                  _area('maintenance_report', 'REPORT', required: true),
                  _bar('ORSANCO'),
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
                    Expanded(child: _field('branch_stamp', 'BRANCH STAMP')),
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
                child: _field(keys[i], labels[i], number: true),
              ),
            ),
          ),
        ),
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

  Widget _reportTile(Map<String, dynamic> row) => Card(
        child: ListTile(
          leading: const CircleAvatar(
              backgroundColor: blue,
              child: Icon(Icons.assignment_outlined, color: Colors.white)),
          title: Text('${row['branch_id']} · ${row['report_date']}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
              'Reported by ${row['reported_by']}\n${row['maintenance_report'] ?? ''}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          trailing: widget.adminMode
              ? IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () => _review(row))
              : null,
        ),
      );

  Future<void> _review(Map<String, dynamic> row) async {
    final comment = TextEditingController(text: row['hq_comment']?.toString());
    final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('${row['branch_id']} · ${row['report_date']}'),
              content: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(
                        'Maintenance / Equipment\n${row['maintenance_report'] ?? '-'}'),
                    const SizedBox(height: 12),
                    Text('Report Crew\n${row['report_crew'] ?? '-'}'),
                    const SizedBox(height: 12),
                    Text(
                        'Recommendation / Demand / Sales\n${row['recommendation'] ?? '-'}'),
                    const SizedBox(height: 16),
                    TextField(
                        controller: comment,
                        minLines: 3,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(labelText: 'COMMENT BY HQ')),
                  ])),
              actions: [
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
          reviewer: AppService.instance.currentUser?.displayName ??
              AppService.instance.currentUser?.username ??
              'Admin');
      if (mounted) setState(() => reports = _load());
    }
    comment.dispose();
  }
}
