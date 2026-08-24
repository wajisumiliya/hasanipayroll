import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'supabase_service.dart';

// ============================================================================
// ATTENDANCE DIALOG
// ============================================================================

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

  /// Branch: true. Admin: true + adminOnlyAfterSubmit. Employee: false.
  final bool editable;
  final bool showSubmitButton;
  final bool adminOnlyAfterSubmit;

  @override
  State<AttendanceDialog> createState() =>
      _AttendanceDialogState();
}

class _AttendanceDialogState
    extends State<AttendanceDialog> {
  late final List<AttendanceDayControllers>
  controllers;

  late final int daysInMonth;

  bool loading = true;
  bool saving = false;
  bool submitted = false;
  String? loadError;
  Timer? _liveRefreshTimer;

  // ==========================================================================
  // INIT / DISPOSE
  // ==========================================================================

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

    // Employee view is read-only, so it is safe to refresh automatically.
    // This makes a branch submission appear without the employee pressing Refresh.
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

  // ==========================================================================
  // EMPLOYEE HELPERS
  // ==========================================================================

  String _employeeId() {
    return (
        widget.employee['employee_id'] ??
            widget.employee['id'] ??
            ''
    ).toString();
  }

  String _employeeName() {
    return widget.employee['name']?.toString() ??
        'Employee';
  }

  String _department() {
    return widget.employee['department']
        ?.toString() ??
        '';
  }

  String _section() {
    return widget.employee['section']?.toString() ??
        '';
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() ==
        'true';
  }

  // ==========================================================================
  // LOAD ATTENDANCE
  // ==========================================================================

  Future<void> _loadAttendance({bool silent = false}) async {
    try {
      final employeeId = _employeeId();

      if (employeeId.trim().isEmpty) {
        throw Exception(
          'Employee ID is missing.',
        );
      }

      final start = DateTime(widget.month.year, widget.month.month, 1);
      final end = DateTime(widget.month.year, widget.month.month + 1, 1);

      // Employee queries are filtered at the database query itself so the
      // Employee Portal never asks Supabase for unsubmitted attendance.
      final List<Map<String, dynamic>> allRows = widget.editable
          ? await SupabaseService.getAttendanceByEmployeeMonth(
              employeeId,
              widget.month.year,
              widget.month.month,
            )
          : List<Map<String, dynamic>>.from(
              await SupabaseService.client
                  .from('attendance')
                  .select()
                  .eq('employee_id', employeeId)
                  .eq('is_submitted', true)
                  .gte('attendance_date', start.toIso8601String().substring(0, 10))
                  .lt('attendance_date', end.toIso8601String().substring(0, 10))
                  .order('attendance_date'),
            );

      // Only submitted rows are visible outside the Branch Portal.
      final rows = widget.editable
          ? allRows
          : allRows;

      submitted = allRows.any((row) => _toBool(row['is_submitted']));

      // For admin view, the employee can only be edited after Branch submission.
      // For employee view, rows are always read-only.

      for (final row in rows) {
        final date = DateTime.tryParse(
          (row['attendance_date'] ?? '')
              .toString(),
        );

        if (date == null) continue;

        if (date.year != widget.month.year ||
            date.month != widget.month.month) {
          continue;
        }

        if (date.day < 1 ||
            date.day > daysInMonth) {
          continue;
        }

        final c = controllers[date.day - 1];

        c.workingIn.text = (
            row['check_in'] ??
                row['working_in'] ??
                ''
        ).toString();

        c.workingOut.text = (
            row['check_out'] ??
                row['working_out'] ??
                ''
        ).toString();

        c.morningIn.text =
            (row['morning_in'] ?? '').toString();

        c.morningOut.text =
            (row['morning_out'] ?? '').toString();

        c.afternoonIn.text =
            (row['afternoon_in'] ?? '').toString();

        c.afternoonOut.text =
            (row['afternoon_out'] ?? '').toString();

        // IMPORTANT:
        // These database columns are kept for compatibility,
        // but the UI treats them as EVENING BREAK.
        c.overtimeIn.text =
            (row['overtime_in'] ?? '').toString();

        c.overtimeOut.text =
            (row['overtime_out'] ?? '').toString();

        c.otAuthorized =
            _toBool(row['ot_authorized']);
      }
    } catch (e) {
      loadError = e.toString();
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  bool get _canEdit {
    if (!widget.editable) return false;
    if (widget.adminOnlyAfterSubmit) return submitted;
    return true;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Dialog(
        child: SizedBox(
          width: 400,
          height: 250,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (loadError != null) {
      return Dialog(
        child: SizedBox(
          width: 450,
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 55,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Unable to load attendance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  loadError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: saving
                          ? null
                          : () {
                        Navigator.of(
                          context,
                        ).pop();
                      },
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 12),
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
                      icon: const Icon(
                        Icons.refresh,
                      ),
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
      insetPadding: const EdgeInsets.all(10),
      child: SizedBox(
        width: 1250,
        height:
        MediaQuery.of(context).size.height *
            .94,
        child: Column(
          children: [
            _attendanceDialogHeader(),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child:
                      _workingAttendanceCard(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child:
                      _breakAttendanceCard(),
                    ),
                  ],
                ),
              ),
            ),

            // FIXED:
            // No positional arguments are passed.
            _attendanceSummary(),

            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration:
              const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    child: const Text('Close'),
                  ),
                  const Spacer(),
                  if (_canEdit) ...[
                    OutlinedButton.icon(
                      onPressed: saving ? null : () => _saveAttendance(submit: false),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Draft'),
                    ),
                    const SizedBox(width: 10),
                    if (widget.showSubmitButton)
                      FilledButton.icon(
                        onPressed: saving ? null : () => _saveAttendance(submit: true),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(saving ? 'Submitting...' : 'Submit Attendance'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: saving ? null : () => _saveAttendance(submit: false),
                        icon: const Icon(Icons.save),
                        label: const Text('Save Changes'),
                      ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: submitted ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        submitted ? 'Submitted by Branch' : 'Not Submitted',
                        style: TextStyle(
                          color: submitted ? Colors.green.shade700 : Colors.orange.shade700,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SAVE ATTENDANCE
  // ==========================================================================

  Future<void> _saveAttendance({required bool submit}) async {
    if (saving) return;

    final employeeId = _employeeId();

    if (employeeId.trim().isEmpty) {
      _showError(
        'Cannot save attendance: employee ID is missing.',
      );
      return;
    }

    final employeeBranchId = (
        widget.employee['branch_id'] ??
            widget.employee['branchId'] ??
            widget.branchId
    ).toString();

    setState(() {
      saving = true;
    });

    var savedRows = 0;

    try {
      for (var day = 1;
      day <= daysInMonth;
      day++) {
        final row = controllers[day - 1];

        if (!row.hasData) {
          continue;
        }

        // ================================================================
        // VALIDATE TIME INPUTS
        // ================================================================

        final timeFields = <String, String>{
          'Working In': row.workingIn.text,
          'Working Out': row.workingOut.text,
          'Morning In': row.morningIn.text,
          'Morning Out': row.morningOut.text,
          'Afternoon In':
          row.afternoonIn.text,
          'Afternoon Out':
          row.afternoonOut.text,

          // Kept as overtime_in/out in database,
          // but used as EVENING BREAK.
          'Evening In': row.overtimeIn.text,
          'Evening Out': row.overtimeOut.text,
        };

        for (final entry
        in timeFields.entries) {
          final value = entry.value.trim();

          if (value.isNotEmpty &&
              parseTimeToMinutes(value) ==
                  null) {
            throw Exception(
              'Invalid ${entry.key} time on '
                  '${DateFormat('dd MMM yyyy').format(
                DateTime(
                  widget.month.year,
                  widget.month.month,
                  day,
                ),
              )}. '
                  'Use HH:MM, e.g. 08:30.',
            );
          }
        }

        // ================================================================
        // CALCULATE WORK
        // ================================================================

        final workMinutes =
        calculateWorkMinutes(row);

        // ================================================================
        // CALCULATE BREAKS
        // ================================================================

        final morningMinutes =
        calculateMinutes(
          row.morningIn.text,
          row.morningOut.text,
        );

        final afternoonMinutes =
        calculateMinutes(
          row.afternoonIn.text,
          row.afternoonOut.text,
        );

        // IMPORTANT:
        // EVENING / OT COLUMN IS A BREAK.
        // It is NOT overtime.
        final eveningBreakMinutes =
        calculateMinutes(
          row.overtimeIn.text,
          row.overtimeOut.text,
        );

        final breakMinutes =
            morningMinutes +
                afternoonMinutes +
                eveningBreakMinutes;

        // ================================================================
        // SAVE
        // ================================================================

        await SupabaseService
            .saveMonthlyAttendanceRow(
          employeeId: employeeId,
          branchId: employeeBranchId,
          date: DateTime(
            widget.month.year,
            widget.month.month,
            day,
          ),

          // WORK
          workingIn:
          row.workingIn.text.trim(),
          workingOut:
          row.workingOut.text.trim(),

          // MORNING BREAK
          morningIn:
          row.morningIn.text.trim(),
          morningOut:
          row.morningOut.text.trim(),

          // AFTERNOON BREAK
          afternoonIn:
          row.afternoonIn.text.trim(),
          afternoonOut:
          row.afternoonOut.text.trim(),

          // EVENING BREAK
          //
          // Database column names remain overtime_in/out
          // for compatibility with the existing schema.
          overtimeIn:
          row.overtimeIn.text.trim(),
          overtimeOut:
          row.overtimeOut.text.trim(),

          // Do NOT treat evening as overtime.
          // Authorization is retained only for compatibility.
          otAuthorized:
          false,

          // CALCULATED
          workMinutes:
          workMinutes,
          breakMinutes:
          breakMinutes,
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
            .gte('attendance_date', start.toIso8601String().substring(0, 10))
            .lt('attendance_date', end.toIso8601String().substring(0, 10));

        submitted = true;
      }

      if (!mounted) return;

      setState(() {
        saving = false;
      });

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      _showError(
        'Attendance was NOT saved:\n$e',
      );
    }
  }

  // ==========================================================================
  // ERROR MESSAGE
  // ==========================================================================

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

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _attendanceDialogHeader() {
    final name = _employeeName();
    final id = _employeeId();
    final department = _department();
    final section = _section();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      color: const Color(0xFF15965D),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              color: Color(0xFF15965D),
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    id,
                    department,
                    section,
                  ]
                      .where(
                        (v) => v.isNotEmpty,
                  )
                      .join(' • '),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(widget.month),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                submitted ? 'SUBMITTED' : 'DRAFT',
                style: TextStyle(
                  color: submitted ? Colors.white : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WORK ATTENDANCE
  // ==========================================================================

  Widget _workingAttendanceCard() {
    const blue = Color(0xFF15965D);

    return _attendanceTableCard(
      title: 'WORK ATTENDANCE',
      color: blue,
      child: Column(
        children: [
          _workHeader(blue),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: daysInMonth,
                itemBuilder: (
                    context,
                    index,
                    ) {
                  final day = index + 1;
                  final c = controllers[index];

                  return _workRow(
                    day,
                    c,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workHeader(Color color) {
    return Container(
      height: 42,
      color: const Color(0xFFE7F7EF),
      child: Row(
        children: [
          _headerCell(
            'DATE',
            55,
            color,
          ),
          _headerCell(
            'CHECK IN',
            115,
            color,
          ),
          _headerCell(
            'CHECK OUT',
            115,
            color,
          ),
          _headerCell(
            'TOTAL',
            100,
            color,
          ),
          Expanded(
            child: Container(
              height: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: color,
                  ),
                ),
              ),
              child: const Text(
                'STATUS',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workRow(
      int day,
      AttendanceDayControllers c,
      ) {
    final total = calculateWorkMinutes(c);

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _tableCell(
            day.toString(),
            55,
            bold: true,
          ),
          _timeInput(
            c.workingIn,
            115,
          ),
          _timeInput(
            c.workingOut,
            115,
          ),
          _tableCell(
            formatMinutes(total),
            100,
            bold: true,
            color: total > 0
                ? const Color(0xFF15965D)
                : Colors.black54,
          ),
          Expanded(
            child: Container(
              height: double.infinity,
              alignment: Alignment.center,
              decoration:
              const BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Color(0xFF15965D),
                  ),
                  bottom: BorderSide(
                    color: Color(0xFF15965D),
                  ),
                ),
              ),
              child: Text(
                total > 0 ? 'RECORDED' : '-',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: total > 0
                      ? const Color(0xFF15965D)
                      : Colors.black38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BREAK ATTENDANCE
  // ==========================================================================

  Widget _breakAttendanceCard() {
    const red = Color(0xFF315AD9);

    return _attendanceTableCard(
      title: 'BREAK ATTENDANCE',
      color: red,
      child: Column(
        children: [
          _breakHeader(red),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: daysInMonth,
                itemBuilder: (
                    context,
                    index,
                    ) {
                  final day = index + 1;
                  final c = controllers[index];

                  // FIXED:
                  // _breakRow takes exactly 2 arguments.
                  return _breakRow(
                    day,
                    c,
                  );
                },
              ),
            ),
          ),
        ],
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
              _headerCell(
                'DATE',
                45,
                color,
              ),
              Expanded(
                child: _groupHeader(
                  'MORNING',
                  color,
                ),
              ),
              Expanded(
                child: _groupHeader(
                  'AFTERNOON',
                  color,
                ),
              ),
              Expanded(
                child: _groupHeader(
                  'EVENING BREAK',
                  color,
                ),
              ),
              _headerCell(
                'TOTAL',
                80,
                color,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 34,
          child: Row(
            children: [
              _headerCell(
                '',
                45,
                color,
              ),
              Expanded(
                child: _subHeader(
                  'IN',
                  color,
                ),
              ),
              Expanded(
                child: _subHeader(
                  'OUT',
                  color,
                ),
              ),
              Expanded(
                child: _subHeader(
                  'IN',
                  color,
                ),
              ),
              Expanded(
                child: _subHeader(
                  'OUT',
                  color,
                ),
              ),
              Expanded(
                child: _subHeader(
                  'IN',
                  color,
                ),
              ),
              Expanded(
                child: _subHeader(
                  'OUT',
                  color,
                ),
              ),
              _headerCell(
                '',
                80,
                color,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // BREAK ROW
  // ==========================================================================

  Widget _breakRow(
      int day,
      AttendanceDayControllers c,
      ) {
    final morning = calculateMinutes(
      c.morningIn.text,
      c.morningOut.text,
    );

    final afternoon = calculateMinutes(
      c.afternoonIn.text,
      c.afternoonOut.text,
    );

    // IMPORTANT:
    // overtimeIn/out are used for EVENING BREAK.
    // They are NEVER added to overtime.
    final evening = calculateMinutes(
      c.overtimeIn.text,
      c.overtimeOut.text,
    );

    final breakTotal =
        morning +
            afternoon +
            evening;

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _tableCell(
            day.toString(),
            45,
            bold: true,
          ),

          // ==============================================================
          // MORNING BREAK
          // ==============================================================

          Expanded(
            child: _smallTimeInput(
              c.morningIn,
            ),
          ),

          Expanded(
            child: _smallTimeInput(
              c.morningOut,
            ),
          ),

          // ==============================================================
          // AFTERNOON BREAK
          // ==============================================================

          Expanded(
            child: _smallTimeInput(
              c.afternoonIn,
            ),
          ),

          Expanded(
            child: _smallTimeInput(
              c.afternoonOut,
            ),
          ),

          // ==============================================================
          // EVENING BREAK
          //
          // IMPORTANT:
          // These use overtimeIn/overtimeOut because the database already
          // has those columns. They are DISPLAYED as Evening Break and
          // CALCULATED as break time.
          // ==============================================================

          Expanded(
            child: _smallTimeInput(
              c.overtimeIn,
            ),
          ),

          Expanded(
            child: _smallTimeInput(
              c.overtimeOut,
            ),
          ),

          // ==============================================================
          // TOTAL BREAK
          // ==============================================================

          Container(
            width: 80,
            height: double.infinity,
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Color(0xFF315AD9),
                ),
                bottom: BorderSide(
                  color: Color(0xFF315AD9),
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              formatMinutes(breakTotal),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF315AD9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TABLE CARD
  // ==========================================================================

  Widget _attendanceTableCard({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: color,
          width: 1.5,
        ),
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
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TABLE HELPERS
  // ==========================================================================

  Widget _headerCell(
      String text,
      double width,
      Color color,
      ) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: color,
          ),
          bottom: BorderSide(
            color: color,
          ),
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

  Widget _groupHeader(
      String text,
      Color color,
      ) {
    return Container(
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        border: Border(
          right: BorderSide(
            color: color,
          ),
          bottom: BorderSide(
            color: color,
          ),
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

  Widget _subHeader(
      String text,
      Color color,
      ) {
    return Container(
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: color,
          ),
          bottom: BorderSide(
            color: color,
          ),
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
      decoration:
      const BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Color(0xFF15965D),
          ),
          bottom: BorderSide(
            color: Color(0xFF15965D),
          ),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: bold
              ? FontWeight.w800
              : FontWeight.normal,
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
      decoration:
      const BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Color(0xFF15965D),
          ),
          bottom: BorderSide(
            color: Color(0xFF15965D),
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: !_canEdit,
        enabled: _canEdit,
        onChanged: (_) {
          if (mounted) {
            setState(() {});
          }
        },
        textAlign: TextAlign.center,
        keyboardType: TextInputType.datetime,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        decoration:
        const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding:
          EdgeInsets.symmetric(
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

  // ==========================================================================
  // SMALL BREAK TIME INPUT
  //
  // FIXED:
  // This accepts ONLY the controller.
  // It rebuilds the dialog on every change so the break total and
  // monthly summary update immediately.
  // ==========================================================================

  Widget _smallTimeInput(
      TextEditingController controller,
      ) {
    return Container(
      height: double.infinity,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Color(0xFF315AD9),
          ),
          bottom: BorderSide(
            color: Color(0xFF315AD9),
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: !_canEdit,
        enabled: _canEdit,
        onChanged: (_) {
          if (mounted) {
            setState(() {});
          }
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
          contentPadding:
          EdgeInsets.symmetric(
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

  // ==========================================================================
  // ATTENDANCE SUMMARY
  // ==========================================================================

  Widget _attendanceSummary() {
    var workTotal = 0;
    var breakTotal = 0;

    for (var i = 0;
    i < daysInMonth;
    i++) {
      final c = controllers[i];

      // WORK
      workTotal += calculateWorkMinutes(c);

      // MORNING BREAK
      breakTotal += calculateMinutes(
        c.morningIn.text,
        c.morningOut.text,
      );

      // AFTERNOON BREAK
      breakTotal += calculateMinutes(
        c.afternoonIn.text,
        c.afternoonOut.text,
      );

      // EVENING BREAK
      //
      // This is intentionally NOT overtime.
      breakTotal += calculateMinutes(
        c.overtimeIn.text,
        c.overtimeOut.text,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        border: Border.all(
          color: Colors.black12,
        ),
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
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 20),
            _summaryChip(
              'WORK',
              formatMinutes(workTotal),
              const Color(0xFF15965D),
            ),
            const SizedBox(width: 10),
            _summaryChip(
              'BREAK',
              formatMinutes(breakTotal),
              const Color(0xFF315AD9),
            ),
            const SizedBox(width: 10),

            // Evening/OT is a break, therefore OT is ZERO.
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

  Widget _summaryChip(
      String title,
      String value,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
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
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TIME CALCULATIONS
  // ==========================================================================

  int calculateWorkMinutes(
      AttendanceDayControllers c,
      ) {
    return calculateMinutes(
      c.workingIn.text,
      c.workingOut.text,
    );
  }

  int calculateMinutes(
      String start,
      String end,
      ) {
    final startMinutes =
    parseTimeToMinutes(start);

    final endMinutes =
    parseTimeToMinutes(end);

    if (startMinutes == null ||
        endMinutes == null) {
      return 0;
    }

    var difference =
        endMinutes - startMinutes;

    // Overnight shift.
    if (difference < 0) {
      difference += 24 * 60;
    }

    return difference;
  }

  int? parseTimeToMinutes(
      String value,
      ) {
    final text = value.trim();

    if (text.isEmpty) {
      return null;
    }

    final match = RegExp(
      r'^(\d{1,2})\s*[:.]\s*(\d{1,2})$',
    ).firstMatch(text);

    if (match == null) {
      return null;
    }

    final hour = int.tryParse(
      match.group(1)!,
    );

    final minute = int.tryParse(
      match.group(2)!,
    );

    if (hour == null ||
        minute == null) {
      return null;
    }

    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return hour * 60 + minute;
  }

  String formatMinutes(
      int minutes,
      ) {
    if (minutes <= 0) {
      return '00:00';
    }

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${mins.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// ATTENDANCE DAY CONTROLLERS
// ============================================================================

class AttendanceDayControllers {
  final TextEditingController workingIn =
  TextEditingController();

  final TextEditingController workingOut =
  TextEditingController();

  final TextEditingController morningIn =
  TextEditingController();

  final TextEditingController morningOut =
  TextEditingController();

  final TextEditingController afternoonIn =
  TextEditingController();

  final TextEditingController afternoonOut =
  TextEditingController();

  // ==========================================================================
  // IMPORTANT:
  // These names remain "overtime" ONLY because your existing database uses
  // overtime_in / overtime_out.
  //
  // In the Branch Portal they are now treated as:
  //
  //     EVENING BREAK IN
  //     EVENING BREAK OUT
  //
  // They are NOT calculated as overtime.
  // ==========================================================================

  final TextEditingController overtimeIn =
  TextEditingController();

  final TextEditingController overtimeOut =
  TextEditingController();

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