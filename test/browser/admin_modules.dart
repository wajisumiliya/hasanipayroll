// Browser-only CI entry point. Every row and credential is synthetic.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/widgets.dart';
import 'package:hasani_payroll_portal/services/neon_api.dart';
import 'package:hasani_payroll_portal/widgets/employee_photo.dart';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:hasani_payroll_portal/services/app_service.dart';
import 'package:hasani_payroll_portal/services/attendance_payroll_service.dart';
import 'package:hasani_payroll_portal/screens/supabase_service.dart';

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final completed = <String>[];
  html.document.body!.setAttribute('data-module-result', 'running');
  try {
    final loginError = await AppService.instance
        .login('FIX_ADMIN', 'browser-fixture-password');
    require(loginError == null, 'Login failed: $loginError');
    completed.add('login');
    final photo = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aFJkAAAAASUVORK5CYII=');
    final reference = await SupabaseService.uploadEmployeePhoto(
        employeeId: 'FIX_E1', bytes: photo, contentType: 'image/png');
    require(reference == 'neon-photo/FIX_E1', 'Photo reference missing');
    final loadedPhoto = await loadEmployeePhoto('FIX_E1', reference);
    require(base64Encode(loadedPhoto!) == base64Encode(photo),
        'Neon photo bytes did not roundtrip');
    final replacement = await SupabaseService.uploadEmployeePhoto(
        employeeId: 'FIX_E1', bytes: photo, contentType: 'image/png');
    require(await loadEmployeePhoto('FIX_E1', replacement) != null,
        'Replacement photo did not reload');
    await SupabaseService.removeEmployeePhoto('FIX_E1');
    require(await NeonApi.photoRequest('FIX_E1') == null,
        'Deleted photo is still available');
    completed.add('Neon photo upload, authenticated read, replacement and delete');
    final generated = await AttendancePayrollService.generateMonthlyPayroll(
      month: DateTime(2026, 10),
      employeeIds: ['FIX_E1'],
      overwriteExisting: true,
    );
    require(generated.generated.length == 1,
        'Payroll did not generate: ${generated.skipped.map((item) => item.message).join(', ')}');
    final db = SupabaseService.database;
    var row = await db
        .from('payroll')
        .select()
        .eq('employee_id', 'FIX_E1')
        .eq('period', '2026-10-01')
        .single();
    require(row['basic_salary'] == 2000, 'Generated payroll missing');
    completed.add('generate payroll');
    final contributions =
        await AttendancePayrollService.calculateStatutoryContributions(
      employeeId: 'FIX_E1',
      basicSalary: 2200,
      unpaidDeduction: 0,
    );
    row = await db
        .from('payroll')
        .upsert({
          ...row,
          'basic_salary': 2200,
          for (final key in [
            'epf_employee',
            'epf_employer',
            'socso_employee',
            'socso_employer',
            'eis_employee',
            'eis_employer'
          ])
            key: contributions[key],
        }, onConflict: 'employee_id,period')
        .select()
        .single();
    require(row['basic_salary'] == 2200, 'Edited payroll did not persist');
    completed.add('edit payroll');
    final logs = await SupabaseService.getBranchActivityLogs(branchId: 'FIX_A');
    require(logs.any((log) => log['action'] == 'FIXTURE_LOGIN'),
        'Branch logs missing');
    completed.add('branch logs');
    final requests =
        await SupabaseService.getEmployeeRequests(status: 'PENDING');
    require(requests.length == 1, 'Employee requests missing');
    await SupabaseService.updateEmployeeRequest(
        requestId: requests.single['id'].toString(),
        changes: {'name': 'Edited Fixture Request'});
    final approved = await SupabaseService.approveEmployeeRequest(
        requestId: requests.single['id'].toString(), employeeId: 'FIX_NEW1');
    require(approved['employee_id'] == 'FIX_NEW1', 'Employee approval failed');
    completed.add('employee request edit and approval');
    final ot = await SupabaseService.getPendingOtRequests();
    require(ot.length == 1, 'OT request missing');
    await SupabaseService.reviewOtRequest(
        requestId: ot.single['id'].toString(),
        approve: true,
        approvedOtMinutes: 60);
    final reviewed = await db
        .from('overtime_requests')
        .select()
        .eq('id', ot.single['id'])
        .single();
    require(
        reviewed['status'] == 'approved' && reviewed['approved_minutes'] == 60,
        'OT review failed');
    completed.add('OT request review');
    final payroll = await SupabaseService.getPayroll();
    require(payroll.length == 1106, 'Report pagination truncated payroll');
    final current =
        payroll.where((item) => item['period'] == '2026-10-01').toList();
    require(current.length == 1, 'Preview month filtering failed');
    final employees = await SupabaseService.getEmployees();
    final branches = await SupabaseService.getBranches();
    final defaults = await db
        .from('employee_salary_defaults')
        .select()
        .inFilter('employee_id', ['FIX_E1']);
    require(employees.isNotEmpty && branches.isNotEmpty && defaults.isNotEmpty,
        'Report dependencies missing');
    for (final report in [
      'RHB',
      'EPF',
      'EIS',
      'SOCSO',
      'HRDF',
      'Payroll Summary',
      'Payroll Preview'
    ]) {
      final workbook = xls.Excel.createExcel();
      final sheet = workbook[report];
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = xls.TextCellValue(report);
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
          .value = xls.TextCellValue(current.single['employee_id'].toString());
      final bytes = workbook.encode();
      require(bytes != null && bytes.isNotEmpty, '$report workbook failed');
      completed.add('$report data and workbook');
    }
    for (final key in ['epf_employee', 'socso_employee', 'eis_employee']) {
      require((row[key] as num) > 0, '$key contribution missing');
    }
    html.document.body!.setAttribute(
        'data-module-result', jsonEncode({'ok': true, 'completed': completed}));
  } catch (error, stack) {
    html.document.body!.setAttribute(
        'data-module-result',
        jsonEncode({
          'ok': false,
          'completed': completed,
          'error': error.toString(),
          'stack': stack.toString()
        }));
  }
}
