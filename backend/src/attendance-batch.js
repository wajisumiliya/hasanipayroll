import {normalizeAttendanceWrite} from './attendance-status.js';
const allowedAttendanceFields = [
  "id", "employee_id", "branch_id", "attendance_date", "check_in", "check_out",
  "status", "morning_in", "morning_out", "afternoon_in", "afternoon_out",
  "evening_in", "evening_out", "overtime_in", "overtime_out", "work_minutes",
  "break_minutes", "net_working_minutes", "net_working_duration", "work_duration",
  "break_duration", "overtime_minutes", "overtime_duration", "ot_requested",
  "ot_authorized", "approved_ot_minutes", "ot_manual_override", "is_unpaid",
  "is_public_holiday",
];

const conflictKeys = new Set(["id", "employee_id", "branch_id", "attendance_date"]);

/** Use the branch stored on the verified employee, never the client copy. */
export function withCanonicalBranchId(row, branchId) {
  return { ...row, branch_id: String(branchId ?? "").trim() };
}

/** Build parameterized multi-row upserts, grouping rows with the same fields. */
export function buildAttendanceUpserts(rows) {
  const groups = new Map();

  for (const original of rows) {
    const row = normalizeAttendanceWrite(original);
    const fields = allowedAttendanceFields.filter((field) => Object.hasOwn(row, field));
    const key = fields.join(",");
    const group = groups.get(key) ?? { fields, rows: [] };
    group.rows.push(row);
    groups.set(key, group);
  }

  return [...groups.values()].map(({ fields, rows: groupRows }) => {
    const values = [];
    const tuples = groupRows.map((row) => {
      const placeholders = fields.map((field) => {
        values.push(row[field]);
        return `$${values.length}`;
      });
      return `(${placeholders.join(",")})`;
    });
    const updates = fields
      .filter((field) => !conflictKeys.has(field))
      .map((field) => `${field}=EXCLUDED.${field}`)
      .join(",");

    return {
      sql: `INSERT INTO public.attendance (${fields.join(",")}) VALUES ${tuples.join(",")} ON CONFLICT (employee_id,attendance_date) DO UPDATE SET ${updates}`,
      values,
    };
  });
}
