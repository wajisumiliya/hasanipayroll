import 'package:supabase_flutter/supabase_flutter.dart';
import 'NotUsed.dart';

class PayrollSupabaseService {
  PayrollSupabaseService._();

  static SupabaseClient get _client => SupabaseService.client;

  // ============================================================
  // EMPLOYEES
  // ============================================================

  static Future<List<Map<String, dynamic>>> getEmployees() async {
    final response = await _client
        .from('employees')
        .select()
        .order('employee_id');

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> getEmployee(
      String employeeId,
      ) async {
    final response = await _client
        .from('employees')
        .select()
        .eq('employee_id', employeeId)
        .maybeSingle();

    return response;
  }

  // ============================================================
  // PAYROLL
  // ============================================================

  static Future<List<Map<String, dynamic>>> getPayroll() async {
    final response = await _client
        .from('payroll')
        .select()
        .order('period', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getPayrollForEmployee(
      String employeeId,
      ) async {
    final response = await _client
        .from('payroll')
        .select()
        .eq('employee_id', employeeId)
        .order('period', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getPayrollForPeriod(
      DateTime period,
      ) async {
    final periodString =
        '${period.year.toString().padLeft(4, '0')}-'
        '${period.month.toString().padLeft(2, '0')}-01';

    final response = await _client
        .from('payroll')
        .select()
        .eq('period', periodString)
        .order('employee_id');

    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================
  // SAVE / UPDATE EMPLOYEE
  // ============================================================

  static Future<void> saveEmployee(
      Map<String, dynamic> employee,
      ) async {
    await _client
        .from('employees')
        .upsert(employee, onConflict: 'employee_id');
  }

  // ============================================================
  // SAVE / UPDATE PAYROLL
  // ============================================================

  static Future<void> savePayroll(
      Map<String, dynamic> payroll,
      ) async {
    await _client
        .from('payroll')
        .upsert(
      payroll,
      onConflict: 'employee_id,period',
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  static Future<void> deleteEmployee(String employeeId) async {
    await _client
        .from('employees')
        .delete()
        .eq('employee_id', employeeId);
  }

  static Future<void> deletePayroll(String id) async {
    await _client
        .from('payroll')
        .delete()
        .eq('id', id);
  }
}