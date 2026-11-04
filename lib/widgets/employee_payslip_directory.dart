import '../services/payroll_month_scope.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payroll.dart';
import 'employee_photo.dart';
import 'employee_directory_pagination.dart';

class EmployeePayslipDirectory extends StatefulWidget {
  const EmployeePayslipDirectory(
      {super.key,
      required this.employees,
      required this.records,
      required this.totalEmployees,
      required this.activeEmployees,
      required this.totalPayslips,
      required this.period,
      required this.branches,
      required this.branch,
      required this.active,
      required this.searchController,
      required this.tab,
      required this.onPeriod,
      required this.onBranch,
      required this.onActive,
      required this.onSearch,
      required this.onTab,
      required this.onView,
      required this.onPayslips,
      required this.onRefresh,
      required this.onExport,
      this.history,
      this.exporting = false});
  final List<Employee> employees;
  final Map<String, List<PayrollRecord>> records;
  final int totalEmployees, activeEmployees, totalPayslips;
  final DateTime period;
  final Map<String, String> branches;
  final String? branch;
  final bool? active;
  final TextEditingController searchController;
  final String tab;
  final ValueChanged<DateTime> onPeriod;
  final ValueChanged<String?> onBranch;
  final ValueChanged<bool?> onActive;
  final ValueChanged<String> onSearch, onTab;
  final ValueChanged<Employee> onView, onPayslips;
  final VoidCallback onRefresh;
  final ValueChanged<String> onExport;
  final Widget? history;
  final bool exporting;
  @override
  State<EmployeePayslipDirectory> createState() =>
      _EmployeePayslipDirectoryState();
}

class _EmployeePayslipDirectoryState extends State<EmployeePayslipDirectory> {
  static const navy = Color(0xFF11345F), line = Color(0xFFE1E6F0);
  int page = 0;
  @override
  void didUpdateWidget(covariant EmployeePayslipDirectory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period ||
        oldWidget.branch != widget.branch ||
        oldWidget.active != widget.active ||
        oldWidget.tab != widget.tab ||
        oldWidget.employees.map((e) => e.employeeId).join('|') !=
            widget.employees.map((e) => e.employeeId).join('|')) page = 0;
  }

  Widget pill(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w700)));
  InputDecoration input(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 11),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFFAB791F)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line)));
  List<PayrollRecord> recordsFor(Employee e) =>
      widget.records[e.employeeId.trim().toUpperCase()] ?? const [];
  List<PayrollRecord> periodFor(Employee e) => recordsFor(e)
      .where((p) =>
          p.period.year == widget.period.year &&
          p.period.month == widget.period.month)
      .toList();
  @override
  Widget build(BuildContext context) {
    final summary = widget.tab == 'summary';
    final employees = widget.employees.where((employee) =>
        periodFor(employee).isNotEmpty &&
        PayrollMonthScope.activeInMonth(employee.toJson(), widget.period))
        .toList();
    final pages = (employees.length / 10).ceil();
    final current = page.clamp(0, pages > 0 ? pages - 1 : 0).toInt();
    final visible = employees.skip(current * 10).take(10).toList();
    final years = <int>{
      widget.period.year,
      DateTime.now().year,
      for (final rows in widget.records.values)
        for (final p in rows) p.period.year
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final stats = [
      (
        'Total Employees',
        widget.totalEmployees,
        Icons.groups_outlined,
        const Color(0xFF425FBE)
      ),
      (
        'Active',
        widget.activeEmployees,
        Icons.check_circle_outline,
        const Color(0xFF26974D)
      ),
      (
        'Inactive',
        widget.totalEmployees - widget.activeEmployees,
        Icons.person_outline,
        const Color(0xFF6A7386)
      ),
      (
        'Total Payslips',
        widget.totalPayslips,
        Icons.description_outlined,
        const Color(0xFF5774C6)
      )
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Image.asset('assets/hasani_books_logo.jpg',
            width: 105, height: 40, fit: BoxFit.contain),
        const SizedBox(width: 15),
        const Icon(Icons.description_outlined,
            color: Color(0xFFB07E22), size: 27),
        const SizedBox(width: 10),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Employee Payslips',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: navy)),
          Text('Search, view and manage employee payslips by month and year.',
              style: TextStyle(fontSize: 11, color: Color(0xFF68758A)))
        ]))
      ]),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (_, box) {
        final columns = box.maxWidth >= 700 ? 4 : 2;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final metric in stats)
            Container(
                width: (box.maxWidth - 10 * (columns - 1)) / columns,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.white,
                      metric.$4.withValues(alpha: .09)
                    ]),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: line),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 5,
                          offset: Offset(0, 2))
                    ]),
                child: Row(children: [
                  CircleAvatar(
                      radius: 19,
                      backgroundColor: metric.$4.withValues(alpha: .1),
                      child: Icon(metric.$3, color: metric.$4, size: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(metric.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: navy)),
                        Text(NumberFormat.decimalPattern().format(metric.$2),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: navy))
                      ]))
                ]))
        ]);
      }),
      const SizedBox(height: 14),
      Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
                width: 175,
                child: DropdownButtonFormField<int>(
                    key: ValueKey('payslip-month-${widget.period.month}'),
                    initialValue: widget.period.month,
                    isExpanded: true,
                    decoration: input('Month', Icons.calendar_month_outlined),
                    items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(DateFormat('MMMM')
                                .format(DateTime(2000, i + 1))))),
                    onChanged: (m) {
                      if (m != null)
                        widget.onPeriod(DateTime(widget.period.year, m));
                    })),
            SizedBox(
                width: 140,
                child: DropdownButtonFormField<int>(
                    key: ValueKey('payslip-year-${widget.period.year}'),
                    initialValue: widget.period.year,
                    isExpanded: true,
                    decoration: input('Year', Icons.calendar_today_outlined),
                    items: years
                        .map((y) =>
                            DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (y) {
                      if (y != null)
                        widget.onPeriod(DateTime(y, widget.period.month));
                    })),
            SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                    initialValue: widget.branch ?? '',
                    isExpanded: true,
                    decoration: input('Branch', Icons.apartment_outlined),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('All Branches')),
                      ...widget.branches.entries.map((b) => DropdownMenuItem(
                          value: b.key,
                          child:
                              Text(b.value, overflow: TextOverflow.ellipsis)))
                    ],
                    onChanged: (v) => widget.onBranch(v == '' ? null : v))),
            SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: widget.active == null
                        ? 'all'
                        : widget.active!
                            ? 'active'
                            : 'inactive',
                    decoration: input('Status', Icons.layers_outlined),
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Employees')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Inactive'))
                    ],
                    onChanged: (v) =>
                        widget.onActive(v == 'all' ? null : v == 'active'))),
            SizedBox(
                width: 300,
                child: TextField(
                    controller: widget.searchController,
                    onChanged: widget.onSearch,
                    decoration: input('', Icons.search).copyWith(
                        hintText: 'Search employee by name, ID or IC number...',
                        hintStyle: const TextStyle(fontSize: 11),
                        suffixIcon: IconButton(
                            tooltip: 'Refresh employees and payroll',
                            onPressed: widget.onRefresh,
                            icon: const Icon(Icons.refresh, size: 18))))),
          ]),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (_, box) {
        final tabs = Wrap(spacing: 8, runSpacing: 8, children: [
          for (final item in [
            ('list', 'Employee List', Icons.list),
            ('history', 'Payslip History', Icons.history),
            ('summary', 'Payslip Summary', Icons.bar_chart)
          ])
            ChoiceChip(
                label: Text(item.$2,
                    style: TextStyle(
                        fontSize: 11,
                        color: widget.tab == item.$1 ? Colors.white : navy)),
                avatar: Icon(item.$3,
                    size: 17,
                    color: widget.tab == item.$1
                        ? const Color(0xFFFFCE67)
                        : const Color(0xFFAD7C23)),
                selected: widget.tab == item.$1,
                showCheckmark: false,
                selectedColor: navy,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7)),
                side: const BorderSide(color: line),
                onSelected: (_) => widget.onTab(item.$1))
        ]);
        final exports = Wrap(spacing: 8, children: [
          OutlinedButton.icon(
              onPressed:
                  widget.exporting ? null : () => widget.onExport('xlsx'),
              icon: const Icon(Icons.file_download_outlined,
                  size: 17, color: Color(0xFF188146)),
              label:
                  const Text('Export Excel', style: TextStyle(fontSize: 11))),
          OutlinedButton.icon(
              onPressed: widget.exporting ? null : () => widget.onExport('pdf'),
              icon: const Icon(Icons.picture_as_pdf_outlined,
                  size: 17, color: Colors.red),
              label: const Text('Export PDF', style: TextStyle(fontSize: 11)))
        ]);
        return box.maxWidth >= 1000
            ? Row(children: [Expanded(child: tabs), exports])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [tabs, const SizedBox(height: 8), exports]);
      }),
      const SizedBox(height: 12),
      if (widget.tab == 'history' && widget.history != null)
        widget.history!
      else ...[
        if (widget.tab == 'history')
          const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                  'Choose Payslips for an employee to view their history.')),
        Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line)),
            clipBehavior: Clip.antiAlias,
            child: employees.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(
                        child: Text(
                            'No employees or payslips match these filters.')))
                : LayoutBuilder(
                    builder: (_, box) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: box.maxWidth),
                            child: DataTable(
                                headingRowColor:
                                    const WidgetStatePropertyAll(navy),
                                headingRowHeight: 34,
                                dataRowMinHeight: 48,
                                dataRowMaxHeight: 48,
                                dividerThickness: .6,
                                horizontalMargin: 14,
                                columnSpacing: 24,
                                headingTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                                dataTextStyle:
                                    const TextStyle(color: navy, fontSize: 11),
                                columns: [
                                  const DataColumn(label: Text('#')),
                                  const DataColumn(label: Text('EMPLOYEE')),
                                  const DataColumn(label: Text('EMPLOYEE ID')),
                                  const DataColumn(label: Text('BRANCH')),
                                  const DataColumn(label: Text('STATUS')),
                                  if (summary) ...[
                                    const DataColumn(
                                        label: Text('EARNINGS RM')),
                                    const DataColumn(
                                        label: Text('DEDUCTIONS RM')),
                                    const DataColumn(label: Text('NET RM'))
                                  ] else
                                    const DataColumn(
                                        label: Text('TOTAL PAYSLIPS')),
                                  const DataColumn(label: Text('ACTIONS'))
                                ],
                                rows: visible.asMap().entries.map((entry) {
                                  final e = entry.value;
                                  final rows = periodFor(e);
                                  return DataRow(cells: [
                                    DataCell(Text(
                                        '${current * 10 + entry.key + 1}')),
                                    DataCell(
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              EmployeePhoto(
                                                  name: e.name,
                                                  photoUrl: e.photoUrl,
                                                  radius: 15),
                                              const SizedBox(width: 10),
                                              SizedBox(
                                                  width: 230,
                                                  child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(e.name,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontSize: 11)),
                                                        Text(e.department,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: const TextStyle(
                                                                fontSize: 10,
                                                                color: Color(
                                                                    0xFF76839A)))
                                                      ]))
                                            ]),
                                        onTap: () => widget.onPayslips(e)),
                                    DataCell(Text(e.employeeId)),
                                    DataCell(pill(
                                        widget.branches[e.branchId] ??
                                            e.branchId,
                                        const Color(0xFF4165A2))),
                                    DataCell(pill(
                                        PayrollMonthScope.activeInMonth(
                                                e.toJson(), widget.period)
                                            ? 'Active' : 'Inactive',
                                        PayrollMonthScope.activeInMonth(
                                                e.toJson(), widget.period)
                                            ? const Color(0xFF229546)
                                            : const Color(0xFF7A8190))),
                                    if (summary) ...[
                                      DataCell(Text(rows
                                          .fold<double>(
                                              0, (s, p) => s + p.totalEarnings)
                                          .toStringAsFixed(2))),
                                      DataCell(Text(rows
                                          .fold<double>(0,
                                              (s, p) => s + p.totalDeductions)
                                          .toStringAsFixed(2))),
                                      DataCell(Text(rows
                                          .fold<double>(
                                              0,
                                              (s, p) =>
                                                  s +
                                                  (p.storedNetSalary ??
                                                      p.netPay))
                                          .toStringAsFixed(2)))
                                    ] else
                                      DataCell(Text('${periodFor(e).length}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800))),
                                    DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton.icon(
                                              onPressed: () => widget.onView(e),
                                              icon: const Icon(
                                                  Icons.visibility_outlined,
                                                  size: 14),
                                              label: const Text('View',
                                                  style:
                                                      TextStyle(fontSize: 10))),
                                          const SizedBox(width: 6),
                                          OutlinedButton.icon(
                                              onPressed: () =>
                                                  widget.onPayslips(e),
                                              icon: const Icon(
                                                  Icons.description_outlined,
                                                  size: 14),
                                              label: const Text('Payslips',
                                                  style:
                                                      TextStyle(fontSize: 10))),
                                          PopupMenuButton<String>(
                                              tooltip:
                                                  'Employee payslip actions',
                                              icon: const Icon(Icons.more_vert,
                                                  size: 18),
                                              onSelected: (action) =>
                                                  action == 'view'
                                                      ? widget.onView(e)
                                                      : widget.onPayslips(e),
                                              itemBuilder: (_) => const [
                                                    PopupMenuItem(
                                                        value: 'view',
                                                        child: Text(
                                                            'View employee')),
                                                    PopupMenuItem(
                                                        value: 'history',
                                                        child: Text(
                                                            'Payslip history'))
                                                  ])
                                        ]))
                                  ]);
                                }).toList()))))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: Text(
                  employees.isEmpty
                      ? 'Showing 0 employees'
                      : 'Showing ${current * 10 + 1}–${current * 10 + visible.length} of ${employees.length} employees',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF697A92)))),
          EmployeeDirectoryPagination(
              page: current,
              pageCount: pages,
              compact: MediaQuery.sizeOf(context).width < 1000,
              onChanged: (v) => setState(() => page = v))
        ]),
      ],
    ]);
  }
}
