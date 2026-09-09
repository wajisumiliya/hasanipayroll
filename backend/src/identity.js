export function normalizeIdentityNumber(value) {
  return String(value ?? "")
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, "")
    .slice(0, 100);
}

export async function findActiveEmployeeIdentity(pool, employeeId) {
  const result = await pool.query(
    `SELECT NULLIF(TRIM(COALESCE(
             to_jsonb(employee_row) ->> 'new_ic_no',
             to_jsonb(employee_row) ->> 'newIcNo',
             ''
           )), '') AS new_ic_no
     FROM public.employees AS employee_row
     WHERE UPPER(TRIM(COALESCE(
             to_jsonb(employee_row) ->> 'employee_id',
             to_jsonb(employee_row) ->> 'employeeId',
             ''
           ))) = $1
       AND LOWER(COALESCE(
             to_jsonb(employee_row) ->> 'is_active',
             to_jsonb(employee_row) ->> 'isActive',
             'true'
           )) IN ('true', 't', '1')
     LIMIT 1`,
    [String(employeeId ?? "").trim().toUpperCase()],
  );

  return result.rows[0]?.new_ic_no ?? null;
}
