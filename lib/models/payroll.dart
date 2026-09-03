// lib/models/payroll.dart

// ============================================================================
// PAYROLL RECORD
// ============================================================================

class PayrollRecord {
  final String id;
  final String employeeId;
  final DateTime period;

  // --------------------------------------------------------------------------
  // EARNINGS
  // --------------------------------------------------------------------------

  final double basicSalary;

  /// FW SALARY
  final double fwSalary;

  /// ELAUN KEDATANGAN
  final double elaunKedatangan;

  /// ELAUN PERKHIDMATAN
  final double elaunPerkhidmatan;

  /// ELAUN KERAJINAN
  final double elaunKerajinan;

  final double overtime;
  final double bonus;
  final double commission;
  final double otherEarnings;
  final double housingAllowance;
  final double travelAllowance;

  // --------------------------------------------------------------------------
  // EMPLOYEE DEDUCTIONS
  // --------------------------------------------------------------------------

  /// CUTI UMUM
  final double cutiUmum;

  final double epfEmployee;
  final double socsoEmployee;
  final double eisEmployee;
  final double pcb;
  final double zakat;
  final double advanceDeduction;
  final double loanDeduction;
  final double unpaidLeave;
  final double lateDeduction;
  final double otherDeductionAmount;

  // --------------------------------------------------------------------------
  // EMPLOYER CONTRIBUTIONS
  // --------------------------------------------------------------------------

  final double epfEmployer;
  final double socsoEmployer;
  final double eisEmployer;

  // --------------------------------------------------------------------------
  // EMPLOYEE / BANK INFORMATION
  // --------------------------------------------------------------------------

  final String newIcNo;
  final String bankCode;
  final String bankAccount;
  final String bankName;
  final double? storedGrossSalary;
  final double? storedNetSalary;
  final double? storedTotalDeductions;
  final bool isPaid;
  final DateTime? paidAt;
  final String paymentReference;

  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PayrollRecord({
    required this.id,
    required this.employeeId,
    required this.period,

    // Earnings
    required this.basicSalary,
    this.fwSalary = 0,
    required this.elaunKedatangan,
    required this.elaunPerkhidmatan,
    required this.elaunKerajinan,
    this.overtime = 0,
    this.bonus = 0,
    this.commission = 0,
    this.otherEarnings = 0,
    this.housingAllowance = 0,
    this.travelAllowance = 0,

    // Employee deductions
    required this.cutiUmum,
    required this.epfEmployee,
    required this.socsoEmployee,
    required this.eisEmployee,
    required this.pcb,
    required this.zakat,
    this.advanceDeduction = 0,
    this.loanDeduction = 0,
    this.unpaidLeave = 0,
    this.lateDeduction = 0,
    this.otherDeductionAmount = 0,

    // Employer contributions
    required this.epfEmployer,
    required this.socsoEmployer,
    required this.eisEmployer,

    // Employee / bank information
    this.newIcNo = '',
    this.bankCode = '',
    this.bankAccount = '',
    this.bankName = '',
    this.storedGrossSalary,
    this.storedNetSalary,
    this.storedTotalDeductions,
    this.isPaid = false,
    this.paidAt,
    this.paymentReference = '',
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  // ==========================================================================
  // COMPATIBILITY GETTERS
  // ==========================================================================

  double get foodAllowance => elaunKedatangan;

  double get otherAllowance {
    return elaunPerkhidmatan + elaunKerajinan;
  }

  double get otherDeduction {
    return cutiUmum +
        zakat +
        advanceDeduction +
        loanDeduction +
        unpaidLeave +
        otherDeductionAmount;
  }

  // ==========================================================================
  // TOTALS
  // ==========================================================================

  double get totalAllowance {
    return fwSalary + elaunKedatangan + elaunPerkhidmatan + elaunKerajinan;
  }

  double get additionalEarnings {
    return fwSalary +
        elaunKedatangan +
        elaunPerkhidmatan +
        elaunKerajinan +
        overtime +
        bonus +
        commission +
        otherEarnings +
        housingAllowance +
        travelAllowance +
        cutiUmum;
  }

  double get totalEarnings {
    return basicSalary + additionalEarnings;
  }

  double get statutoryDeductions {
    return epfEmployee + socsoEmployee + eisEmployee + pcb + zakat;
  }

  double get totalDeductions {
    return statutoryDeductions +
        advanceDeduction +
        loanDeduction +
        unpaidLeave +
        lateDeduction +
        otherDeductionAmount;
  }

  double get netPay {
    return totalEarnings - totalDeductions;
  }

  double get totalEmployerContribution {
    return epfEmployer + socsoEmployer + eisEmployer;
  }

  double get totalEmployerCost {
    return totalEarnings + totalEmployerContribution;
  }

  // ==========================================================================
  // COPY WITH
  // ==========================================================================

  PayrollRecord copyWith({
    String? id,
    String? employeeId,
    DateTime? period,
    double? basicSalary,
    double? fwSalary,
    double? elaunKedatangan,
    double? elaunPerkhidmatan,
    double? elaunKerajinan,
    double? overtime,
    double? bonus,
    double? commission,
    double? otherEarnings,
    double? cutiUmum,
    double? epfEmployee,
    double? socsoEmployee,
    double? eisEmployee,
    double? pcb,
    double? zakat,
    double? lateDeduction,
    double? epfEmployer,
    double? socsoEmployer,
    double? eisEmployer,
    String? newIcNo,
    String? bankCode,
    String? bankAccount,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PayrollRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      period: period ?? this.period,
      basicSalary: basicSalary ?? this.basicSalary,
      fwSalary: fwSalary ?? this.fwSalary,
      elaunKedatangan: elaunKedatangan ?? this.elaunKedatangan,
      elaunPerkhidmatan: elaunPerkhidmatan ?? this.elaunPerkhidmatan,
      elaunKerajinan: elaunKerajinan ?? this.elaunKerajinan,
      overtime: overtime ?? this.overtime,
      bonus: bonus ?? this.bonus,
      commission: commission ?? this.commission,
      otherEarnings: otherEarnings ?? this.otherEarnings,
      cutiUmum: cutiUmum ?? this.cutiUmum,
      epfEmployee: epfEmployee ?? this.epfEmployee,
      socsoEmployee: socsoEmployee ?? this.socsoEmployee,
      eisEmployee: eisEmployee ?? this.eisEmployee,
      pcb: pcb ?? this.pcb,
      zakat: zakat ?? this.zakat,
      lateDeduction: lateDeduction ?? this.lateDeduction,
      epfEmployer: epfEmployer ?? this.epfEmployer,
      socsoEmployer: socsoEmployer ?? this.socsoEmployer,
      eisEmployer: eisEmployer ?? this.eisEmployer,
      newIcNo: newIcNo ?? this.newIcNo,
      bankCode: bankCode ?? this.bankCode,
      bankAccount: bankAccount ?? this.bankAccount,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ==========================================================================
  // JSON
  // ==========================================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'period': period.toIso8601String(),
      'basicSalary': basicSalary,
      'fwSalary': fwSalary,
      'elaunKedatangan': elaunKedatangan,
      'elaunPerkhidmatan': elaunPerkhidmatan,
      'elaunKerajinan': elaunKerajinan,
      'overtime': overtime,
      'bonus': bonus,
      'commission': commission,
      'otherEarnings': otherEarnings,
      'cutiUmum': cutiUmum,
      'epfEmployee': epfEmployee,
      'socsoEmployee': socsoEmployee,
      'eisEmployee': eisEmployee,
      'pcb': pcb,
      'zakat': zakat,
      'lateDeduction': lateDeduction,
      'epfEmployer': epfEmployer,
      'socsoEmployer': socsoEmployer,
      'eisEmployer': eisEmployer,
      'newIcNo': newIcNo,
      'bankCode': bankCode,
      'bankAccount': bankAccount,
      'remarks': remarks,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // ==========================================================================
  // FROM JSON
  // ==========================================================================

  factory PayrollRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return PayrollRecord(
      id: _stringValue(json['id']),
      employeeId: _stringValue(json['employeeId']),
      period: _parseDate(json['period']),
      basicSalary: _doubleValue(json['basicSalary']),
      fwSalary: _doubleValue(
        json['fwSalary'] ??
            json['fw_salary'] ??
            json['FW_salary'] ??
            json['FW SALARY'],
      ),
      elaunKedatangan: _doubleValue(
        json['elaunKedatangan'] ?? json['ELAUN KEDATANGAN'],
      ),
      elaunPerkhidmatan: _doubleValue(
        json['elaunPerkhidmatan'] ??
            json['ELAUAN PERKHIDMATAN'] ??
            json['ELAUN PERKHIDMATAN'],
      ),
      elaunKerajinan: _doubleValue(
        json['elaunKerajinan'] ?? json['ELAUN KERAJINAN'],
      ),
      overtime: _doubleValue(json['overtime']),
      bonus: _doubleValue(json['bonus']),
      commission: _doubleValue(json['commission']),
      otherEarnings: _doubleValue(json['otherEarnings']),
      housingAllowance:
          _doubleValue(json['housingAllowance'] ?? json['housing_allowance']),
      travelAllowance:
          _doubleValue(json['travelAllowance'] ?? json['travel_allowance']),
      cutiUmum: _doubleValue(
        json['cutiUmum'] ?? json['CUTI UMUM'],
      ),
      epfEmployee: _doubleValue(json['epfEmployee']),
      socsoEmployee: _doubleValue(json['socsoEmployee']),
      eisEmployee: _doubleValue(json['eisEmployee']),
      pcb: _doubleValue(json['pcb']),
      zakat: _doubleValue(json['zakat']),
      advanceDeduction: _doubleValue(
        json['advanceDeduction'] ?? json['advance_deduction'],
      ),
      loanDeduction: _doubleValue(
        json['loanDeduction'] ?? json['loan_deduction'],
      ),
      unpaidLeave: _doubleValue(
        json['unpaidLeave'] ??
            json['unpaid_leave'] ??
            json['unpaidDeduction'] ??
            json['unpaid_deduction'],
      ),
      lateDeduction: _doubleValue(
        json['lateDeduction'] ?? json['late_deduction'],
      ),
      otherDeductionAmount: _doubleValue(
        json['otherDeduction'] ?? json['other_deduction'],
      ),
      epfEmployer: _doubleValue(json['epfEmployer']),
      socsoEmployer: _doubleValue(json['socsoEmployer']),
      eisEmployer: _doubleValue(json['eisEmployer']),
      newIcNo: _stringValue(json['newIcNo']),
      bankCode: _stringValue(json['bankCode']),
      bankAccount: _stringValue(json['bankAccount']),
      bankName: _stringValue(json['bankName'] ?? json['bank_name']),
      storedGrossSalary: _nullableDouble(
        json['grossSalary'] ?? json['gross_salary'],
      ),
      storedNetSalary: _nullableDouble(
        json['netSalary'] ?? json['net_salary'],
      ),
      storedTotalDeductions: _nullableDouble(
        json['totalDeductions'] ?? json['total_deductions'],
      ),
      isPaid: _boolValue(json['isPaid'] ?? json['is_paid']),
      paidAt: _parseNullableDate(json['paidAt'] ?? json['paid_at']),
      paymentReference: _stringValue(
        json['paymentReference'] ?? json['payment_reference'],
      ),
      remarks: _nullableString(json['remarks']),
      createdAt: _parseNullableDate(json['createdAt']),
      updatedAt: _parseNullableDate(json['updatedAt']),
    );
  }
}

// ============================================================================
// EMPLOYEE
// ============================================================================

class Employee {
  final String employeeId;
  final String name;
  final String designation;
  final String department;
  final String email;

  final String newIcNo;
  final String bankCode;
  final String bankAccount;

  final String phone;
  final String address;
  final DateTime? joiningDate;
  final bool isActive;

  final String branchId;

  const Employee({
    required this.employeeId,
    required this.name,
    required this.designation,
    required this.department,
    required this.email,
    required this.newIcNo,
    required this.bankCode,
    required this.bankAccount,
    this.phone = '',
    this.address = '',
    this.joiningDate,
    this.isActive = true,
    this.branchId = '',
  });

  // ==========================================================================
  // COPY WITH
  // ==========================================================================

  Employee copyWith({
    String? employeeId,
    String? name,
    String? designation,
    String? department,
    String? email,
    String? newIcNo,
    String? bankCode,
    String? bankAccount,
    String? phone,
    String? address,
    DateTime? joiningDate,
    bool? isActive,
    String? branchId,
  }) {
    return Employee(
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      email: email ?? this.email,
      newIcNo: newIcNo ?? this.newIcNo,
      bankCode: bankCode ?? this.bankCode,
      bankAccount: bankAccount ?? this.bankAccount,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      joiningDate: joiningDate ?? this.joiningDate,
      isActive: isActive ?? this.isActive,
      branchId: branchId ?? this.branchId,
    );
  }

  // ==========================================================================
  // JSON
  // ==========================================================================

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'name': name,
      'designation': designation,
      'department': department,
      'email': email,
      'newIcNo': newIcNo,
      'bankCode': bankCode,
      'bankAccount': bankAccount,
      'phone': phone,
      'address': address,
      'joiningDate': joiningDate?.toIso8601String(),
      'isActive': isActive,
      'branchId': branchId,
    };
  }

  factory Employee.fromJson(
    Map<String, dynamic> json,
  ) {
    return Employee(
      employeeId: _stringValue(json['employeeId']),
      name: _stringValue(json['name']),
      designation: _stringValue(json['designation']),
      department: _stringValue(json['department']),
      email: _stringValue(json['email']),
      newIcNo: _stringValue(json['newIcNo']),
      bankCode: _stringValue(json['bankCode']),
      bankAccount: _stringValue(json['bankAccount']),
      phone: _stringValue(json['phone']),
      address: _stringValue(json['address']),
      joiningDate: _parseNullableDate(
        json['joiningDate'],
      ),
      isActive: _boolValue(
        json['isActive'],
        defaultValue: true,
      ),
      branchId: _stringValue(json['branchId']),
    );
  }
}

// ============================================================================
// ATTENDANCE
// ============================================================================

class AttendanceRecord {
  final String id;
  final String employeeId;
  final DateTime date;

  // --------------------------------------------------------------------------
  // LEGACY / SIMPLE ATTENDANCE
  // --------------------------------------------------------------------------

  final String checkIn;
  final String checkOut;
  final String status;

  // --------------------------------------------------------------------------
  // MONTHLY ATTENDANCE
  // --------------------------------------------------------------------------

  final String morningIn;
  final String morningOut;

  final String afternoonIn;
  final String afternoonOut;

  final String overtimeIn;
  final String overtimeOut;

  final bool otAuthorized;

  final String branchId;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkIn = '',
    this.checkOut = '',
    this.status = 'Absent',
    this.morningIn = '',
    this.morningOut = '',
    this.afternoonIn = '',
    this.afternoonOut = '',
    this.overtimeIn = '',
    this.overtimeOut = '',
    this.otAuthorized = false,
    this.branchId = '',
  });

  // ==========================================================================
  // COMPATIBILITY GETTERS
  // ==========================================================================

  /// If the newer monthly attendance fields exist, use them.
  /// Otherwise fall back to the old checkIn value.
  String get effectiveCheckIn {
    if (morningIn.trim().isNotEmpty) {
      return morningIn;
    }

    return checkIn;
  }

  /// If the newer monthly attendance fields exist, use them.
  /// Otherwise fall back to the old checkOut value.
  String get effectiveCheckOut {
    if (afternoonOut.trim().isNotEmpty) {
      return afternoonOut;
    }

    if (afternoonIn.trim().isNotEmpty) {
      return afternoonIn;
    }

    return checkOut;
  }

  // ==========================================================================
  // COPY WITH
  // ==========================================================================

  AttendanceRecord copyWith({
    String? id,
    String? employeeId,
    DateTime? date,
    String? checkIn,
    String? checkOut,
    String? status,
    String? morningIn,
    String? morningOut,
    String? afternoonIn,
    String? afternoonOut,
    String? overtimeIn,
    String? overtimeOut,
    bool? otAuthorized,
    String? branchId,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status ?? this.status,
      morningIn: morningIn ?? this.morningIn,
      morningOut: morningOut ?? this.morningOut,
      afternoonIn: afternoonIn ?? this.afternoonIn,
      afternoonOut: afternoonOut ?? this.afternoonOut,
      overtimeIn: overtimeIn ?? this.overtimeIn,
      overtimeOut: overtimeOut ?? this.overtimeOut,
      otAuthorized: otAuthorized ?? this.otAuthorized,
      branchId: branchId ?? this.branchId,
    );
  }

  // ==========================================================================
  // JSON
  // ==========================================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'date': date.toIso8601String(),

      // Legacy/simple fields
      'checkIn': checkIn,
      'checkOut': checkOut,
      'status': status,

      // Monthly attendance fields
      'morningIn': morningIn,
      'morningOut': morningOut,
      'afternoonIn': afternoonIn,
      'afternoonOut': afternoonOut,
      'overtimeIn': overtimeIn,
      'overtimeOut': overtimeOut,
      'otAuthorized': otAuthorized,

      'branchId': branchId,
    };
  }

  // ==========================================================================
  // FROM JSON
  // ==========================================================================

  factory AttendanceRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    final checkInValue = _stringValue(
      json['checkIn'] ?? json['check_in'],
      defaultValue: '',
    );

    final checkOutValue = _stringValue(
      json['checkOut'] ?? json['check_out'],
      defaultValue: '',
    );

    return AttendanceRecord(
      id: _stringValue(json['id']),
      employeeId: _stringValue(
        json['employeeId'] ?? json['employee_id'],
      ),
      date: _parseDate(
        json['date'] ?? json['attendance_date'],
      ),
      checkIn: checkInValue,
      checkOut: checkOutValue,
      status: _stringValue(
        json['status'],
        defaultValue: 'Absent',
      ),
      morningIn: _stringValue(
        json['morningIn'] ?? json['morning_in'] ?? checkInValue,
      ),
      morningOut: _stringValue(
        json['morningOut'] ?? json['morning_out'],
      ),
      afternoonIn: _stringValue(
        json['afternoonIn'] ?? json['afternoon_in'],
      ),
      afternoonOut: _stringValue(
        json['afternoonOut'] ?? json['afternoon_out'] ?? checkOutValue,
      ),
      overtimeIn: _stringValue(
        json['overtimeIn'] ?? json['overtime_in'],
      ),
      overtimeOut: _stringValue(
        json['overtimeOut'] ?? json['overtime_out'],
      ),
      otAuthorized: _boolValue(
        json['otAuthorized'] ?? json['ot_authorized'],
        defaultValue: false,
      ),
      branchId: _stringValue(
        json['branchId'] ?? json['branch_id'],
      ),
    );
  }
}

// ============================================================================
// BRANCH
// ============================================================================

class Branch {
  final String id;
  final String name;
  final String location;

  final String username;

  final String address;
  final String phone;
  final bool isActive;

  const Branch({
    String? id,
    String? name,
    String? location,
    String? branchId,
    String? branchName,
    this.username = '',
    this.address = '',
    this.phone = '',
    this.isActive = true,
  })  : id = id ?? branchId ?? '',
        name = name ?? branchName ?? '',
        location = location ?? '';

  // ==========================================================================
  // COMPATIBILITY GETTERS
  // ==========================================================================

  String get branchId => id;

  String get branchName => name;

  // ==========================================================================
  // COPY WITH
  // ==========================================================================

  Branch copyWith({
    String? id,
    String? name,
    String? location,
    String? branchId,
    String? branchName,
    String? username,
    String? address,
    String? phone,
    bool? isActive,
  }) {
    return Branch(
      id: id ?? branchId ?? this.id,
      name: name ?? branchName ?? this.name,
      location: location ?? this.location,
      username: username ?? this.username,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
    );
  }

  // ==========================================================================
  // JSON
  // ==========================================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'branchId': id,
      'branchName': name,
      'username': username,
      'address': address,
      'phone': phone,
      'isActive': isActive,
    };
  }

  factory Branch.fromJson(
    Map<String, dynamic> json,
  ) {
    return Branch(
      id: _stringValue(
        json['branchId'] ?? json['id'],
      ),
      name: _stringValue(
        json['branchName'] ?? json['name'],
      ),
      location: _stringValue(json['location']),
      username: _stringValue(json['username']),
      address: _stringValue(json['address']),
      phone: _stringValue(json['phone']),
      isActive: _boolValue(
        json['isActive'],
        defaultValue: true,
      ),
    );
  }
}

// ============================================================================
// SHARED PARSING HELPERS
// ============================================================================

String _stringValue(
  dynamic value, {
  String defaultValue = '',
}) {
  if (value == null) {
    return defaultValue;
  }

  final text = value.toString().trim();

  if (text.isEmpty) {
    return defaultValue;
  }

  return text;
}

// ----------------------------------------------------------------------------

String? _nullableString(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();

  if (text.isEmpty) {
    return null;
  }

  return text;
}

// ----------------------------------------------------------------------------

double _doubleValue(
  dynamic value,
) {
  if (value == null) {
    return 0.0;
  }

  if (value is double) {
    return value;
  }

  if (value is int) {
    return value.toDouble();
  }

  if (value is num) {
    return value.toDouble();
  }

  var text = value.toString().trim();

  if (text.isEmpty) {
    return 0.0;
  }

  text =
      text.replaceAll(',', '').replaceAll('RM', '').replaceAll('rm', '').trim();

  if (text.startsWith('(') && text.endsWith(')')) {
    text = '-${text.substring(1, text.length - 1)}';
  }

  text = text.replaceAll(' ', '');

  return double.tryParse(text) ?? 0.0;
}

// ----------------------------------------------------------------------------

DateTime _parseDate(
  dynamic value,
) {
  if (value == null) {
    return DateTime.now();
  }

  final text = value.toString().trim();

  if (text.isEmpty) {
    return DateTime.now();
  }

  final parsed = DateTime.tryParse(text);

  if (parsed != null) {
    return parsed;
  }

  final parts = text.split('-');

  if (parts.length == 3) {
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year != null &&
        month != null &&
        day != null &&
        month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= 31) {
      return DateTime(
        year,
        month,
        day,
      );
    }
  }

  return DateTime.now();
}

// ----------------------------------------------------------------------------

DateTime? _parseNullableDate(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();

  if (text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text);
}

// ----------------------------------------------------------------------------

bool _boolValue(
  dynamic value, {
  bool defaultValue = false,
}) {
  if (value == null) {
    return defaultValue;
  }

  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final text = value.toString().trim().toLowerCase();

  switch (text) {
    case 'true':
    case '1':
    case 'yes':
    case 'y':
    case 'active':
      return true;

    case 'false':
    case '0':
    case 'no':
    case 'n':
    case 'inactive':
      return false;

    default:
      return defaultValue;
  }
}

double? _nullableDouble(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  return _doubleValue(value);
}
