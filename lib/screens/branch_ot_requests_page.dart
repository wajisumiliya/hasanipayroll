import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'supabase_service.dart';

class BranchOtRequestsPage extends StatefulWidget {
  final String branchId;

  const BranchOtRequestsPage({super.key, required this.branchId});

  @override
  State<BranchOtRequestsPage> createState() => _BranchOtRequestsPageState();
}

class _BranchOtRequestsPageState extends State<BranchOtRequestsPage> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() =>
      _future = SupabaseService.getBranchOtRequests(widget.branchId);

  String _time(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  String _duration(dynamic value) {
    final minutes = int.tryParse(value?.toString() ?? '') ?? 0;
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }

  String _stamp(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null
        ? 'Waiting'
        : DateFormat('dd/MM/yyyy hh:mm a').format(date);
  }

  String _status(String value) {
    switch (value) {
      case 'pending_branch':
        return 'Waiting for branch';
      case 'pending_admin':
        return 'Waiting for admin';
      default:
        return value.replaceAll('_', ' ');
    }
  }

  Future<void> _review(Map<String, dynamic> request, bool approve) async {
    try {
      await SupabaseService.reviewBranchOtRequest(
        requestId: request['id'].toString(),
        approve: approve,
      );
      if (!mounted) return;
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve
            ? 'OT request forwarded to admin.'
            : 'OT request rejected by branch.'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to review OT request: $error')));
    }
  }

  Widget _cell(String text,
          {bool header = false, Alignment alignment = Alignment.center}) =>
      Container(
        height: 54,
        alignment: alignment,
        padding: const EdgeInsets.all(6),
        color: header ? const Color(0xFF3155A4) : null,
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: header ? Colors.white : const Color(0xFF263B73),
                fontSize: header ? 10 : 12,
                fontWeight: FontWeight.w700)),
      );

  Future<void> _showForm(Map<String, dynamic> request) async {
    final status = request['status']?.toString() ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Container(
          width: 1120,
          height: 700,
          color: const Color(0xFFFFFCED),
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    color: const Color(0xFF3155A4),
                    padding: const EdgeInsets.all(9),
                    child: const Text('BORANG TUNTUTAN\nKERJA LEBIH MASA',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 16),
                  const Text('hasani BOOKS',
                      style: TextStyle(
                          color: Color(0xFF3155A4),
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(color: const Color(0xFF3155A4)),
                  children: [
                    TableRow(children: [
                      _cell('NAMA'),
                      _cell(request['employee_name']?.toString() ?? '-'),
                      _cell('CAWANGAN'),
                      _cell(request['branch_id']?.toString() ?? '-'),
                    ]),
                    TableRow(children: [
                      _cell('BAHAGIAN'),
                      _cell(request['department']?.toString() ?? '-'),
                      _cell('NO. PEKERJA'),
                      _cell(request['employee_id']?.toString() ?? '-'),
                    ]),
                  ],
                ),
                const SizedBox(height: 10),
                Table(
                  border: TableBorder.all(color: const Color(0xFF3155A4)),
                  children: [
                    TableRow(children: [
                      _cell('NO', header: true),
                      _cell('TARIKH', header: true),
                      _cell('MASA MASUK', header: true),
                      _cell('KELUAR SEBENAR', header: true),
                      _cell('KELUAR', header: true),
                      _cell('JUMLAH OT', header: true),
                      _cell('SEBAB', header: true),
                      _cell('DISAHKAN', header: true),
                    ]),
                    TableRow(children: [
                      _cell('1'),
                      _cell(request['overtime_date']?.toString() ?? '-'),
                      _cell(_time(request['shift_start'])),
                      _cell(_time(request['overtime_start'])),
                      _cell(_time(request['overtime_end'])),
                      _cell(_duration(request['requested_minutes'])),
                      _cell(request['reason']?.toString() ?? '-'),
                      _cell(_status(status).toUpperCase()),
                    ]),
                    for (var row = 2; row <= 8; row++)
                      TableRow(children: [
                        _cell('$row'),
                        _cell(''),
                        _cell(''),
                        _cell(''),
                        _cell(''),
                        _cell(''),
                        _cell(''),
                        _cell(''),
                      ]),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _approval(
                          'DIMOHON OLEH',
                          request['employee_name']?.toString() ?? '-',
                          _stamp(request['submitted_at']))),
                  Expanded(
                      child: _approval('DISEMAK OLEH', widget.branchId,
                          _stamp(request['branch_approved_at']))),
                  Expanded(
                      child: _approval('DISAHKAN OLEH', 'ADMIN',
                          _stamp(request['admin_approved_at']))),
                ]),
                const SizedBox(height: 14),
                if (status == 'pending_branch')
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await _review(request, false);
                      },
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await _review(request, true);
                      },
                      child: const Text('Branch Approve'),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _approval(String title, String name, String stamp) => Container(
        height: 92,
        decoration:
            BoxDecoration(border: Border.all(color: const Color(0xFF3155A4))),
        child: Column(children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF3155A4),
            padding: const EdgeInsets.all(5),
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 7),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(stamp, style: const TextStyle(fontSize: 11)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Employee OT Requests',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    Text('Branch approval is required before admin approval.',
                        style: TextStyle(color: Colors.black54)),
                  ]),
            ),
            IconButton(
                onPressed: () => setState(_refresh),
                icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          'Unable to load OT requests:\n${snapshot.error}'));
                }
                final rows = snapshot.data ?? [];
                if (rows.isEmpty)
                  return const Center(child: Text('No OT requests.'));
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final status = row['status']?.toString() ?? '';
                    return Card(
                      child: ListTile(
                        onTap: () => _showForm(row),
                        leading:
                            const CircleAvatar(child: Icon(Icons.more_time)),
                        title: Text(row['employee_name']?.toString() ?? '-'),
                        subtitle: Text(
                            '${row['employee_id']} • ${row['overtime_date']} • '
                            '${_duration(row['requested_minutes'])} • ${row['reason']}'),
                        trailing:
                            Chip(label: Text(_status(status).toUpperCase())),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}
