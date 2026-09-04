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

  String _stamp(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return parsed == null
        ? 'Waiting'
        : DateFormat('dd/MM/yyyy hh:mm a').format(parsed);
  }

  String _statusText(String status) {
    if (status == 'pending_branch') return 'WAITING FOR BRANCH';
    if (status == 'pending_admin') return 'WAITING FOR ADMIN';
    return status.replaceAll('_', ' ').toUpperCase();
  }

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
      _message('Overtime request submitted to your branch for approval.');
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
          color: const Color(0xFFFFFCED),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF3155A4), width: 1.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: const Color(0xFF3155A4),
                        child: const Text(
                          'BORANG TUNTUTAN\nKERJA LEBIH MASA',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.15),
                        ),
                      ),
                      const SizedBox(width: 18),
                      const Text('hasani ',
                          style: TextStyle(
                              color: Color(0xFF3155A4),
                              fontSize: 35,
                              fontWeight: FontWeight.w900)),
                      const Text('BOOKS',
                          style: TextStyle(
                              color: Color(0xFFE51D2A),
                              fontSize: 35,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Table(
                    border: TableBorder.all(
                        color: const Color(0xFF3155A4), width: 1.1),
                    columnWidths: const {
                      0: FixedColumnWidth(90),
                      1: FlexColumnWidth(),
                      2: FixedColumnWidth(105),
                      3: FlexColumnWidth(),
                    },
                    children: [
                      TableRow(children: [
                        _paperLabel('NAMA'),
                        _paperValue(widget.employee.name),
                        _paperLabel('CAWANGAN'),
                        _paperValue(widget.employee.branchId),
                      ]),
                      TableRow(children: [
                        _paperLabel('BAHAGIAN'),
                        _paperValue(widget.employee.department),
                        _paperLabel('NO. PEKERJA'),
                        _paperValue(widget.employee.employeeId),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Table(
                    border: TableBorder.all(
                        color: const Color(0xFF3155A4), width: 1.1),
                    columnWidths: const {
                      0: FlexColumnWidth(.45),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(.85),
                      3: FlexColumnWidth(1),
                      4: FlexColumnWidth(1),
                      5: FlexColumnWidth(1.15),
                      6: FlexColumnWidth(2.4),
                      7: FlexColumnWidth(1.05),
                    },
                    children: [
                      TableRow(children: [
                        _paperHeader('NO'),
                        _paperHeader('TARIKH'),
                        _paperHeader('MASA\nMASUK'),
                        _paperHeader('KELUAR\nSEBENAR'),
                        _paperHeader('KELUAR'),
                        _paperHeader('JUMLAH LEBIH MASA\n(JAM:MINIT)'),
                        _paperHeader('SEBAB\nLEBIH MASA'),
                        _paperHeader('DISAHKAN\nOLEH'),
                      ]),
                      TableRow(children: [
                        _paperCell('1'),
                        _paperDateButton(),
                        _paperCell(_shiftStart.isEmpty ? '-' : _shiftStart),
                        _paperTimeField(_otStart, 'HH:MM'),
                        _paperTimeField(_otEnd, 'HH:MM'),
                        _paperCell(_duration(_requestedMinutes)),
                        _paperReasonField(),
                        _paperCell('MENUNGGU'),
                      ]),
                      for (var row = 2; row <= 8; row++)
                        TableRow(children: [
                          _paperCell('$row'),
                          _paperCell(''),
                          _paperCell(''),
                          _paperCell(''),
                          _paperCell(''),
                          _paperCell(''),
                          _paperCell(''),
                          _paperCell(''),
                        ]),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 7),
                    child: Text(
                      'Tuntutan kerja lebih masa tidak sah sekiranya tiada kelulusan oleh pengurus cawangan dengan sebab yang munasabah.',
                      style: TextStyle(color: Color(0xFF3155A4), fontSize: 11),
                    ),
                  ),
                  Table(
                    border: TableBorder.all(
                        color: const Color(0xFF3155A4), width: 1.1),
                    children: [
                      TableRow(children: [
                        _approvalCell('DIMOHON OLEH', widget.employee.name,
                            DateFormat('dd/MM/yyyy').format(DateTime.now())),
                        _approvalCell('DISEMAK OLEH', '', ''),
                        _approvalCell('DISAHKAN OLEH', '', ''),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: const Icon(Icons.send),
                      label:
                          Text(_saving ? 'Submitting...' : 'Submit to Branch'),
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
                final status = row['status']?.toString() ?? 'pending_branch';
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_shortTime(row['overtime_start'])}-${_shortTime(row['overtime_end'])}  '
                          'Requested ${_duration(row['requested_minutes'] as int?)}'
                          '${row['approved_minutes'] == null ? '' : '  Approved ${_duration(row['approved_minutes'] as int?)}'}',
                        ),
                        const SizedBox(height: 5),
                        Wrap(spacing: 16, runSpacing: 4, children: [
                          Text('Submitted: ${_stamp(row['submitted_at'])}',
                              style: const TextStyle(fontSize: 11)),
                          Text('Branch: ${_stamp(row['branch_approved_at'])}',
                              style: const TextStyle(fontSize: 11)),
                          Text('Admin: ${_stamp(row['admin_approved_at'])}',
                              style: const TextStyle(fontSize: 11)),
                        ]),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(_statusText(status)),
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

  Widget _paperLabel(String text) => Container(
        height: 38,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF3155A4),
                fontSize: 11,
                fontWeight: FontWeight.w800)),
      );

  Widget _paperValue(String text) => Container(
        height: 38,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(text.isEmpty ? '-' : text,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _paperHeader(String text) => Container(
        height: 58,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF3155A4),
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      );

  Widget _paperCell(String text) => Container(
        height: 50,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(5),
        child: Text(text, textAlign: TextAlign.center),
      );

  Widget _paperDateButton() => SizedBox(
        height: 50,
        child: TextButton(
          onPressed: _chooseDate,
          child: Text(DateFormat('dd/MM/yyyy').format(_date)),
        ),
      );

  Widget _paperTimeField(TextEditingController controller, String hint) =>
      SizedBox(
        height: 50,
        child: TextFormField(
          controller: controller,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 5)),
          onChanged: (_) => setState(() {}),
          validator: (value) => _minutes(value ?? '') == null ? 'HH:MM' : null,
        ),
      );

  Widget _paperReasonField() => SizedBox(
        height: 50,
        child: TextFormField(
          controller: _reason,
          decoration: const InputDecoration(
              hintText: 'Sebab',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 7)),
          validator: (value) =>
              value?.trim().isEmpty == true ? 'Required' : null,
        ),
      );

  Widget _approvalCell(String title, String name, String date) => Container(
        height: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFF3155A4),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 0, 7, 5),
              child: Text('TARIKH: $date',
                  style:
                      const TextStyle(color: Color(0xFF3155A4), fontSize: 9)),
            ),
          ],
        ),
      );
}
