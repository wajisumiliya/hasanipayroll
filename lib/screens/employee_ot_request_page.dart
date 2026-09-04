import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payroll.dart';
import 'supabase_service.dart';

class EmployeeOtRequestPage extends StatefulWidget {
  final Employee employee;

  const EmployeeOtRequestPage({super.key, required this.employee});

  @override
  State<EmployeeOtRequestPage> createState() => _EmployeeOtRequestPageState();
}

class _EmployeeOtRequestPageState extends State<EmployeeOtRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _otStart = TextEditingController();
  final _otEnd = TextEditingController();
  final _reason = TextEditingController();
  DateTime _date = DateTime.now();
  String _shiftStart = '';
  String _shiftEnd = '';
  bool _saving = false;
  Future<List<Map<String, dynamic>>>? _requests;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadShift();
  }

  @override
  void dispose() {
    _otStart.dispose();
    _otEnd.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _refresh() {
    _requests =
        SupabaseService.getEmployeeOtRequests(widget.employee.employeeId);
  }

  Future<void> _loadShift() async {
    final rows = await SupabaseService.getMonthlyRosters(
      branchId: widget.employee.branchId,
      employeeId: widget.employee.employeeId,
      year: _date.year,
      month: _date.month,
    );
    final week = ((_date.day - 1) ~/ 7) + 1;
    final matches = rows.where((row) => row['week_number'] == week);
    if (!mounted) return;
    setState(() {
      final row = matches.isEmpty ? null : matches.first;
      _shiftStart = _shortTime(row?['shift_start']);
      _shiftEnd = _shortTime(row?['shift_end']);
      if (_otStart.text.trim().isEmpty && _shiftEnd.isNotEmpty) {
        _otStart.text = _shiftEnd;
      }
    });
  }

  String _shortTime(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  int? _minutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  int? get _requestedMinutes {
    final start = _minutes(_otStart.text);
    final end = _minutes(_otEnd.text);
    if (start == null || end == null) return null;
    final result = end >= start ? end - start : 1440 - start + end;
    return result > 0 ? result : null;
  }

  String _duration(int? minutes) => minutes == null
      ? '--:--'
      : '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
          '${(minutes % 60).toString().padLeft(2, '0')}';

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _shiftStart = '';
      _shiftEnd = '';
    });
    await _loadShift();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final requested = _requestedMinutes;
    if (requested == null) {
      _message('Enter a valid overtime start and end time.');
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.submitOtRequest({
        'employee_id': widget.employee.employeeId,
        'employee_name': widget.employee.name,
        'branch_id': widget.employee.branchId,
        'department': widget.employee.department,
        'overtime_date': DateFormat('yyyy-MM-dd').format(_date),
        'shift_start': _shiftStart.isEmpty ? null : _shiftStart,
        'shift_end': _shiftEnd.isEmpty ? null : _shiftEnd,
        'overtime_start': _otStart.text.trim(),
        'overtime_end': _otEnd.text.trim(),
        'requested_minutes': requested,
        'reason': _reason.text.trim(),
      });
      _otEnd.clear();
      _reason.clear();
      setState(_refresh);
      _message('Overtime request submitted to admin.');
    } catch (error) {
      _message('Unable to submit overtime request: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Overtime Claim Form',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Borang Tuntutan Kerja Lebih Masa',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF2D55D8),
                    child: const Text('HASANI BOOKS - OVERTIME REQUEST',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _info('Name', widget.employee.name),
                      _info('Employee ID', widget.employee.employeeId),
                      _info('Department', widget.employee.department),
                      _info('Branch', widget.employee.branchId),
                    ],
                  ),
                  const Divider(height: 30),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _chooseDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(DateFormat('dd MMM yyyy').format(_date)),
                      ),
                      _info(
                          'Scheduled shift',
                          _shiftStart.isEmpty
                              ? 'Not assigned'
                              : '$_shiftStart - $_shiftEnd'),
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          controller: _otStart,
                          decoration: _decoration('OT start (HH:MM)'),
                          onChanged: (_) => setState(() {}),
                          validator: (value) => _minutes(value ?? '') == null
                              ? 'Use HH:MM'
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          controller: _otEnd,
                          decoration: _decoration('OT end (HH:MM)'),
                          onChanged: (_) => setState(() {}),
                          validator: (value) => _minutes(value ?? '') == null
                              ? 'Use HH:MM'
                              : null,
                        ),
                      ),
                      _info('Requested OT', _duration(_requestedMinutes)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reason,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _decoration('Reason for overtime'),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Reason is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: const Icon(Icons.send),
                      label:
                          Text(_saving ? 'Submitting...' : 'Submit to Admin'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('My OT Requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Unable to load requests: ${snapshot.error}');
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) return const Text('No OT requests submitted.');
            return Column(
              children: rows.map((row) {
                final status = row['status']?.toString() ?? 'pending';
                final color = status == 'approved'
                    ? Colors.green
                    : status == 'rejected'
                        ? Colors.red
                        : Colors.orange;
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(Icons.more_time, color: color),
                    title: Text('${row['overtime_date']} - ${row['reason']}'),
                    subtitle: Text(
                      '${_shortTime(row['overtime_start'])}-${_shortTime(row['overtime_end'])}  '
                      'Requested ${_duration(row['requested_minutes'] as int?)}'
                      '${row['approved_minutes'] == null ? '' : '  Approved ${_duration(row['approved_minutes'] as int?)}'}',
                    ),
                    trailing: Chip(
                      label: Text(status.toUpperCase()),
                      side: BorderSide(color: color),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _info(String label, String value) => SizedBox(
        width: 210,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text(value.isEmpty ? '-' : value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
