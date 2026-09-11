export function normalizeIdentityNumber(value) {
  return String(value ?? "")
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, 100);
}

export function resolvePasswordRecoveryEmployeeId(user, login) {
  const linkedEmployeeId = String(
    user?.employeeId ?? user?.employee_id ?? "",
  ).trim();
  if (linkedEmployeeId) return linkedEmployeeId.toUpperCase();

  const enteredEmployeeId = String(login ?? "").trim().toUpperCase();
  return enteredEmployeeId || null;
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

export async function findPasswordResetUser(pool, userId) {
  const cleanUserId = String(userId ?? "").trim();
  if (!cleanUserId) return null;

  // Read the account as JSON so password recovery also works on deployments
  // that predate optional app_user columns in the Prisma model.
  const result = await pool.query(
    `SELECT to_jsonb(account_row) AS data
     FROM public."app_user" AS account_row
     WHERE account_row."id" = $1
     LIMIT 1`,
    [cleanUserId],
  );

  const data = result.rows[0]?.data;
  if (!data) return null;

  return {
    ...data,
    passwordHash: data.passwordHash ?? data.password_hash ?? null,
    passwordChangedAt:
      data.passwordChangedAt ?? data.password_changed_at ?? null,
    isActive: [true, "true", "t", "1"].includes(
      data.isActive ?? data.is_active ?? true,
    ),
  };
}
