import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalaryReportTemporaryPayroll extends StatefulWidget {
  const SalaryReportTemporaryPayroll({super.key, required this.startYear,
    required this.load, required this.save});
  final int startYear;
  final Future<Map<String, dynamic>> Function(int year) load;
  final Future<void> Function(Map<String, dynamic> entry, String method) save;
  @override
  State<SalaryReportTemporaryPayroll> createState() => _TemporaryPayrollState();
}

class _TemporaryPayrollState extends State<SalaryReportTemporaryPayroll> {
  final scroll = ScrollController();
  final id = TextEditingController(), name = TextEditingController(), notes = TextEditingController();
  final amounts = {for (final field in ['basic_salary', 'allowances', 'other_earnings', 'deductions']) field: TextEditingController(text: '0.00')};
  Map<String, dynamic>? data;
  String? employee, branch, error, success;
  String classification = 'local';
  late String from = '${widget.startYear}-07';
  late String through = from;
  bool manual = false, loading = true, saving = false, editing = false;
  bool get busy => loading || saving;
  List<Map<String, dynamic>> rows(String field) => (data?[field] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<String> get months => List.generate(12, (i) => DateFormat('yyyy-MM').format(DateTime(widget.startYear, 7+i)));
  String monthLabel(String month) => DateFormat('MMM yyyy').format(DateTime.parse('$month-01'));
  double amount(String field) => double.tryParse(amounts[field]!.text.replaceAll(',', '').trim()) ?? 0;
  double get total => amount('basic_salary') + amount('allowances') + amount('other_earnings') - amount('deductions');

  @override
  void initState() { super.initState(); reload(); }
  @override
  void dispose() {
    scroll.dispose(); id.dispose(); name.dispose(); notes.dispose();
    for (final controller in amounts.values) { controller.dispose(); }
    super.dispose();
  }
  Future<void> reload() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await widget.load(widget.startYear);
      if (mounted) setState(() {
        data = result;
        if (result['staff_scope'] is String) classification = result['staff_scope'] as String;
        if (employee != null && !rows('employees').any((row) => row['employee_id'] == employee)) {
          if (editing) { manual = true; employee = null; } else { reset(); }
        }
        if (!rows('branches').any((row) => row['id'] == branch)) branch = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to load temporary payroll: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  void reset() {
    editing = false; employee = null; id.clear(); name.clear(); notes.clear();
    for (final controller in amounts.values) { controller.text = '0.00'; }
    from = '${widget.startYear}-07'; through = from;
  }
  void edit(Map<String, dynamic> entry) {
    final existing = rows('employees').where((e) => e['employee_id'] == entry['employee_id']).firstOrNull;
    setState(() {
      editing = true; manual = existing == null;
      employee = existing?['employee_id']?.toString();
      id.text = '${entry['employee_id']}'; name.text = '${entry['display_name'] ?? entry['employee_name']}';
      notes.text = '${entry['notes'] ?? ''}'; branch = '${entry['branch_id']}';
      from = '${entry['month']}'; through = from; classification = '${existing?['staff_scope'] ?? entry['staff_scope']}';
      for (final field in amounts.keys) { amounts[field]!.text = '${entry[field]}'; }
      error = null; success = null;
    });
    if (scroll.hasClients) scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }
  Future<void> submit() async {
    if (id.text.trim().isEmpty || (manual && name.text.trim().isEmpty) || branch == null) {
      setState(() => error = 'Select an employee or enter a historical ID and name, then select a branch.'); return;
    }
    if (from.compareTo(through) > 0) { setState(() => error = 'The end month must be on or after the start month.'); return; }
    for (final controller in amounts.values) {
      final text = controller.text.replaceAll(',', '').trim();
      if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) || (double.tryParse(text) ?? double.infinity) > 9999999999.99) {
        setState(() => error = 'Enter non-negative amounts with no more than two decimal places.'); return;
      }
    }
    setState(() { saving = true; error = null; success = null; });
    try {
      await widget.save({'employee_id': id.text.trim().toUpperCase(), 'employee_name': name.text.trim(),
        'branch_id': branch, 'staff_scope': classification, 'from_month': from, 'through_month': through,
        for (final field in amounts.keys) field: amounts[field]!.text.replaceAll(',', '').trim(), 'notes': notes.text.trim()}, editing ? 'PUT' : 'POST');
      if (!mounted) return;
      setState(() { reset(); success = 'Temporary reconciliation payroll saved. It will appear in the Salary Report only.'; });
      await reload();
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to save temporary payroll: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  Future<void> remove(Map<String, dynamic> entry) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Remove temporary entry?'),
      content: Text('Remove ${entry['employee_id']} for ${monthLabel('${entry['month']}')} from reconciliation? Saved payroll is unchanged.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))]));
    if (confirm != true || !mounted) return;
    setState(() { saving = true; error = null; success = null; });
    try {
      await widget.save({'employee_id': entry['employee_id'], 'from_month': entry['month'], 'through_month': entry['month']}, 'DELETE');
      if (!mounted) return;
      setState(() { reset(); success = 'Temporary entry removed.'; });
      await reload();
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to remove temporary payroll: $e');
    } finally { if (mounted) setState(() => saving = false); }
  }
  Widget select(String label, String? value, List<DropdownMenuItem<String>> items, ValueChanged<String?> changed, {bool locked = false}) =>
    DropdownButtonFormField<String>(key: ValueKey('$label:$value'), initialValue: value, isExpanded: true,
      decoration: InputDecoration(labelText: label), items: items, onChanged: busy || locked ? null : changed);

  @override
  Widget build(BuildContext context) {
    final branchNames = {for (final b in rows('branches')) '${b['id']}': '${b['name']}'};
    final allEntries = rows('entries').where((e) => id.text.trim().isEmpty || '${e['employee_id']}'.toUpperCase().contains(id.text.trim().toUpperCase())).toList();
    return PopScope(canPop: !saving, child: AlertDialog(
      title: Text(editing ? 'Edit Temporary Payroll' : 'Add Temporary Payroll'),
      content: SizedBox(width: 700, height: 560, child: loading ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(controller: scroll, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Historical reconciliation only. No payslip, bank payment, statutory submission or notification is created.'),
          const SizedBox(height: 8),
          const Text('Amount = basic salary + allowances + other earnings − deductions excluding EPF, EIS and SOCSO. The same amounts apply to every month selected; add different salaries separately.'),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Employee is missing from the current employee list'),
            value: manual, onChanged: busy || editing ? null : (value) => setState(() { reset(); manual = value; })),
          if (!manual) select('Existing employee', employee, rows('employees').map((e) => DropdownMenuItem<String>(value: '${e['employee_id']}',
            child: Text('${e['employee_id']} · ${e['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
            (value) => setState(() {
              employee = value;
              final selected = rows('employees').firstWhere((e) => e['employee_id'] == value);
              id.text = '$value'; name.text = '${selected['name']}'; classification = '${selected['staff_scope']}';
            }), locked: editing),
          if (manual) ...[
            TextField(key: const ValueKey('temporary-employee-id'), controller: id, enabled: !busy && !editing,
              maxLength: 100, decoration: const InputDecoration(labelText: 'Historical employee ID'), onChanged: (_) => setState(() {})),
            TextField(key: const ValueKey('temporary-employee-name'), controller: name, enabled: !busy, maxLength: 200,
              decoration: const InputDecoration(labelText: 'Historical employee name')),
            select('Employee classification', classification, const [DropdownMenuItem(value: 'local', child: Text('Local')),
              DropdownMenuItem(value: 'foreign', child: Text('FRN / Foreign'))], (v) => setState(() => classification = v!), locked: data?['staff_scope'] != null),
          ],
          const SizedBox(height: 12),
          select('Reconciliation branch', branch, rows('branches').map((b) => DropdownMenuItem<String>(value: '${b['id']}',
            child: Text('${b['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(), (v) => setState(() => branch = v)),
          const SizedBox(height: 12),
          select('From month', from, months.map((m) => DropdownMenuItem(value: m, child: Text(monthLabel(m)))).toList(),
            (v) => setState(() => from = v!), locked: editing),
          const SizedBox(height: 12),
          select('Through month', through, months.map((m) => DropdownMenuItem(value: m, child: Text(monthLabel(m)))).toList(),
            (v) => setState(() => through = v!), locked: editing),
          for (final item in const {'basic_salary': 'Basic salary (RM)', 'allowances': 'Total allowances (RM)',
            'other_earnings': 'Other earnings including OT / bonus (RM)', 'deductions': 'Deductions excluding EPF/EIS/SOCSO (RM)'}.entries)
            Padding(padding: const EdgeInsets.only(top: 12), child: TextField(key: ValueKey('temporary-${item.key}'), controller: amounts[item.key],
              enabled: !busy, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: item.value), onChanged: (_) => setState(() {}))),
          const SizedBox(height: 12),
          Text('Salary Report amount per month: RM ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: notes, enabled: !busy, maxLength: 2000, maxLines: 2, decoration: const InputDecoration(labelText: 'Reconciliation note / evidence')),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          if (success != null) Text(success!, style: const TextStyle(color: Colors.green)),
          const SizedBox(height: 16),
          const Text('Saved temporary entries', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Real saved payroll always takes precedence. Select an entry to edit its amounts or branch.'),
          if (allEntries.isEmpty) const Text('No temporary entries for this selection.'),
          for (final entry in allEntries.take(100)) Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${entry['employee_id']} · ${entry['display_name'] ?? entry['employee_name']}'),
            Text('${monthLabel('${entry['month']}')} · ${branchNames['${entry['branch_id']}'] ?? entry['branch_id']} · RM ${entry['amount']}'),
            if (entry['has_saved_payroll'] == true) const Text('Saved payroll now exists. This temporary entry is excluded from the report.'),
            Wrap(spacing: 8, children: [TextButton(onPressed: busy || entry['has_saved_payroll'] == true ? null : () => edit(entry), child: const Text('Edit entry')),
              TextButton(onPressed: busy ? null : () => remove(entry), child: const Text('Remove entry'))]),
          ]))),
          if (allEntries.length > 100) const Text('Showing the first 100 entries. Select or enter an employee ID to narrow the list.'),
        ]))),
      actions: [TextButton(onPressed: busy ? null : reload, child: const Text('Refresh')),
        if (editing) TextButton(onPressed: busy ? null : () => setState(reset), child: const Text('Cancel edit')),
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Done')),
        FilledButton(onPressed: busy || data == null ? null : submit, child: Text(saving ? 'Saving…' : editing ? 'Update entry' : 'Save temporary payroll'))],
    ));
  }
}
