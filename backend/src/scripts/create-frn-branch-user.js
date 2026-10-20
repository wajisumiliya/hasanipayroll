import "dotenv/config";
import bcrypt from "bcryptjs";
import pg from "pg";

// Updates only the ten existing branch FRN accounts in the Neon app_user schema.
// The password must be provided at execution time; never commit it to Git.
const usernames = [
  "HPSPFRN", "HBSPFRN", "HBAMJFRN", "HBASFRN", "HBASTANAFRN",
  "HBGURUNFRN", "HBJITRAFRN", "HBPERAIFRN", "HBKULIMFRN", "HBLKWFRN",
];
const password = process.env.FRN_BRANCH_PASSWORD;
if (!password || password.length < 12) {
  throw new Error("Set FRN_BRANCH_PASSWORD to a password of at least 12 characters.");
}
if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL is required.");
}
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const client = await pool.connect();
try {
  await client.query("BEGIN");
  const existing = await client.query(
    'SELECT username FROM public.app_user WHERE username = ANY($1::text[]) AND LOWER(role) = $2 FOR UPDATE',
    [usernames, "branch"],
  );
  const found = new Set(existing.rows.map((row) => row.username));
  const missing = usernames.filter((username) => !found.has(username));
  if (missing.length) {
    throw new Error(`Refusing partial FRN update; missing branch accounts: ${missing.join(", ")}`);
  }
  const hash = await bcrypt.hash(password, 12);
  const result = await client.query(
    `UPDATE public.app_user
       SET "passwordHash" = $1, is_active = TRUE,
           must_change_password = FALSE, first_login = FALSE,
           temporary_password_expires_at = NULL,
           password_changed_at = NOW(), updated_at = NOW()
       WHERE username = ANY($2::text[]) AND LOWER(role) = 'branch'
       RETURNING username`,
    [hash, usernames],
  );
  if (result.rowCount !== usernames.length) {
    throw new Error(`Expected ${usernames.length} accounts; updated ${result.rowCount}`);
  }
  await client.query("COMMIT");
  console.log(`Activated and updated ${result.rowCount} FRN branch accounts; password change not required.`);
} catch (error) {
  await client.query("ROLLBACK");
  throw error;
} finally {
  client.release();
  await pool.end();
}
