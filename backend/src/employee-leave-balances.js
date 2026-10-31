export function employeeLeaveView(employee, role) {
  if (!employee || String(role).toUpperCase() === 'ADMIN') return employee;
  const {medical_leave_balance, medical_leave_opening_month, ...visible} = employee;
  return visible;
}
