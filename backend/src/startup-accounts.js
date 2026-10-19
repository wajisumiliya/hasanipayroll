// Account bootstrap for the imported payroll schema. username is the primary
// key; auth metadata uses snake_case except the existing passwordHash column.
function requirePassword(password, setting) {
  if (password.length < 12) {
    throw new Error(`${setting} must contain at least 12 characters.`);
  }
}

export async function ensureAdminAccount(pool, { email, password, hashPassword, log = console }) {
  email = String(email || "").trim().toLowerCase();
  password = String(password || "");
  if (!email || !password) {
    log.warn("Admin account bootstrap skipped: ADMIN_EMAIL or ADMIN_PASSWORD is not set.");
    return;
  }
  requirePassword(password, "ADMIN_PASSWORD");
  const existing = await pool.query(
    `SELECT username FROM public.app_user
     WHERE UPPER(TRIM(username)) = 'ADMIN'
        OR LOWER(TRIM(COALESCE(email, ''))) = $1
     LIMIT 1`,
    [email],
  );
  if (existing.rows.length > 0) {
    log.log("Admin account already exists; startup password left unchanged.");
    return;
  }
  const passwordHash = await hashPassword(password);
  await pool.query(
    `INSERT INTO public.app_user (
       username, email, "passwordHash", role, is_active, first_login,
       must_change_password, password_changed_at
     ) VALUES ('ADMIN', $1, $2, 'admin', TRUE, FALSE, FALSE, NOW())
     ON CONFLICT (username) DO NOTHING`,
    [email, passwordHash],
  );
  log.log("Admin account bootstrap complete.");
}

export async function ensureFrnBranchAccounts(pool, { password, hashPassword, log = console }) {
  password = String(password || "");
  if (!password) {
    log.warn("FRN branch account bootstrap skipped: FRN_BRANCH_PASSWORD is not set.");
    return;
  }
  requirePassword(password, "FRN_BRANCH_PASSWORD");
  const usernames = [
    "HPSPFRN", "HBSPFRN", "HBAMJFRN", "HBASFRN", "HBASTANAFRN",
    "HBGURUNFRN", "HBJITRAFRN", "HBPERAIFRN", "HBKULIMFRN", "HBLKWFRN",
  ];
  const passwordHash = await hashPassword(password);
  for (const username of usernames) {
    const email = `${username.toLowerCase()}@hasani.local`;
    await pool.query(
      `INSERT INTO public.app_user (
         username, email, "passwordHash", role, is_active, first_login,
         must_change_password
       ) SELECT $1, $2, $3, 'branch', TRUE, FALSE, FALSE
       WHERE NOT EXISTS (
         SELECT 1 FROM public.app_user
         WHERE UPPER(TRIM(username)) = $1
            OR LOWER(TRIM(COALESCE(email, ''))) = $2
       )
       ON CONFLICT (username) DO NOTHING`,
      [username, email, passwordHash],
    );
  }
  log.log(`FRN branch account bootstrap complete: ${usernames.length}`);
}

export async function ensurePlayReviewerAccount(pool, {
  username, email, employeeId, password, hashPassword, log = console,
}) {
  password = String(password || "");
  if (!password) {
    log.warn("Google Play reviewer account skipped: PLAY_REVIEWER_PASSWORD is not set.");
    return;
  }
  requirePassword(password, "PLAY_REVIEWER_PASSWORD");
  const passwordHash = await hashPassword(password);
  // The review account uses synthetic data. Link its employee only when that
  // employee exists, respecting the imported employee_id foreign key. Reviewer
  // identity is also recognized by the configured username/email in the API.
  const values = [employeeId, username, email, passwordHash];
  const updated = await pool.query(
    `UPDATE public.app_user
     SET employee_id = (SELECT employee_id FROM public.employees WHERE employee_id = $1),
         email = $3, "passwordHash" = $4, role = 'employee', is_active = TRUE,
         first_login = FALSE, must_change_password = FALSE,
         password_changed_at = NOW(), updated_at = NOW()
     WHERE UPPER(TRIM(COALESCE(employee_id, ''))) = $1
        OR LOWER(TRIM(username)) = $2
        OR LOWER(TRIM(COALESCE(email, ''))) = $3
     RETURNING username`,
    values,
  );
  if (updated.rowCount === 0) {
    await pool.query(
      `INSERT INTO public.app_user (
         employee_id, username, email, "passwordHash", role, is_active,
         first_login, must_change_password, password_changed_at
       ) VALUES (
         (SELECT employee_id FROM public.employees WHERE employee_id = $1),
         $2, $3, $4, 'employee', TRUE, FALSE, FALSE, NOW()
       ) ON CONFLICT (username) DO NOTHING`,
      values,
    );
  }
  log.log("Google Play reviewer account synchronized.");
}
