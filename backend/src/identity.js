export function normalizeIdentityNumber(value) {
  return String(value ?? "")
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, "")
    .slice(0, 100);
}

export async function findActiveEmployeeIdentity(pool, employeeId) {
  const result = await pool.query(
    `SELECT new_ic_no
     FROM public.employees
     WHERE UPPER(TRIM(employee_id)) = $1
       AND is_active IS TRUE
     LIMIT 1`,
    [String(employeeId ?? "").trim().toUpperCase()],
  );

  return result.rows[0]?.new_ic_no ?? null;
}
