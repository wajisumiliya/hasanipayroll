export function employeeLeaveView(employee, role) {
  if (!employee || String(role).toUpperCase() === 'ADMIN') return employee;
  const {medical_leave_balance, ...visible} = employee;
  return visible;
}
