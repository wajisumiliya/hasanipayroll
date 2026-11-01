import '../services/qr_card_pdf_service.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import '../services/neon_api.dart';
import '../services/qr_attendance_service.dart';
import '../widgets/qr_attendance/employee_photo.dart';
import 'qr_station_dialog.dart';

class EmployeeQrCardsPage extends StatefulWidget {
  const EmployeeQrCardsPage({super.key});
  @override
  State<EmployeeQrCardsPage> createState() => _EmployeeQrCardsPageState();
}

class _EmployeeQrCardsPageState extends State<EmployeeQrCardsPage> {
  final search = TextEditingController();
  final selected = <String>{};
  List<Map<String, dynamic>> employees = [];
  bool busy = true;
  String? error;
  Uint8List? issuedPdf;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    issuedPdf = null;
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data =
          await QrAttendanceService.get('/employees', {'q': search.text});
      if (mounted) {
        setState(() {
          employees =
              List<Map<String, dynamic>>.from(data['employees'] as List);
          selected.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> issue(List<String> ids) async {
    if (ids.isEmpty || busy) return;
    setState(() {
      busy = true;
      error = null;
      issuedPdf = null;
    });
    try {
      final renderer = await QrCardPdfService.load();
      final data =
          await QrAttendanceService.post('/issue', {'employee_ids': ids});
      final cards = List<Map<String, dynamic>>.from(data['cards'] as List);
      final photos = <String, Uint8List>{};
      for (var offset = 0; offset < cards.length; offset += 4) {
        await Future.wait(cards.skip(offset).take(4).map((card) async {
          try {
            final bytes = await NeonApi.photoRequest('${card['employee_id']}');
            if (bytes != null) photos['${card['employee_id']}'] = bytes;
          } catch (_) {
            /* Card remains usable with manual identity verification. */
          }
        }));
      }
      final bytes = await renderer.build(cards, photos);
      if (!mounted) return;
      setState(() {
        issuedPdf = bytes;
        selected.clear();
      });
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error =
            'Card generation failed. If credentials were issued, reissue and print again. $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> revoke(Map<String, dynamic> employee) async {
    setState(() => busy = true);
    try {
      await QrAttendanceService.post(
          '/revoke', {'employee_id': employee['employee_id']});
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> history(String id) async {
    try {
      final data = await QrAttendanceService.get(
          '/credentials/${Uri.encodeComponent(id)}/history');
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text('QR history · $id'),
                  content: SizedBox(
                      width: 600,
                      child: SingleChildScrollView(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final row in data['history'] as List)
                          ListTile(
                              title: Text('${row['action']}'),
                              subtitle: Text(
                                  '${QrAttendanceService.malaysiaTime(row['created_at'])} MYT · ${row['operator']}')),
                        if ((data['history'] as List).isEmpty)
                          const Text('No issuance history recorded.'),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Attendance Management · Employee QR Cards',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text(
                          'Generate or reissue cards for up to 100 employees. Reissuing immediately invalidates old cards. Credentials are returned once and are not saved in browser storage.'),
                      const SizedBox(height: 16),
                      TextField(
                          controller: search,
                          onSubmitted: (_) => load(),
                          decoration: InputDecoration(
                              labelText: 'Employee name or ID',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: IconButton(
                                  onPressed: busy ? null : load,
                                  icon: const Icon(Icons.refresh)))),
                      const SizedBox(height: 12),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        FilledButton.icon(
                            onPressed: busy || selected.isEmpty
                                ? null
                                : () => issue(selected.toList()),
                            icon: const Icon(Icons.qr_code),
                            label: Text(
                                'Generate / reissue ${selected.length} cards')),
                        OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                      selected.clear();
                                      selected.addAll(employees
                                          .where((e) => e['is_active'] == true)
                                          .take(100)
                                          .map((e) => '${e['employee_id']}'));
                                    }),
                            child: const Text(
                                'Select up to 100 active employees')),
                        OutlinedButton.icon(
                            onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => const QrStationDialog()),
                            icon: const Icon(Icons.desktop_windows),
                            label: const Text('Scanner stations')),
                        if (issuedPdf != null) ...[
                          OutlinedButton.icon(
                              onPressed: () => Printing.layoutPdf(
                                  name: 'employee_qr_cards.pdf',
                                  onLayout: (_) async => issuedPdf!),
                              icon: const Icon(Icons.print),
                              label: const Text('Print A4 cards')),
                          OutlinedButton.icon(
                              onPressed: () => Printing.sharePdf(
                                  bytes: issuedPdf!,
                                  filename: 'employee_qr_cards.pdf'),
                              icon: const Icon(Icons.download),
                              label: const Text('Download PDF')),
                          TextButton(
                              onPressed: () => setState(() => issuedPdf = null),
                              child:
                                  const Text('Clear issued cards from screen')),
                        ],
                      ]),
                      if (busy)
                        const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator()),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(error!,
                                style: const TextStyle(color: Colors.red))),
                    ]))),
        SliverList(
            delegate: SliverChildBuilderDelegate((_, index) {
          final e = employees[index], id = '${employees[index]['employee_id']}';
          final state = e['issued_at'] == null
              ? 'Not issued'
              : e['revoked_at'] != null
                  ? 'Revoked'
                  : 'Issued';
          return Card(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Row(children: [
                      Checkbox(
                          value: selected.contains(id),
                          onChanged: busy || e['is_active'] != true
                              ? null
                              : (value) => setState(() {
                                    if (value == true &&
                                        selected.length < 100) {
                                      selected.add(id);
                                    } else {
                                      selected.remove(id);
                                    }
                                  })),
                      QrEmployeePhoto(employeeId: id),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              '${e['name']}\n$id · ${e['branch_id']} · $state${e['is_active'] == true ? '' : ' · Inactive'}'))
                    ]),
                    Wrap(spacing: 8, children: [
                      TextButton(
                          onPressed: busy || e['is_active'] != true
                              ? null
                              : () => issue([id]),
                          child: Text(
                              e['issued_at'] == null ? 'Generate' : 'Reissue')),
                      TextButton(
                          onPressed: busy ||
                                  e['issued_at'] == null ||
                                  e['revoked_at'] != null
                              ? null
                              : () => revoke(e),
                          child: const Text('Revoke')),
                      TextButton(
                          onPressed: () => history(id),
                          child: const Text('History'))
                    ]),
                  ])));
        }, childCount: employees.length)),
      ]);
}
