import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ea_form_pdf_service.dart';
import '../services/notification_service.dart';
import 'supabase_service.dart';

class EaFormsPage extends StatefulWidget {
  const EaFormsPage.admin({super.key})
      : employeeId = null,
        isAdmin = true;

  const EaFormsPage.employee({super.key, required this.employeeId})
      : isAdmin = false;

  final String? employeeId;
  final bool isAdmin;

  @override
  State<EaFormsPage> createState() => _EaFormsPageState();
}

class _EaFormsPageState extends State<EaFormsPage> {
  int _year = DateTime.now().year - 1;
  DateTime _generatedDate = DateUtils.dateOnly(DateTime.now());
  bool _busy = false;
  String _search = '';
  Future<List<Map<String, dynamic>>>? _future;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeReloadTimer;

  @override
  void initState() {
    super.initState();
    _reload();
    _subscribeToEaFormChanges();
  }

  void _subscribeToEaFormChanges() {
    final channel = SupabaseService.client.channel(
      'ea-forms-${widget.isAdmin ? 'admin' : widget.employeeId}-$hashCode',
    );
    if (widget.isAdmin) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'employee_ea_forms',
        callback: (_) => _scheduleRealtimeReload(),
      );
    } else {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'employee_ea_forms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'employee_id',
          value: widget.employeeId!,
        ),
        callback: (_) => _scheduleRealtimeReload(),
      );
    }
    _realtimeChannel = channel..subscribe();
  }

  void _scheduleRealtimeReload() {
    _realtimeReloadTimer?.cancel();
    _realtimeReloadTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _realtimeReloadTimer?.cancel();
    final channel = _realtimeChannel;
    if (channel != null) {
      SupabaseService.client.removeChannel(channel);
    }
    super.dispose();
  }

  void _reload() {
    _future = _load();
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _load() async {
    var query = SupabaseService.client
        .from('employee_ea_forms')
        .select()
        .eq('tax_year', _year);
    if (!widget.isAdmin) query = query.eq('employee_id', widget.employeeId!);
    final rows = await query.order('employee_id');
    return List<Map<String, dynamic>>.from(rows);
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  double _money(double value) => (value * 100).roundToDouble() / 100;

  Future<void> _selectGeneratedDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _generatedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select EA generated date',
    );
    if (selected == null || !mounted) return;
    setState(() => _generatedDate = DateUtils.dateOnly(selected));
  }

  Future<void> _generateAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final results = await Future.wait([
        SupabaseService.client.from('employees').select(),
        SupabaseService.getPayrollForYear(_year),
      ]);
      final employees = List<Map<String, dynamic>>.from(results[0]);
      final payroll = List<Map<String, dynamic>>.from(results[1]);
      final rows = <Map<String, dynamic>>[];
      for (final employee in employees) {
        final id = '${employee['employee_id'] ?? ''}'.trim();
        if (id.isEmpty) continue;
        final records = payroll
            .where(
              (row) =>
                  '${row['employee_id']}'.trim().toUpperCase() ==
                  id.toUpperCase(),
            )
            .toList();
        if (records.isEmpty) continue;
        final monthlyBreakdown = <Map<String, dynamic>>[];
        final monthsIncluded = <int>{};
        for (final record in records) {
          final period = DateTime.tryParse('${record['period']}');
          if (period == null || period.year != _year) continue;
          monthsIncluded.add(period.month);
          final salaryWages = _money(
            _number(record['basic_salary']) +
                _number(record['fw_salary']) +
                _number(record['overtime']) +
                _number(record['cuti_umum']) -
                _number(record['late_deduction']) -
                _number(record['unpaid_deduction']),
          );
          final allowances = _money(
            _number(record['elaun_kedatangan']) +
                _number(record['elaun_perkhidmatan']) +
                _number(record['elaun_kerajinan']) +
                _number(record['elaun_makanan']),
          );
          monthlyBreakdown.add({
            'month': period.month,
            'period': '$_year-${period.month.toString().padLeft(2, '0')}',
            'salary_wages': salaryWages,
            'commission_bonus': 0.0,
            'allowances': allowances,
            'gross_income': _money(salaryWages + allowances),
            'pcb': _money(_number(record['pcb'])),
            'zakat': _money(_number(record['zakat'])),
            'epf_employee': _money(_number(record['epf_employee'])),
            'socso_employee': _money(_number(record['socso_employee'])),
            'eis_employee': _money(_number(record['eis_employee'])),
          });
        }
        if (monthlyBreakdown.isEmpty) continue;

        double annual(String field) => _money(
              monthlyBreakdown.fold(
                0,
                (total, month) => total + _number(month[field]),
              ),
            );
        final salaryWages = annual('salary_wages');
        final commissionBonus = annual('commission_bonus');
        final allowances = annual('allowances');
        final employeeSocso = annual('socso_employee');
        final employeeEis = annual('eis_employee');
        rows.add({
          'employee_id': id,
          'tax_year': _year,
          'generated_by': SupabaseService.client.auth.currentUser?.id,
          'generated_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'form_data': {
            'tax_year': _year,
            'employer_name': 'HASANI BOOKS EDAR SDN BHD',
            'employer_no': '',
            'employer_address': '',
            'employee_id': id,
            'employee_name': employee['name'] ?? '',
            'designation': employee['designation'] ?? '',
            'identification_no': employee['new_ic_no'] ?? '',
            'income_tax_no': employee['income_tax_no'] ?? '',
            'epf_no': employee['epf_no'] ?? '',
            'socso_no': employee['socso_no'] ?? '',
            'employment_start': employee['joining_date'] ?? '',
            'employment_end': '',
            'eligible_children': '',
            'salary_wages': salaryWages,
            'commission_bonus': commissionBonus,
            'allowances_overtime': allowances,
            'benefits_in_kind': 0,
            'living_accommodation': 0,
            'pension_refund': 0,
            'compensation': 0,
            'total_employment_income':
                _money(salaryWages + commissionBonus + allowances),
            'months_included': monthsIncluded.toList()..sort(),
            'monthly_breakdown': monthlyBreakdown,
            'pension': 0,
            'other_income': 0,
            'section_c_total': _money(salaryWages + allowances),
            'pcb': annual('pcb'),
            'cp38': 0,
            'epf_employee': annual('epf_employee'),
            'socso_employee': employeeSocso,
            'eis_employee': employeeEis,
            'zakat': annual('zakat'),
            'tax_exempt_allowances': 0,
            'generated_date': DateFormat('dd/MM/yyyy').format(_generatedDate),
          },
        });
      }
      if (rows.isEmpty) throw Exception('No payroll records found for $_year.');
      await SupabaseService.client
          .from('employee_ea_forms')
          .upsert(rows, onConflict: 'employee_id,tax_year');
      String? notificationWarning;
      try {
        await NotificationService.sendEaFormsAvailable(
          employeeIds: rows.map((row) => '${row['employee_id']}'),
          taxYear: _year,
        );
      } catch (_) {
        notificationWarning = ' Employee notifications failed.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${rows.length} EA form(s) generated and published.'
          '${notificationWarning ?? ' Employees notified.'}',
        ),
      ));
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to generate EA forms: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPdf(Map<String, dynamic> form) async {
    final bytes = await EaFormPdfService.build(form);
    final id = form['employee_id'] ?? 'employee';
    await Printing.layoutPdf(
      name: 'EA_${id}_${form['tax_year']}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(8, (index) => DateTime.now().year - index);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final rows =
            (snapshot.data ?? const <Map<String, dynamic>>[]).where((row) {
          final data =
              Map<String, dynamic>.from(row['form_data'] as Map? ?? const {});
          final haystack =
              '${row['employee_id']} ${data['employee_name']}'.toLowerCase();
          return haystack.contains(_search.toLowerCase());
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.isAdmin ? 'Employee EA Forms' : 'My EA Forms',
                style:
                    const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(widget.isAdmin
                ? 'Generate and publish annual EA statements from completed payroll records.'
                : 'EA forms published by payroll administration will appear here.'),
            const SizedBox(height: 18),
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<int>(
                  initialValue: _year,
                  decoration: const InputDecoration(
                      labelText: 'Tax year', border: OutlineInputBorder()),
                  items: years
                      .map((year) =>
                          DropdownMenuItem(value: year, child: Text('$year')))
                      .toList(),
                  onChanged: (year) {
                    if (year == null) return;
                    _year = year;
                    _reload();
                  },
                ),
              ),
              if (widget.isAdmin)
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _selectGeneratedDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      'Generated date: '
                      '${DateFormat('dd/MM/yyyy').format(_generatedDate)}',
                    ),
                  ),
                ),
              if (widget.isAdmin)
                FilledButton.icon(
                  onPressed: _busy ? null : _generateAll,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(_busy ? 'Generating...' : 'Generate & publish'),
                ),
              if (widget.isAdmin)
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search employee',
                        border: OutlineInputBorder()),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator()))
            else if (snapshot.hasError)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                          'Unable to load EA forms. Apply the EA form database migration first.\n\n${snapshot.error}')))
            else if (rows.isEmpty)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                          child: Text(
                              'No EA forms have been generated for this year.'))))
            else
              ...rows.map((row) {
                final data = Map<String, dynamic>.from(
                    row['form_data'] as Map? ?? const {});
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.description_outlined)),
                    title: Text(
                        '${data['employee_name'] ?? row['employee_id']}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                        'EA ${row['tax_year']} • ${row['employee_id']} • Published ${DateFormat('dd MMM yyyy').format(DateTime.tryParse('${row['generated_at']}')?.toLocal() ?? DateTime.now())}'),
                    trailing: FilledButton.tonalIcon(
                      onPressed: () => _openPdf(row),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('View PDF'),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
