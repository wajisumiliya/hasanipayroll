import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_service.dart';
import '../services/neon_api.dart';
import '../services/qr_attendance_service.dart';
import '../widgets/qr_attendance/employee_photo.dart';

/// USB HID input. The browser cannot detect physical scanner connectivity.
class QrAttendancePage extends StatefulWidget {
  const QrAttendancePage(
      {super.key,
      this.kiosk = false,
      this.gateway = const QrAttendanceGateway()});
  final bool kiosk;
  final QrAttendanceGateway gateway;
  @override
  State<QrAttendancePage> createState() => _QrAttendancePageState();
}

class _QrAttendancePageState extends State<QrAttendancePage> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  List<Map<String, dynamic>> stations = [];
  String? stationId, sessionId, error;
  Map<String, dynamic>? pending, preview, confirmed;
  String? pendingCode, verificationToken, previewEmployeeId;
  bool busy = true;
  late final String storageKey =
      'qr_pending_${AppService.instance.currentUser?.username}';
  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && preview == null) focusNode.requestFocus();
    });
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      if (saved != null) {
        pending = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      }
      final data = await widget.gateway.get('/stations');
      if (!mounted) return;
      setState(() {
        stations = List<Map<String, dynamic>>.from(data['stations'] as List);
        stationId = stations
            .where((s) => s['enabled'] == true)
            .firstOrNull?['id']
            ?.toString();
      });
      if (pending != null) {
        sessionId = pending!['session_id']?.toString();
        await checkResult();
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refocus();
      }
    }
  }

  Future<void> startSession() async {
    if (stationId == null || pending != null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result =
          await widget.gateway.post('/session', {'station_id': stationId});
      if (mounted) {
        setState(() {
          sessionId = result['id'].toString();
          confirmed = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refocus();
      }
    }
  }

  Future<void> scan(String value) async {
    if (busy || preview != null || sessionId == null) return;
    final code = value.trim();
    controller.clear();
    setState(() {
      busy = true;
      error = null;
      confirmed = null;
    });
    try {
      if (pending != null) {
        final status = await widget.gateway.get(
            '/requests/${pending!['request_id']}',
            {'session_id': pending!['session_id'].toString()});
        if (status['state'] != 'NOT_FOUND') {
          await accept(status);
          return;
        }
      }
      final result = await widget.gateway
          .post('/preview', {'session_id': sessionId, 'qr_value': code});
      if (!mounted) return;
      final employee = Map<String, dynamic>.from(result['employee'] as Map);
      if (pending != null &&
          pending!['employee_id'] != employee['employee_id']) {
        throw StateError(
            'Rescan the original employee card for the pending request.');
      }
      previewEmployeeId = employee['employee_id']?.toString();
      pendingCode = code;
      verificationToken = result['verification_token']?.toString();
      if (result['verification_required'] == true) {
        setState(() =>
            preview = Map<String, dynamic>.from(result['employee'] as Map));
      } else {
        await submit();
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refocus();
      }
    }
  }

  Future<void> clearPending() async {
    await (await SharedPreferences.getInstance()).remove(storageKey);
    pending = null;
    pendingCode = null;
    verificationToken = null;
  }

  Future<void> accept(Map<String, dynamic> result) async {
    if (result['ok'] != true || result['event_id'] == null) {
      throw StateError('The server has not confirmed a recorded punch.');
    }
    await clearPending();
    if (mounted) {
      setState(() {
        confirmed = result;
        preview = null;
        error = null;
      });
    }
  }

  Future<void> submit() async {
    if (pendingCode == null || sessionId == null) return;
    setState(() => busy = true);
    try {
      pending ??= {
        'request_id': QrAttendanceService.requestId(),
        'session_id': sessionId,
        'employee_id': previewEmployeeId
      };
      // Persist identifiers only. Never store the employee card credential.
      await (await SharedPreferences.getInstance())
          .setString(storageKey, jsonEncode(pending));
      final result = await widget.gateway.post('/scan', {
        ...pending!,
        'qr_value': pendingCode,
        'verification_token': verificationToken
      });
      await accept(result);
    } catch (e) {
      if (e is NeonApiException && e.data?['attempt_recorded'] == true) {
        await clearPending();
      }
      if (mounted) {
        setState(() {
          preview = null;
          error = pending != null
              ? 'Result uncertain. Check the saved request before retrying. $e'
              : '$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refocus();
      }
    }
  }

  Future<void> checkResult() async {
    if (pending == null) return;
    if (mounted) setState(() => busy = true);
    try {
      final result = await widget.gateway.get(
          '/requests/${pending!['request_id']}',
          {'session_id': pending!['session_id'].toString()});
      if (result['state'] == 'NOT_FOUND') {
        if (mounted) {
          setState(() => error =
              'No committed result yet. Rescan the ORIGINAL card to retry with the same request identifier.');
        }
      } else {
        await accept(result);
      }
    } catch (e) {
      if (e is NeonApiException && e.data?['attempt_recorded'] == true) {
        await clearPending();
      }
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refocus();
      }
    }
  }

  Future<void> cancelPending() async {
    if (pending == null || busy) return;
    setState(() => busy = true);
    try {
      final result = await widget.gateway.post('/requests/cancel', pending!);
      if (result['cancelled'] == true) {
        await clearPending();
        if (mounted) {
          setState(() {
            sessionId = null;
            error =
                'Pending request cancelled. No punch was recorded for it. Start a new scanner session.';
          });
        }
      } else {
        await accept(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error =
            'Cancellation is not confirmed. Check the request again. $e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        refocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const Icon(Icons.qr_code_scanner, size: 40),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Text('QR Attendance Scanner',
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800))),
                        if (!widget.kiosk)
                          IconButton(
                              tooltip:
                                  'Open kiosk display (F11 for browser fullscreen)',
                              onPressed: busy || pending != null
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const QrAttendancePage(
                                                  kiosk: true))),
                              icon: const Icon(Icons.fullscreen)),
                      ]),
                      const SizedBox(height: 12),
                      const Text(
                          'USB keyboard (HID) scanner · Enter suffix · Malaysia time. Keep this browser tab focused. Hardware connection is not detectable from this screen.'),
                      const SizedBox(height: 20),
                      if (sessionId == null) ...[
                        if (stations.isEmpty && !busy)
                          const Text(
                              'No registered station. Ask an administrator to register this branch scanner.'),
                        DropdownButtonFormField<String>(
                            initialValue: stationId,
                            decoration: const InputDecoration(
                                labelText: 'Registered station'),
                            items: stations
                                .where((s) => s['enabled'] == true)
                                .map((s) => DropdownMenuItem(
                                    value: '${s['id']}',
                                    child: Text(
                                        '${s['label']} · ${s['branch_id']}')))
                                .toList(),
                            onChanged: busy
                                ? null
                                : (value) => setState(() => stationId = value)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed:
                                busy || stationId == null ? null : startSession,
                            icon: const Icon(Icons.login),
                            label: const Text('Start scanner session')),
                      ] else ...[
                        TextField(
                            controller: controller,
                            focusNode: focusNode,
                            autofocus: true,
                            readOnly: busy || preview != null,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: InputDecoration(
                                labelText: pending == null
                                    ? 'Ready — scan employee card'
                                    : 'Pending result — rescan original card only',
                                border: const OutlineInputBorder(),
                                suffixIcon: const Icon(Icons.qr_code_scanner)),
                            onSubmitted: scan),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: busy || pending != null
                                ? null
                                : () => setState(() => sessionId = null),
                            child:
                                const Text('Change / renew station session')),
                      ],
                      if (busy)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: LinearProgressIndicator()),
                      if (preview != null)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(children: [
                                  QrEmployeePhoto(
                                      employeeId: '${preview!['employee_id']}',
                                      size: 110),
                                  const SizedBox(height: 12),
                                  Text('${preview!['name']}',
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      '${preview!['employee_id']} · ${preview!['branch_id']}'),
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      child: Text(
                                          'Supervisor: verify the person against the photo. A card alone does not prove identity.')),
                                  Wrap(spacing: 12, children: [
                                    FilledButton(
                                        onPressed: busy ? null : submit,
                                        child: const Text(
                                            'Photo verified — record punch')),
                                    TextButton(
                                        onPressed: busy
                                            ? null
                                            : () {
                                                setState(() {
                                                  preview = null;
                                                  pendingCode = null;
                                                  verificationToken = null;
                                                });
                                                refocus();
                                              },
                                        child: const Text('Cancel'))
                                  ]),
                                ]))),
                      if (confirmed != null)
                        Card(
                            color: const Color(0xFFE0F4EB),
                            child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 64),
                                  QrEmployeePhoto(
                                      employeeId:
                                          '${confirmed!['employee_id']}',
                                      size: 80),
                                  Text('${confirmed!['action']} RECORDED',
                                      style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900)),
                                  Text(
                                      '${confirmed!['name']} · ${confirmed!['employee_id']} · ${confirmed!['branch_id']}'),
                                  Text(
                                      '${QrAttendanceService.malaysiaTime(confirmed!['scanned_at'])} MYT',
                                      style: const TextStyle(fontSize: 20)),
                                  Text(
                                      'Server confirmation #${confirmed!['event_id']} · Work date ${confirmed!['work_date']}'),
                                ]))),
                      if (error != null)
                        Card(
                            color: const Color(0xFFFFE8E8),
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(error!))),
                      if (pending != null) ...[
                        OutlinedButton.icon(
                            onPressed: busy ? null : checkResult,
                            icon: const Icon(Icons.sync),
                            label: const Text('Check pending request result')),
                        TextButton(
                            onPressed: busy ? null : cancelPending,
                            child:
                                const Text('Cancel unresolved request safely')),
                        SelectableText('Request: ${pending!['request_id']}'),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                          'First scan IN, next scan OUT. Overnight sessions keep the original work date. Minimum intervals and supervised verification follow station policy. QR punches enter payroll only after administrator reconciliation and normal attendance submission.'),
                    ]))));
    return widget.kiosk
        ? Scaffold(
            appBar: AppBar(title: const Text('Attendance kiosk')),
            body: content)
        : content;
  }
}
