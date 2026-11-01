import 'package:flutter/material.dart';
import '../services/qr_attendance_service.dart';
import 'supabase_service.dart';

class QrStationDialog extends StatefulWidget {
  const QrStationDialog({super.key});
  @override
  State<QrStationDialog> createState() => _QrStationDialogState();
}

class _QrStationDialogState extends State<QrStationDialog> {
  List<Map<String, dynamic>> stations = [], branches = [];
  final label = TextEditingController(text: 'USB Scanner 1');
  final interval = TextEditingController(text: '60');
  final maxHours = TextEditingController(text: '36');
  String? branchId, stationId, error;
  bool busy = true, verify = true, multiple = true, enabled = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    label.dispose();
    interval.dispose();
    maxHours.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final result = await Future.wait([
        QrAttendanceService.get('/stations'),
        SupabaseService.getBranches()
      ]);
      if (!mounted) return;
      setState(() {
        stations = List<Map<String, dynamic>>.from(
            (result[0] as Map)['stations'] as List);
        branches = List<Map<String, dynamic>>.from(result[1] as List);
        branchId ??= branches.firstOrNull?['id']?.toString();
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void edit(Map<String, dynamic>? s) {
    setState(() {
      stationId = s?['id']?.toString();
      branchId = s?['branch_id']?.toString() ??
          branches.firstOrNull?['id']?.toString();
      label.text = s?['label']?.toString() ?? 'USB Scanner 1';
      interval.text = '${s?['min_interval_seconds'] ?? 60}';
      maxHours.text = '${s?['max_open_hours'] ?? 36}';
      verify = s?['verification_required'] != false;
      multiple = s?['allow_multiple_sessions'] != false;
      enabled = s?['enabled'] != false;
    });
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await QrAttendanceService.post('/stations', {
        if (stationId != null) 'id': stationId,
        'branch_id': branchId,
        'label': label.text,
        'min_interval_seconds': int.tryParse(interval.text),
        'max_open_hours': int.tryParse(maxHours.text),
        'verification_required': verify,
        'allow_multiple_sessions': multiple,
        'enabled': enabled
      });
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Registered scanner stations'),
          content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final s in stations)
                  ListTile(
                      title: Text('${s['branch_id']} · ${s['label']}'),
                      subtitle:
                          Text(s['enabled'] == true ? 'Enabled' : 'Disabled'),
                      trailing: IconButton(
                          onPressed: () => edit(s),
                          icon: const Icon(Icons.edit))),
                TextButton(
                    onPressed: () => edit(null),
                    child: const Text('New station')),
                DropdownButtonFormField<String>(
                    key: ValueKey('$stationId-$branchId'),
                    initialValue: branchId,
                    decoration: const InputDecoration(labelText: 'Branch'),
                    items: branches
                        .map((b) => DropdownMenuItem(
                            value: '${b['id']}',
                            child: Text('${b['name'] ?? b['id']}')))
                        .toList(),
                    onChanged: busy || stationId != null
                        ? null
                        : (value) => setState(() => branchId = value)),
                TextField(
                    controller: label,
                    decoration:
                        const InputDecoration(labelText: 'Station label')),
                TextField(
                    controller: interval,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Minimum seconds between punches (1–3600)')),
                TextField(
                    controller: maxHours,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText:
                            'Review unmatched IN after hours (1–168; never auto OUT)')),
                SwitchListTile(
                    value: verify,
                    onChanged:
                        busy ? null : (value) => setState(() => verify = value),
                    title:
                        const Text('Supervisor photo verification required')),
                SwitchListTile(
                    value: multiple,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => multiple = value),
                    title: const Text('Allow multiple work sessions per day')),
                SwitchListTile(
                    value: enabled,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => enabled = value),
                    title: const Text('Station enabled')),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
            FilledButton(
                onPressed: busy ? null : save, child: const Text('Save policy'))
          ]);
}
