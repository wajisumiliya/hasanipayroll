import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/app_service.dart';

class LateReportPage extends StatefulWidget {
  const LateReportPage(
      {super.key, required this.month, required this.branches, this.loader});
  final DateTime month;
  final List<Map<String, dynamic>> branches;
  final Future<Map<String, dynamic>> Function(DateTime)? loader;
  @override
  State<LateReportPage> createState() => _LateReportPageState();
}

class _LateReportPageState extends State<LateReportPage> {
  late DateTime _month;
  late Future<Map<String, dynamic>> _report;
  String? _branch;
  @override
  void initState() {
    super.initState();
    _month = widget.month;
    _load();
  }

  void _load() {
    _report = (widget.loader ?? AppService.instance.loadLateReport)(_month);
  }

  String _branchName(String id) {
    for (final b in widget.branches) {
      if ((b['id'] ?? b['branch_id']).toString().toUpperCase() ==
          id.toUpperCase()) {
        return (b['name'] ?? b['branch_name'] ?? id).toString();
      }
    }
    return id;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Late Report'), actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh)),
        ]),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => setState(() {
                            _month = DateTime(_month.year, _month.month - 1);
                            _load();
                          }),
                      icon: const Icon(Icons.chevron_left)),
                  Expanded(
                      child: Text(DateFormat('MMMM yyyy').format(_month),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18))),
                  IconButton(
                      tooltip: 'Next month',
                      onPressed: () => setState(() {
                            _month = DateTime(_month.year, _month.month + 1);
                            _load();
                          }),
                      icon: const Icon(Icons.chevron_right)),
                ]),
                const Text(
                    'Employees with 3 or more combined occurrences: late arrivals + days exceeding allocated break minutes.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    initialValue: _branch ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Branch', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('All branches')),
                      ...widget.branches.map((b) => DropdownMenuItem(
                          value: (b['id'] ?? b['branch_id']).toString(),
                          child:
                              Text((b['name'] ?? b['branch_name']).toString())))
                    ],
                    onChanged: (v) =>
                        setState(() => _branch = v == '' ? null : v)),
              ])),
          Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                  future: _report,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Unable to load late report.'),
                        TextButton(
                            onPressed: () => setState(_load),
                            child: const Text('Retry')),
                      ]));
                    }
                    final data = snap.data!;
                    final reports = (data['reports'] as List)
                        .cast<Map<String, dynamic>>()
                        .where((r) =>
                            _branch == null ||
                            r['branch_id'].toString().toUpperCase() ==
                                _branch!.toUpperCase())
                        .toList();
                    final missing = _branch == null
                        ? data['missing_schedules'] ?? 0
                        : (data['missing_schedules_by_branch'] as Map? ??
                                {})[_branch] ??
                            0;
                    return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          if (missing != 0)
                            Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                    '$missing attendance day(s) have missing schedule details and could not be assessed. Complete the rosters and refresh.',
                                    style: const TextStyle(
                                        color: Color(0xFF965A00)))),
                          Text(
                              '${reports.length} employee(s) meet the monthly threshold',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (reports.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                    'No employees with 3 or more occurrences in this period.')),
                          ...reports.asMap().entries.expand((entry) {
                            final r = entry.value;
                            return <Widget>[
                              if (entry.key == 0 ||
                                  reports[entry.key - 1]['branch_id'] !=
                                      r['branch_id'])
                                Padding(
                                    padding: const EdgeInsets.only(
                                        top: 20, bottom: 8),
                                    child: Text(
                                        _branchName(r['branch_id'].toString()),
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold))),
                              Card(
                                  child: ExpansionTile(
                                title:
                                    Text('${r['name']} · ${r['employee_id']}'),
                                subtitle: Text(
                                    '${_branchName(r['branch_id'].toString())}\n${r['arrival_count']} late arrivals + ${r['break_count']} exceeded breaks = ${r['count']} occurrences · ${r['total_minutes']} min total'),
                                children: (r['events'] as List)
                                    .map((e) => ListTile(
                                          leading: Icon(e['type'] == 'arrival'
                                              ? Icons.schedule
                                              : Icons.free_breakfast_outlined),
                                          title: Text(
                                              '${DateFormat('EEE, dd MMM').format(DateTime.parse(e['date']))} · ${e['type'] == 'arrival' ? 'Late arrival' : 'Break exceeded'}'),
                                          subtitle: Text(e['type'] == 'arrival'
                                              ? "Scheduled ${e['scheduled']} · arrived ${e['actual']}"
                                              : "Allowed ${e['allocated_minutes']} min · used ${e['actual_minutes']} min"),
                                          trailing:
                                              Text("+${e['minutes']} min"),
                                        ))
                                    .toList(),
                              )),
                            ];
                          }),
                        ]);
                  })),
        ]),
      );
}
