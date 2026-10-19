import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Independent read-only Neon preview. The normal Supabase app is not started
/// when NEON_PREVIEW=true. Never compile production with this flag.
class NeonPreviewApp extends StatelessWidget {
  const NeonPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Hasani Payroll — Neon DEV',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF08255F)),
          useMaterial3: true,
        ),
        home: const NeonPreviewPage(),
      );
}

class NeonPreviewPage extends StatefulWidget {
  const NeonPreviewPage({super.key});

  @override
  State<NeonPreviewPage> createState() => _NeonPreviewPageState();
}

class _NeonPreviewPageState extends State<NeonPreviewPage> {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5001',
  );

  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? token;
  String? error;
  String? signedInAs;
  List<Map<String, dynamic>> employees = const [];

  Uri _uri(String path) {
    final base = apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return {...Map<String, dynamic>.from(decoded), '_status': response.statusCode};
      }
    } catch (_) {
      // Malformed/unavailable response gets a safe, generic error.
    }
    return {'ok': false, 'message': 'Unexpected API response.', '_status': response.statusCode};
  }

  Future<void> login() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      employees = const [];
    });
    try {
      final response = await http
          .post(
            _uri('/api/auth/login'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'username': username.text.trim(),
              'password': password.text,
            }),
          )
          .timeout(const Duration(seconds: 25));
      final data = await _decode(response);
      final accessToken = data['accessToken']?.toString() ?? '';
      if (response.statusCode != 200 || data['ok'] != true) {
        throw StateError(data['message']?.toString() ?? 'Login failed.');
      }
      if (data['requiresPasswordChange'] == true || data['firstLogin'] == true) {
        throw StateError('This account requires first-login password setup. Use the regular payroll app to complete it.');
      }
      if (accessToken.isEmpty) {
        throw StateError('The API did not return a login token.');
      }
      token = accessToken;
      signedInAs = username.text.trim();
      password.clear();
      await refreshDirectory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        token = null;
        signedInAs = null;
        error = e is StateError ? e.message.toString() : 'Cannot reach Neon DEV API. Check the backend and API_BASE_URL.';
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refreshDirectory() async {
    final activeToken = token;
    if (activeToken == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await http
          .get(_uri('/api/neon/preview/employees'), headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $activeToken',
          })
          .timeout(const Duration(seconds: 25));
      final data = await _decode(response);
      if (response.statusCode != 200 || data['ok'] != true || data['source'] != 'neon') {
        throw StateError(data['message']?.toString() ?? 'Unable to load employees from Neon.');
      }
      final rows = data['employees'];
      if (!mounted) return;
      setState(() {
        employees = rows is List
            ? rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
            : const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e is StateError ? e.message.toString() : 'Neon DEV API request failed.';
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void signOut() {
    setState(() {
      token = null;
      signedInAs = null;
      employees = const [];
      error = null;
      password.clear();
    });
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = token != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasani Payroll • Neon DEV'),
        actions: [
          if (loggedIn) IconButton(onPressed: busy ? null : signOut, icon: const Icon(Icons.logout), tooltip: 'Sign out'),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_done, color: Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Neon PostgreSQL DEV Preview\nRead-only directory • no Supabase connection'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(error!),
                  ),
                ),
              if (!loggedIn) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: username,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Username / Employee ID', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  onSubmitted: (_) => login(),
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : login,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in to Neon DEV'),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: Text('Signed in: ${signedInAs ?? ""}', style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(
                      onPressed: busy ? null : refreshDirectory,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh from Neon',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Employees returned by Neon: ${employees.length}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (employees.isEmpty && !busy)
                  const Text('No employees are visible to this account.'),
                ...employees.map((employee) {
                  final name = employee['name']?.toString() ?? '';
                  final id = employee['employee_id']?.toString() ?? '';
                  final branch = employee['branch_id']?.toString() ?? '';
                  final department = employee['department']?.toString() ?? '';
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(name.isEmpty ? id : name),
                      subtitle: Text('$id • $branch\n$department'),
                      isThreeLine: true,
                      trailing: employee['is_active'] == true
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.remove_circle_outline),
                    ),
                  );
                }),
              ],
              if (busy) const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              const SizedBox(height: 20),
              SelectableText('DEV API: $apiBaseUrl', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
