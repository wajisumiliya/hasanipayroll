import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'supabase_service.dart';

class AttendanceDialog extends StatefulWidget {
  const AttendanceDialog({
    super.key,
    required this.employee,
    required this.month,
    required this.branchId,
    this.editable = true,
    this.showSubmitButton = false,
    this.adminOnlyAfterSubmit = false,
  });

  final Map<String, dynamic> employee;
  final DateTime month;
  final String branchId;
  final bool editable;
  final bool showSubmitButton;
  final bool adminOnlyAfterSubmit;

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  late final List<AttendanceDayControllers> controllers;
  late final int daysInMonth;

  bool loading = true;
  bool saving = false;
  bool submitted = false;
  String? loadError;
  Timer? _liveRefreshTimer;

  static const Color workColor = Color(0xFF15965D);
  static const Color breakColor = Color(0xFF315AD9);

  @override
  void initState() {
    super.initState();

    daysInMonth = DateUtils.getDaysInMonth(
      widget.month.year,
      widget.month.month,
    );

    controllers = List.generate(
      daysInMonth,
      (_) => AttendanceDayControllers(),
    );

    _loadAttendance();

    if (!widget.editable) {
      _liveRefreshTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _loadAttendance(silent: true),
      );
    }
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _employeeId() {
    return (widget.employee['employee_id'] ??
            widget.employee['id'] ??
            '')
        .toString();
  }

  String _employeeName() {
    return widget.employee['name']?.toString() ?? 'Employee';
  }

  String _department() {
    return widget.employee['department']?.toString() ?? '';
  }

  String _section() {
    return widget.employee['section']?.toString() ?? '';
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  bool get _canEdit {
    if (!widget.editable) return false;
    if (widget.adminOnlyAfterSubmit) return submitted;
    return true;
  }

  Future<void> _loadAttendance({bool silent = false}) async {
    try {
      final employeeId = _employeeId().trim();

      if (employeeId.isEmpty) {
        throw Exception('Employee ID is missing.');
      }

      final start = DateTime(widget.month.year, widget.month.month, 1);
      final end = DateTime(widget.month.year, widget.month.month + 1, 1);

      final List<Map<String, dynamic>> rows;

      if (widget.editable) {
        rows = List<Map<String, dynamic>>.from(
          await SupabaseService.getAttendanceByEmployeeMonth(
            employeeId,
            widget.month.year,
            widget.month.month,
          ),
        );
      } else {
        rows = List<Map<String, dynamic>>.from(
          await SupabaseService.client
              .from('attendance')
              .select()
              .eq('employee_id', employeeId)
              .eq('is_submitted', true)
              .gte(
                'attendance_date',
                start.toIso8601String().substring(0, 10),
              )
              .lt(
                'attendance_date',
                end.toIso8601String().substring(0, 10),
              )
              .order('attendance_date'),
        );
      }

      submitted = rows.any((row) => _toBool(row['is_submitted']));

      for (final row in rows) {
        final date = DateTime.tryParse(
          (row['attendance_date'] ?? '').toString(),
        );

        if (date == null ||
            date.year != widget.month.year ||
            date.month != widget.month.month ||
            date.day < 1 ||
            date.day > daysInMonth) {
          continue;
        }

        final c = controllers[date.day - 1];

        c.workingIn.text =
            (row['check_in'] ?? row['working_in'] ?? '').toString();
        c.workingOut.text =
            (row['check_out'] ?? row['working_out'] ?? '').toString();

        c.morningIn.text = (row['morning_in'] ?? '').toString();
        c.morningOut.text = (row['morning_out'] ?? '').toString();
        c.afternoonIn.text = (row['afternoon_in'] ?? '').toString();
        c.afternoonOut.text = (row['afternoon_out'] ?? '').toString();

        // Existing DB columns are retained for compatibility.
        // The UI treats these as EVENING BREAK, not overtime.
        c.overtimeIn.text = (row['overtime_in'] ?? '').toString();
        c.overtimeOut.text = (row['overtime_out'] ?? '').toString();
        c.otAuthorized = _toBool(row['ot_authorized']);
      }

      loadError = null;
    } catch (e) {
      loadError = e.toString();
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  Future<void> _saveAttendance({required bool submit}) async {
    if (saving) return;

    final employeeId = _employeeId().trim();

    if (employeeId.isEmpty) {
      _showError('Cannot save attendance: employee ID is missing.');
      return;
    }

    final employeeBranchId =
        (widget.employee['branch_id'] ??
                widget.employee['branchId'] ??
                widget.branchId)
            .toString();

    setState(() => saving = true);

    var savedRows = 0;

    try {
      for (var day = 1; day <= daysInMonth; day++) {
        final row = controllers[day - 1];

        if (!row.hasData) continue;

        final fields = <String, String>{
          'Working In': row.workingIn.text,
          'Working Out': row.workingOut.text,
          'Morning In': row.morningIn.text,
          'Morning Out': row.morningOut.text,
          'Afternoon In': row.afternoonIn.text,
          'Afternoon Out': row.afternoonOut.text,
          'Evening In': row.overtimeIn.text,
          'Evening Out': row.overtimeOut.text,
        };

        for (final entry in fields.entries) {
          if (entry.value.trim().isNotEmpty &&
              parseTimeToMinutes(entry.value) == null) {
            final date = DateTime(
              widget.month.year,
              widget.month.month,
              day,
            );
            throw Exception(
              'Invalid ${entry.key} time on '
              '${DateFormat('dd MMM yyyy').format(date)}. '
              'Use HH:MM, e.g. 08:30.',
            );
          }
        }

        final workMinutes = calculateWorkMinutes(row);
        final breakMinutes =
            calculateMinutes(row.morningIn.text, row.morningOut.text) +
            calculateMinutes(
              row.afternoonIn.text,
              row.afternoonOut.text,
            ) +
            calculateMinutes(
              row.overtimeIn.text,
              row.overtimeOut.text,
            );

        await SupabaseService.saveMonthlyAttendanceRow(
          employeeId: employeeId,
          branchId: employeeBranchId,
          date: DateTime(
            widget.month.year,
            widget.month.month,
            day,
          ),
          workingIn: row.workingIn.text.trim(),
          workingOut: row.workingOut.text.trim(),
          morningIn: row.morningIn.text.trim(),
          morningOut: row.morningOut.text.trim(),
          afternoonIn: row.afternoonIn.text.trim(),
          afternoonOut: row.afternoonOut.text.trim(),
          overtimeIn: row.overtimeIn.text.trim(),
          overtimeOut: row.overtimeOut.text.trim(),
          otAuthorized: false,
          workMinutes: workMinutes,
          breakMinutes: breakMinutes,
        );

        savedRows++;
      }

      if (savedRows == 0) {
        throw Exception(
          'Please enter attendance in at least one date row.',
        );
      }

      if (submit) {
        final start = DateTime(widget.month.year, widget.month.month, 1);
        final end = DateTime(widget.month.year, widget.month.month + 1, 1);

        await SupabaseService.client
            .from('attendance')
            .update({
              'is_submitted': true,
              'submitted_at': DateTime.now().toIso8601String(),
              'submitted_by': 'branch',
            })
            .eq('employee_id', employeeId)
            .eq('branch_id', employeeBranchId)
            .gte(
              'attendance_date',
              start.toIso8601String().substring(0, 10),
            )
            .lt(
              'attendance_date',
              end.toIso8601String().substring(0, 10),
            );

        submitted = true;
      }

      if (!mounted) return;

      setState(() => saving = false);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      setState(() => saving = false);
      _showError('Attendance was NOT saved:\n$e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 700;

    if (loading) {
      return const Dialog(
        child: SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (loadError != null) {
      return Dialog(
        insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 52,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Unable to load attendance',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  loadError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () {
                              setState(() {
                                loading = true;
                                loadError = null;
                              });
                              _loadAttendance();
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: EdgeInsets.all(isMobile ? 6 : 16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: isMobile
            ? media.size.width - 12
            : minDouble(media.size.width - 32, 1250),
        height: isMobile
            ? media.size.height - 12
            : media.size.height * .94,
        child: Column(
          children: [
            _attendanceDialogHeader(isMobile),
            Expanded(
              child: isMobile
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 430,
                            child: _workingAttendanceCard(),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 430,
                            child: _breakAttendanceCard(),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _workingAttendanceCard(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _breakAttendanceCard(),
                          ),
                        ],
                      ),
                    ),
            ),
            _attendanceSummary(isMobile),
            _bottomActions(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _attendanceDialogHeader(bool isMobile) {
    final details = [
      _employeeId(),
      _department(),
      _section(),
    ].where((v) => v.isNotEmpty).join(' • ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 14,
      ),
      color: workColor,
      child: Row(
        children: [
          CircleAvatar(
            radius: isMobile ? 19 : 23,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              color: workColor,
              size: isMobile ? 22 : 27,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _employeeName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 15 : 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('MMM yyyy').format(widget.month),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 12 : 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                submitted ? 'SUBMITTED' : 'DRAFT',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workingAttendanceCard() {
    return _attendanceTableCard(
      title: 'WORK ATTENDANCE',
      color: workColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 560,
          child: Column(
            children: [
              _workHeader(workColor),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: daysInMonth,
                  itemBuilder: (context, index) {
                    return _workRow(index + 1, controllers[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workHeader(Color color) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _headerCell('DATE', 55, color),
          _headerCell('CHECK IN', 115, color),
          _headerCell('CHECK OUT', 115, color),
          _headerCell('TOTAL', 100, color),
          Expanded(
            child: _headerCellExpanded('STATUS', color),
          ),
        ],
      ),
    );
  }

  Widget _workRow(int day, AttendanceDayControllers c) {
    final total = calculateWorkMinutes(c);

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _tableCell(day.toString(), 55, bold: true),
          _timeInput(c.workingIn, 115),
          _timeInput(c.workingOut, 115),
          _tableCell(
            formatMinutes(total),
            100,
            bold: true,
            color: total > 0 ? workColor : Colors.black54,
          ),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: workColor),
                  bottom: BorderSide(color: workColor),
                ),
              ),
              child: Text(
                total > 0 ? 'RECORDED' : '-',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: total > 0 ? workColor : Colors.black38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakAttendanceCard() {
    return _attendanceTableCard(
      title: 'BREAK ATTENDANCE',
      color: breakColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 570,
          child: Column(
            children: [
              _breakHeader(breakColor),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: daysInMonth,
                  itemBuilder: (context, index) {
                    return _breakRow(index + 1, controllers[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakHeader(Color color) {
    return Column(
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              _headerCell('DATE', 45, color),
              Expanded(child: _groupHeader('MORNING', color)),
              Expanded(child: _groupHeader('AFTERNOON', color)),
              Expanded(child: _groupHeader('EVENING BREAK', color)),
              _headerCell('TOTAL', 80, color),
            ],
          ),
        ),
        SizedBox(
          height: 34,
          child: Row(
            children: [
              _headerCell('', 45, color),
              Expanded(child: _subHeader('IN', color)),
              Expanded(child: _subHeader('OUT', color)),
              Expanded(child: _subHeader('IN', color)),
              Expanded(child: _subHeader('OUT', color)),
              Expanded(child: _subHeader('IN', color)),
              Expanded(child: _subHeader('OUT', color)),
              _headerCell('', 80, color),
            ],
          ),
        ),
      ],
    );
  }

  Widget _breakRow(int day, AttendanceDayControllers c) {
    final breakTotal =
        calculateMinutes(c.morningIn.text, c.morningOut.text) +
        calculateMinutes(c.afternoonIn.text, c.afternoonOut.text) +
        calculateMinutes(c.overtimeIn.text, c.overtimeOut.text);

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _tableCell(
            day.toString(),
            45,
            bold: true,
            color: breakColor,
          ),
          Expanded(child: _smallTimeInput(c.morningIn)),
          Expanded(child: _smallTimeInput(c.morningOut)),
          Expanded(child: _smallTimeInput(c.afternoonIn)),
          Expanded(child: _smallTimeInput(c.afternoonOut)),
          Expanded(child: _smallTimeInput(c.overtimeIn)),
          Expanded(child: _smallTimeInput(c.overtimeOut)),
          Container(
            width: 80,
            height: double.infinity,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: breakColor),
                bottom: BorderSide(color: breakColor),
              ),
            ),
            child: Text(
              formatMinutes(breakTotal),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: breakColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceTableCard({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 44,
            width: double.infinity,
            color: color,
            alignment: Alignment.center,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _headerCell(String text, double width, Color color) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: color),
          bottom: BorderSide(color: color),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _headerCellExpanded(String text, Color color) {
    return Container(
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: color),
          bottom: BorderSide(color: color),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _groupHeader(String text, Color color) {
    return Container(
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        border: Border(
          right: BorderSide(color: color),
          bottom: BorderSide(color: color),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _subHeader(String text, Color color) {
    return Container(
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: color),
          bottom: BorderSide(color: color),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _tableCell(
    String text,
    double width, {
    bool bold = false,
    Color? color,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: workColor),
          bottom: BorderSide(color: workColor),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  Widget _timeInput(
    TextEditingController controller,
    double width,
  ) {
    return Container(
      width: width,
      height: double.infinity,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: workColor),
          bottom: BorderSide(color: workColor),
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: !_canEdit,
        enabled: _canEdit,
        onChanged: (_) {
          if (mounted) setState(() {});
        },
        textAlign: TextAlign.center,
        keyboardType: TextInputType.datetime,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 10,
          ),
          hintText: '--:--',
          hintStyle: TextStyle(
            fontSize: 10,
            color: Colors.black26,
          ),
        ),
      ),
    );
  }

  Widget _smallTimeInput(TextEditingController controller) {
    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: breakColor),
          bottom: BorderSide(color: breakColor),
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: !_canEdit,
        enabled: _canEdit,
        onChanged: (_) {
          if (mounted) setState(() {});
        },
        textAlign: TextAlign.center,
        keyboardType: TextInputType.datetime,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 1,
            vertical: 11,
          ),
          hintText: '--:--',
          hintStyle: TextStyle(
            fontSize: 9,
            color: Colors.black26,
          ),
        ),
      ),
    );
  }

  Widget _attendanceSummary(bool isMobile) {
    var workTotal = 0;
    var breakTotal = 0;

    for (final c in controllers) {
      workTotal += calculateWorkMinutes(c);
      breakTotal += calculateMinutes(
        c.morningIn.text,
        c.morningOut.text,
      );
      breakTotal += calculateMinutes(
        c.afternoonIn.text,
        c.afternoonOut.text,
      );
      breakTotal += calculateMinutes(
        c.overtimeIn.text,
        c.overtimeOut.text,
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'MONTHLY TOTAL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 12),
            _summaryChip(
              'WORK',
              formatMinutes(workTotal),
              workColor,
            ),
            const SizedBox(width: 8),
            _summaryChip(
              'BREAK',
              formatMinutes(breakTotal),
              breakColor,
            ),
            const SizedBox(width: 8),
            _summaryChip(
              'OVERTIME',
              '00:00',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$title: ',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomActions(bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 8 : 16,
        8,
        isMobile ? 8 : 16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (_canEdit) ...[
            OutlinedButton.icon(
              onPressed:
                  saving ? null : () => _saveAttendance(submit: false),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Draft'),
            ),
            if (widget.showSubmitButton)
              FilledButton.icon(
                onPressed:
                    saving ? null : () => _saveAttendance(submit: true),
                icon: saving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(
                  saving ? 'Submitting...' : 'Submit Attendance',
                ),
              )
            else
              FilledButton.icon(
                onPressed:
                    saving ? null : () => _saveAttendance(submit: false),
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Changes'),
              ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: submitted
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                submitted ? 'Submitted by Branch' : 'Not Submitted',
                style: TextStyle(
                  color: submitted
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  int calculateWorkMinutes(AttendanceDayControllers c) {
    return calculateMinutes(
      c.workingIn.text,
      c.workingOut.text,
    );
  }

  int calculateMinutes(String start, String end) {
    final startMinutes = parseTimeToMinutes(start);
    final endMinutes = parseTimeToMinutes(end);

    if (startMinutes == null || endMinutes == null) {
      return 0;
    }

    var difference = endMinutes - startMinutes;

    if (difference < 0) {
      difference += 24 * 60;
    }

    return difference;
  }

  int? parseTimeToMinutes(String value) {
    final text = value.trim();

    if (text.isEmpty) return null;

    final match = RegExp(
      r'^(\d{1,2})\s*[:.]\s*(\d{1,2})$',
    ).firstMatch(text);

    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return hour * 60 + minute;
  }

  String formatMinutes(int minutes) {
    if (minutes <= 0) return '00:00';

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${mins.toString().padLeft(2, '0')}';
  }
}

double minDouble(double a, double b) => a < b ? a : b;

class AttendanceDayControllers {
  final TextEditingController workingIn = TextEditingController();
  final TextEditingController workingOut = TextEditingController();

  final TextEditingController morningIn = TextEditingController();
  final TextEditingController morningOut = TextEditingController();

  final TextEditingController afternoonIn = TextEditingController();
  final TextEditingController afternoonOut = TextEditingController();

  // Existing database fields retained for compatibility.
  // The UI displays these as EVENING BREAK.
  final TextEditingController overtimeIn = TextEditingController();
  final TextEditingController overtimeOut = TextEditingController();

  bool otAuthorized = false;

  bool get hasData {
    return workingIn.text.trim().isNotEmpty ||
        workingOut.text.trim().isNotEmpty ||
        morningIn.text.trim().isNotEmpty ||
        morningOut.text.trim().isNotEmpty ||
        afternoonIn.text.trim().isNotEmpty ||
        afternoonOut.text.trim().isNotEmpty ||
        overtimeIn.text.trim().isNotEmpty ||
        overtimeOut.text.trim().isNotEmpty;
  }

  void dispose() {
    workingIn.dispose();
    workingOut.dispose();
    morningIn.dispose();
    morningOut.dispose();
    afternoonIn.dispose();
    afternoonOut.dispose();
    overtimeIn.dispose();
    overtimeOut.dispose();
  }
}
