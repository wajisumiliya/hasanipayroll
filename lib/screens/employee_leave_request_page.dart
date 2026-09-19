import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payroll.dart';

class EmployeeLeaveRequestPage extends StatefulWidget {
  final Employee employee;

  const EmployeeLeaveRequestPage({super.key, required this.employee});

  @override
  State<EmployeeLeaveRequestPage> createState() =>
      _EmployeeLeaveRequestPageState();
}

class _EmployeeLeaveRequestPageState extends State<EmployeeLeaveRequestPage> {
  static const _pink = Color(0xFFF24F78);
  static const _paper = Color(0xFFFFFEF1);

  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _emergencyAddress = TextEditingController();
  final _emergencyPhone = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  String _leaveType = 'Unpaid Leave';

  @override
  void dispose() {
    _reason.dispose();
    _emergencyAddress.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  int get _days {
    if (_fromDate == null || _toDate == null || _toDate!.isBefore(_fromDate!)) {
      return 0;
    }
    return _toDate!.difference(_fromDate!).inDays + 1;
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the leave start and end dates.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Leave form completed. Submission workflow is coming next.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 650;
    return ListView(
      padding: EdgeInsets.all(mobile ? 10 : 24),
      children: [
        Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 850),
            decoration: BoxDecoration(
              color: _paper,
              border: Border.all(color: _pink, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .10),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _header(mobile),
                  _bar('LEAVE APPLICATION FORM'),
                  Padding(
                    padding: EdgeInsets.all(mobile ? 12 : 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _leaveTypes(mobile),
                        const SizedBox(height: 12),
                        const Text(
                          'Please submit this leave application at least 5 days before your leave date, except for emergency leave.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _pink, fontSize: 11),
                        ),
                        const SizedBox(height: 22),
                        _employeeDetails(mobile),
                        const SizedBox(height: 14),
                        _dateSection(mobile),
                        const SizedBox(height: 14),
                        _lineField(
                          controller: _reason,
                          label: 'Reason for leave',
                          maxLines: 3,
                          required: true,
                        ),
                        const SizedBox(height: 14),
                        _lineField(
                          controller: _emergencyAddress,
                          label: 'Address during leave',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        _lineField(
                          controller: _emergencyPhone,
                          label: 'Emergency contact number',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              'Application date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                              style: const TextStyle(color: _pink, fontSize: 11),
                            ),
                            const Spacer(),
                            Text(
                              widget.employee.name,
                              style: const TextStyle(
                                color: _pink,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _bar('FOR OFFICIAL USE'),
                  _officialUse(mobile),
                  _bar('NOTES'),
                  const SizedBox(height: 76),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FilledButton.icon(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _pink,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Submit Leave Application'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(bool mobile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 28, vertical: 14),
      child: Row(
        children: [
          Image.asset(
            'assets/hasani_books_payslip_logo.jpeg',
            width: mobile ? 120 : 190,
            height: 58,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              'hasani',
              style: TextStyle(color: _pink, fontSize: 38, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HASANI EDAR SDN. BHD.',
                  style: TextStyle(
                    color: _pink,
                    fontSize: mobile ? 13 : 19,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (!mobile)
                  const Text(
                    'No. 43 & 44A, Jalan Pengkalan Taman Pekan Baru, Sungai Petani, Kedah Darul Aman',
                    style: TextStyle(color: _pink, fontSize: 9),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        color: _pink,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
          ),
        ),
      );

  Widget _leaveTypes(bool mobile) {
    const types = ['Unpaid Leave', 'Emergency Leave', 'Replacement Leave'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final selected = _leaveType == type;
        return SizedBox(
          width: mobile ? double.infinity : 250,
          child: InkWell(
            onTap: () => setState(() => _leaveType = type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: selected ? _pink.withValues(alpha: .10) : Colors.transparent,
                border: Border.all(color: _pink, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      type.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _pink,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Radio<String>(
                    value: type,
                    groupValue: _leaveType,
                    activeColor: _pink,
                    onChanged: (value) => setState(() => _leaveType = value!),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _employeeDetails(bool mobile) {
    final fields = [
      ('Name', widget.employee.name),
      ('Employee ID', widget.employee.employeeId),
      ('Designation', widget.employee.designation),
      ('Department', widget.employee.department),
    ];
    return Wrap(
      spacing: 18,
      runSpacing: 12,
      children: fields
          .map((field) => SizedBox(
                width: mobile ? double.infinity : 380,
                child: _readOnlyLine(field.$1, field.$2),
              ))
          .toList(),
    );
  }

  Widget _readOnlyLine(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _pink, fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 5),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _pink)),
            ),
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      );

  Widget _dateSection(bool mobile) {
    final from = _fromDate == null ? 'Select date' : DateFormat('dd/MM/yyyy').format(_fromDate!);
    final to = _toDate == null ? 'Select date' : DateFormat('dd/MM/yyyy').format(_toDate!);
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        _dateButton('From date', from, () => _pickDate(from: true), mobile),
        _dateButton('Until', to, () => _pickDate(from: false), mobile),
        SizedBox(
          width: mobile ? double.infinity : 130,
          child: _readOnlyLine('Number of days', _days == 0 ? '-' : '$_days'),
        ),
      ],
    );
  }

  Widget _dateButton(String label, String value, VoidCallback onTap, bool mobile) {
    return SizedBox(
      width: mobile ? double.infinity : 245,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _pink, fontSize: 11)),
          OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: _pink,
              side: const BorderSide(color: _pink),
              minimumSize: const Size.fromHeight(44),
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _lineField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _pink),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _pink)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _pink, width: 2)),
      ),
    );
  }

  Widget _officialUse(bool mobile) {
    return Padding(
      padding: EdgeInsets.all(mobile ? 14 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: const [
              _ApprovalOption('Leave approved'),
              _ApprovalOption('Leave not approved'),
            ],
          ),
          const SizedBox(height: 15),
          _readOnlyLine('Approved leave', ''),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _readOnlyLine('Date', '')),
              const SizedBox(width: 24),
              Expanded(child: _readOnlyLine('Head of Department', '')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalOption extends StatelessWidget {
  final String label;

  const _ApprovalOption(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            border: Border.all(color: _EmployeeLeaveRequestPageState._pink),
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(color: _EmployeeLeaveRequestPageState._pink)),
      ],
    );
  }
}
