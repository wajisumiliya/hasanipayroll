/// Centralized pure payroll calculations.
///
/// Historical foreign-worker records can contain the same salary in both
/// basic_salary and fw_salary. [salaryBase] deliberately chooses one salary
/// source so those records are never double counted.
class PayrollCalculationService {
  const PayrollCalculationService._();

  static double salaryBase({
    required double basicSalary,
    required double fwSalary,
  }) {
    if (fwSalary != 0) return fwSalary;
    return basicSalary;
  }

  static double grossEarnings({
    required double basicSalary,
    required double fwSalary,
    double elaunKedatangan = 0,
    double elaunPerkhidmatan = 0,
    double elaunKerajinan = 0,
    double overtime = 0,
    double bonus = 0,
    double commission = 0,
    double otherEarnings = 0,
    double housingAllowance = 0,
    double travelAllowance = 0,
    double cutiUmum = 0,
  }) {
    return salaryBase(basicSalary: basicSalary, fwSalary: fwSalary) +
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

  static double totalDeductions({
    double epfEmployee = 0,
    double socsoEmployee = 0,
    double eisEmployee = 0,
    double pcb = 0,
    double zakat = 0,
    double advance = 0,
    double loan = 0,
    double unpaid = 0,
    double late = 0,
    double other = 0,
  }) {
    return epfEmployee +
        socsoEmployee +
        eisEmployee +
        pcb +
        zakat +
        advance +
        loan +
        unpaid +
        late +
        other;
  }

  static double netPay({
    required double gross,
    required double deductions,
  }) =>
      gross - deductions;
}
