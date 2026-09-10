import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'supabase_service.dart';
import '../services/attendance_pdf_service.dart';

// ============================================================================
// ATTENDANCE DIALOG
// ============================================================================

/// Attendance / payroll calculation rules:
/// - Entered working time defaults to Present; Late is not assigned automatically.
/// - Unpaid: automatically based on attendance rows marked unpaid by Admin.
/// - Public holiday: only counted when Admin marks the day as public holiday
///   and the employee actually worked.
/// - OT requests have no eligibility gate; displayed OT is calculated from
///   net hours and Admin controls approval.
/// The payroll service should consume these attendance totals.
///
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
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  late final List<AttendanceDayControllers> controllers;

  late final int daysInMonth;

  bool loading = true;
  bool saving = false;
  bool printingAttendance = false;
  bool submitted = false;
  final Set<int> _submittedDays = <int>{};
  bool _showBreakAttendanceOnMobile = false;
  String? loadError;
  Timer? _liveRefreshTimer;

  double _requiredWorkHours = 7.5;
  bool _salaryRuleLoaded = false;
  final Map<int, Map<String, dynamic>> _weeklyRoster = {};
  final Map<int, Map<String, dynamic>> _dailyRoster = {};

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
    return (widget.employee['employee_id'] ?? widget.employee['id'] ?? '')
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
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  int _intValue(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _loadSalaryWorkingRule(String employeeId) async {
    try {
      Map<String, dynamic>? salary;

      // Your project has used both spellings in earlier schema versions.
      // Prefer epf_catagory, then fall back to epf_category.
      try {
        final rows = await SupabaseService.client
            .from('employee_salary_defaults')
            .select('eis_applicable,epf_catagory')
            .eq('employee_id', employeeId)
            .limit(1);
        if (rows.isNotEmpty) {
          salary = Map<String, dynamic>.from(rows.first);
        }
      } catch (_) {
        final rows = await SupabaseService.client
            .from('employee_salary_defaults')
            .select('eis_applicable,epf_category')
            .eq('employee_id', employeeId)
            .limit(1);
        if (rows.isNotEmpty) {
          salary = Map<String, dynamic>.from(rows.first);
        }
      }

      if (salary != null) {
        final epfCategory =
            (salary['epf_catagory'] ?? salary['epf_category'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
        final eisApplicable = _toBool(salary['eis_applicable']);

        // normal1 has 7:30 target and can receive approved OT.
        // EIS-applicable employees also have 7:30 target and can receive OT.
        // EIS-not-applicable employees have 10:30 target and no OT.
        if (epfCategory == 'normal1' || eisApplicable) {
          _requiredWorkHours = 7.5;
        } else {
          _requiredWorkHours = 10.5;
        }
      }
    } finally {
      _salaryRuleLoaded = true;
    }
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

      // Admin needs the employee's salary rule to decide whether OT can be
      // authorized for a particular day.
      if (widget.adminOnlyAfterSubmit && !_salaryRuleLoaded) {
        await _loadSalaryWorkingRule(employeeId);
      }

      final rosterRows = await SupabaseService.getMonthlyRosters(
        branchId: widget.branchId,
        year: widget.month.year,
        month: widget.month.month,
        employeeId: employeeId,
      );
      _weeklyRoster
        ..clear()
        ..addEntries(rosterRows
            .map((row) => MapEntry(_intValue(row['week_number']), row)));
      final dailyRosterRows = await SupabaseService.getDailyRosters(
        branchId: widget.branchId,
        employeeId: employeeId,
        start: DateTime(widget.month.year, widget.month.month, 1),
        end: DateTime(widget.month.year, widget.month.month + 1, 1),
      );
      _dailyRoster
        ..clear()
        ..addEntries(dailyRosterRows.map((row) {
          final date = DateTime.parse(row['roster_date'].toString());
          return MapEntry(date.day, row);
        }));

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
                  .gte('attendance_date',
                      start.toIso8601String().substring(0, 10))
                  .lt('attendance_date', end.toIso8601String().substring(0, 10))
                  .order('attendance_date'),
            );

      // Only submitted rows are visible outside the Branch Portal.
      final rows = widget.editable ? allRows : allRows;

      _submittedDays.clear();
      for (final row in allRows) {
        if (!_toBool(row['is_submitted'])) continue;
        final submittedDate =
            DateTime.tryParse((row['attendance_date'] ?? '').toString());
        if (submittedDate != null) _submittedDays.add(submittedDate.day);
      }
      submitted = _submittedDays.isNotEmpty;

      // For admin view, the employee can only be edited after Branch submission.
      // For employee view, rows are always read-only.

      for (final row in rows) {
        final date = DateTime.tryParse(
          (row['attendance_date'] ?? '').toString(),
        );

        if (date == null) continue;

        if (date.year != widget.month.year ||
            date.month != widget.month.month) {
          continue;
        }

        if (date.day < 1 || date.day > daysInMonth) {
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

        // IMPORTANT:
        // These database columns are kept for compatibility,
        // but the UI treats them as EVENING BREAK.
        c.overtimeIn.text = (row['overtime_in'] ?? '').toString();

        c.overtimeOut.text = (row['overtime_out'] ?? '').toString();

        c.status = (row['status'] ?? '').toString().trim();
        c.otRequested = _toBool(row['ot_requested']);
        c.otAuthorized = _toBool(row['ot_authorized']);
        c.isUnpaid = _toBool(row['is_unpaid']);
        c.isPublicHoliday = _toBool(row['is_public_holiday']);

        c.savedNetWorkingMinutes = _intValue(row['net_working_minutes']);
        c.savedOvertimeMinutes = _intValue(row['overtime_minutes']);
        c.approvedOtMinutes = _intValue(row['approved_ot_minutes']);
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

  bool _canEditDay(int day) {
    if (!_canEdit) return false;
    if (widget.adminOnlyAfterSubmit) return true;
    return !_submittedDays.contains(day);
  }

  int? get _nextSubmissionEnd {
    for (final checkpoint in <int>[10, 20, daysInMonth]) {
      if (!_submittedDays.contains(checkpoint)) return checkpoint;
    }
    return null;
  }

  bool get _canSubmitCheckpoint => _nextSubmissionEnd != null && !saving;

  String get _submissionButtonLabel {
    final end = _nextSubmissionEnd;
    if (end == null) return 'Month Fully Submitted';
    if (saving) return 'Submitting...';
    return 'Submit Days 1-$end';
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
                  mainAxisAlignment: MainAxisAlignment.center,
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
        height: MediaQuery.of(context).size.height * .94,
        child: Column(
          children: [
            _attendanceDialogHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 720) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _workingAttendanceCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _breakAttendanceCard()),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 8)
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: () => setState(() =>
                                      _showBreakAttendanceOnMobile = false),
                                  icon: const Icon(Icons.schedule_outlined),
                                  label: const Text('Work'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        !_showBreakAttendanceOnMobile
                                            ? const Color(0xFF3155D9)
                                            : Colors.transparent,
                                    foregroundColor:
                                        !_showBreakAttendanceOnMobile
                                            ? Colors.white
                                            : const Color(0xFF3155D9),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: () => setState(() =>
                                      _showBreakAttendanceOnMobile = true),
                                  icon:
                                      const Icon(Icons.free_breakfast_outlined),
                                  label: const Text('Break'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        _showBreakAttendanceOnMobile
                                            ? const Color(0xFFD92F2F)
                                            : Colors.transparent,
                                    foregroundColor:
                                        _showBreakAttendanceOnMobile
                                            ? Colors.white
                                            : const Color(0xFFD92F2F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                              scale: Tween<double>(begin: .92, end: 1)
                                  .animate(animation),
                              child: FadeTransition(
                                  opacity: animation, child: child),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey(_showBreakAttendanceOnMobile),
                              child: _showBreakAttendanceOnMobile
                                  ? _breakAttendanceCard()
                                  : _workingAttendanceCard(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            _attendanceSummary(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
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
                  const Expanded(
                    child: Center(child: _AttendanceSportsCats()),
                  ),
                  OutlinedButton.icon(
                    onPressed: printingAttendance ? null : _printAttendance,
                    icon: printingAttendance
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    label:
                        Text(printingAttendance ? 'Preparing...' : 'Print A4'),
                  ),
                  const SizedBox(width: 10),
                  if (_canEdit) ...[
                    OutlinedButton.icon(
                      onPressed:
                          saving ? null : () => _saveAttendance(submit: false),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Draft'),
                    ),
                    const SizedBox(width: 10),
                    if (widget.showSubmitButton)
                      FilledButton.icon(
                        onPressed: _canSubmitCheckpoint
                            ? () => _saveAttendance(submit: true)
                            : null,
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
                        label: Text(_submissionButtonLabel),
                      )
                    else
                      FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () => _saveAttendance(submit: false),
                        icon: const Icon(Icons.save),
                        label: const Text('Save Changes'),
                      ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: submitted
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Text(
                        submitted ? 'Submitted by Branch' : 'Not Submitted',
                        style: TextStyle(
                          color: submitted
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
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

  Future<bool> _reviewDailyRoster(int submissionEnd) async {
    final firstDay = List<int>.generate(submissionEnd, (index) => index + 1)
        .firstWhere((day) => !_submittedDays.contains(day), orElse: () => 0);
    if (firstDay == 0) return true;

    const shifts = <String, List<dynamic>>{
      '09:00 - 17:30 (60 min break)': ['09:00', '17:30', 60],
      '09:00 - 18:00 (90 min break)': ['09:00', '18:00', 90],
      '10:00 - 19:00 (90 min break)': ['10:00', '19:00', 90],
      '11:00 - 20:00 (90 min break)': ['11:00', '20:00', 90],
      '12:00 - 21:00 (90 min break)': ['12:00', '21:00', 90],
      '13:00 - 22:00 (90 min break)': ['13:00', '22:00', 90],
      '09:00 - 21:00 (90 min break)': ['09:00', '21:00', 90],
      '10:00 - 22:00 (90 min break)': ['10:00', '22:00', 90],
    };
    const nonWorking = <String>['OFF', 'MC', 'PL', 'AL', 'EL', 'PH', 'UNPAID'];
    final choices = <int, String?>{};

    for (var day = firstDay; day <= submissionEnd; day++) {
      final existing = _dailyRoster[day];
      final type = existing?['assignment_type']?.toString() ?? '';
      if (type == 'SHIFT') {
        final start = _shortRosterTime(existing?['shift_start']);
        final end = _shortRosterTime(existing?['shift_end']);
        final breaks = _intValue(existing?['break_minutes']);
        for (final entry in shifts.entries) {
          if (entry.value[0] == start &&
              entry.value[1] == end &&
              entry.value[2] == breaks) {
            choices[day] = entry.key;
            break;
          }
        }
      } else if (nonWorking.contains(type)) {
        choices[day] = type;
      } else if (nonWorking.contains(controllers[day - 1].status)) {
        choices[day] = controllers[day - 1].status;
      }
    }

    bool savingRoster = false;
    String? rosterError;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.calendar_month, color: Color(0xFF3155D9)),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Assign roster: days $firstDay-$submissionEnd')),
          ]),
          content: SizedBox(
            width: 560,
            height: MediaQuery.of(context).size.height * .68,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${_employeeName()} • ${DateFormat('MMMM yyyy').format(widget.month)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              const Text(
                'Assign a shift for each working day. For a non-working day choose OFF, MC, leave, public holiday, or unpaid.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: submissionEnd - firstDay + 1,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final day = firstDay + index;
                    final date =
                        DateTime(widget.month.year, widget.month.month, day);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        SizedBox(
                          width: 115,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('EEE, dd MMM').format(date),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(
                                    controllers[day - 1].status.isEmpty
                                        ? 'Attendance: not set'
                                        : 'Attendance: ${controllers[day - 1].status}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.black54)),
                              ]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: choices[day],
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Shift / status',
                                isDense: true,
                                border: OutlineInputBorder()),
                            items: [
                              ...shifts.keys.map((label) => DropdownMenuItem(
                                  value: label,
                                  child: Text(label,
                                      overflow: TextOverflow.ellipsis))),
                              const DropdownMenuItem(
                                  enabled: false, child: Divider()),
                              ...nonWorking.map((status) => DropdownMenuItem(
                                  value: status, child: Text(status))),
                            ],
                            onChanged: savingRoster
                                ? null
                                : (value) => setDialogState(() {
                                      choices[day] = value;
                                      rosterError = null;
                                    }),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),
              if (rosterError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(rosterError!,
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: savingRoster
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: savingRoster
                  ? null
                  : () async {
                      final missing = <int>[
                        for (var day = firstDay; day <= submissionEnd; day++)
                          if (choices[day] == null) day
                      ];
                      if (missing.isNotEmpty) {
                        setDialogState(() => rosterError =
                            'Assign a roster or status for day(s): ${missing.join(', ')}.');
                        return;
                      }
                      setDialogState(() {
                        savingRoster = true;
                        rosterError = null;
                      });
                      try {
                        final updatedAt =
                            DateTime.now().toUtc().toIso8601String();
                        final rows = <Map<String, dynamic>>[];
                        for (var day = firstDay; day <= submissionEnd; day++) {
                          final choice = choices[day]!;
                          final shift = shifts[choice];
                          final type = shift == null ? choice : 'SHIFT';
                          final row = <String, dynamic>{
                            'branch_id': widget.branchId,
                            'employee_id': _employeeId(),
                            'roster_date': DateFormat('yyyy-MM-dd').format(
                                DateTime(widget.month.year, widget.month.month,
                                    day)),
                            'assignment_type': type,
                            'shift_start': shift?[0],
                            'shift_end': shift?[1],
                            'break_minutes': shift?[2] ?? 0,
                            'updated_at': updatedAt,
                          };
                          rows.add(row);
                          _dailyRoster[day] = row;
                          final attendance = controllers[day - 1];
                          if (shift == null) {
                            attendance.status = type;
                            attendance.isPublicHoliday = type == 'PH';
                            attendance.isUnpaid = type == 'UNPAID';
                          } else if (nonWorking.contains(attendance.status)) {
                            attendance.status = '';
                            attendance.isPublicHoliday = false;
                            attendance.isUnpaid = false;
                          }
                        }
                        await SupabaseService.saveDailyRosters(rows);
                        if (dialogContext.mounted)
                          Navigator.pop(dialogContext, true);
                      } catch (error) {
                        setDialogState(() {
                          savingRoster = false;
                          rosterError = 'Unable to save daily roster: $error';
                        });
                      }
                    },
              icon: savingRoster
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: Text(savingRoster ? 'Saving...' : 'Continue to Submit'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
    return result == true;
  }

  String _shortRosterTime(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  Future<void> _printAttendance() async {
    if (printingAttendance) return;
    setState(() => printingAttendance = true);

    try {
      final days = List<AttendancePrintDay>.generate(daysInMonth, (index) {
        final day = index + 1;
        final c = controllers[index];
        final work = calculateWorkMinutes(c);
        final breaks = _calculateBreakMinutes(c);
        final net = (work - breaks).clamp(0, 24 * 60).toInt();
        return AttendancePrintDay(
          day: day,
          workingIn: c.workingIn.text,
          workingOut: c.workingOut.text,
          morningIn: c.morningIn.text,
          morningOut: c.morningOut.text,
          afternoonIn: c.afternoonIn.text,
          afternoonOut: c.afternoonOut.text,
          eveningIn: c.overtimeIn.text,
          eveningOut: c.overtimeOut.text,
          status: _calculatedAttendanceStatus(day, c),
          workMinutes: work,
          breakMinutes: breaks,
          netMinutes: net,
          overtimeMinutes: _calculateDailyOtMinutes(
            day: day,
            c: c,
            netWorkingMinutes: net,
          ),
          lateMinutes: _calculateLateMinutes(day, c),
        );
      });

      final bytes = await AttendancePdfService.build(
        employeeId: _employeeId(),
        employeeName: _employeeName(),
        department: _department(),
        section: _section(),
        branchId: widget.branchId,
        month: widget.month,
        days: days,
      );
      await Printing.layoutPdf(
        name:
            'attendance_${_employeeId()}_${DateFormat('yyyy_MM').format(widget.month)}.pdf',
        format: PdfPageFormat.a4,
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (mounted) {
        _showError('Unable to print attendance:\n$error');
      }
    } finally {
      if (mounted) setState(() => printingAttendance = false);
    }
  }
  // ==========================================================================
  // SAVE ATTENDANCE
  // ==========================================================================

  Future<void> _saveAttendance({required bool submit}) async {
    if (saving) return;

    int? submissionEnd;
    if (submit) {
      submissionEnd = _nextSubmissionEnd;
      if (submissionEnd == null) return;
      final rosterReady = await _reviewDailyRoster(submissionEnd);
      if (!rosterReady || !mounted) return;

      final incompleteDays = <int>[
        for (var day = 1; day <= submissionEnd; day++)
          if (!_isNonWorkingDay(day, controllers[day - 1]) &&
              !_hasCompleteWorkingTime(controllers[day - 1]))
            day,
      ];
      if (incompleteDays.isNotEmpty) {
        _showError(
          'Attendance is still missing for working day(s): ${incompleteDays.join(', ')}. Enter attendance times, or choose OFF/MC/leave in the roster.',
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.lock_outline,
              color: Color(0xFF3155D9), size: 34),
          title: Text('Submit attendance for days 1-$submissionEnd?'),
          content: Text(
            'Are you sure you want to submit this attendance? Days 1-$submissionEnd will be locked and cannot be edited by the branch after submission.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Review Again'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.lock),
              label: const Text('Yes, Submit & Lock'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final employeeId = _employeeId();

    if (employeeId.trim().isEmpty) {
      _showError(
        'Cannot save attendance: employee ID is missing.',
      );
      return;
    }

    final employeeBranchId = (widget.employee['branch_id'] ??
            widget.employee['branchId'] ??
            widget.branchId)
        .toString();

    setState(() {
      saving = true;
    });

    var savedRows = 0;

    try {
      for (var day = 1; day <= daysInMonth; day++) {
        if (submit && day > submissionEnd!) continue;
        if (!widget.adminOnlyAfterSubmit && _submittedDays.contains(day)) {
          continue;
        }
        final row = controllers[day - 1];

        if (!row.hasData &&
            !(widget.adminOnlyAfterSubmit &&
                (row.otAuthorized || row.isUnpaid || row.isPublicHoliday))) {
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
          'Afternoon In': row.afternoonIn.text,
          'Afternoon Out': row.afternoonOut.text,

          // Kept as overtime_in/out in database,
          // but used as EVENING BREAK.
          'Evening In': row.overtimeIn.text,
          'Evening Out': row.overtimeOut.text,
        };

        for (final entry in timeFields.entries) {
          final value = entry.value.trim();

          if (!_isTimePlaceholder(value) && parseTimeToMinutes(value) == null) {
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

        final workMinutes = calculateWorkMinutes(row);

        // ================================================================
        // CALCULATE BREAKS
        // ================================================================

        final morningMinutes = calculateMinutes(
          row.morningIn.text,
          row.morningOut.text,
        );

        final afternoonMinutes = calculateMinutes(
          row.afternoonIn.text,
          row.afternoonOut.text,
        );

        // IMPORTANT:
        // EVENING / OT COLUMN IS A BREAK.
        // It is NOT overtime.
        final eveningBreakMinutes = calculateMinutes(
          row.overtimeIn.text,
          row.overtimeOut.text,
        );

        final breakMinutes =
            morningMinutes + afternoonMinutes + eveningBreakMinutes;

        // NET WORKING = WORKING PERIOD - ALL BREAKS.
        final netWorkingMinutes =
            (workMinutes - breakMinutes).clamp(0, 24 * 60).toInt();

        // OT is available only when the employee exceeds the required
        // working hours AND Admin has explicitly authorized OT.
        final dailyOtMinutes = _calculateDailyOtMinutes(
          day: day,
          c: row,
          netWorkingMinutes: netWorkingMinutes,
        );

        // ================================================================
        // SAVE
        // ================================================================

        await SupabaseService.saveMonthlyAttendanceRow(
          employeeId: employeeId,
          branchId: employeeBranchId,
          date: DateTime(
            widget.month.year,
            widget.month.month,
            day,
          ),

          // WORK
          workingIn: row.workingIn.text.trim(),
          workingOut: row.workingOut.text.trim(),

          // MORNING BREAK
          morningIn: row.morningIn.text.trim(),
          morningOut: row.morningOut.text.trim(),

          // AFTERNOON BREAK
          afternoonIn: row.afternoonIn.text.trim(),
          afternoonOut: row.afternoonOut.text.trim(),

          // EVENING BREAK
          //
          // Database column names remain overtime_in/out
          // for compatibility with the existing schema.
          overtimeIn: row.overtimeIn.text.trim(),
          overtimeOut: row.overtimeOut.text.trim(),

          status: _calculatedAttendanceStatus(day, row),
          otRequested: row.otRequested,
          otAuthorized: widget.adminOnlyAfterSubmit ? row.otAuthorized : false,

          // CALCULATED
          workMinutes: workMinutes,
          breakMinutes: breakMinutes,
        );

        // Keep the attendance table synchronized with the exact values shown
        // on this screen. These columns already exist in attendance.
        await SupabaseService.client
            .from('attendance')
            .update({
              'work_minutes': workMinutes,
              'break_minutes': breakMinutes,
              'net_working_minutes': netWorkingMinutes,
              'net_working_duration': formatMinutes(netWorkingMinutes),
              'overtime_minutes': dailyOtMinutes,
              'overtime_duration': formatMinutes(dailyOtMinutes),
              'ot_requested': row.otRequested,
              'ot_authorized':
                  widget.adminOnlyAfterSubmit ? row.otAuthorized : false,
              'is_unpaid': row.isUnpaid,
              'is_public_holiday': row.isPublicHoliday,
            })
            .eq('employee_id', employeeId)
            .eq('branch_id', employeeBranchId)
            .eq(
              'attendance_date',
              '${widget.month.year.toString().padLeft(4, '0')}-'
                  '${widget.month.month.toString().padLeft(2, '0')}-'
                  '${day.toString().padLeft(2, '0')}',
            );

        // Admin-only payroll flags are saved directly because the existing
        // SupabaseService method does not expose these columns.
        savedRows++;
      }

      if (savedRows == 0) {
        throw Exception(
          'Please enter attendance in at least one date row.',
        );
      }

      if (submit) {
        final start = DateTime(widget.month.year, widget.month.month, 1);
        final end = DateTime(
          widget.month.year,
          widget.month.month,
          submissionEnd! + 1,
        );

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

        _submittedDays.addAll(
          List<int>.generate(submissionEnd, (index) => index + 1),
        );
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
    const blue = Color(0xFF315AD9);

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
      color: const Color(0xFFE8EEFF),
      child: Row(
        children: [
          _headerCell(
            'DATE',
            55,
            color,
          ),
          _headerCell(
            'CHECK IN',
            95,
            color,
          ),
          _headerCell(
            'CHECK OUT',
            95,
            color,
          ),
          _headerCell(
            'TOTAL',
            75,
            color,
          ),
          _headerCell(
            'NET WORKING HOURS',
            105,
            color,
          ),
          _headerCell(
            'OVERTIME',
            75,
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
    final breakMinutes = _calculateBreakMinutes(c);
    final netWorkingMinutes = (total - breakMinutes).clamp(0, 24 * 60).toInt();
    final overtimeMinutes = _calculateDailyOtMinutes(
      day: day,
      c: c,
      netWorkingMinutes: netWorkingMinutes,
    );

    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _tableCell(day.toString(), 55, bold: true),
          _timeInput(
            c.workingIn,
            95,
            day: day,
            focusNode: c.workingInFocus,
            prevFocus: day > 1 ? controllers[day - 2].workingOutFocus : null,
            nextFocus: c.workingOutFocus,
          ),
          _timeInput(
            c.workingOut,
            95,
            day: day,
            focusNode: c.workingOutFocus,
            prevFocus: c.workingInFocus,
            nextFocus:
                day < daysInMonth ? controllers[day].workingInFocus : null,
          ),
          _tableCell(
            formatMinutes(total),
            75,
            bold: true,
            color: total > 0 ? const Color(0xFF315AD9) : Colors.black54,
          ),
          _tableCell(
            formatMinutes(netWorkingMinutes),
            105,
            bold: true,
            color: netWorkingMinutes > 0
                ? const Color(0xFF315AD9)
                : Colors.black54,
          ),
          _tableCell(
            formatMinutes(overtimeMinutes),
            75,
            bold: true,
            color:
                overtimeMinutes > 0 ? Colors.orange.shade800 : Colors.black38,
          ),
          Expanded(
            child: Container(
              height: double.infinity,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFF15965D)),
                  bottom: BorderSide(color: Color(0xFF15965D)),
                ),
              ),
              child: _statusCell(day, c, netWorkingMinutes),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ADMIN PAYROLL OPTIONS
  // ==========================================================================

  bool _isAdminView() => widget.adminOnlyAfterSubmit;

  int _calculateBreakMinutes(AttendanceDayControllers c) {
    return calculateMinutes(c.morningIn.text, c.morningOut.text) +
        calculateMinutes(c.afternoonIn.text, c.afternoonOut.text) +
        calculateMinutes(c.overtimeIn.text, c.overtimeOut.text);
  }

  int _calculateDailyOtMinutes({
    required int day,
    required AttendanceDayControllers c,
    required int netWorkingMinutes,
  }) {
    // Overtime is never inferred from long working hours. It appears only
    // after the employee request has been approved by Admin for this date.
    return c.otAuthorized ? c.approvedOtMinutes : 0;
  }

  int? _clockMinutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  bool _isTimePlaceholder(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ||
        normalized == '-' ||
        normalized == '--' ||
        normalized == '--:--';
  }

  bool _isNonWorkingDay(int day, AttendanceDayControllers c) {
    const nonWorkingStatuses = {
      'OFF',
      'MC',
      'PL',
      'AL',
      'EL',
      'PH',
      'UNPAID',
    };
    final status = c.status.trim().toUpperCase();
    final rosterStatus = (_dailyRoster[day]?['assignment_type'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    return nonWorkingStatuses.contains(status) ||
        nonWorkingStatuses.contains(rosterStatus);
  }

  bool _hasCompleteWorkingTime(AttendanceDayControllers c) {
    return _clockMinutes(c.workingIn.text) != null &&
        _clockMinutes(c.workingOut.text) != null;
  }

  int _calculateLateMinutes(int day, AttendanceDayControllers c) {
    final actualIn = _clockMinutes(c.workingIn.text);
    final roster = _dailyRoster[day] ?? _weeklyRoster[((day - 1) ~/ 7) + 1];
    final shiftIn = _clockMinutes(roster?['shift_start']?.toString() ?? '');
    if (actualIn == null || shiftIn == null) return 0;
    return (actualIn - shiftIn).clamp(0, 24 * 60).toInt();
  }

  String _calculatedAttendanceStatus(
    int day,
    AttendanceDayControllers c,
  ) {
    const manualStatuses = {'OFF', 'MC', 'PL', 'AL', 'EL', 'PH', 'UNPAID'};
    final manual = c.status.trim();
    if (manualStatuses.contains(manual)) return manual;

    final actualIn = _clockMinutes(c.workingIn.text);
    if (actualIn == null) return '';

    final roster = _dailyRoster[day] ?? _weeklyRoster[((day - 1) ~/ 7) + 1];
    if (roster == null) return 'Present';

    final shiftIn = _clockMinutes(roster['shift_start']?.toString() ?? '');
    final shiftOut = _clockMinutes(roster['shift_end']?.toString() ?? '');
    final actualOut = _clockMinutes(c.workingOut.text);
    final isLate = shiftIn != null && actualIn > shiftIn;
    final isEarlyOut =
        actualOut != null && shiftOut != null && actualOut < shiftOut;

    if (isLate && isEarlyOut) return 'Late + Early Out';
    if (isLate) return 'Late';
    if (isEarlyOut) return 'Early Out';
    return 'Present';
  }

  Widget _statusCell(
    int day,
    AttendanceDayControllers c,
    int netWorkingMinutes,
  ) {
    final effectiveStatus = _calculatedAttendanceStatus(day, c);
    final hasWorkingTime = _clockMinutes(c.workingIn.text) != null;
    final roster = _dailyRoster[day] ?? _weeklyRoster[((day - 1) ~/ 7) + 1];
    final actualIn = _clockMinutes(c.workingIn.text);
    final shiftIn = _clockMinutes(roster?['shift_start']?.toString() ?? '');
    final lateMinutes = actualIn != null && shiftIn != null
        ? (actualIn - shiftIn).clamp(0, 1440)
        : 0;

    Color background;
    Color foreground;
    switch (effectiveStatus) {
      case 'Late':
      case 'Late + Early Out':
      case 'Early Out':
        background = const Color(0xFFFFCDD2);
        foreground = const Color(0xFFC62828);
        break;
      case 'MC':
      case 'PH':
        background = const Color(0xFFFFCDD2);
        foreground = const Color(0xFFB71C1C);
        break;
      case 'PL':
      case 'AL':
      case 'UNPAID':
        background = const Color(0xFFE1BEE7);
        foreground = const Color(0xFF6A1B9A);
        break;
      case 'EL':
        background = const Color(0xFFBBDEFB);
        foreground = const Color(0xFF1565C0);
        break;
      case 'OFF':
      case '':
        background = const Color(0xFFECEFF1);
        foreground = const Color(0xFF455A64);
        break;
      default:
        background = const Color(0xFFE8F5E9);
        foreground = const Color(0xFF2E7D32);
    }

    final displayStatus = lateMinutes > 0 && effectiveStatus.contains('Late')
        ? '$effectiveStatus ($lateMinutes min)'
        : effectiveStatus;
    final child = Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      color: background,
      child: Text(
        displayStatus,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 8.5, fontWeight: FontWeight.w800, color: foreground),
      ),
    );
    if (!_canEditDay(day)) return child;

    return PopupMenuButton<String>(
      tooltip: 'Status / OT for day $day',
      padding: EdgeInsets.zero,
      onSelected: (value) {
        setState(() {
          switch (value) {
            case 'OFF':
            case 'MC':
            case 'PL':
            case 'AL':
            case 'EL':
            case 'PH':
            case 'UNPAID':
              c.status = value;
              c.isPublicHoliday = value == 'PH';
              c.isUnpaid = value == 'UNPAID';
              if (!hasWorkingTime) {
                c.otRequested = false;
                c.otAuthorized = false;
              }
              break;
            case 'CLEAR_STATUS':
              c.status = '';
              c.isPublicHoliday = false;
              c.isUnpaid = false;
              break;
            case 'REQUEST_OT':
              if (!_isAdminView()) {
                c.otRequested = true;
                c.otAuthorized = false;
              }
              break;
            case 'CANCEL_OT':
              c.otRequested = false;
              c.otAuthorized = false;
              break;
            case 'APPROVE_OT':
              if (_isAdminView() && c.otRequested) {
                c.otAuthorized = true;
              }
              break;
            case 'REJECT_OT':
              if (_isAdminView()) {
                c.otRequested = false;
                c.otAuthorized = false;
              }
              break;
          }
        });
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[
          const PopupMenuItem(value: 'OFF', child: Text('OFF')),
          const PopupMenuItem(value: 'MC', child: Text('MC')),
          const PopupMenuItem(value: 'PL', child: Text('PL')),
          const PopupMenuItem(value: 'AL', child: Text('AL')),
          const PopupMenuItem(value: 'EL', child: Text('EL')),
          const PopupMenuItem(
            value: 'PH',
            child: Text('PH - PUBLIC HOLIDAY'),
          ),
          const PopupMenuItem(
            value: 'UNPAID',
            child: Text('UNPAID'),
          ),
          const PopupMenuDivider(),
        ];

        if (_isAdminView()) {
          items.add(
            PopupMenuItem(
              value: 'APPROVE_OT',
              enabled: c.otRequested,
              child: Text(
                c.otAuthorized
                    ? 'OT APPROVED'
                    : (c.otRequested
                        ? 'APPROVE OT'
                        : 'APPROVE OT (request required)'),
              ),
            ),
          );
          items.add(
            PopupMenuItem(
              value: 'REJECT_OT',
              enabled: c.otRequested || c.otAuthorized,
              child: const Text('REJECT OT'),
            ),
          );
        } else {
          items.add(
            PopupMenuItem(
              value: 'REQUEST_OT',
              enabled: !c.otRequested,
              child: const Text('REQUEST OT'),
            ),
          );
          items.add(
            PopupMenuItem(
              value: 'CANCEL_OT',
              enabled: c.otRequested,
              child: const Text('CANCEL OT REQUEST'),
            ),
          );
        }

        items.add(const PopupMenuDivider());
        items.add(
          const PopupMenuItem(
            value: 'CLEAR_STATUS',
            child: Text('CLEAR STATUS'),
          ),
        );
        return items;
      },
      child: child,
    );
  }

  // ==========================================================================
  // BREAK ATTENDANCE
  // ==========================================================================

  Widget _breakAttendanceCard() {
    const red = Color(0xFFD32F2F);

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

    final breakTotal = morning + afternoon + evening;

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
              day: day,
              focusNode: c.morningInFocus,
              prevFocus: day > 1 ? controllers[day - 2].overtimeOutFocus : null,
              nextFocus: c.morningOutFocus,
            ),
          ),

          Expanded(
            child: _smallTimeInput(
              c.morningOut,
              day: day,
              focusNode: c.morningOutFocus,
              prevFocus: c.morningInFocus,
              nextFocus: c.afternoonInFocus,
            ),
          ),

          // ==============================================================
          // AFTERNOON BREAK
          // ==============================================================

          Expanded(
            child: _smallTimeInput(
              c.afternoonIn,
              day: day,
              focusNode: c.afternoonInFocus,
              prevFocus: c.morningOutFocus,
              nextFocus: c.afternoonOutFocus,
            ),
          ),

          Expanded(
            child: _smallTimeInput(
              c.afternoonOut,
              day: day,
              focusNode: c.afternoonOutFocus,
              prevFocus: c.afternoonInFocus,
              nextFocus: c.overtimeInFocus,
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
              day: day,
              focusNode: c.overtimeInFocus,
              prevFocus: c.afternoonOutFocus,
              nextFocus: c.overtimeOutFocus,
            ),
          ),

          Expanded(
            child: _smallTimeInput(
              c.overtimeOut,
              day: day,
              focusNode: c.overtimeOutFocus,
              prevFocus: c.overtimeInFocus,
              nextFocus:
                  day < daysInMonth ? controllers[day].morningInFocus : null,
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
      decoration: const BoxDecoration(
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
          fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  Widget _timeInput(
    TextEditingController controller,
    double width, {
    required int day,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    FocusNode? prevFocus,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Color(0xFF15965D),
          ),
          bottom: BorderSide(
            color: Color(0xFF15965D),
          ),
        ),
      ),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) {
          if (!_canEditDay(day)) return;

          // Arrow Down or Right: Move to next focus
          if (event.isKeyPressed(LogicalKeyboardKey.arrowDown) ||
              event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            }
          }
          // Arrow Up or Left: Move to previous focus
          else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp) ||
              event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
            if (prevFocus != null) {
              prevFocus.requestFocus();
            }
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: !_canEditDay(day),
          enabled: _canEditDay(day),
          textInputAction:
              nextFocus == null ? TextInputAction.done : TextInputAction.next,
          onChanged: (value) {
            _formatTimeInput(controller, value, nextFocus);
            if (mounted) {
              setState(() {});
            }
          },
          onSubmitted: (_) => _moveToNextField(nextFocus),
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
    TextEditingController controller, {
    required int day,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    FocusNode? prevFocus,
  }) {
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
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) {
          if (!_canEditDay(day)) return;

          // Arrow Down or Right: Move to next focus
          if (event.isKeyPressed(LogicalKeyboardKey.arrowDown) ||
              event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            }
          }
          // Arrow Up or Left: Move to previous focus
          else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp) ||
              event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
            if (prevFocus != null) {
              prevFocus.requestFocus();
            }
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: !_canEditDay(day),
          enabled: _canEditDay(day),
          textInputAction:
              nextFocus == null ? TextInputAction.done : TextInputAction.next,
          onChanged: (value) {
            _formatTimeInput(controller, value, nextFocus);
            if (mounted) {
              setState(() {});
            }
          },
          onSubmitted: (_) => _moveToNextField(nextFocus),
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
      ),
    );
  }

  void _formatTimeInput(
    TextEditingController controller,
    String value,
    FocusNode? nextFocus,
  ) {
    // Remove all non-digit characters
    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Limit to 4 digits max (HHMM)
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;

    // Format as HH:MM
    String formatted;
    if (limited.isEmpty) {
      formatted = '';
    } else if (limited.length == 1) {
      formatted = limited;
    } else if (limited.length == 2) {
      // Auto-insert colon after 2 digits
      formatted = '$limited:';
    } else if (limited.length == 3) {
      // Format: HH:M
      formatted = '${limited.substring(0, 2)}:${limited.substring(2)}';
    } else {
      // Format: HH:MM
      formatted = '${limited.substring(0, 2)}:${limited.substring(2)}';
    }

    // Update the controller only if the formatted value is different
    if (controller.text != formatted) {
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    // Auto-move to next field when time is complete (HH:MM format)
    if (limited.length == 4 && nextFocus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) nextFocus.requestFocus();
      });
    }
  }

  void _moveToNextField(FocusNode? nextFocus) {
    if (nextFocus != null) {
      nextFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  // ==========================================================================
  // ATTENDANCE SUMMARY
  // ==========================================================================

  Widget _attendanceSummary() {
    var workTotal = 0;
    var breakTotal = 0;
    var netTotal = 0;
    var overtimeTotal = 0;

    for (var i = 0; i < daysInMonth; i++) {
      final c = controllers[i];
      final work = calculateWorkMinutes(c);
      final breaks = _calculateBreakMinutes(c);
      final net = (work - breaks).clamp(0, 24 * 60).toInt();
      final ot = _calculateDailyOtMinutes(
        day: i + 1,
        c: c,
        netWorkingMinutes: net,
      );

      workTotal += work;
      breakTotal += breaks;
      netTotal += net;
      overtimeTotal += ot;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 20),
            _summaryChip(
                'WORK', formatMinutes(workTotal), const Color(0xFF315AD9)),
            const SizedBox(width: 10),
            _summaryChip(
                'BREAK', formatMinutes(breakTotal), const Color(0xFFD32F2F)),
            const SizedBox(width: 10),
            _summaryChip(
                'NET WORK', formatMinutes(netTotal), const Color(0xFF315AD9)),
            const SizedBox(width: 10),
            _summaryChip('OT', formatMinutes(overtimeTotal), Colors.orange),
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
        borderRadius: BorderRadius.zero,
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
    final startMinutes = parseTimeToMinutes(start);

    final endMinutes = parseTimeToMinutes(end);

    if (startMinutes == null || endMinutes == null) {
      return 0;
    }

    var difference = endMinutes - startMinutes;

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

    if (hour == null || minute == null) {
      return null;
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
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

class _AttendanceSportsCats extends StatefulWidget {
  const _AttendanceSportsCats();

  @override
  State<_AttendanceSportsCats> createState() => _AttendanceSportsCatsState();
}

class _AttendanceSportsCatsState extends State<_AttendanceSportsCats>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Two cats playing football',
      child: SizedBox(
        width: 220,
        height: 68,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value;
            final ballX = math.sin(progress * math.pi * 2) * 35;
            final ballY = math.sin(progress * math.pi * 4).abs() * 18;
            final catStep = math.sin(progress * math.pi * 4).abs() * 2;

            Widget cat(bool faceRight) => Transform.translate(
                  offset: Offset(0, -catStep),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(
                      faceRight ? -1 : 1,
                      1,
                      1,
                    ),
                    child: Image.asset(
                      'assets/login_walking_cat.png',
                      width: 82,
                      height: 62,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                );

            return Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(left: 0, bottom: 0, child: cat(true)),
                Positioned(right: 0, bottom: 0, child: cat(false)),
                Positioned(
                  left: 100 + ballX,
                  bottom: 4 + ballY,
                  child: Transform.rotate(
                    angle: progress * math.pi * 4,
                    child: const Icon(
                      Icons.sports_soccer,
                      size: 24,
                      color: Color(0xFF3155D9),
                      shadows: [Shadow(color: Colors.black26, blurRadius: 5)],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AttendanceDayControllers {
  final TextEditingController workingIn = TextEditingController();

  final TextEditingController workingOut = TextEditingController();
  final FocusNode workingInFocus = FocusNode();
  final FocusNode workingOutFocus = FocusNode();

  final TextEditingController morningIn = TextEditingController();

  final TextEditingController morningOut = TextEditingController();
  final FocusNode morningInFocus = FocusNode();
  final FocusNode morningOutFocus = FocusNode();

  final TextEditingController afternoonIn = TextEditingController();

  final TextEditingController afternoonOut = TextEditingController();
  final FocusNode afternoonInFocus = FocusNode();
  final FocusNode afternoonOutFocus = FocusNode();

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

  final TextEditingController overtimeIn = TextEditingController();

  final TextEditingController overtimeOut = TextEditingController();
  final FocusNode overtimeInFocus = FocusNode();
  final FocusNode overtimeOutFocus = FocusNode();

  String status = '';
  bool otRequested = false;
  bool otAuthorized = false;
  bool isUnpaid = false;
  bool isPublicHoliday = false;

  int savedNetWorkingMinutes = 0;
  int savedOvertimeMinutes = 0;
  int approvedOtMinutes = 0;

  bool get hasData {
    return workingIn.text.trim().isNotEmpty ||
        workingOut.text.trim().isNotEmpty ||
        morningIn.text.trim().isNotEmpty ||
        morningOut.text.trim().isNotEmpty ||
        afternoonIn.text.trim().isNotEmpty ||
        afternoonOut.text.trim().isNotEmpty ||
        overtimeIn.text.trim().isNotEmpty ||
        overtimeOut.text.trim().isNotEmpty ||
        status.trim().isNotEmpty ||
        otRequested ||
        otAuthorized ||
        isUnpaid ||
        isPublicHoliday;
  }

  void dispose() {
    workingIn.dispose();
    workingOut.dispose();
    workingInFocus.dispose();
    workingOutFocus.dispose();

    morningIn.dispose();
    morningOut.dispose();
    morningInFocus.dispose();
    morningOutFocus.dispose();

    afternoonIn.dispose();
    afternoonOut.dispose();
    afternoonInFocus.dispose();
    afternoonOutFocus.dispose();

    overtimeIn.dispose();
    overtimeOut.dispose();
    overtimeInFocus.dispose();
    overtimeOutFocus.dispose();
  }
}
