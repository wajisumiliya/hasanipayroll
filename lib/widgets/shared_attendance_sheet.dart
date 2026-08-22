import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SharedAttendanceSheet extends StatelessWidget {
  final List<Map<String, dynamic>> attendance;
  final DateTime month;
  final String title;
  final String employeeId;
  final String employeeName;
  final bool showOtAuthorization;

  /// Called only by Admin.
  final Future<void> Function(
    DateTime date,
    bool authorized,
  )? onOtAuthorizationChanged;

  const SharedAttendanceSheet({
    super.key,
    required this.attendance,
    required this.month,
    required this.title,
    required this.employeeId,
    required this.employeeName,
    this.showOtAuthorization = false,
    this.onOtAuthorizationChanged,
  });

  // ============================================================
  // DATA HELPERS
  // ============================================================

  Map<String, dynamic>? _rowForDay(int day) {
    for (final row in attendance) {
      final rawDate =
          row['attendance_date'] ??
          row['date'] ??
          row['work_date'];

      if (rawDate == null) {
        continue;
      }

      final date = DateTime.tryParse(
        rawDate.toString(),
      );

      if (date == null) {
        continue;
      }

      if (date.year == month.year &&
          date.month == month.month &&
          date.day == day) {
        return row;
      }
    }

    return null;
  }

  String _value(
    Map<String, dynamic>? row,
    List<String> keys,
  ) {
    if (row == null) {
      return '-';
    }

    for (final key in keys) {
      final value = row[key];

      if (value != null &&
          value.toString().trim().isNotEmpty) {
        return _formatTime(value);
      }
    }

    return '-';
  }

  String _formatTime(dynamic value) {
    if (value == null) {
      return '-';
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return '-';
    }

    if (text.contains('T')) {
      final date = DateTime.tryParse(text);

      if (date != null) {
        return DateFormat('hh:mm a').format(date);
      }
    }

    return text;
  }

  double _number(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value
              .toString()
              .replaceAll(',', '')
              .trim(),
        ) ??
        0;
  }

  int _workMinutes(
    Map<String, dynamic>? row,
  ) {
    if (row == null) {
      return 0;
    }

    return _number(
      row['work_minutes'] ??
          row['working_minutes'] ??
          row['total_work_minutes'],
    ).round();
  }

  int _breakMinutes(
    Map<String, dynamic>? row,
  ) {
    if (row == null) {
      return 0;
    }

    return _number(
      row['break_minutes'] ??
          row['total_break_minutes'],
    ).round();
  }

  int _otMinutes(
    Map<String, dynamic>? row,
  ) {
    if (row == null) {
      return 0;
    }

    return _number(
      row['overtime_minutes'] ??
          row['ot_minutes'],
    ).round();
  }

  bool _otAuthorized(
    Map<String, dynamic>? row,
  ) {
    if (row == null) {
      return false;
    }

    final value =
        row['ot_authorized'];

    if (value is bool) {
      return value;
    }

    final text =
        value?.toString().toLowerCase().trim();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) {
      return '-';
    }

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${mins.toString().padLeft(2, '0')}';
  }

  int get _daysInMonth {
    return DateTime(
      month.year,
      month.month + 1,
      0,
    ).day;
  }

  int get _totalWorkMinutes {
    return attendance.fold<int>(
      0,
      (total, row) =>
          total + _workMinutes(row),
    );
  }

  int get _totalBreakMinutes {
    return attendance.fold<int>(
      0,
      (total, row) =>
          total + _breakMinutes(row),
    );
  }

  int get _authorizedOtMinutes {
    return attendance.fold<int>(
      0,
      (total, row) {
        if (_otAuthorized(row)) {
          return total + _otMinutes(row);
        }

        return total;
      },
    );
  }

  int get _workingDays {
    return attendance.where(
      (row) => _workMinutes(row) > 0,
    ).length;
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          _header(),

          const SizedBox(height: 16),

          _summary(),

          const SizedBox(height: 20),

          _sectionTitle(
            'WORK ATTENDANCE',
            Icons.work_outline,
            const Color(0xFF15965D),
          ),

          const SizedBox(height: 8),

          _horizontalTable(
            _buildWorkTable(),
          ),

          const SizedBox(height: 24),

          _sectionTitle(
            'BREAK ATTENDANCE',
            Icons.coffee_outlined,
            const Color(0xFF315AD9),
          ),

          const SizedBox(height: 8),

          _horizontalTable(
            _buildBreakTable(),
          ),

          const SizedBox(height: 24),

          _sectionTitle(
            'OVERTIME ATTENDANCE',
            Icons.timer_outlined,
            const Color(0xFFF59E0B),
          ),

          const SizedBox(height: 8),

          _horizontalTable(
            _buildOvertimeTable(),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF15965D),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            employeeName.isEmpty
                ? employeeId
                : employeeName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Employee ID: $employeeId',
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'FOR THE MONTH OF '
            '${DateFormat('MMMM yyyy').format(month).toUpperCase()}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard(
          'WORKING DAYS',
          _workingDays.toString(),
          Icons.calendar_month,
          const Color(0xFF15965D),
        ),

        _summaryCard(
          'WORKING HOURS',
          _formatMinutes(
            _totalWorkMinutes,
          ),
          Icons.access_time,
          const Color(0xFF315AD9),
        ),

        _summaryCard(
          'BREAK TIME',
          _formatMinutes(
            _totalBreakMinutes,
          ),
          Icons.coffee_outlined,
          const Color(0xFF7C3AED),
        ),

        _summaryCard(
          'AUTHORIZED OT',
          _formatMinutes(
            _authorizedOtMinutes,
          ),
          Icons.timer_outlined,
          const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _summaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: 180,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.25),
          ),
          color: color.withOpacity(0.06),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
            ),

            const SizedBox(height: 8),

            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String text,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
        ),

        const SizedBox(width: 8),

        Text(
          text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _horizontalTable(
    Widget child,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: child,
    );
  }

  // ============================================================
  // WORK TABLE
  // ============================================================

  Widget _buildWorkTable() {
    final rows = <Widget>[];

    rows.add(
      Row(
        children: [
          _cell(
            'DATE',
            70,
            header: true,
            color: const Color(0xFF15965D),
          ),
          _cell(
            'CHECK IN',
            150,
            header: true,
            color: const Color(0xFF15965D),
          ),
          _cell(
            'CHECK OUT',
            150,
            header: true,
            color: const Color(0xFF15965D),
          ),
          _cell(
            'TOTAL WORK',
            120,
            header: true,
            color: const Color(0xFF15965D),
          ),
          _cell(
            'STATUS',
            140,
            header: true,
            color: const Color(0xFF15965D),
          ),
        ],
      ),
    );

    for (
      int day = 1;
      day <= _daysInMonth;
      day++
    ) {
      final row = _rowForDay(day);
      final work = _workMinutes(row);

      rows.add(
        Row(
          children: [
            _cell(
              day.toString(),
              70,
            ),
            _cell(
              _value(
                row,
                [
                  'check_in',
                  'working_in',
                  'work_in',
                ],
              ),
              150,
            ),
            _cell(
              _value(
                row,
                [
                  'check_out',
                  'working_out',
                  'work_out',
                ],
              ),
              150,
            ),
            _cell(
              _formatMinutes(work),
              120,
              bold: true,
            ),
            _cell(
              work > 0
                  ? 'RECORDED'
                  : '-',
              140,
            ),
          ],
        ),
      );
    }

    return Column(
      children: rows,
    );
  }

  // ============================================================
  // BREAK TABLE
  // ============================================================

  Widget _buildBreakTable() {
    final rows = <Widget>[];

    rows.add(
      Row(
        children: [
          _cell(
            'DATE',
            70,
            header: true,
            color: const Color(0xFF315AD9),
          ),
          _cell(
            'MORNING IN',
            130,
            header: true,
            color: const Color(0xFF315AD9),
          ),
          _cell(
            'MORNING OUT',
            130,
            header: true,
            color: const Color(0xFF315AD9),
          ),
          _cell(
            'AFTERNOON IN',
            130,
            header: true,
            color: const Color(0xFF315AD9),
          ),
          _cell(
            'AFTERNOON OUT',
            130,
            header: true,
            color: const Color(0xFF315AD9),
          ),
          _cell(
            'EVENING IN',
            130,
            header: true,
            color: const Color(0xFF315AD9),
          ),
          _cell(
            'EVENING OUT',
            130,
            header: true,
            color: const Color(0xFF315AD9),
          ),
          _cell(
            'TOTAL BREAK',
            120,
            header: true,
            color: const Color(0xFF315AD9),
          ),
        ],
      ),
    );

    for (
      int day = 1;
      day <= _daysInMonth;
      day++
    ) {
      final row = _rowForDay(day);

      rows.add(
        Row(
          children: [
            _cell(
              day.toString(),
              70,
            ),
            _cell(
              _value(
                row,
                [
                  'morning_in',
                  'break_morning_in',
                ],
              ),
              130,
            ),
            _cell(
              _value(
                row,
                [
                  'morning_out',
                  'break_morning_out',
                ],
              ),
              130,
            ),
            _cell(
              _value(
                row,
                [
                  'afternoon_in',
                  'break_afternoon_in',
                ],
              ),
              130,
            ),
            _cell(
              _value(
                row,
                [
                  'afternoon_out',
                  'break_afternoon_out',
                ],
              ),
              130,
            ),
            _cell(
              _value(
                row,
                [
                  'evening_in',
                  'overtime_in',
                ],
              ),
              130,
            ),
            _cell(
              _value(
                row,
                [
                  'evening_out',
                  'overtime_out',
                ],
              ),
              130,
            ),
            _cell(
              _formatMinutes(
                _breakMinutes(row),
              ),
              120,
              bold: true,
            ),
          ],
        ),
      );
    }

    return Column(
      children: rows,
    );
  }

  // ============================================================
  // OVERTIME TABLE
  // ============================================================

  Widget _buildOvertimeTable() {
    final rows = <Widget>[];

    rows.add(
      Row(
        children: [
          _cell(
            'DATE',
            70,
            header: true,
            color: const Color(0xFFF59E0B),
          ),
          _cell(
            'OT IN',
            150,
            header: true,
            color: const Color(0xFFF59E0B),
          ),
          _cell(
            'OT OUT',
            150,
            header: true,
            color: const Color(0xFFF59E0B),
          ),
          _cell(
            'OT HOURS',
            120,
            header: true,
            color: const Color(0xFFF59E0B),
          ),
          _cell(
            showOtAuthorization
                ? 'AUTHORIZE OT'
                : 'OT STATUS',
            220,
            header: true,
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );

    for (
      int day = 1;
      day <= _daysInMonth;
      day++
    ) {
      final row = _rowForDay(day);
      final ot = _otMinutes(row);
      final authorized =
          _otAuthorized(row);

      Widget statusWidget;

      if (showOtAuthorization &&
          row != null &&
          onOtAuthorizationChanged != null) {
        statusWidget = Switch(
          value: authorized,
          onChanged: (value) async {
            await onOtAuthorizationChanged!(
              DateTime(
                month.year,
                month.month,
                day,
              ),
              value,
            );
          },
        );
      } else {
        statusWidget = Text(
          ot <= 0
              ? '-'
              : authorized
                  ? 'AUTHORIZED'
                  : 'PENDING',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: authorized
                ? Colors.green
                : Colors.orange,
          ),
        );
      }

      rows.add(
        Row(
          children: [
            _cell(
              day.toString(),
              70,
            ),
            _cell(
              _value(
                row,
                [
                  'overtime_in',
                  'ot_in',
                ],
              ),
              150,
            ),
            _cell(
              _value(
                row,
                [
                  'overtime_out',
                  'ot_out',
                ],
              ),
              150,
            ),
            _cell(
              _formatMinutes(ot),
              120,
              bold: true,
            ),
            Container(
              width: 220,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: statusWidget,
            ),
          ],
        ),
      );
    }

    return Column(
      children: rows,
    );
  }

  // ============================================================
  // CELL
  // ============================================================

  Widget _cell(
    String text,
    double width, {
    bool header = false,
    bool bold = false,
    Color? color,
  }) {
    return Container(
      width: width,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: header
            ? (color ?? Colors.blue)
            : Colors.white,
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: header
              ? Colors.white
              : Colors.black87,
          fontWeight: header || bold
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
    );
  }
}