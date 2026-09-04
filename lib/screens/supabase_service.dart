// lib/screens/supabase_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<List<Map<String, dynamic>>> getMonthlyRosters({
    required String branchId,
    required int year,
    required int month,
    String? employeeId,
  }) async {
    var query = client
        .from('monthly_rosters')
        .select()
        .eq('branch_id', branchId)
        .eq('roster_year', year)
        .eq('roster_month', month);
    if (employeeId != null) query = query.eq('employee_id', employeeId);
    final response = await query.order('employee_id').order('week_number');
    return _mapList(response);
  }

  static Future<void> saveMonthlyRoster(Map<String, dynamic> roster) async {
    await client.from('monthly_rosters').upsert(roster,
        onConflict:
            'branch_id,employee_id,roster_year,roster_month,week_number');
  }
  // ============================================================
  // SUPABASE CONFIGURATION
  // ============================================================

  static const String supabaseUrl = 'https://qychfoxygqzmtsqtxihp.supabase.co';

  static const String supabaseAnonKey =
      'sb_publishable_zZk97NP7edFidJ0HBCUKtQ_SAQ69tId';

  // ============================================================
  // CLIENT
  // ============================================================

  static SupabaseClient get client => Supabase.instance.client;

  // ============================================================
  // INITIALIZE
  // ============================================================

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );

      debugPrint('======================================');
      debugPrint('SUPABASE INITIALIZED');
      debugPrint('URL: $supabaseUrl');
      debugPrint('======================================');
    } catch (e, stackTrace) {
      debugPrint('======================================');
      debugPrint('SUPABASE INITIALIZATION ERROR');
      debugPrint('$e');
      debugPrint('$stackTrace');
      debugPrint('======================================');
      rethrow;
    }
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  static User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (e) {
      debugPrint('CURRENT USER ERROR: $e');
      return null;
    }
  }

  // ============================================================
  // BRANCH ACTIVITY LOGS
  // ============================================================

  static Future<String?> startBranchActivity({
    required String branchId,
    required String action,
    String? employeeId,
    String? employeeName,
    Map<String, dynamic>? details,
  }) async {
    try {
      final response = await client
          .from('branch_activity_logs')
          .insert({
            'branch_id': branchId.trim(),
            'action': action.trim(),
            'employee_id': employeeId?.trim(),
            'employee_name': employeeName?.trim(),
            'opened_at': DateTime.now().toUtc().toIso8601String(),
            'details': details ?? <String, dynamic>{},
          })
          .select('id')
          .single();

      return response['id']?.toString();
    } catch (e) {
      debugPrint('START BRANCH ACTIVITY ERROR: $e');
      return null;
    }
  }

  static Future<void> closeBranchActivity(String? activityId) async {
    if (activityId == null || activityId.trim().isEmpty) return;

    try {
      await client
          .from('branch_activity_logs')
          .update({'closed_at': DateTime.now().toUtc().toIso8601String()}).eq(
              'id', activityId);
    } catch (e) {
      debugPrint('CLOSE BRANCH ACTIVITY ERROR: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getBranchActivityLogs({
    String? branchId,
    DateTime? date,
    int limit = 500,
  }) async {
    try {
      var query = client.from('branch_activity_logs').select();

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.eq('branch_id', branchId.trim());
      }

      if (date != null) {
        final start = DateTime(date.year, date.month, date.day).toUtc();
        final end = DateTime(date.year, date.month, date.day + 1).toUtc();
        query = query
            .gte('opened_at', start.toIso8601String())
            .lt('opened_at', end.toIso8601String());
      }

      final response =
          await query.order('opened_at', ascending: false).limit(limit);
      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET BRANCH ACTIVITY LOGS ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // AUTH
  // ============================================================

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      debugPrint('LOGIN SUCCESS: ${response.user?.email}');

      return response;
    } catch (e, stackTrace) {
      debugPrint('LOGIN ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await client.auth.signOut();
      debugPrint('LOGOUT SUCCESS');
    } catch (e, stackTrace) {
      debugPrint('LOGOUT ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // CONNECTION TEST
  // ============================================================

  static Future<bool> testConnection() async {
    try {
      await client.from('employees').select('employee_id').limit(1);

      debugPrint('SUPABASE CONNECTION: OK');
      return true;
    } catch (e, stackTrace) {
      debugPrint('SUPABASE CONNECTION ERROR: $e');
      debugPrint('$stackTrace');
      return false;
    }
  }

  static Future<bool> testEmployeesTable() async {
    try {
      final response = await client.from('employees').select().limit(1);

      debugPrint('EMPLOYEES TABLE OK: $response');
      return true;
    } catch (e, stackTrace) {
      debugPrint('EMPLOYEES TABLE ERROR: $e');
      debugPrint('$stackTrace');
      return false;
    }
  }

  static Future<bool> testPayrollTable() async {
    try {
      final response = await client.from('payroll').select().limit(1);

      debugPrint('PAYROLL TABLE OK: $response');
      return true;
    } catch (e, stackTrace) {
      debugPrint('PAYROLL TABLE ERROR: $e');
      debugPrint('$stackTrace');
      return false;
    }
  }

  // ============================================================
  // NORMALIZATION
  // ============================================================

  static List<Map<String, dynamic>> _mapList(dynamic response) {
    if (response == null || response is! List) {
      return <Map<String, dynamic>>[];
    }

    return response
        .map<Map<String, dynamic>>(
          (item) => Map<String, dynamic>.from(item as Map),
        )
        .toList();
  }

  static Map<String, dynamic> _map(dynamic response) {
    return Map<String, dynamic>.from(response as Map);
  }

  // ============================================================
  // DATE
  // ============================================================

  static String _dateOnlyText(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BRANCH NORMALIZATION
  // ============================================================

  static String _normaliseBranchValue(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('branch', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();

    const branchLoginAliases = <String, String>{
      'hbsp': 'sungaipetani',
      'hbamj': 'amanjaya',
      'hbas': 'alorsetar',
      'hbastana': 'astana',
      'hbgurun': 'gurun',
      'hbjitra': 'jitra',
      'hbperai': 'prai',
      'hbkulim': 'kulim',
      'hblkw': 'langkawi',
      'hpspfrn': 'sungaipetani',
      'hbspfrn': 'sungaipetani',
      'hbamjfrn': 'amanjaya',
      'hbasfrn': 'alorsetar',
      'hbastanafrn': 'astana',
      'hbgurunfrn': 'gurun',
      'hbjitrafrn': 'jitra',
      'hbperaifrn': 'prai',
      'hbkulimfrn': 'kulim',
      'hblkwfrn': 'langkawi',
    };

    return branchLoginAliases[normalized] ?? normalized;
  }

  // ============================================================
  // EMPLOYEES
  // ============================================================

  static Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final response = await client
          .from('employees')
          .select()
          .order('name', ascending: true);

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET EMPLOYEES ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getActiveEmployees() async {
    try {
      final response = await client
          .from('employees')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET ACTIVE EMPLOYEES ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getInactiveEmployees() async {
    try {
      final response = await client
          .from('employees')
          .select()
          .eq('is_active', false)
          .order('name', ascending: true);

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET INACTIVE EMPLOYEES ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getEmployee(
    dynamic employeeId,
  ) async {
    try {
      final response = await client
          .from('employees')
          .select()
          .eq('employee_id', employeeId.toString())
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('GET EMPLOYEE ERROR [$employeeId]: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getEmployeesByBranch(
    String? branchId, {
    Iterable<String?> aliases = const [],
    bool? frnOnly,
  }) async {
    try {
      final wanted = <String>{
        if (branchId != null && branchId.trim().isNotEmpty)
          _normaliseBranchValue(branchId),
        ...aliases
            .whereType<String>()
            .where((v) => v.trim().isNotEmpty)
            .map(_normaliseBranchValue),
      }..remove('');

      if (wanted.isEmpty) {
        return getEmployees();
      }

      final response = await client
          .from('employees')
          .select()
          .order('name', ascending: true);

      return _mapList(response).where((employee) {
        final isFrn =
            employee['address']?.toString().toUpperCase().contains('FRN') ==
                true;
        if (frnOnly == true && !isFrn) return false;
        if (frnOnly == false && isFrn) return false;

        final values = <dynamic>[
          employee['branch_id'],
          employee['branch_name'],
          employee['branch'],
          employee['branchName'],
        ];

        return values.any((value) {
          final actual = _normaliseBranchValue(
            value?.toString() ?? '',
          );

          if (actual.isEmpty) {
            return false;
          }

          return wanted.any(
            (target) =>
                actual == target ||
                actual.contains(target) ||
                target.contains(actual),
          );
        });
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('GET EMPLOYEES BY BRANCH ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getActiveEmployeesByBranch(
    String? branchId,
  ) async {
    try {
      if (branchId == null || branchId.trim().isEmpty) {
        return getActiveEmployees();
      }

      final response = await client
          .from('employees')
          .select()
          .eq('branch_id', branchId.trim())
          .eq('is_active', true)
          .order('name', ascending: true);

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET ACTIVE BRANCH EMPLOYEES ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getEmployeesByDepartment(
    String department,
  ) async {
    try {
      final response = await client
          .from('employees')
          .select()
          .eq('department', department.trim())
          .order('name', ascending: true);

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET EMPLOYEES BY DEPARTMENT ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getActiveEmployeesByDepartment(
    String department,
  ) async {
    try {
      final response = await client
          .from('employees')
          .select()
          .eq('department', department.trim())
          .eq('is_active', true)
          .order('name', ascending: true);

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET ACTIVE DEPARTMENT EMPLOYEES ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getEmployeesByBranchAndDepartment({
    String? branchId,
    String? department,
    bool? activeOnly,
  }) async {
    try {
      var query = client.from('employees').select();

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.eq('branch_id', branchId.trim());
      }

      if (department != null && department.trim().isNotEmpty) {
        query = query.eq('department', department.trim());
      }

      if (activeOnly == true) {
        query = query.eq('is_active', true);
      }

      final response = await query.order(
        'name',
        ascending: true,
      );

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET BRANCH/DEPARTMENT EMPLOYEES ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // NEW JOINERS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getNewJoiners({
    String? branchId,
  }) async {
    try {
      final now = DateTime.now();

      final sixMonthsAgo = DateTime(
        now.year,
        now.month - 6,
        now.day,
      );

      var query = client
          .from('employees')
          .select()
          .gte('joining_date', _dateOnlyText(sixMonthsAgo))
          .lte('joining_date', _dateOnlyText(now));

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.eq('branch_id', branchId.trim());
      }

      final response = await query.order(
        'joining_date',
        ascending: false,
      );

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET NEW JOINERS ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getActiveNewJoiners({
    String? branchId,
  }) async {
    try {
      final now = DateTime.now();

      final sixMonthsAgo = DateTime(
        now.year,
        now.month - 6,
        now.day,
      );

      var query = client
          .from('employees')
          .select()
          .eq('is_active', true)
          .gte('joining_date', _dateOnlyText(sixMonthsAgo))
          .lte('joining_date', _dateOnlyText(now));

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.eq('branch_id', branchId.trim());
      }

      final response = await query.order(
        'joining_date',
        ascending: false,
      );

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET ACTIVE NEW JOINERS ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // EMPLOYEE COUNTS
  // ============================================================

  static Future<int> getTotalEmployeeCount({
    String? branchId,
  }) async {
    try {
      var query = client.from('employees').select('employee_id');

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.eq('branch_id', branchId.trim());
      }

      final response = await query;

      return (response as List).length;
    } catch (e, stackTrace) {
      debugPrint('TOTAL EMPLOYEE COUNT ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<int> getActiveEmployeeCount({
    String? branchId,
  }) async {
    try {
      var query =
          client.from('employees').select('employee_id').eq('is_active', true);

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.eq('branch_id', branchId.trim());
      }

      final response = await query;

      return (response as List).length;
    } catch (e, stackTrace) {
      debugPrint('ACTIVE EMPLOYEE COUNT ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<int> getNewJoinerCount({
    String? branchId,
  }) async {
    final employees = await getNewJoiners(
      branchId: branchId,
    );

    return employees.length;
  }

  // ============================================================
  // DEPARTMENTS
  // ============================================================

  static Future<List<String>> getDepartments({
    String? branchId,
  }) async {
    try {
      var query = client.from('employees').select('department');

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.eq('branch_id', branchId.trim());
      }

      final response = await query;

      final values = <String>{};

      for (final item in response as List) {
        final map = Map<String, dynamic>.from(item as Map);
        final value = map['department']?.toString().trim();

        if (value != null && value.isNotEmpty) {
          values.add(value);
        }
      }

      final departments = values.toList()..sort();

      return departments;
    } catch (e, stackTrace) {
      debugPrint('GET DEPARTMENTS ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // BRANCHES
  // ============================================================

  static Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final response =
          await client.from('branches').select().order('name', ascending: true);

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET BRANCHES ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllBranches() async {
    try {
      final response = await client.from('employees').select();

      final seen = <String>{};
      final result = <Map<String, dynamic>>[];

      for (final row in _mapList(response)) {
        for (final key in [
          'branch_id',
          'branch',
          'branch_name',
          'branchName',
        ]) {
          final value = row[key]?.toString().trim();

          if (value != null &&
              value.isNotEmpty &&
              seen.add(value.toLowerCase())) {
            result.add({
              'value': value,
            });
          }
        }
      }

      result.sort(
        (a, b) => a['value'].toString().toLowerCase().compareTo(
              b['value'].toString().toLowerCase(),
            ),
      );

      return result;
    } catch (e, stackTrace) {
      debugPrint('GET ALL BRANCHES ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // ADD EMPLOYEE
  // ============================================================

  static Future<Map<String, dynamic>> addEmployee(
    Map<String, dynamic> employee,
  ) async {
    try {
      final response =
          await client.from('employees').insert(employee).select().single();

      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('ADD EMPLOYEE ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> addEmployeeForBranch({
    required String branchId,
    required Map<String, dynamic> employee,
  }) async {
    final payload = Map<String, dynamic>.from(employee)
      ..['branch_id'] = branchId.trim();
    return addEmployee(payload);
  }

  static Future<Map<String, dynamic>> submitEmployeeRequest({
    required String branchId,
    required Map<String, dynamic> employee,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(employee)
        ..remove('employee_id')
        ..remove('is_active')
        ..['branch_id'] = branchId.trim()
        ..['status'] = 'PENDING';
      final response = await client
          .from('employee_requests')
          .insert(payload)
          .select()
          .single();
      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('SUBMIT EMPLOYEE REQUEST ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getEmployeeRequests({
    String? status,
  }) async {
    try {
      var query = client.from('employee_requests').select();
      if (status != null && status.trim().isNotEmpty) {
        query = query.eq('status', status.trim().toUpperCase());
      }
      final response = await query.order('requested_at', ascending: false);
      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET EMPLOYEE REQUESTS ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> approveEmployeeRequest({
    required String requestId,
    required String employeeId,
  }) async {
    try {
      final response = await client.rpc(
        'approve_employee_request',
        params: {
          'request_id': requestId,
          'new_employee_id': employeeId.trim().toUpperCase(),
        },
      );
      if (response is List && response.isNotEmpty) {
        return _map(response.first);
      }
      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('APPROVE EMPLOYEE REQUEST ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<void> rejectEmployeeRequest({
    required String requestId,
    String? note,
  }) async {
    try {
      await client
          .from('employee_requests')
          .update({
            'status': 'REJECTED',
            'admin_note': note?.trim(),
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('status', 'PENDING');
    } catch (e, stackTrace) {
      debugPrint('REJECT EMPLOYEE REQUEST ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // UPDATE EMPLOYEE
  // ============================================================

  static Future<Map<String, dynamic>> updateEmployee(
    dynamic employeeId,
    Map<String, dynamic> employee,
  ) async {
    try {
      final response = await client
          .from('employees')
          .update(employee)
          .eq('employee_id', employeeId.toString())
          .select()
          .single();

      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('UPDATE EMPLOYEE ERROR [$employeeId]: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateEmployeeForBranch({
    required String employeeId,
    required String branchId,
    required Map<String, dynamic> changes,
  }) async {
    try {
      final response = await client
          .from('employees')
          .update(changes)
          .eq('employee_id', employeeId.trim())
          .eq('branch_id', branchId.trim())
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception('Employee does not belong to this branch.');
      }
      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('BRANCH UPDATE EMPLOYEE ERROR [$employeeId]: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // UPDATE EMPLOYEE STATUS
  // ============================================================

  static Future<void> updateEmployeeStatus({
    required dynamic employeeId,
    required bool isActive,
  }) async {
    try {
      await client
          .from('employees')
          .update({
            'is_active': isActive,
          })
          .eq(
            'employee_id',
            employeeId.toString(),
          )
          .select('employee_id');
    } catch (e, stackTrace) {
      debugPrint('UPDATE EMPLOYEE STATUS ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // DELETE EMPLOYEE
  // ============================================================

  static Future<void> deleteEmployee(
    dynamic employeeId,
  ) async {
    try {
      await client.from('employees').delete().eq(
            'employee_id',
            employeeId.toString(),
          );
    } catch (e, stackTrace) {
      debugPrint('DELETE EMPLOYEE ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // PAYROLL
  // ============================================================

  static Future<List<Map<String, dynamic>>> getPayroll() async {
    try {
      final response = await client
          .from('payroll')
          .select()
          .order('period', ascending: false);

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET PAYROLL ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getPayrollByEmployee(
    dynamic employeeId,
  ) async {
    try {
      final response = await client
          .from('payroll')
          .select()
          .eq(
            'employee_id',
            employeeId.toString(),
          )
          .order(
            'period',
            ascending: false,
          );

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET EMPLOYEE PAYROLL ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getPayrollByBranch(
    String? branchId,
  ) async {
    try {
      if (branchId == null || branchId.trim().isEmpty) {
        return getPayroll();
      }

      final employees = await getEmployeesByBranch(branchId);

      final employeeIds = employees
          .map((e) => e['employee_id']?.toString())
          .whereType<String>()
          .toSet();

      if (employeeIds.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      final payroll = await getPayroll();

      return payroll.where((record) {
        final employeeId = record['employee_id']?.toString();

        return employeeId != null && employeeIds.contains(employeeId);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('GET PAYROLL BY BRANCH ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> addPayroll(
    Map<String, dynamic> payroll,
  ) async {
    try {
      final response =
          await client.from('payroll').insert(payroll).select().single();

      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('ADD PAYROLL ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updatePayroll(
    dynamic payrollId,
    Map<String, dynamic> payroll,
  ) async {
    try {
      final response = await client
          .from('payroll')
          .update(payroll)
          .eq(
            'id',
            payrollId.toString(),
          )
          .select()
          .single();

      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('UPDATE PAYROLL ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<void> deletePayroll(
    dynamic payrollId,
  ) async {
    try {
      await client.from('payroll').delete().eq(
            'id',
            payrollId.toString(),
          );
    } catch (e, stackTrace) {
      debugPrint('DELETE PAYROLL ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // ATTENDANCE - ALL
  // ============================================================

  static Future<List<Map<String, dynamic>>> getAttendance() async {
    try {
      final response = await client.from('attendance').select().order(
            'attendance_date',
            ascending: false,
          );

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET ATTENDANCE ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // ATTENDANCE BY BRANCH
  // ============================================================

  static Future<List<Map<String, dynamic>>> getAttendanceByBranch(
    String? branchId,
  ) async {
    try {
      if (branchId == null || branchId.trim().isEmpty) {
        return getAttendance();
      }

      final response = await client
          .from('attendance')
          .select()
          .eq(
            'branch_id',
            branchId.trim(),
          )
          .order(
            'attendance_date',
            ascending: false,
          );

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET BRANCH ATTENDANCE ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getAttendanceByBranchDate({
    required String branchId,
    required DateTime date,
  }) async {
    try {
      final dateText = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final response = await client
          .from('attendance')
          .select()
          .eq('branch_id', branchId.trim())
          .eq('attendance_date', dateText);
      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET BRANCH DATE ATTENDANCE ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingOtRequests() async {
    try {
      final response = await client
          .from('overtime_requests')
          .select()
          .order('submitted_at', ascending: false);
      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET OT REQUESTS ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<void> reviewOtRequest({
    required String requestId,
    required bool approve,
    int? approvedOtMinutes,
  }) async {
    try {
      await client.from('overtime_requests').update({
        'status': approve ? 'approved' : 'rejected',
        'approved_minutes': approve ? approvedOtMinutes : null,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'reviewed_by': currentUser?.id,
        'admin_approved_at':
            approve ? DateTime.now().toUtc().toIso8601String() : null,
        'admin_approved_by': approve ? currentUser?.id : null,
      }).eq('id', requestId);
    } catch (e, stackTrace) {
      debugPrint('REVIEW OT REQUEST ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getBranchOtRequests(
      String branchId) async {
    final response = await client
        .from('overtime_requests')
        .select()
        .ilike('branch_id', branchId.trim())
        .order('submitted_at', ascending: false);
    return _mapList(response);
  }

  static Future<void> reviewBranchOtRequest({
    required String requestId,
    required bool approve,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await client.from('overtime_requests').update({
      'status': approve ? 'pending_admin' : 'rejected',
      'branch_approved_at': approve ? now : null,
      'branch_approved_by': approve ? currentUser?.id : null,
      if (!approve) 'reviewed_at': now,
      if (!approve) 'reviewed_by': currentUser?.id,
    }).eq('id', requestId);
  }

  static Future<List<Map<String, dynamic>>> getEmployeeOtRequests(
      String employeeId) async {
    final response = await client
        .from('overtime_requests')
        .select()
        .eq('employee_id', employeeId.trim())
        .order('overtime_date', ascending: false);
    return _mapList(response);
  }

  static Future<void> submitOtRequest(Map<String, dynamic> request) async {
    await client.from('overtime_requests').insert(request);
  }

  // ============================================================
  // ATTENDANCE BY EMPLOYEE
  // ============================================================

  static Future<List<Map<String, dynamic>>> getAttendanceByEmployee(
    dynamic employeeId,
  ) async {
    try {
      final response = await client
          .from('attendance')
          .select()
          .eq(
            'employee_id',
            employeeId.toString(),
          )
          .order(
            'attendance_date',
            ascending: false,
          );

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET EMPLOYEE ATTENDANCE ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // ATTENDANCE BY EMPLOYEE + MONTH
  // ============================================================

  static Future<List<Map<String, dynamic>>> getAttendanceByEmployeeMonth(
    dynamic employeeId,
    int year,
    int month,
  ) async {
    try {
      final startDate = '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-01';

      final nextMonth = DateTime(
        year,
        month + 1,
        1,
      );

      final endDate = _dateOnlyText(nextMonth);

      final response = await client
          .from('attendance')
          .select()
          .eq(
            'employee_id',
            employeeId.toString(),
          )
          .gte(
            'attendance_date',
            startDate,
          )
          .lt(
            'attendance_date',
            endDate,
          )
          .order(
            'attendance_date',
            ascending: true,
          );

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint(
        'GET EMPLOYEE ATTENDANCE BY MONTH ERROR: $e',
      );
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // ATTENDANCE BY DATE
  // ============================================================

  static Future<List<Map<String, dynamic>>> getAttendanceByDate(
    String date, {
    String? branchId,
  }) async {
    try {
      var query = client.from('attendance').select().eq(
            'attendance_date',
            date,
          );

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.eq(
          'branch_id',
          branchId.trim(),
        );
      }

      final response = await query.order(
        'employee_id',
        ascending: true,
      );

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint('GET ATTENDANCE BY DATE ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // ADD ATTENDANCE
  // ============================================================

  static Future<Map<String, dynamic>> addAttendance(
    Map<String, dynamic> attendance,
  ) async {
    try {
      final response =
          await client.from('attendance').insert(attendance).select().single();

      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('ADD ATTENDANCE ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // UPDATE ATTENDANCE
  // ============================================================

  static Future<Map<String, dynamic>> updateAttendance(
    dynamic id,
    Map<String, dynamic> attendance,
  ) async {
    try {
      final response = await client
          .from('attendance')
          .update(attendance)
          .eq(
            'id',
            id.toString(),
          )
          .select()
          .single();

      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('UPDATE ATTENDANCE ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // UPDATE OT AUTHORIZATION
  // ============================================================

  static Future<void> updateAttendanceOtAuthorization({
    required String employeeId,
    required DateTime date,
    required bool otAuthorized,
  }) async {
    try {
      await client
          .from('attendance')
          .update({
            'ot_authorized': otAuthorized,
          })
          .eq(
            'employee_id',
            employeeId.trim(),
          )
          .eq(
            'attendance_date',
            _dateOnlyText(date),
          );
    } catch (e, stackTrace) {
      debugPrint(
        'UPDATE ATTENDANCE OT AUTHORIZATION ERROR: $e',
      );
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // MONTHLY ATTENDANCE
  //
  // WORK:
  //   workingIn -> workingOut
  //
  // BREAK:
  //   morningIn -> morningOut
  //   +
  //   afternoonIn -> afternoonOut
  //   +
  //   eveningIn -> eveningOut
  //
  // OT:
  //   overtimeIn -> overtimeOut
  //
  // NET:
  //   work - break
  // ============================================================

  // ============================================================
  // SAVE MONTHLY ATTENDANCE ROW
  // ============================================================
  //
  // Supports both:
  //
  // 1. Existing dashboard calls that provide:
  //    workMinutes
  //    breakMinutes
  //    overtimeMinutes
  //    netWorkingMinutes
  //
  // 2. Calls that only provide clock-in/out times.
  //
  // If the minute values are supplied, they are used.
  // Otherwise they are calculated from the time fields.
  //
  // ============================================================

  // ============================================================
// MONTHLY ATTENDANCE
//
// BUSINESS RULES
//
// 1. Working time:
//      workingIn -> workingOut
//
// 2. Break time:
//      morningIn   -> morningOut
//      afternoonIn -> afternoonOut
//      eveningIn   -> eveningOut
//
// 3. OT time:
//      overtimeIn -> overtimeOut is STORED ONLY.
//      It does NOT automatically calculate OT.
//
// 4. Net working:
//      gross working - all breaks
//
// 5. Daily allocated working time:
//      7 hours 30 minutes = 450 minutes
//
// 6. Automatic OT:
//      max(net working - 450, 0)
//
// Example:
//
//      08:30 -> 17:00 = 510 min
//      Break = 60 min
//      Net = 450 min
//      OT = 0
//
//      08:30 -> 18:00 = 570 min
//      Break = 60 min
//      Net = 510 min
//      OT = 60 min
//
// ============================================================

  // ============================================================
// MONTHLY ATTENDANCE
//
// WORK:
//   workingIn -> workingOut
//
// BREAK:
//   morningIn -> morningOut
//   afternoonIn -> afternoonOut
//   eveningIn -> eveningOut
//
// NET:
//   work - all breaks
//
// NORMAL DAILY TARGET:
//   7 hours 30 minutes = 450 minutes
//
// OVERTIME:
//   net working minutes above 450
//
// IMPORTANT:
//   eveningIn/eveningOut are BREAK.
//   They are NOT overtime.
//
//   overtimeIn/overtimeOut are retained as optional display/
//   reference fields, but they DO NOT determine overtime.
//
//   OT is automatically calculated from NET WORKING TIME.
// ============================================================

  static Future<Map<String, dynamic>> saveMonthlyAttendanceRow({
    required String employeeId,
    required String branchId,
    required DateTime date,
    String workingIn = '',
    String workingOut = '',
    String morningIn = '',
    String morningOut = '',
    String afternoonIn = '',
    String afternoonOut = '',
    String eveningIn = '',
    String eveningOut = '',

    // Kept for compatibility with branch_dashboard.dart.
    // These DO NOT calculate OT.
    String overtimeIn = '',
    String overtimeOut = '',

    // Kept for compatibility with existing calls.
    bool otAuthorized = false,

    // Branch OT request. Admin approval is required before OT is payable.
    bool otRequested = false,

    // Daily attendance status selected by Branch/Admin.
    String status = '',

    // Kept for compatibility with existing branch_dashboard.dart.
    // The service recalculates these and DOES NOT trust them.
    int? workMinutes,
    int? breakMinutes,
    int? overtimeMinutes,
    int? netWorkingMinutes,
  }) async {
    try {
      // ==========================================================
      // DAILY NORMAL WORKING TARGET
      // 7 HOURS 30 MINUTES
      // ==========================================================

      const int normalWorkingMinutes = 450;

      // ==========================================================
      // HH:mm -> MINUTES
      // ==========================================================

      int? parseTime(String value) {
        final text = value.trim();

        if (text.isEmpty || text == '-') {
          return null;
        }

        final parts = text.split(':');

        if (parts.length != 2) {
          return null;
        }

        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);

        if (hour == null || minute == null) {
          return null;
        }

        if (hour < 0 || hour > 23) {
          return null;
        }

        if (minute < 0 || minute > 59) {
          return null;
        }

        return hour * 60 + minute;
      }

      // ==========================================================
      // TIME DIFFERENCE
      // ==========================================================

      int difference(
        String start,
        String end,
      ) {
        final startMinutes = parseTime(start);
        final endMinutes = parseTime(end);

        if (startMinutes == null || endMinutes == null) {
          return 0;
        }

        var result = endMinutes - startMinutes;

        // Overnight support.
        if (result < 0) {
          result += 1440;
        }

        return result;
      }

      // ==========================================================
      // MINUTES -> H:MM
      // ==========================================================

      String duration(int minutes) {
        if (minutes <= 0) {
          return '0:00';
        }

        final hours = minutes ~/ 60;
        final mins = minutes % 60;

        return '$hours:${mins.toString().padLeft(2, '0')}';
      }

      // ==========================================================
      // CLEAN TIME
      // ==========================================================

      String? cleanTime(String value) {
        final text = value.trim();

        if (text.isEmpty || text == '-') {
          return null;
        }

        return text;
      }

      // ==========================================================
      // 1. WORKING TIME
      //
      // Example:
      // 08:55 -> 20:55 = 720 minutes
      // ==========================================================

      final calculatedWorkMinutes = difference(
        workingIn,
        workingOut,
      );

      // ==========================================================
      // 2. BREAKS
      //
      // Morning = BREAK
      // Afternoon = BREAK
      // Evening = BREAK
      //
      // Evening is NOT OT.
      // ==========================================================

      final morningBreakMinutes = difference(
        morningIn,
        morningOut,
      );

      final afternoonBreakMinutes = difference(
        afternoonIn,
        afternoonOut,
      );

      final eveningBreakMinutes = difference(
        eveningIn,
        eveningOut,
      );

      // ==========================================================
      // 3. TOTAL BREAK
      // ==========================================================

      final calculatedBreakMinutes =
          morningBreakMinutes + afternoonBreakMinutes + eveningBreakMinutes;

      // ==========================================================
      // 4. NET WORKING TIME
      //
      // WORK - BREAK
      // ==========================================================

      var calculatedNetWorkingMinutes =
          calculatedWorkMinutes - calculatedBreakMinutes;

      if (calculatedNetWorkingMinutes < 0) {
        calculatedNetWorkingMinutes = 0;
      }

      // ==========================================================
      // 5. AUTOMATIC OT
      //
      // ONLY NET WORKING ABOVE 7:30 IS OT.
      //
      // 7:30 = 450 minutes
      // ==========================================================

      final extraMinutes = calculatedNetWorkingMinutes > normalWorkingMinutes
          ? calculatedNetWorkingMinutes - normalWorkingMinutes
          : 0;

      // OT requires ALL conditions:
      // 1) allocated break fulfilled (60 minutes),
      // 2) more than 10 minutes above the normal 7:30 net target,
      // 3) Branch requested OT,
      // 4) Admin approved OT.
      final bool breakFulfilled = calculatedBreakMinutes >= 60;
      final bool otEligible = breakFulfilled && extraMinutes > 10;

      final int calculatedOvertimeMinutes =
          (otEligible && otRequested && otAuthorized) ? extraMinutes : 0;

      final String otStatus = otAuthorized ? 'true' : 'false';

      // ==========================================================
      // 7. DATE
      // ==========================================================

      final dateString = _dateOnlyText(date);

      // ==========================================================
      // 8. ATTENDANCE ID
      //
      // employee + date is unique.
      // ==========================================================

      final attendanceId = '${employeeId.trim()}_$dateString';

      // ==========================================================
      // 9. STATUS
      // ==========================================================

      final bool hasWorkingTime = workingIn.trim().isNotEmpty &&
          workingIn.trim() != '-' &&
          workingOut.trim().isNotEmpty &&
          workingOut.trim() != '-';

      // Never send an empty/unsupported status. The attendance table uses
      // these business statuses: Present, Late, OFF, MC, PL, AL, EL, PH, UNPAID.
      String attendanceStatus = status.trim();

      if (attendanceStatus.isEmpty) {
        if (hasWorkingTime) {
          final checkIn = parseTime(workingIn);
          attendanceStatus =
              (checkIn != null && checkIn > 480) ? 'Late' : 'Present';
        } else {
          attendanceStatus = 'OFF';
        }
      }

      const allowedStatuses = {
        'Present',
        'Late',
        'Absent',
        'OFF',
        'MC',
        'PL',
        'AL',
        'EL',
        'PH',
        'UNPAID',
      };

      if (!allowedStatuses.contains(attendanceStatus)) {
        throw Exception(
          'Invalid attendance status: $attendanceStatus',
        );
      }

      // ==========================================================
      // 10. DATABASE DATA
      // ==========================================================

      final data = <String, dynamic>{
        // --------------------------------------------------------
        // PRIMARY KEY
        // --------------------------------------------------------

        'id': attendanceId,

        // --------------------------------------------------------
        // EMPLOYEE
        // --------------------------------------------------------

        'employee_id': employeeId.trim(),

        // --------------------------------------------------------
        // BRANCH
        // --------------------------------------------------------

        'branch_id': branchId.trim(),

        // --------------------------------------------------------
        // DATE
        // --------------------------------------------------------

        'attendance_date': dateString,

        // --------------------------------------------------------
        // CHECK IN / OUT
        //
        // IMPORTANT:
        // These columns are NOT NULL.
        // Therefore NEVER send null.
        // --------------------------------------------------------

        'check_in': workingIn.trim().isEmpty ? '-' : workingIn.trim(),

        'check_out': workingOut.trim().isEmpty ? '-' : workingOut.trim(),

        // --------------------------------------------------------
        // STATUS
        // --------------------------------------------------------

        'status': attendanceStatus,

        // --------------------------------------------------------
        // MORNING BREAK
        // --------------------------------------------------------

        'morning_in': cleanTime(morningIn),
        'morning_out': cleanTime(morningOut),

        // --------------------------------------------------------
        // AFTERNOON BREAK
        // --------------------------------------------------------

        'afternoon_in': cleanTime(afternoonIn),
        'afternoon_out': cleanTime(afternoonOut),

        // --------------------------------------------------------
        // EVENING BREAK
        // --------------------------------------------------------

        'evening_in': cleanTime(eveningIn),
        'evening_out': cleanTime(eveningOut),

        // --------------------------------------------------------
        // OPTIONAL OT TIME
        //
        // These fields are informational only.
        // They DO NOT calculate overtime.
        // --------------------------------------------------------

        'overtime_in': cleanTime(overtimeIn),
        'overtime_out': cleanTime(overtimeOut),

        // --------------------------------------------------------
        // OT AUTHORIZATION
        // --------------------------------------------------------

        'ot_authorized': otStatus,
        'ot_requested': otRequested,

        // --------------------------------------------------------
        // CALCULATIONS
        // --------------------------------------------------------

        'work_minutes': calculatedWorkMinutes,

        'break_minutes': calculatedBreakMinutes,

        'overtime_minutes': calculatedOvertimeMinutes,

        'net_working_minutes': calculatedNetWorkingMinutes,

        // --------------------------------------------------------
        // DISPLAY DURATIONS
        // --------------------------------------------------------

        'work_duration': duration(calculatedWorkMinutes),

        'break_duration': duration(calculatedBreakMinutes),

        'overtime_duration': duration(calculatedOvertimeMinutes),

        'net_working_duration': duration(calculatedNetWorkingMinutes),
      };

      // ==========================================================
      // DEBUG
      // ==========================================================

      debugPrint(
        '====================================================',
      );

      debugPrint(
        'SAVING MONTHLY ATTENDANCE',
      );

      debugPrint(
        'Employee: ${employeeId.trim()}',
      );

      debugPrint(
        'Branch: ${branchId.trim()}',
      );

      debugPrint(
        'Date: $dateString',
      );

      debugPrint(
        'Working: $workingIn -> $workingOut',
      );

      debugPrint(
        'Work minutes: $calculatedWorkMinutes',
      );

      debugPrint(
        'Morning break: '
        '$morningIn -> $morningOut '
        '= $morningBreakMinutes',
      );

      debugPrint(
        'Afternoon break: '
        '$afternoonIn -> $afternoonOut '
        '= $afternoonBreakMinutes',
      );

      debugPrint(
        'Evening break: '
        '$eveningIn -> $eveningOut '
        '= $eveningBreakMinutes',
      );

      debugPrint(
        'TOTAL BREAK: $calculatedBreakMinutes',
      );

      debugPrint(
        'NET WORKING: '
        '$calculatedNetWorkingMinutes '
        '(${duration(calculatedNetWorkingMinutes)})',
      );

      debugPrint(
        'NORMAL TARGET: '
        '$normalWorkingMinutes (7:30)',
      );

      debugPrint(
        'AUTOMATIC OT: '
        '$calculatedOvertimeMinutes '
        '(${duration(calculatedOvertimeMinutes)})',
      );

      debugPrint(
        'OT AUTHORIZATION: $otStatus',
      );

      debugPrint(
        '====================================================',
      );

      // ==========================================================
      // UPSERT
      // ==========================================================

      final response = await client
          .from('attendance')
          .upsert(
            data,
            onConflict: 'employee_id,attendance_date',
          )
          .select()
          .single();

      return _map(response);
    } catch (e, stackTrace) {
      debugPrint(
        'SAVE MONTHLY ATTENDANCE ERROR: $e',
      );

      debugPrint('$e');
      debugPrint('$stackTrace');

      rethrow;
    }
  }
  // ============================================================
  // DELETE ATTENDANCE
  // ============================================================

  static Future<void> deleteAttendance(
    dynamic id,
  ) async {
    try {
      await client.from('attendance').delete().eq(
            'id',
            id.toString(),
          );
    } catch (e, stackTrace) {
      debugPrint('DELETE ATTENDANCE ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // GET APPLICATION USER
  // ============================================================

  static Future<Map<String, dynamic>?> getApplicationUser(
    String username,
  ) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq(
            'username',
            username.trim(),
          )
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return _map(response);
    } catch (e, stackTrace) {
      debugPrint('GET APPLICATION USER ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // DASHBOARD EMPLOYEES
  // ============================================================

  static Future<List<Map<String, dynamic>>> getDashboardEmployees({
    String? branchId,
    bool activeOnly = false,
  }) async {
    try {
      var query = client.from('employees').select();

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.eq(
          'branch_id',
          branchId.trim(),
        );
      }

      if (activeOnly) {
        query = query.eq(
          'is_active',
          true,
        );
      }

      final response = await query.order(
        'name',
        ascending: true,
      );

      return _mapList(response);
    } catch (e, stackTrace) {
      debugPrint(
        'GET DASHBOARD EMPLOYEES ERROR: $e',
      );
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // DASHBOARD SUMMARY
  // ============================================================

  static Future<Map<String, dynamic>> getDashboardSummary({
    String? branchId,
  }) async {
    try {
      final employees = await getDashboardEmployees(
        branchId: branchId,
      );

      final activeEmployees = employees
          .where(
            (e) => e['is_active'] == true,
          )
          .toList();

      final now = DateTime.now();

      final sixMonthsAgo = DateTime(
        now.year,
        now.month - 6,
        now.day,
      );

      final newJoiners = employees.where(
        (employee) {
          final raw = employee['joining_date'];

          if (raw == null) {
            return false;
          }

          final date = DateTime.tryParse(
            raw.toString(),
          );

          if (date == null) {
            return false;
          }

          return !date.isBefore(
                sixMonthsAgo,
              ) &&
              !date.isAfter(now);
        },
      ).toList();

      final departments = <String>{};

      for (final employee in employees) {
        final department = employee['department']?.toString().trim();

        if (department != null && department.isNotEmpty) {
          departments.add(department);
        }
      }

      final branches = <String>{};

      for (final employee in employees) {
        final branch = employee['branch_id']?.toString().trim();

        if (branch != null && branch.isNotEmpty) {
          branches.add(branch);
        }
      }

      return <String, dynamic>{
        'totalEmployees': employees.length,
        'activeEmployees': activeEmployees.length,
        'newJoiners': newJoiners.length,
        'departments': departments.length,
        'branches': branches.length,
        'employees': employees,
      };
    } catch (e, stackTrace) {
      debugPrint(
        'GET DASHBOARD SUMMARY ERROR: $e',
      );
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  // ============================================================
  // SEARCH EMPLOYEES
  // ============================================================

  static Future<List<Map<String, dynamic>>> searchEmployees(
    String search, {
    String? branchId,
  }) async {
    try {
      final value = search.trim();

      if (value.isEmpty) {
        return getDashboardEmployees(
          branchId: branchId,
        );
      }

      var query = client.from('employees').select();

      if (branchId != null && branchId.trim().isNotEmpty) {
        query = query.eq(
          'branch_id',
          branchId.trim(),
        );
      }

      final responseById = await query
          .ilike(
            'employee_id',
            '%$value%',
          )
          .order(
            'name',
            ascending: true,
          );

      final results = _mapList(
        responseById,
      );

      if (results.isNotEmpty) {
        return results;
      }

      var nameQuery = client.from('employees').select();

      if (branchId != null && branchId.trim().isNotEmpty) {
        nameQuery = nameQuery.eq(
          'branch_id',
          branchId.trim(),
        );
      }

      final responseByName = await nameQuery
          .ilike(
            'name',
            '%$value%',
          )
          .order(
            'name',
            ascending: true,
          );

      return _mapList(
        responseByName,
      );
    } catch (e, stackTrace) {
      debugPrint('SEARCH EMPLOYEES ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }
}
