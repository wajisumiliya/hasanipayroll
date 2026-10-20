// The imported Neon app_user table uses username as its primary key.
export function normalizeAccount(data) {
  if (!data) return null;
  return {
    ...data,
    id: data.id ?? data.username,
    employeeId: data.employeeId ?? data.employee_id ?? null,
    passwordHash: data.passwordHash ?? data.passwordhash ?? data.password_hash ?? null,
    isActive: [true, 'true', 't', '1'].includes(data.isActive ?? data.is_active ?? true),
    mustChangePassword: data.mustChangePassword ?? data.must_change_password ?? false,
    passwordChangedAt: data.passwordChangedAt ?? data.password_changed_at ?? null,
  };
}

export async function provisionEmployeeAccount(pool, { employeeId, email, isActive, resetPassword, hashPassword }) {
  const client = await pool.connect();
  const reject = (message, status=409) => Object.assign(new Error(message), { status });
  try {
    await client.query('BEGIN');
    const employee = await client.query('SELECT employee_id FROM public.employees WHERE UPPER(TRIM(employee_id))=$1 FOR UPDATE', [employeeId]);
    if (employee.rowCount !== 1) throw reject('Employee not found.',404);
    const canonicalId=employee.rows[0].employee_id;
    const existing = await client.query(`SELECT username,role,employee_id,email,"passwordHash" FROM public.app_user
      WHERE UPPER(TRIM(COALESCE(employee_id,'')))=$1 OR LOWER(TRIM(COALESCE(email,'')))=$2
         OR LOWER(TRIM(username))=$2 FOR UPDATE`,[employeeId,email]);
    if (existing.rows.length>1) throw reject('Conflicting application accounts. Correct the duplicate account before resetting its password.');
    const account=existing.rows[0];
    if(account && (String(account.role).toLowerCase()!=='employee' || (account.employee_id && String(account.employee_id).trim().toUpperCase()!==employeeId))) {
      throw reject('That login belongs to another account.');
    }
    const needsPassword = !account || resetPassword || !account.passwordHash;
    const passwordHash = needsPassword ? await hashPassword() : null;
    if(account) {
      // Keep the imported username so existing employee IDs and sessions remain valid.
      await client.query(`UPDATE public.app_user SET employee_id=$2,email=$3,role='employee',is_active=$4,
        "passwordHash"=CASE WHEN $5 THEN $6 ELSE "passwordHash" END,
        must_change_password=CASE WHEN $5 THEN TRUE ELSE must_change_password END,
        first_login=CASE WHEN $5 THEN TRUE ELSE first_login END,
        password_changed_at=CASE WHEN $5 THEN NULL ELSE password_changed_at END,
        "otpHash"=CASE WHEN $5 THEN NULL ELSE "otpHash" END,
        "otpExpiresAt"=CASE WHEN $5 THEN NULL ELSE "otpExpiresAt" END,
        "otpVerifiedAt"=CASE WHEN $5 THEN NULL ELSE "otpVerifiedAt" END,updated_at=NOW()
        WHERE username=$1`,[account.username,canonicalId,email,isActive,needsPassword,passwordHash]);
    } else {
      await client.query(`INSERT INTO public.app_user(username,employee_id,email,"passwordHash",role,is_active,first_login,must_change_password)
        VALUES($1,$2,$1,$3,'employee',$4,TRUE,TRUE)`,[email,canonicalId,passwordHash,isActive]);
    }
    await client.query('COMMIT');
    return {created:!account,passwordReset:needsPassword,employeeId:canonicalId,email,username:account?.username ?? email};
  } catch(error) {
    await client.query('ROLLBACK');throw error;
  } finally {client.release();}
}

export async function saveAccountPassword(pool, username, passwordHash, { firstLoginOnly=false }={}) {
  const result=await pool.query(`UPDATE public.app_user SET "passwordHash"=$1,
    must_change_password=FALSE,first_login=FALSE,password_changed_at=NOW(),updated_at=NOW(),
    "otpHash"=NULL,"otpExpiresAt"=NULL,"otpAttempts"=0,"otpLastSentAt"=NULL,"otpVerifiedAt"=NULL
    WHERE username=$2 AND (NOT $3::boolean OR must_change_password=TRUE)
    RETURNING *`,[passwordHash,username,firstLoginOnly]);
  return normalizeAccount(result.rows[0]);
}
