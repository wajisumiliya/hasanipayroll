// Confirmed historical report corrections only. These never update employees,
// payroll, attendance, or bank exports. Keep every correction date-bounded.
const corrections = [
  {employeeId:'BAS025',from:'2025-07',through:'2026-06',branchName:'GURUN'},
];

const key = value => String(value ?? '').trim().toUpperCase();

export function salaryReportBranchCorrection(employeeId, month, branches) {
  const correction = corrections.find(row => row.employeeId === key(employeeId)
    && month >= row.from && month <= row.through);
  if (!correction) return null;
  // Resolve the real branch ID from the directory instead of inventing one.
  const matches = new Set(branches.filter(branch => key(branch.name) === correction.branchName
    || key(branch.id) === correction.branchName).map(branch => key(branch.id)).filter(Boolean));
  if (matches.size !== 1) {
    throw new Error(`Salary Report branch correction for ${key(employeeId)} requires one ${correction.branchName} branch. Review the branch directory.`);
  }
  return [...matches][0];
}
