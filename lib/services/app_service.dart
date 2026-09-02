import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/payroll.dart';

// ============================================================================
// APP USER
// ============================================================================

class app_user {
  final String username;
  final String password;
  final String role;
  final String? branchId;
  final String? employeeId;
  final String? displayName;

  const app_user({
    required this.username,
    required this.password,
    required this.role,
    this.branchId,
    this.employeeId,
    this.displayName,
  });

  bool get isAdmin =>
      role.trim().toLowerCase() == 'admin';

  bool get isBranch =>
      role.trim().toLowerCase() == 'branch';

  bool get isEmployee =>
      role.trim().toLowerCase() == 'employee';

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'role': role,
      'branch_id': branchId,
      'employee_id': employeeId,
      'display_name': displayName,
    };
  }

  factory app_user.fromJson(
    Map<String, dynamic> json,
  ) {
    return app_user(
      username:
          json['username']?.toString() ?? '',
      password:
          json['password']?.toString() ?? '',
      role:
          json['role']?.toString() ?? '',
      branchId:
          json['branch_id']?.toString() ??
              json['branchId']?.toString(),
      employeeId:
          json['employee_id']?.toString() ??
              json['employeeId']?.toString(),
      displayName:
          json['display_name']?.toString() ??
              json['displayName']?.toString(),
    );
  }
}

// ============================================================================
// APP USER COMPATIBILITY MODEL
// ============================================================================

class AppUser {
  final String id;
  final String name;
  String password;

  AppUser({
    required this.id,
    required this.name,
    required this.password,
  });
}


class FirstLoginOtpState {
  final String employeeId;
  final String email;
  final String? username;
  final String? otpId;
  final String? verificationId;

  const FirstLoginOtpState({
    required this.employeeId,
    required this.email,
    this.username,
    this.otpId,
    this.verificationId,
  });

  FirstLoginOtpState copyWith({
    String? employeeId,
    String? email,
    String? username,
    String? otpId,
    String? verificationId,
  }) {
    return FirstLoginOtpState(
      employeeId: employeeId ?? this.employeeId,
      email: email ?? this.email,
      username: username ?? this.username,
      otpId: otpId ?? this.otpId,
      verificationId: verificationId ?? this.verificationId,
    );
  }
}

// ============================================================================
// APP SERVICE
// ============================================================================

class AppService extends ChangeNotifier {
  AppService._();

  static final AppService instance =
      AppService._();

  static const String _currentUserStorageKey = 'hasani_current_user';

  SupabaseClient get _supabase =>
      Supabase.instance.client;


  static const String _authApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hasaniworkhub.onrender.com/',
  );

  FirstLoginOtpState? _firstLoginOtpState;

  FirstLoginOtpState? get firstLoginOtpState => _firstLoginOtpState;

  bool get requiresFirstLoginOtp => _firstLoginOtpState != null;

  Uri _authUri(String path) {
    final base = _authApiBaseUrl.endsWith('/')
        ? _authApiBaseUrl.substring(0, _authApiBaseUrl.length - 1)
        : _authApiBaseUrl;
    return Uri.parse('$base/${path.replaceFirst(RegExp(r'^/+'), '')}');
  }

  Future<Map<String, dynamic>> _postAuth(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          _authUri(path),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    Map<String, dynamic> data = {};
    if (response.body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        data = {'message': response.body};
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      data['ok'] = false;
    }
    return data;
  }

  // ==========================================================================
  // CURRENT USER
  // ==========================================================================

  app_user? _currentUser;

  app_user? get currentUser =>
      _currentUser;

  bool get isLoggedIn =>
      _currentUser != null;

  bool get isAdmin =>
      _currentUser?.isAdmin ?? false;

  bool get isBranch =>
      _currentUser?.isBranch ?? false;

  bool get isEmployee =>
      _currentUser?.isEmployee ?? false;

  String? get currentBranchId =>
      _currentUser?.branchId;

  String? get currentEmployeeId =>
      _currentUser?.employeeId;

  Employee? get employee =>
      currentEmployee;

  // ==========================================================================
  // PASSWORD
  // ==========================================================================

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current =
        currentPassword.trim();

    final newPass =
        newPassword.trim();

    if (current.isEmpty ||
        newPass.isEmpty) {
      return false;
    }

    if (newPass.length < 6) {
      return false;
    }

    if (current == newPass) {
      return false;
    }

    try {
      final user =
          _currentUser;

      if (user == null) {
        return false;
      }

      if (user.password != current) {
        return false;
      }

      final response =
          await _supabase
              .from('app_user')
              .update({
        'password': newPass,
      })
              .eq(
                'username',
                user.username,
              )
              .select()
              .maybeSingle();

      if (response == null) {
        return false;
      }

      _currentUser = app_user(
        username:
            user.username,
        password:
            newPass,
        role:
            user.role,
        branchId:
            user.branchId,
        employeeId:
            user.employeeId,
        displayName:
            user.displayName,
      );

      await loadUsersFromSupabase();

      notifyListeners();

      return true;
    } catch (e) {
      debugPrint(
        'Password update failed: $e',
      );

      return false;
    }
  }

  // ==========================================================================
  // BRANCHES
  // ==========================================================================

  final List<Branch> branches = const [
    Branch(
      id: 'ALOR SETAR',
      name: 'ALOR SETAR',
      location: 'ALOR SETAR',
      username: 'ALOR SETAR',
      password: '',
    ),
    Branch(
      id: 'AMANJAYA',
      name: 'AMANJAYA',
      location: 'AMANJAYA',
      username: 'AMANJAYA',
      password: '',
    ),
    Branch(
      id: 'ASTANA',
      name: 'ASTANA',
      location: 'ASTANA',
      username: 'ASTANA',
      password: '',
    ),
    Branch(
      id: 'GURUN',
      name: 'GURUN',
      location: 'GURUN',
      username: 'GURUN',
      password: '',
    ),
    Branch(
      id: 'JITRA',
      name: 'JITRA',
      location: 'JITRA',
      username: 'JITRA',
      password: '',
    ),
    Branch(
      id: 'KULIM',
      name: 'KULIM',
      location: 'KULIM',
      username: 'KULIM',
      password: '',
    ),
    Branch(
      id: 'LANGKAWI',
      name: 'LANGKAWI',
      location: 'LANGKAWI',
      username: 'LANGKAWI',
      password: '',
    ),
    Branch(
      id: 'PRAI',
      name: 'PRAI',
      location: 'PRAI',
      username: 'PRAI',
      password: '',
    ),
    Branch(
      id: 'SUNGAI PETANI',
      name: 'SUNGAI PETANI',
      location: 'SUNGAI PETANI',
      username: 'SUNGAI PETANI',
      password: '',
    ),
  ];

  // ==========================================================================
  // USERS
  // ==========================================================================

  final List<app_user> users = [];

  bool _usersLoaded = false;

  // ==========================================================================
  // EMPLOYEES
  // ==========================================================================

  final List<Employee> employees = [];

  bool _employeesLoaded = false;

  List<Employee> get employeesDemo {
    return List<Employee>.from(
      employees,
    );
  }

  // ==========================================================================
  // PAYROLL
  // ==========================================================================

  final List<PayrollRecord> payroll = [];

  bool _payrollLoaded = false;

  // ==========================================================================
  // ATTENDANCE
  // ==========================================================================

  final List<AttendanceRecord> attendance = [];

  bool _attendanceLoaded = false;

  // ==========================================================================
  // RESTORE
  // ==========================================================================

  Future<void> restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedUser = preferences.getString(_currentUserStorageKey);

      if (storedUser != null && storedUser.isNotEmpty) {
        _currentUser = app_user.fromJson(
          Map<String, dynamic>.from(jsonDecode(storedUser) as Map),
        );
      }
    } catch (e) {
      debugPrint('Restore current user error: $e');
      await _clearStoredUser();
    }

    try {
      await loadUsersFromSupabase();
    } catch (e) {
      debugPrint(
        'Restore users error: $e',
      );
    }

    try {
      await loadEmployeesFromSupabase();
    } catch (e) {
      debugPrint(
        'Restore employees error: $e',
      );
    }

    try {
      await loadPayrollFromSupabase();
    } catch (e) {
      debugPrint(
        'Restore payroll error: $e',
      );
    }

    try {
      await loadAttendanceFromSupabase();
    } catch (e) {
      debugPrint(
        'Restore attendance error: $e',
      );
    }

    notifyListeners();
  }

  Future<void> _persistCurrentUser() async {
    final user = _currentUser;
    if (user == null) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _currentUserStorageKey,
      jsonEncode(user.toJson()),
    );
  }

  Future<void> _clearStoredUser() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_currentUserStorageKey);
  }

  // ==========================================================================
  // LOAD USERS
  // ==========================================================================

  Future<void>
      loadUsersFromSupabase() async {
    try {
      final response =
          await _supabase
              .from('app_user')
              .select();

      users.clear();

      for (final row in response) {
        final data =
            Map<String, dynamic>.from(
          row,
        );

        final user =
            app_user.fromJson(data);

        if (user.username
            .trim()
            .isNotEmpty) {
          users.add(user);
        }
      }

      _usersLoaded = true;

      debugPrint(
        'Supabase app_user loaded: ${users.length}',
      );

      notifyListeners();
    } catch (e) {
      _usersLoaded = false;

      debugPrint(
        'ERROR loading app_user: $e',
      );

      rethrow;
    }
  }

  // ==========================================================================
  // LOAD EMPLOYEES
  // ==========================================================================

  Future<void>
      loadEmployeesFromSupabase() async {
    try {
      final response =
          await _supabase
              .from('employees')
              .select();

      employees.clear();

      for (final row in response) {
        try {
          final employee =
              _employeeFromSupabase(
            Map<String, dynamic>.from(
              row,
            ),
          );

          if (employee.employeeId
              .trim()
              .isNotEmpty) {
            employees.add(employee);
          }
        } catch (e) {
          debugPrint(
            'Employee conversion error: $e',
          );
        }
      }

      _employeesLoaded = true;

      debugPrint(
        'Supabase employees loaded: ${employees.length}',
      );

      notifyListeners();
    } catch (e) {
      _employeesLoaded = false;

      debugPrint(
        'ERROR loading employees: $e',
      );

      rethrow;
    }
  }

  // ==========================================================================
  // EMPLOYEE FROM SUPABASE
  // ==========================================================================

  Employee _employeeFromSupabase(
    Map<String, dynamic> data,
  ) {
    return Employee(
      employeeId:
          data['employee_id']
                  ?.toString() ??
              data['employeeId']
                  ?.toString() ??
              '',
      name:
          data['name']?.toString() ??
              '',
      designation:
          data['designation']
                  ?.toString() ??
              '',
      department:
          data['department']
                  ?.toString() ??
              '',
      email:
          data['email']?.toString() ??
              '',
      newIcNo:
          data['new_ic_no']
                  ?.toString() ??
              data['newIcNo']
                  ?.toString() ??
              '',
      bankCode:
          data['bank_code']
                  ?.toString() ??
              data['bankCode']
                  ?.toString() ??
              '',
      bankAccount:
          data['bank_account']
                  ?.toString() ??
              data['bankAccount']
                  ?.toString() ??
              '',
      phone:
          data['phone']?.toString() ??
              '',
      address:
          data['address']?.toString() ??
              '',
      joiningDate:
          _supabaseDate(
        data['joining_date'] ??
            data['joiningDate'],
      ),
      isActive:
          _supabaseBool(
        data['is_active'] ??
            data['isActive'],
      ),
      branchId:
          data['branch_id']
                  ?.toString() ??
              data['branchId']
                  ?.toString() ??
              '',
    );
  }

  // ==========================================================================
  // LOAD PAYROLL
  // ==========================================================================

  Future<void>
      loadPayrollFromSupabase() async {
    try {
      final response =
          await _supabase
              .from('payroll')
              .select();

      payroll.clear();

      for (final row in response) {
        try {
          payroll.add(
            _payrollFromSupabase(
              Map<String, dynamic>.from(
                row,
              ),
            ),
          );
        } catch (e) {
          debugPrint(
            'Payroll conversion error: $e',
          );
        }
      }

      _payrollLoaded = true;

      debugPrint(
        'Supabase payroll loaded: ${payroll.length}',
      );

      notifyListeners();
    } catch (e) {
      _payrollLoaded = false;

      debugPrint(
        'ERROR loading payroll: $e',
      );

      rethrow;
    }
  }

  // ==========================================================================
  // PAYROLL FROM SUPABASE
  // ==========================================================================

  PayrollRecord _payrollFromSupabase(
    Map<String, dynamic> data,
  ) {
    final employeeId =
        data['employee_id']
                ?.toString() ??
            data['employeeId']
                ?.toString() ??
            '';

    final period =
        _supabaseDate(
              data['period'],
            ) ??
            DateTime.now();

    return PayrollRecord(
      id:
          data['id']?.toString() ??
              'PAY-$employeeId-${period.year}-${period.month}',
      employeeId:
          employeeId,
      period:
          period,
      basicSalary:
          _doubleValue(
        data['basic_salary'] ??
            data['basicSalary'],
      ),
      elaunKedatangan:
          _doubleValue(
        data['elaun_kedatangan'] ??
            data['elaunKedatangan'] ??
            data['food_allowance'] ??
            data['foodAllowance'],
      ),
      elaunPerkhidmatan:
          _doubleValue(
        data['elaun_perkhidmatan'] ??
            data['elaunPerkhidmatan'] ??
            data['other_allowance'] ??
            data['otherAllowance'],
      ),
      elaunKerajinan:
          _doubleValue(
        data['elaun_kerajinan'] ??
            data['elaunKerajinan'],
      ),
      overtime:
          _doubleValue(
        data['overtime'],
      ),
      bonus:
          _doubleValue(
        data['bonus'],
      ),
      commission:
          _doubleValue(
        data['commission'],
      ),
      otherEarnings:
          _doubleValue(
        data['other_earnings'] ??
            data['otherEarnings'],
      ),
      housingAllowance: _doubleValue(
        data['housing_allowance'] ?? data['housingAllowance'],
      ),
      travelAllowance: _doubleValue(
        data['travel_allowance'] ?? data['travelAllowance'],
      ),
      cutiUmum:
          _doubleValue(
        data['cuti_umum'] ??
            data['cutiUmum'],
      ),
      epfEmployee:
          _doubleValue(
        data['epf_employee'] ??
            data['epfEmployee'],
      ),
      socsoEmployee:
          _doubleValue(
        data['socso_employee'] ??
            data['socsoEmployee'],
      ),
      eisEmployee:
          _doubleValue(
        data['eis_employee'] ??
            data['eisEmployee'],
      ),
      pcb:
          _doubleValue(
        data['pcb'],
      ),
      zakat:
          _doubleValue(
        data['zakat'],
      ),
      advanceDeduction: _doubleValue(
        data['advance_deduction'] ?? data['advanceDeduction'],
      ),
      loanDeduction: _doubleValue(
        data['loan_deduction'] ?? data['loanDeduction'],
      ),
      unpaidLeave: _doubleValue(
        data['unpaid_leave'] ??
            data['unpaidLeave'] ??
            data['unpaid_deduction'] ??
            data['unpaidDeduction'],
      ),
      otherDeductionAmount: _doubleValue(
        data['other_deduction'] ?? data['otherDeduction'],
      ),
      epfEmployer:
          _doubleValue(
        data['epf_employer'] ??
            data['epfEmployer'],
      ),
      socsoEmployer:
          _doubleValue(
        data['socso_employer'] ??
            data['socsoEmployer'],
      ),
      eisEmployer:
          _doubleValue(
        data['eis_employer'] ??
            data['eisEmployer'],
      ),
      newIcNo:
          data['new_ic_no']
                  ?.toString() ??
              data['newIcNo']
                  ?.toString() ??
              '',
      bankCode:
          data['bank_code']
                  ?.toString() ??
              data['bankCode']
                  ?.toString() ??
              '',
      bankAccount:
          data['bank_account']
                  ?.toString() ??
              data['bankAccount']
                  ?.toString() ??
              '',
      bankName: data['bank_name']?.toString() ?? data['bankName']?.toString() ?? '',
      storedGrossSalary: _nullableDoubleValue(
        data['gross_salary'] ?? data['grossSalary'],
      ),
      storedNetSalary: _nullableDoubleValue(
        data['net_salary'] ?? data['netSalary'],
      ),
      storedTotalDeductions: _nullableDoubleValue(
        data['total_deductions'] ?? data['totalDeductions'],
      ),
      isPaid: _supabaseBool(data['is_paid'] ?? data['isPaid']),
      paidAt: _supabaseDate(data['paid_at'] ?? data['paidAt']),
      paymentReference: data['payment_reference']?.toString() ??
          data['paymentReference']?.toString() ?? '',
      remarks:
          data['remarks']?.toString(),
      createdAt:
          _supabaseDate(
        data['created_at'] ??
            data['createdAt'],
      ),
      updatedAt:
          _supabaseDate(
        data['updated_at'] ??
            data['updatedAt'],
      ),
    );
  }

  // ==========================================================================
  // LOAD ATTENDANCE
  // ==========================================================================

  Future<void>
      loadAttendanceFromSupabase() async {
    try {
      final response =
          await _supabase
              .from('attendance')
              .select();

      attendance.clear();

      for (final row in response) {
        try {
          attendance.add(
            _attendanceFromSupabase(
              Map<String, dynamic>.from(
                row,
              ),
            ),
          );
        } catch (e) {
          debugPrint(
            'Attendance conversion error: $e',
          );
        }
      }

      _attendanceLoaded = true;

      debugPrint(
        'Supabase attendance loaded: ${attendance.length}',
      );

      notifyListeners();
    } catch (e) {
      _attendanceLoaded = false;

      debugPrint(
        'ERROR loading attendance: $e',
      );

      rethrow;
    }
  }

  // ==========================================================================
  // ATTENDANCE FROM SUPABASE
  // ==========================================================================

  AttendanceRecord _attendanceFromSupabase(
    Map<String, dynamic> data,
  ) {
    return AttendanceRecord(
      id:
          data['id']?.toString() ??
              '',
      employeeId:
          data['employee_id']
                  ?.toString() ??
              data['employeeId']
                  ?.toString() ??
              '',
      branchId:
          data['branch_id']
                  ?.toString() ??
              data['branchId']
                  ?.toString() ??
              '',
      date:
          _supabaseDate(
            data['date'],
          ) ??
              DateTime.now(),
      checkIn:
          data['check_in']
                  ?.toString() ??
              data['checkIn']
                  ?.toString() ??
              '-',
      checkOut:
          data['check_out']
                  ?.toString() ??
              data['checkOut']
                  ?.toString() ??
              '-',
      status:
          data['status']?.toString() ??
              'Present',
    );
  }

  // ==========================================================================
  // LOGIN WITH SUPABASE AUTH COMPATIBILITY
  // ==========================================================================

  Future<String?> loginWithSupabaseAuth(
    String username,
    String password,
  ) async {
    return login(
      username,
      password,
    );
  }

  // ==========================================================================
  // LOGIN
  // ==========================================================================

  Future<String?> login(
    String username,
    String password,
  ) async {
    final enteredUsername = username.trim();
    final enteredPassword = password.trim();

    if (enteredUsername.isEmpty) {
      return 'Please enter your username or employee ID.';
    }
    if (enteredPassword.isEmpty) {
      return 'Please enter your password.';
    }

    try {
      final data = await _postAuth(
        '/api/auth/login',
        {
          'username': enteredUsername,
          'password': enteredPassword,
        },
      );

      if (data['ok'] != true) {
        return data['message']?.toString() ??
            'Invalid username or password.';
      }

      final userData = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'])
          : <String, dynamic>{};

      final firstLogin =
          data['firstLogin'] == true ||
          data['requiresOtp'] == true ||
          userData['firstLogin'] == true ||
          userData['requiresOtp'] == true;

      final employeeId =
          userData['employeeId']?.toString() ??
          data['employeeId']?.toString() ??
          enteredUsername.toUpperCase();

      final email =
          userData['email']?.toString() ??
              data['email']?.toString() ??
              '';

            final role =
    userData['role']?.toString().trim().toLowerCase() ?? 'employee';

if (role == 'employee' && firstLogin) {
  _firstLoginOtpState = FirstLoginOtpState(
    employeeId: employeeId,
    email: email,
    username: userData['username']?.toString() ??
        userData['email']?.toString() ??
        enteredUsername,
  );

  notifyListeners();
  return 'FIRST_LOGIN_OTP_REQUIRED';
}

      final backendEmployee = userData['employee'] is Map
          ? Map<String, dynamic>.from(userData['employee'])
          : <String, dynamic>{};

      String? branchId =
          userData['branchId']?.toString() ??
          userData['branch_id']?.toString() ??
          backendEmployee['branchId']?.toString() ??
          backendEmployee['branch_id']?.toString();

      if (role == 'branch' &&
          (branchId == null || branchId.trim().isEmpty)) {
        branchId = userData['username']?.toString() ?? enteredUsername;
      }

      String? displayName =
          backendEmployee['name']?.toString();

      try {
        if (!_employeesLoaded) {
          await loadEmployeesFromSupabase();
        }
        final localEmployee = findEmployee(employeeId);
        if (localEmployee != null) {
          branchId ??= localEmployee.branchId;
          displayName ??= localEmployee.name;
        }
      } catch (e) {
        debugPrint('Employee compatibility load error: $e');
      }

      _currentUser = app_user(
  username:
      userData['username']?.toString() ??
      userData['email']?.toString() ??
      employeeId,
  password: enteredPassword,
  role: role,
  branchId: branchId,
  employeeId: employeeId,
  displayName: displayName ?? email,
);

      _firstLoginOtpState = null;
      await _persistCurrentUser();
      notifyListeners();
      await _loadDataForCurrentUser();
      return null;
    } on http.ClientException catch (e) {
      debugPrint('AUTH CONNECTION ERROR: $e');
      return 'Cannot connect to the payroll server. Make sure the Node.js backend is running.';
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      return 'Login failed: $e';
    }
  }

Future<String?> requestFirstLoginOtp() async {
final state = _firstLoginOtpState;

if (state == null) {
return 'No first-login session found. Please login again.';
}

final username = state.username?.trim();

if (username == null || username.isEmpty) {
return 'No username found. Please login again.';
}

try {
final data = await _postAuth(
'/api/auth/send-otp',
{
'username': username,
},
);

if (data['ok'] != true) {
return data['message']?.toString() ??
'Unable to generate OTP.';
}

_firstLoginOtpState = state.copyWith(
otpId: data['otpId']?.toString(),
);

notifyListeners();

return null;
} catch (e) {
debugPrint('REQUEST OTP ERROR: $e');
return 'Unable to request OTP: $e';
}
}
  Future<String?> requestOtp() => requestFirstLoginOtp();

Future<String?> verifyFirstLoginOtp(String otp) async {
final state = _firstLoginOtpState;

if (state == null) {
return 'No first-login session found. Please login again.';
}

final username = state.username?.trim();

if (username == null || username.isEmpty) {
return 'No username found. Please login again.';
}

final code = otp.trim();

if (!RegExp(r'^\d{6}$').hasMatch(code)) {
return 'Please enter the 6-digit OTP.';
}

try {
final data = await _postAuth(
'/api/auth/verify-otp',
{
'username': username,
'otp': code,
},
);

if (data['ok'] != true) {
return data['message']?.toString() ??
'OTP verification failed.';
}

_firstLoginOtpState = state.copyWith(
verificationId: data['verificationId']?.toString(),
);

notifyListeners();

return null;
} catch (e) {
debugPrint('VERIFY OTP ERROR: $e');
return 'OTP verification failed: $e';
}
}

  Future<String?> verifyOtp(String otp) => verifyFirstLoginOtp(otp);

  Future<String?> completeFirstLogin(String newPassword) async {
    final state = _firstLoginOtpState;
    if (state == null ||
        state.verificationId == null ||
        state.verificationId!.isEmpty) {
      return 'Please verify the OTP first.';
    }

    final password = newPassword.trim();
    if (password.length < 6) {
      return 'Password must contain at least 6 characters.';
    }

    try {
      final data = await _postAuth(
        '/api/auth/set-password',
        {
          'verificationId': state.verificationId,
          'newPassword': password,
        },
      );

      if (data['ok'] != true) {
        return data['message']?.toString() ??
            'Unable to create the new password.';
      }

      final userData = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'])
          : <String, dynamic>{};

      final employeeId =
          userData['employeeId']?.toString() ?? state.employeeId;

      final employee = userData['employee'] is Map
          ? Map<String, dynamic>.from(userData['employee'])
          : <String, dynamic>{};

      String? branchId =
          employee['branchId']?.toString() ??
          employee['branch_id']?.toString();

      String? displayName = employee['name']?.toString();

      try {
        if (!_employeesLoaded) {
          await loadEmployeesFromSupabase();
        }
        final localEmployee = findEmployee(employeeId);
        if (localEmployee != null) {
          branchId ??= localEmployee.branchId;
          displayName ??= localEmployee.name;
        }
      } catch (e) {
        debugPrint('First login compatibility error: $e');
      }

      _currentUser = app_user(
  username:
      userData['username']?.toString() ??
      userData['email']?.toString() ??
      employeeId,
  password: password,
  role: userData['role']?.toString() ?? 'employee',
  branchId: branchId,
  employeeId: employeeId,
  displayName: displayName ?? userData['email']?.toString(),
);

      _firstLoginOtpState = null;
      await _persistCurrentUser();
      notifyListeners();
      await _loadDataForCurrentUser();
      return null;
    } catch (e) {
      debugPrint('COMPLETE FIRST LOGIN ERROR: $e');
      return 'Unable to complete first login: $e';
    }
  }

  Future<String?> setNewPassword(String newPassword) =>
      completeFirstLogin(newPassword);

  void cancelFirstLoginOtp() {
    _firstLoginOtpState = null;
    notifyListeners();
  }

  // ==========================================================================
  // LOAD CURRENT USER DATA
  // ==========================================================================

  Future<void>
      _loadDataForCurrentUser() async {
    try {
      await loadEmployeesFromSupabase();
      await loadPayrollFromSupabase();
      await loadAttendanceFromSupabase();
    } catch (e) {
      debugPrint(
        'User data loading error: $e',
      );
    }

    notifyListeners();
  }

  // ==========================================================================
  // LOGOUT
  // ==========================================================================

  Future<void> logout() async {
    _currentUser = null;
    await _clearStoredUser();

    notifyListeners();
  }

  // ==========================================================================
  // NORMALISATION
  // ==========================================================================

  String _normalise(
    String value,
  ) {
    return value
        .trim()
        .toUpperCase();
  }

  // ==========================================================================
  // BRANCH LOOKUP
  // ==========================================================================

  Branch? getBranch(
    String branchId,
  ) {
    final id =
        _normalise(branchId);

    if (id.isEmpty) {
      return null;
    }

    for (final branch in branches) {
      if (_normalise(branch.id) == id ||
          _normalise(branch.name) == id ||
          _normalise(branch.username) ==
              id) {
        return branch;
      }
    }

    return null;
  }

  Branch? branchById(
    String branchId,
  ) {
    return getBranch(branchId);
  }

  // ==========================================================================
  // EMPLOYEE LOOKUP
  // ==========================================================================

  Employee? findEmployee(
    String employeeId,
  ) {
    final id =
        _normalise(employeeId);

    if (id.isEmpty) {
      return null;
    }

    for (final employee in employees) {
      if (_normalise(
            employee.employeeId,
          ) ==
          id) {
        return employee;
      }
    }

    return null;
  }

  Employee? employeeById(
    String employeeId,
  ) {
    return findEmployee(employeeId);
  }

  // ==========================================================================
  // EMPLOYEE USER LOOKUP
  // ==========================================================================

  app_user? _findEmployeeUser(
    String employeeId,
  ) {
    final id =
        _normalise(employeeId);

    for (final user in users) {
      if (user.isEmployee &&
          _normalise(
                user.employeeId ??
                    user.username,
              ) ==
              id) {
        return user;
      }
    }

    return null;
  }

  // ==========================================================================
  // EMPLOYEE -> BRANCH
  // ==========================================================================

  String? branchIdForEmployee(
    String employeeId,
  ) {
    final employee =
        findEmployee(employeeId);

    if (employee != null &&
        employee.branchId
            .trim()
            .isNotEmpty) {
      final branch =
          getBranch(
        employee.branchId,
      );

      return branch?.id ??
          employee.branchId.trim();
    }

    final user =
        _findEmployeeUser(
      employeeId,
    );

    if (user != null &&
        user.branchId != null &&
        user.branchId!
            .trim()
            .isNotEmpty) {
      return user.branchId;
    }

    return null;
  }

  // ==========================================================================
  // ALL EMPLOYEES
  // ==========================================================================

  List<Employee> get allEmployees {
    return List<Employee>.from(
      employees,
    );
  }

  // ==========================================================================
  // EMPLOYEES FOR BRANCH
  // ==========================================================================

  List<Employee> branchEmployees(
    String branchId,
  ) {
    final branch =
        getBranch(branchId);

    if (branch == null) {
      return [];
    }

    final id =
        _normalise(branch.id);

    final result =
        employees
            .where(
              (employee) =>
                  _normalise(
                    employee.branchId,
                  ) ==
                  id,
            )
            .toList();

    result.sort(
      (a, b) => a.name
          .toLowerCase()
          .compareTo(
            b.name.toLowerCase(),
          ),
    );

    return result;
  }

  List<Employee>
      get currentBranchEmployees {
    final branchId =
        currentBranchId;

    if (branchId == null ||
        branchId.trim().isEmpty) {
      return [];
    }

    return branchEmployees(
      branchId,
    );
  }

  Branch? get currentBranch {
    final id =
        currentBranchId;

    if (id == null) {
      return null;
    }

    return getBranch(id);
  }

  // ==========================================================================
  // ADD EMPLOYEE
  // ==========================================================================

  Future<String> addEmployee(
    Employee employee, {
    required String branchId,
    String password =
        'employee123',
  }) async {
    final cleanId =
        employee.employeeId.trim();

    if (cleanId.isEmpty) {
      return 'Employee ID is required.';
    }

    if (findEmployee(cleanId) !=
        null) {
      return 'Employee ID $cleanId already exists.';
    }

    final branch =
        getBranch(branchId);

    if (branch == null) {
      return 'Invalid branch ID: $branchId';
    }

    final employeeWithBranch =
        employee.copyWith(
      branchId: branch.id,
    );

    try {
      await _supabase
          .from('employees')
          .insert(
            _employeeToSupabase(
              employeeWithBranch,
            ),
          );

      await _supabase
          .from('app_user')
          .insert({
        'username':
            employeeWithBranch
                .employeeId,
        'password':
            password,
        'role':
            'employee',
        'employee_id':
            employeeWithBranch
                .employeeId,
        'branch_id':
            branch.id,
        'display_name':
            employeeWithBranch.name,
      });

      await loadEmployeesFromSupabase();
      await loadUsersFromSupabase();

      return 'Employee $cleanId added successfully.';
    } catch (e) {
      debugPrint(
        'Add employee error: $e',
      );

      return 'Failed to add employee: $e';
    }
  }

  // ==========================================================================
  // UPDATE EMPLOYEE
  // ==========================================================================

  Future<String> updateEmployee(
    Employee updatedEmployee,
  ) async {
    final branch =
        getBranch(
      updatedEmployee.branchId,
    );

    if (branch == null) {
      return 'Invalid branch: ${updatedEmployee.branchId}';
    }

    try {
      await _supabase
          .from('employees')
          .update(
            _employeeToSupabase(
              updatedEmployee.copyWith(
                branchId: branch.id,
              ),
            ),
          )
          .eq(
            'employee_id',
            updatedEmployee.employeeId,
          );

      await _supabase
          .from('app_user')
          .update({
        'branch_id':
            branch.id,
        'display_name':
            updatedEmployee.name,
      }).eq(
        'employee_id',
        updatedEmployee.employeeId,
      );

      await loadEmployeesFromSupabase();
      await loadUsersFromSupabase();

      return 'Employee updated successfully.';
    } catch (e) {
      debugPrint(
        'Update employee error: $e',
      );

      return 'Failed to update employee: $e';
    }
  }

  // ==========================================================================
  // DELETE EMPLOYEE
  // ==========================================================================

  Future<String> deleteEmployee(
    String employeeId,
  ) async {
    final employee =
        findEmployee(employeeId);

    if (employee == null) {
      return 'Employee not found.';
    }

    try {
      await _supabase
          .from('attendance')
          .delete()
          .eq(
            'employee_id',
            employee.employeeId,
          );

      await _supabase
          .from('payroll')
          .delete()
          .eq(
            'employee_id',
            employee.employeeId,
          );

      await _supabase
          .from('app_user')
          .delete()
          .eq(
            'employee_id',
            employee.employeeId,
          );

      await _supabase
          .from('employees')
          .delete()
          .eq(
            'employee_id',
            employee.employeeId,
          );

      await loadUsersFromSupabase();
      await loadEmployeesFromSupabase();
      await loadPayrollFromSupabase();
      await loadAttendanceFromSupabase();

      return 'Employee deleted successfully.';
    } catch (e) {
      debugPrint(
        'Delete employee error: $e',
      );

      return 'Failed to delete employee: $e';
    }
  }

  // ==========================================================================
  // CREATE / UPDATE EMPLOYEE LOGIN
  // ==========================================================================

  Future<void>
      _createOrUpdateEmployeeUser(
    Employee employee,
    String branchId, {
    String password =
        'employee123',
  }) async {
    try {
      final existing =
          await _supabase
              .from('app_user')
              .select()
              .eq(
                'employee_id',
                employee.employeeId,
              )
              .maybeSingle();

      final data =
          <String, dynamic>{
        'username':
            employee.employeeId,
        'role':
            'employee',
        'employee_id':
            employee.employeeId,
        'branch_id':
            branchId,
        'display_name':
            employee.name,
      };

      if (existing == null) {
        data['password'] =
            password;

        await _supabase
            .from('app_user')
            .insert(data);
      } else {
        await _supabase
            .from('app_user')
            .update(data)
            .eq(
              'employee_id',
              employee.employeeId,
            );
      }

      await loadUsersFromSupabase();
    } catch (e) {
      debugPrint(
        'Employee user error: $e',
      );
    }
  }

  // ==========================================================================
  // IMPORT EMPLOYEE CSV
  // ==========================================================================

  Future<String>
      importEmployeesCsv() async {
    try {
      final result =
          await FilePicker.platform
              .pickFiles(
        type:
            FileType.custom,
        allowedExtensions:
            ['csv'],
        withData: true,
      );

      if (result == null ||
          result.files.isEmpty) {
        return 'No employee CSV file selected.';
      }

      final file =
          result.files.first;

      if (file.bytes == null) {
        return 'Unable to read the employee CSV file.';
      }

      final csvText =
          utf8.decode(
        file.bytes!,
        allowMalformed: true,
      );

      return importEmployeesCsvText(
        csvText,
      );
    } catch (e) {
      return 'Employee CSV import failed: $e';
    }
  }

  // ==========================================================================
  // IMPORT EMPLOYEE CSV TEXT
  // ==========================================================================

  Future<String>
      importEmployeesCsvText(
    String csvText,
  ) async {
    final lines =
        csvText
            .replaceAll(
              '\r\n',
              '\n',
            )
            .replaceAll(
              '\r',
              '\n',
            )
            .split('\n')
            .where(
              (line) =>
                  line.trim().isNotEmpty,
            )
            .toList();

    if (lines.isEmpty) {
      return 'Employee CSV file is empty.';
    }

    final headers =
        _parseCsvLine(
          lines.first,
        )
            .map(
              _normaliseHeader,
            )
            .toList();

    if (!_hasRequiredEmployeeColumns(
      headers,
    )) {
      return '''
Invalid employee CSV.

Required columns:

employeeId,name,designation,department,email,newIcNo,bankCode,bankAccount,phone,address,joiningDate,isActive,branchId
''';
    }

    int imported = 0;
    int updated = 0;
    int skipped = 0;

    final errors =
        <String>[];

    for (
      int lineIndex = 1;
      lineIndex < lines.length;
      lineIndex++
    ) {
      try {
        final values =
            _parseCsvLine(
          lines[lineIndex],
        );

        final row =
            <String, String>{};

        for (
          int i = 0;
          i < headers.length;
          i++
        ) {
          row[headers[i]] =
              i < values.length
                  ? values[i].trim()
                  : '';
        }

        final employeeId =
            _csvValue(
          row,
          [
            'employeeid',
            'employee_id',
            'id',
          ],
        );

        final name =
            _csvValue(
          row,
          [
            'name',
            'employee_name',
            'employeename',
          ],
        );

        final branchId =
            _csvValue(
          row,
          [
            'branchid',
            'branch_id',
            'branch',
          ],
        );

        if (employeeId.isEmpty) {
          skipped++;

          errors.add(
            'Line ${lineIndex + 1}: Employee ID is missing.',
          );

          continue;
        }

        if (name.isEmpty) {
          skipped++;

          errors.add(
            'Line ${lineIndex + 1}: Employee name is missing.',
          );

          continue;
        }

        if (branchId.isEmpty) {
          skipped++;

          errors.add(
            'Line ${lineIndex + 1}: Branch ID is missing.',
          );

          continue;
        }

        final branch =
            getBranch(branchId);

        if (branch == null) {
          skipped++;

          errors.add(
            'Line ${lineIndex + 1}: Invalid branch "$branchId".',
          );

          continue;
        }

        final joiningDate =
            _parseDate(
          _csvValue(
            row,
            [
              'joiningdate',
              'joining_date',
              'datejoined',
              'date_joined',
            ],
          ),
        );

        if (joiningDate == null) {
          skipped++;

          errors.add(
            'Line ${lineIndex + 1}: Invalid joining date.',
          );

          continue;
        }

        final employee =
            Employee(
          employeeId:
              employeeId,
          name:
              name,
          designation:
              _csvValue(
            row,
            [
              'designation',
              'position',
              'jobtitle',
              'job_title',
            ],
          ),
          department:
              _csvValue(
            row,
            [
              'department',
              'dept',
            ],
          ),
          email:
              _csvValue(
            row,
            [
              'email',
              'emailaddress',
              'email_address',
            ],
          ),
          newIcNo:
              _csvValue(
            row,
            [
              'newicno',
              'new_ic_no',
              'icno',
              'ic_no',
              'ic',
            ],
          ),
          bankCode:
              _csvValue(
            row,
            [
              'bankcode',
              'bank_code',
              'bank',
            ],
          ),
          bankAccount:
              _csvValue(
            row,
            [
              'bankaccount',
              'bank_account',
              'accountnumber',
              'account_number',
            ],
          ),
          phone:
              _csvValue(
            row,
            [
              'phone',
              'mobile',
              'telephone',
              'contact',
            ],
          ),
          address:
              _csvValue(
            row,
            [
              'address',
              'homeaddress',
              'home_address',
            ],
          ),
          joiningDate:
              joiningDate,
          isActive:
              _parseBool(
            _csvValue(
              row,
              [
                'isactive',
                'is_active',
                'active',
                'status',
              ],
            ),
          ),
          branchId:
              branch.id,
        );

        final existing =
            findEmployee(
          employeeId,
        );

        if (existing != null) {
          await _supabase
              .from('employees')
              .update(
                _employeeToSupabase(
                  employee,
                ),
              )
              .eq(
                'employee_id',
                employeeId,
              );

          await _createOrUpdateEmployeeUser(
            employee,
            branch.id,
          );

          updated++;
        } else {
          await _supabase
              .from('employees')
              .insert(
                _employeeToSupabase(
                  employee,
                ),
              );

          await _createOrUpdateEmployeeUser(
            employee,
            branch.id,
          );

          imported++;
        }
      } catch (e) {
        skipped++;

        errors.add(
          'Line ${lineIndex + 1}: $e',
        );
      }
    }

    await loadEmployeesFromSupabase();
    await loadUsersFromSupabase();

    final message =
        StringBuffer();

    message.writeln(
      'Employee CSV import completed.',
    );

    message.writeln(
      'Imported: $imported',
    );

    message.writeln(
      'Updated: $updated',
    );

    message.writeln(
      'Skipped: $skipped',
    );

    if (errors.isNotEmpty) {
      message.writeln();
      message.writeln(
        'Errors:',
      );

      for (
        final error
        in errors.take(10)
      ) {
        message.writeln(
          '• $error',
        );
      }

      if (errors.length > 10) {
        message.writeln(
          '...and ${errors.length - 10} more.',
        );
      }
    }

    return message.toString();
  }

  // ==========================================================================
  // PAYROLL CSV IMPORT
  // ==========================================================================

  Future<String>
      importPayrollCsv() async {
    try {
      final result =
          await FilePicker.platform
              .pickFiles(
        type:
            FileType.custom,
        allowedExtensions:
            ['csv'],
        withData: true,
      );

      if (result == null ||
          result.files.isEmpty) {
        return 'No payroll CSV file selected.';
      }

      final file =
          result.files.first;

      if (file.bytes == null) {
        return 'Unable to read the payroll CSV file.';
      }

      final csvText =
          utf8.decode(
        file.bytes!,
        allowMalformed: true,
      );

      return importPayrollCsvText(
        csvText,
      );
    } catch (e) {
      return 'Payroll CSV import failed: $e';
    }
  }

  // ==========================================================================
  // PAYROLL CSV TEXT
  // ==========================================================================

  Future<String>
      importPayrollCsvText(
    String csvText,
  ) async {
    final lines =
        csvText
            .replaceAll(
              '\r\n',
              '\n',
            )
            .replaceAll(
              '\r',
              '\n',
            )
            .split('\n')
            .where(
              (line) =>
                  line.trim().isNotEmpty,
            )
            .toList();

    if (lines.isEmpty) {
      return 'Payroll CSV file is empty.';
    }

    final headers =
        _parseCsvLine(
          lines.first,
        )
            .map(
              _normalisePayrollHeader,
            )
            .toList();

    if (!_hasRequiredPayrollColumns(
      headers,
    )) {
      return '''
Invalid payroll CSV.

Required columns:

employeeId,period,basicSalary,ELAUN KEDATANGAN,ELAUN PERKHIDMATAN,ELAUN KERAJINAN,OVERTIME,bonus,commission,otherEarnings,CUTI UMUM,epfEmployee,socsoEmployee,eisEmployee,pcb,zakat,epfEmployer,socsoEmployer,eisEmployer
''';
    }

    int imported = 0;
    int updated = 0;
    int skipped = 0;

    final errors =
        <String>[];

    for (
      int lineIndex = 1;
      lineIndex < lines.length;
      lineIndex++
    ) {
      try {
        final values =
            _parseCsvLine(
          lines[lineIndex],
        );

        final row =
            <String, String>{};

        for (
          int i = 0;
          i < headers.length;
          i++
        ) {
          row[headers[i]] =
              i < values.length
                  ? values[i].trim()
                  : '';
        }

        final employeeId =
            _csvValue(
          row,
          [
            'employeeid',
            'employee_id',
            'id',
          ],
        );

        if (employeeId.isEmpty) {
          skipped++;

          errors.add(
            'Line ${lineIndex + 1}: Employee ID is missing.',
          );

          continue;
        }

        final employee =
            findEmployee(
          employeeId,
        );

        if (employee == null) {
          skipped++;

          errors.add(
            'Line ${lineIndex + 1}: Employee $employeeId does not exist. Import employee CSV first.',
          );

          continue;
        }

        final period =
            _parsePayrollPeriod(
          _csvValue(
            row,
            [
              'period',
              'payrollperiod',
              'pay_period',
              'payperiod',
            ],
          ),
        );

        if (period == null) {
          skipped++;

          errors.add(
            'Line ${lineIndex + 1}: Invalid payroll period.',
          );

          continue;
        }

        final payrollId =
            'PAY-${employee.employeeId}-${period.year}-${period.month.toString().padLeft(2, '0')}';

        final record =
            PayrollRecord(
          id:
              payrollId,
          employeeId:
              employee.employeeId,
          period:
              period,
          basicSalary:
              _csvMoney(
            row,
            [
              'basicsalary',
              'basic_salary',
            ],
          ),
          elaunKedatangan:
              _csvMoney(
            row,
            [
              'elaunkedatangan',
            ],
          ),
          elaunPerkhidmatan:
              _csvMoney(
            row,
            [
              'elaunperkhidmatan',
              'elauanperkhidmatan',
            ],
          ),
          elaunKerajinan:
              _csvMoney(
            row,
            [
              'elaunkerajinan',
            ],
          ),
          overtime:
              _csvMoney(
            row,
            [
              'overtime',
              'ot',
            ],
          ),
          bonus:
              _csvMoney(
            row,
            [
              'bonus',
            ],
          ),
          commission:
              _csvMoney(
            row,
            [
              'commission',
            ],
          ),
          otherEarnings:
              _csvMoney(
            row,
            [
              'otherearnings',
              'other_earnings',
            ],
          ),
          cutiUmum:
              _csvMoney(
            row,
            [
              'cutiumum',
            ],
          ),
          epfEmployee:
              _csvMoney(
            row,
            [
              'epfemployee',
              'epf_employee',
            ],
          ),
          socsoEmployee:
              _csvMoney(
            row,
            [
              'socsoemployee',
              'socso_employee',
            ],
          ),
          eisEmployee:
              _csvMoney(
            row,
            [
              'eisemployee',
              'eis_employee',
            ],
          ),
          pcb:
              _csvMoney(
            row,
            [
              'pcb',
            ],
          ),
          zakat:
              _csvMoney(
            row,
            [
              'zakat',
            ],
          ),
          epfEmployer:
              _csvMoney(
            row,
            [
              'epfemployer',
              'epf_employer',
            ],
          ),
          socsoEmployer:
              _csvMoney(
            row,
            [
              'socsoemployer',
              'socso_employer',
            ],
          ),
          eisEmployer:
              _csvMoney(
            row,
            [
              'eisemployer',
              'eis_employer',
            ],
          ),
          newIcNo:
              employee.newIcNo,
          bankCode:
              employee.bankCode,
          bankAccount:
              employee.bankAccount,
          remarks:
              null,
          createdAt:
              DateTime.now(),
          updatedAt:
              DateTime.now(),
        );

        final existing =
            findPayroll(
          employee.employeeId,
          period,
        );

        final data =
            _payrollToSupabase(
          record,
        );

        if (existing != null) {
          await _supabase
              .from('payroll')
              .update(data)
              .eq(
                'id',
                existing.id,
              );

          updated++;
        } else {
          await _supabase
              .from('payroll')
              .upsert(data);

          imported++;
        }
      } catch (e) {
        skipped++;

        errors.add(
          'Line ${lineIndex + 1}: $e',
        );
      }
    }

    await loadPayrollFromSupabase();

    final message =
        StringBuffer();

    message.writeln(
      'Payroll CSV import completed.',
    );

    message.writeln(
      'Imported: $imported',
    );

    message.writeln(
      'Updated: $updated',
    );

    message.writeln(
      'Skipped: $skipped',
    );

    if (errors.isNotEmpty) {
      message.writeln();
      message.writeln(
        'Errors:',
      );

      for (
        final error
        in errors.take(10)
      ) {
        message.writeln(
          '• $error',
        );
      }

      if (errors.length > 10) {
        message.writeln(
          '...and ${errors.length - 10} more.',
        );
      }
    }

    return message.toString();
  }

  // ==========================================================================
  // PAYROLL COLUMN VALIDATION
  // ==========================================================================

  bool _hasRequiredPayrollColumns(
    List<String> headers,
  ) {
    const required =
        <String>[
      'employeeid',
      'period',
      'basicsalary',
      'elaunkedatangan',
      'elaunperkhidmatan',
      'elaunkerajinan',
      'overtime',
      'bonus',
      'commission',
      'otherearnings',
      'cutiumum',
      'epfemployee',
      'socsoemployee',
      'eisemployee',
      'pcb',
      'zakat',
      'epfemployer',
      'socsoemployer',
      'eisemployer',
    ];

    return required.every(
      headers.contains,
    );
  }

  // ==========================================================================
  // PAYROLL HEADER
  // ==========================================================================

  String _normalisePayrollHeader(
    String value,
  ) {
    return value
        .replaceFirst(
          RegExp(r'^\uFEFF'),
          '',
        )
        .trim()
        .toLowerCase()
        .replaceAll(
          RegExp(r'[\s_\-]+'),
          '',
        );
  }

  // ==========================================================================
  // PAYROLL MONEY
  // ==========================================================================

  double _csvMoney(
    Map<String, String> row,
    List<String> keys,
  ) {
    final value =
        _csvValue(
      row,
      keys,
    );

    if (value.trim().isEmpty) {
      return 0;
    }

    var text =
        value.trim();

    bool negative = false;

    if (text.startsWith('(') &&
        text.endsWith(')')) {
      negative = true;

      text = text.substring(
        1,
        text.length - 1,
      );
    }

    text = text
        .replaceAll(
          RegExp(r'(?i)rm'),
          '',
        )
        .replaceAll(
          ',',
          '',
        )
        .trim();

    final parsed =
        double.tryParse(text);

    if (parsed == null) {
      return 0;
    }

    return negative
        ? -parsed
        : parsed;
  }

  // ==========================================================================
  // PAYROLL PERIOD
  // ==========================================================================

  DateTime? _parsePayrollPeriod(
    String value,
  ) {
    final text =
        value.trim();

    if (text.isEmpty) {
      return null;
    }

    final yearMonth =
        RegExp(
      r'^(\d{4})[-/](\d{1,2})$',
    ).firstMatch(text);

    if (yearMonth != null) {
      final year =
          int.tryParse(
        yearMonth.group(1)!,
      );

      final month =
          int.tryParse(
        yearMonth.group(2)!,
      );

      if (year != null &&
          month != null &&
          month >= 1 &&
          month <= 12) {
        return DateTime(
          year,
          month,
          1,
        );
      }
    }

    final monthYear =
        RegExp(
      r'^(\d{1,2})[-/](\d{4})$',
    ).firstMatch(text);

    if (monthYear != null) {
      final month =
          int.tryParse(
        monthYear.group(1)!,
      );

      final year =
          int.tryParse(
        monthYear.group(2)!,
      );

      if (year != null &&
          month != null &&
          month >= 1 &&
          month <= 12) {
        return DateTime(
          year,
          month,
          1,
        );
      }
    }

    final fullDate =
        RegExp(
      r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$',
    ).firstMatch(text);

    if (fullDate != null) {
      final year =
          int.tryParse(
        fullDate.group(1)!,
      );

      final month =
          int.tryParse(
        fullDate.group(2)!,
      );

      final day =
          int.tryParse(
        fullDate.group(3)!,
      );

      if (year != null &&
          month != null &&
          day != null) {
        final result =
            DateTime(
          year,
          month,
          day,
        );

        if (result.year == year &&
            result.month == month &&
            result.day == day) {
          return result;
        }
      }
    }

    final parsed =
        DateTime.tryParse(text);

    if (parsed != null) {
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
      );
    }

    return null;
  }

  // ==========================================================================
  // PAYROLL LOOKUP
  // ==========================================================================

  PayrollRecord? findPayroll(
    String employeeId,
    DateTime period,
  ) {
    for (final record in payroll) {
      if (_normalise(
                record.employeeId,
              ) ==
              _normalise(
                employeeId,
              ) &&
          _sameMonth(
            record.period,
            period,
          )) {
        return record;
      }
    }

    return null;
  }

  PayrollRecord?
      payrollByEmployeeAndPeriod(
    String employeeId,
    DateTime period,
  ) {
    return findPayroll(
      employeeId,
      period,
    );
  }

  // ==========================================================================
  // BRANCH PAYROLL
  // ==========================================================================

  List<PayrollRecord> branchPayroll(
    String branchId,
  ) {
    final branch =
        getBranch(branchId);

    if (branch == null) {
      return [];
    }

    final ids =
        employees
            .where(
              (employee) =>
                  _normalise(
                    employee.branchId,
                  ) ==
                  _normalise(
                    branch.id,
                  ),
            )
            .map(
              (employee) =>
                  _normalise(
                employee.employeeId,
              ),
            )
            .toSet();

    final result =
        payroll
            .where(
              (record) =>
                  ids.contains(
                _normalise(
                  record.employeeId,
                ),
              ),
            )
            .toList();

    result.sort(
      (a, b) =>
          b.period.compareTo(
        a.period,
      ),
    );

    return result;
  }

  List<PayrollRecord>
      get currentBranchPayroll {
    final branchId =
        currentBranchId;

    if (branchId == null) {
      return [];
    }

    return branchPayroll(
      branchId,
    );
  }

  // ==========================================================================
  // EMPLOYEE PAYROLL
  // ==========================================================================

  List<PayrollRecord>
      employeePayroll(
    String employeeId,
  ) {
    final result =
        payroll
            .where(
              (record) =>
                  _normalise(
                    record.employeeId,
                  ) ==
                  _normalise(
                    employeeId,
                  ),
            )
            .toList();

    result.sort(
      (a, b) =>
          b.period.compareTo(
        a.period,
      ),
    );

    return result;
  }

  List<PayrollRecord>
      get currentEmployeePayroll {
    final employeeId =
        currentEmployeeId;

    if (employeeId == null) {
      return [];
    }

    return employeePayroll(
      employeeId,
    );
  }

  // ==========================================================================
  // CURRENT EMPLOYEE
  // ==========================================================================

  Employee? get currentEmployee {
    final id =
        currentEmployeeId;

    if (id == null ||
        id.trim().isEmpty) {
      return null;
    }

    return findEmployee(id);
  }

  // ==========================================================================
  // ADD PAYROLL
  // ==========================================================================

  Future<void> addPayroll(
    PayrollRecord record,
  ) async {
    try {
      await _supabase
          .from('payroll')
          .upsert(
            _payrollToSupabase(
              record,
            ),
          );

      await loadPayrollFromSupabase();
    } catch (e) {
      debugPrint(
        'Add payroll error: $e',
      );

      rethrow;
    }
  }

  // ==========================================================================
  // DELETE PAYROLL
  // ==========================================================================

  Future<String> deletePayroll(
    String payrollId,
  ) async {
    try {
      await _supabase
          .from('payroll')
          .delete()
          .eq(
            'id',
            payrollId,
          );

      await loadPayrollFromSupabase();

      return 'Payroll deleted successfully.';
    } catch (e) {
      debugPrint(
        'Delete payroll error: $e',
      );

      return 'Failed to delete payroll: $e';
    }
  }

  // ==========================================================================
  // OLD PAYROLL IMPORT
  // ==========================================================================

  Future<String> importCsv() async {
    return importPayrollCsv();
  }

  // ==========================================================================
  // BRANCH ATTENDANCE
  // ==========================================================================

  List<AttendanceRecord>
      branchAttendance(
    String branchId,
  ) {
    final branch =
        getBranch(branchId);

    if (branch == null) {
      return [];
    }

    final id =
        _normalise(branch.id);

    final result =
        attendance
            .where(
              (record) =>
                  _normalise(
                    record.branchId,
                  ) ==
                  id,
            )
            .toList();

    result.sort(
      (a, b) =>
          b.date.compareTo(
        a.date,
      ),
    );

    return result;
  }

  List<AttendanceRecord>
      get currentBranchAttendance {
    final branchId =
        currentBranchId;

    if (branchId == null) {
      return [];
    }

    return branchAttendance(
      branchId,
    );
  }

  // ==========================================================================
  // EMPLOYEE ATTENDANCE
  // ==========================================================================

  List<AttendanceRecord>
      employeeAttendance(
    String employeeId,
  ) {
    final result =
        attendance
            .where(
              (record) =>
                  _normalise(
                    record.employeeId,
                  ) ==
                  _normalise(
                    employeeId,
                  ),
            )
            .toList();

    result.sort(
      (a, b) =>
          b.date.compareTo(
        a.date,
      ),
    );

    return result;
  }

  List<AttendanceRecord>
      get currentEmployeeAttendance {
    final employeeId =
        currentEmployeeId;

    if (employeeId == null) {
      return [];
    }

    return employeeAttendance(
      employeeId,
    );
  }

  // ==========================================================================
  // ATTENDANCE BY DATE
  // ==========================================================================

  AttendanceRecord?
      attendanceForDate(
    String employeeId,
    DateTime date,
  ) {
    for (final record in attendance) {
      if (_normalise(
                record.employeeId,
              ) ==
              _normalise(
                employeeId,
              ) &&
          _sameDate(
            record.date,
            date,
          )) {
        return record;
      }
    }

    return null;
  }

  // ==========================================================================
  // SAVE ATTENDANCE
  // ==========================================================================

  Future<AttendanceRecord>
      saveAttendance({
    required String employeeId,
    required String branchId,
    required DateTime date,
    required String checkIn,
    required String checkOut,
    required String status,
  }) async {
    final normalizedDate =
        DateTime(
      date.year,
      date.month,
      date.day,
    );

    final actualBranch =
        getBranch(branchId)?.id ??
            branchId.trim();

    final newRecord =
        AttendanceRecord(
      id:
          'ATT-$employeeId-${normalizedDate.year}-${normalizedDate.month}-${normalizedDate.day}',
      employeeId:
          employeeId.trim(),
      branchId:
          actualBranch,
      date:
          normalizedDate,
      checkIn:
          checkIn.trim().isEmpty
              ? '-'
              : checkIn.trim(),
      checkOut:
          checkOut.trim().isEmpty
              ? '-'
              : checkOut.trim(),
      status:
          status.trim().isEmpty
              ? 'Present'
              : status.trim(),
    );

    try {
      await _supabase
          .from('attendance')
          .upsert(
            _attendanceToSupabase(
              newRecord,
            ),
          );

      await loadAttendanceFromSupabase();

      return newRecord;
    } catch (e) {
      debugPrint(
        'Save attendance error: $e',
      );

      rethrow;
    }
  }

  // ==========================================================================
  // ADD ATTENDANCE
  // ==========================================================================

  Future<void> addAttendance(
    AttendanceRecord record,
  ) async {
    await saveAttendance(
      employeeId:
          record.employeeId,
      branchId:
          record.branchId,
      date:
          record.date,
      checkIn:
          record.checkIn,
      checkOut:
          record.checkOut,
      status:
          record.status,
    );
  }

  // ==========================================================================
  // DELETE ATTENDANCE
  // ==========================================================================

  Future<String> deleteAttendance(
    String employeeId,
    DateTime date,
  ) async {
    try {
      await _supabase
          .from('attendance')
          .delete()
          .eq(
            'employee_id',
            employeeId,
          )
          .eq(
            'date',
            _dateOnlyString(date),
          );

      await loadAttendanceFromSupabase();

      return 'Attendance deleted successfully.';
    } catch (e) {
      debugPrint(
        'Delete attendance error: $e',
      );

      return 'Failed to delete attendance: $e';
    }
  }

  // ==========================================================================
  // CHECK IN
  // ==========================================================================

  Future<AttendanceRecord>
      checkInEmployee(
    String employeeId, {
    String? branchId,
  }) async {
    final now =
        DateTime.now();

    final actualBranchId =
        branchId ??
            branchIdForEmployee(
              employeeId,
            ) ??
            '';

    final existing =
        attendanceForDate(
      employeeId,
      now,
    );

    return saveAttendance(
      employeeId:
          employeeId,
      branchId:
          actualBranchId,
      date:
          now,
      checkIn:
          _formatTime(now),
      checkOut:
          existing?.checkOut ??
              '-',
      status:
          _isLate(now)
              ? 'Late'
              : 'Present',
    );
  }

  // ==========================================================================
  // CHECK OUT
  // ==========================================================================

  Future<AttendanceRecord?>
      checkOutEmployee(
    String employeeId,
  ) async {
    final now =
        DateTime.now();

    final existing =
        attendanceForDate(
      employeeId,
      now,
    );

    if (existing == null) {
      return null;
    }

    return saveAttendance(
      employeeId:
          employeeId,
      branchId:
          existing.branchId,
      date:
          existing.date,
      checkIn:
          existing.checkIn,
      checkOut:
          _formatTime(now),
      status:
          existing.status,
    );
  }

  // ==========================================================================
  // TODAY ATTENDANCE
  // ==========================================================================

  List<AttendanceRecord>
      branchTodayAttendance(
    String branchId,
  ) {
    final today =
        DateTime.now();

    return branchAttendance(
      branchId,
    )
        .where(
          (record) =>
              _sameDate(
            record.date,
            today,
          ),
        )
        .toList();
  }

  // ==========================================================================
  // ATTENDANCE SUMMARY
  // ==========================================================================

  int presentCount(
    String branchId,
  ) {
    return branchTodayAttendance(
      branchId,
    )
        .where(
          (record) =>
              record.status
                  .trim()
                  .toLowerCase() ==
              'present',
        )
        .length;
  }

  int lateCount(
    String branchId,
  ) {
    return branchTodayAttendance(
      branchId,
    )
        .where(
          (record) =>
              record.status
                  .trim()
                  .toLowerCase() ==
              'late',
        )
        .length;
  }

  int absentCount(
    String branchId,
  ) {
    return branchTodayAttendance(
      branchId,
    )
        .where(
          (record) =>
              record.status
                  .trim()
                  .toLowerCase() ==
              'absent',
        )
        .length;
  }

  // ==========================================================================
  // CSV HELPERS
  // ==========================================================================

  bool _hasRequiredEmployeeColumns(
    List<String> headers,
  ) {
    final hasId =
        headers.contains(
              'employeeid',
            ) ||
            headers.contains(
              'employee_id',
            ) ||
            headers.contains(
              'id',
            );

    final hasName =
        headers.contains(
              'name',
            ) ||
            headers.contains(
              'employee_name',
            ) ||
            headers.contains(
              'employeename',
            );

    final hasBranch =
        headers.contains(
              'branchid',
            ) ||
            headers.contains(
              'branch_id',
            ) ||
            headers.contains(
              'branch',
            );

    final hasJoiningDate =
        headers.contains(
              'joiningdate',
            ) ||
            headers.contains(
              'joining_date',
            ) ||
            headers.contains(
              'datejoined',
            ) ||
            headers.contains(
              'date_joined',
            );

    return hasId &&
        hasName &&
        hasBranch &&
        hasJoiningDate;
  }

  String _normaliseHeader(
    String value,
  ) {
    return value
        .replaceFirst(
          RegExp(r'^\uFEFF'),
          '',
        )
        .trim()
        .toLowerCase()
        .replaceAll(
          RegExp(r'[\s_\-]+'),
          '',
        );
  }

  String _csvValue(
    Map<String, String> row,
    List<String> keys,
  ) {
    for (final key in keys) {
      final normalisedKey =
          _normaliseHeader(key);

      final value =
          row[normalisedKey];

      if (value != null &&
          value.trim().isNotEmpty) {
        return value.trim();
      }

      final directValue =
          row[key];

      if (directValue != null &&
          directValue.trim().isNotEmpty) {
        return directValue.trim();
      }
    }

    return '';
  }

  // ==========================================================================
  // CSV LINE PARSER
  // ==========================================================================

  List<String> _parseCsvLine(
    String line,
  ) {
    final values =
        <String>[];

    final buffer =
        StringBuffer();

    bool insideQuotes =
        false;

    for (
      int i = 0;
      i < line.length;
      i++
    ) {
      final char =
          line[i];

      if (char == '"') {
        if (insideQuotes &&
            i + 1 <
                line.length &&
            line[i + 1] ==
                '"') {
          buffer.write('"');
          i++;
        } else {
          insideQuotes =
              !insideQuotes;
        }
      } else if (
          char == ',' &&
          !insideQuotes) {
        values.add(
          buffer
              .toString()
              .trim(),
        );

        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    values.add(
      buffer
          .toString()
          .trim(),
    );

    return values;
  }

  // ==========================================================================
  // DATE PARSER
  // ==========================================================================

  DateTime? _parseDate(
    String value,
  ) {
    final text =
        value.trim();

    if (text.isEmpty) {
      return null;
    }

    final parsed =
        DateTime.tryParse(text);

    if (parsed != null) {
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
      );
    }

    final slash =
        RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
    ).firstMatch(text);

    if (slash != null) {
      final day =
          int.tryParse(
        slash.group(1)!,
      );

      final month =
          int.tryParse(
        slash.group(2)!,
      );

      final year =
          int.tryParse(
        slash.group(3)!,
      );

      if (day != null &&
          month != null &&
          year != null) {
        final result =
            DateTime(
          year,
          month,
          day,
        );

        if (result.year == year &&
            result.month == month &&
            result.day == day) {
          return result;
        }
      }
    }

    final dash =
        RegExp(
      r'^(\d{1,2})-(\d{1,2})-(\d{4})$',
    ).firstMatch(text);

    if (dash != null) {
      final day =
          int.tryParse(
        dash.group(1)!,
      );

      final month =
          int.tryParse(
        dash.group(2)!,
      );

      final year =
          int.tryParse(
        dash.group(3)!,
      );

      if (day != null &&
          month != null &&
          year != null) {
        final result =
            DateTime(
          year,
          month,
          day,
        );

        if (result.year == year &&
            result.month == month &&
            result.day == day) {
          return result;
        }
      }
    }

    return null;
  }

  // ==========================================================================
  // BOOLEAN PARSER
  // ==========================================================================

  bool _parseBool(
    String value,
  ) {
    final text =
        value
            .trim()
            .toLowerCase();

    if (text.isEmpty) {
      return true;
    }

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'active';
  }

  // ==========================================================================
  // DATE HELPERS
  // ==========================================================================

  bool _sameDate(
    DateTime a,
    DateTime b,
  ) {
    return a.year ==
            b.year &&
        a.month ==
            b.month &&
        a.day ==
            b.day;
  }

  bool _sameMonth(
    DateTime a,
    DateTime b,
  ) {
    return a.year ==
            b.year &&
        a.month ==
            b.month;
  }

  // ==========================================================================
  // TIME FORMAT
  // ==========================================================================

  String _formatTime(
    DateTime date,
  ) {
    final hour =
        date.hour == 0
            ? 12
            : date.hour > 12
                ? date.hour - 12
                : date.hour;

    final minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final suffix =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $suffix';
  }

  // ==========================================================================
  // LATE CHECK
  // ==========================================================================

  bool _isLate(
    DateTime date,
  ) {
    final nineAm =
        DateTime(
      date.year,
      date.month,
      date.day,
      9,
      0,
    );

    return date.isAfter(
      nineAm,
    );
  }

  // ==========================================================================
  // SUPABASE DATE
  // ==========================================================================

  DateTime? _supabaseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  // ==========================================================================
  // REQUIRED DATE
  // ==========================================================================

  DateTime _requiredDate(
    DateTime? value, {
    DateTime? fallback,
  }) {
    return value ??
        fallback ??
        DateTime.now();
  }

  // ==========================================================================
  // SUPABASE BOOLEAN
  // ==========================================================================

  bool _supabaseBool(
    dynamic value,
  ) {
    if (value == null) {
      return true;
    }

    if (value is bool) {
      return value;
    }

    final text =
        value
            .toString()
            .trim()
            .toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'active';
  }

  // ==========================================================================
  // DOUBLE VALUE
  // ==========================================================================

  double _doubleValue(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0;
  }

  double? _nullableDoubleValue(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return _doubleValue(value);
  }

  // ==========================================================================
  // DATE STRING
  // ==========================================================================

  String _dateOnlyString(
    DateTime date,
  ) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ==========================================================================
  // EMPLOYEE -> SUPABASE
  // ==========================================================================

  Map<String, dynamic>
      _employeeToSupabase(
    Employee employee,
  ) {
    final joiningDate =
        _requiredDate(
      employee.joiningDate,
    );

    return {
      'employee_id':
          employee.employeeId,
      'name':
          employee.name,
      'designation':
          employee.designation,
      'department':
          employee.department,
      'email':
          employee.email,
      'new_ic_no':
          employee.newIcNo,
      'bank_code':
          employee.bankCode,
      'bank_account':
          employee.bankAccount,
      'phone':
          employee.phone,
      'address':
          employee.address,
      'joining_date':
          _dateOnlyString(
        joiningDate,
      ),
      'is_active':
          employee.isActive,
      'branch_id':
          employee.branchId,
    };
  }

  // ==========================================================================
  // PAYROLL -> SUPABASE
  // ==========================================================================

  Map<String, dynamic>
      _payrollToSupabase(
    PayrollRecord record,
  ) {
    final createdAt =
        _requiredDate(
      record.createdAt,
    );

    final updatedAt =
        _requiredDate(
      record.updatedAt,
    );

    return {
      'id':
          record.id,
      'employee_id':
          record.employeeId,
      'period':
          _dateOnlyString(
        record.period,
      ),
      'basic_salary':
          record.basicSalary,
      'elaun_kedatangan':
          record.elaunKedatangan,
      'elaun_perkhidmatan':
          record.elaunPerkhidmatan,
      'elaun_kerajinan':
          record.elaunKerajinan,
      'overtime':
          record.overtime,
      'bonus':
          record.bonus,
      'commission':
          record.commission,
      'other_earnings':
          record.otherEarnings,
      'cuti_umum':
          record.cutiUmum,
      'epf_employee':
          record.epfEmployee,
      'socso_employee':
          record.socsoEmployee,
      'eis_employee':
          record.eisEmployee,
      'pcb':
          record.pcb,
      'zakat':
          record.zakat,
      'epf_employer':
          record.epfEmployer,
      'socso_employer':
          record.socsoEmployer,
      'eis_employer':
          record.eisEmployer,
      'new_ic_no':
          record.newIcNo,
      'bank_code':
          record.bankCode,
      'bank_account':
          record.bankAccount,
      'remarks':
          record.remarks,
      'created_at':
          createdAt.toIso8601String(),
      'updated_at':
          updatedAt.toIso8601String(),
    };
  }

  // ==========================================================================
  // ATTENDANCE -> SUPABASE
  // ==========================================================================

  Map<String, dynamic>
      _attendanceToSupabase(
    AttendanceRecord record,
  ) {
    return {
      'id':
          record.id,
      'employee_id':
          record.employeeId,
      'branch_id':
          record.branchId,
      'date':
          _dateOnlyString(
        record.date,
      ),
      'check_in':
          record.checkIn,
      'check_out':
          record.checkOut,
      'status':
          record.status,
    };
  }
}

