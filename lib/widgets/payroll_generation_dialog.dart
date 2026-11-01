import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PayrollGenerationChoice {
  const PayrollGenerationChoice(this.month, this.branchIds, this.files);
  final DateTime month;
  final Set<String> branchIds, files;
}

class PayrollGenerationDialog extends StatefulWidget {
  const PayrollGenerationDialog(
      {super.key,
      required this.initialMonth,
      required this.branches,
      required this.employeeCounts});
  final DateTime initialMonth;
  final Map<String, String> branches;
  final Map<String, int> employeeCounts;
  @override
  State<PayrollGenerationDialog> createState() =>
      _PayrollGenerationDialogState();
}

class _PayrollGenerationDialogState extends State<PayrollGenerationDialog> {
  static const navy = Color(0xFF082E64), gold = Color(0xFFC38B23);
  late DateTime month = widget.initialMonth;
  late final selected = widget.branches.keys
      .where((id) => (widget.employeeCounts[id] ?? 0) > 0)
      .toSet();
  final files = <String>{'Branch Payroll', 'EPF', 'SOCSO', 'EIS', 'HRDF'};
  Widget heading(int number, String title, {bool dark = false}) =>
      Row(children: [
        CircleAvatar(
            radius: 12,
            backgroundColor: gold,
            child: Text('$number',
                style: const TextStyle(color: Colors.white, fontSize: 13))),
        const SizedBox(width: 10),
        Flexible(
            child: Text(title,
                style: TextStyle(
                    color: dark ? Colors.white : navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)))
      ]);
  BoxDecoration panel() => BoxDecoration(
      color: const Color(0xFFFFFCF7),
      border: Border.all(color: const Color(0xFFE8E0D5)),
      borderRadius: BorderRadius.circular(12));
  @override
  Widget build(BuildContext context) {
    final ids = widget.branches.keys.toList()
      ..sort((a, b) => widget.branches[a]!.compareTo(widget.branches[b]!));
    final eligible =
        ids.where((id) => (widget.employeeCounts[id] ?? 0) > 0).toSet();
    final years = <int>{
      for (var y = 2020; y <= DateTime.now().year; y++) y,
      month.year
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final count = selected.fold<int>(
        0, (sum, id) => sum + (widget.employeeCounts[id] ?? 0));
    Widget period() => Container(
        padding: const EdgeInsets.all(14),
        decoration: panel(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          heading(1, 'Select Payroll Period'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: DropdownButtonFormField<int>(
                    initialValue: month.month,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Month',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.calendar_month_outlined, size: 18)),
                    items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(
                                DateFormat('MMMM')
                                    .format(DateTime(2000, i + 1)),
                                overflow: TextOverflow.ellipsis))),
                    onChanged: (v) {
                      if (v != null)
                        setState(() => month = DateTime(month.year, v));
                    })),
            const SizedBox(width: 10),
            Expanded(
                child: DropdownButtonFormField<int>(
                    initialValue: month.year,
                    decoration: const InputDecoration(
                        labelText: 'Year',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon:
                            Icon(Icons.calendar_today_outlined, size: 18)),
                    items: years
                        .map((y) =>
                            DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null)
                        setState(() => month = DateTime(v, month.month));
                    })),
          ])
        ]));
    Widget outputs() => Container(
        padding: const EdgeInsets.all(14),
        decoration: panel(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          heading(2, 'Select Files to Generate'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final name in const [
              'Branch Payroll',
              'EPF',
              'SOCSO',
              'EIS',
              'HRDF'
            ])
              FilterChip(
                  label: Text(name,
                      style: const TextStyle(
                          color: navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  selected: files.contains(name),
                  selectedColor: const Color(0xFFEAF3FF),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD7E6F8)),
                  onSelected: (checked) => setState(() {
                        if (checked) {
                          files.add(name);
                        } else {
                          files.remove(name);
                        }
                      }))
          ])
        ]));
    return AlertDialog(
        backgroundColor: const Color(0xFFFFFCF7),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Image.asset('assets/hasani_books_logo.jpg',
              width: MediaQuery.sizeOf(context).width < 600 ? 75 : 110,
              height: 40,
              fit: BoxFit.contain),
          const SizedBox(width: 14),
          if (MediaQuery.sizeOf(context).width >= 600)
            const Icon(Icons.assignment_outlined, color: gold, size: 30),
          const SizedBox(width: 10),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Generate Payroll',
                    style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: navy)),
                Text(
                    'Generate payroll and related statutory files for selected branches.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF62708A)))
              ])),
          IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close))
        ]),
        content: SizedBox(
            width: 1000,
            height: MediaQuery.sizeOf(context).height * .62,
            child: SingleChildScrollView(
                child: Column(children: [
              LayoutBuilder(
                  builder: (_, box) => box.maxWidth >= 780
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              SizedBox(width: 330, child: period()),
                              const SizedBox(width: 12),
                              Expanded(child: outputs())
                            ])
                      : Column(children: [
                          period(),
                          const SizedBox(height: 10),
                          outputs()
                        ])),
              const SizedBox(height: 14),
              Container(
                  decoration: panel(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Container(
                        color: navy,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                  width: 190,
                                  child: heading(3, 'Select Branches',
                                      dark: true)),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Checkbox(
                                    value: eligible.isNotEmpty &&
                                        selected.containsAll(eligible),
                                    checkColor: navy,
                                    fillColor:
                                        WidgetStateProperty.all(Colors.white),
                                    onChanged: (value) => setState(() {
                                          selected.clear();
                                          if (value == true)
                                            selected.addAll(eligible);
                                        })),
                                const Text('Select All Branches',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12))
                              ]),
                            ])),
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(builder: (_, box) {
                          final columns = box.maxWidth >= 700
                              ? 3
                              : box.maxWidth >= 440
                                  ? 2
                                  : 1;
                          return Wrap(spacing: 10, runSpacing: 10, children: [
                            for (var i = 0; i < ids.length; i++)
                              SizedBox(
                                  width: (box.maxWidth - 10 * (columns - 1)) /
                                      columns,
                                  child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: (widget.employeeCounts[ids[i]] ??
                                                  0) ==
                                              0
                                          ? null
                                          : () => setState(() {
                                                if (!selected.add(ids[i]))
                                                  selected.remove(ids[i]);
                                              }),
                                      child: Container(
                                          height: 90,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7),
                                          decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFFFDFA),
                                                    Color(0xFFEAF5FF)
                                                  ]),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      selected.contains(ids[i])
                                                          ? gold
                                                          : const Color(
                                                              0xFFE1E6EF))),
                                          child: Row(children: [
                                            Checkbox(
                                                value:
                                                    selected.contains(ids[i]),
                                                onChanged:
                                                    (widget.employeeCounts[
                                                                    ids[i]] ??
                                                                0) ==
                                                            0
                                                        ? null
                                                        : (checked) =>
                                                            setState(() {
                                                              if (checked ==
                                                                  true) {
                                                                selected.add(
                                                                    ids[i]);
                                                              } else {
                                                                selected.remove(
                                                                    ids[i]);
                                                              }
                                                            })),
                                            CircleAvatar(
                                                backgroundColor: i.isEven
                                                    ? const Color(0xFFCAE2FF)
                                                    : const Color(0xFFFFE6AF),
                                                child: Icon(
                                                    Icons.storefront_outlined,
                                                    color: i.isEven
                                                        ? navy
                                                        : const Color(
                                                            0xFF996011))),
                                            const SizedBox(width: 10),
                                            Expanded(
                                                child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(widget.branches[ids[i]]!,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          color: navy,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 13)),
                                                  const SizedBox(height: 5),
                                                  Text(
                                                      '${widget.employeeCounts[ids[i]] ?? 0} employees',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(
                                                              0xFF53657D)))
                                                ]))
                                          ]))))
                          ]);
                        })),
                  ])),
              const SizedBox(height: 10),
              const Text(
                  'Attendance readiness and employee confirmation are checked before payroll is generated.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF62708A))),
            ]))),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          Text('${selected.length} branches selected  |  $count employees',
              style: const TextStyle(color: navy, fontWeight: FontWeight.w700)),
          Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 10),
                FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: navy, foregroundColor: Colors.white),
                    onPressed: selected.isEmpty || files.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            PayrollGenerationChoice(
                                month, Set.from(selected), Set.from(files))),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Generate Payroll'))
              ])
        ]);
  }
}
