import assert from "node:assert/strict";
import test from "node:test";
import {
  ensureAdminAccount,
  ensureFrnBranchAccounts,
  ensurePlayReviewerAccount,
} from "../src/startup-accounts.js";

const log = { log() {}, warn() {} };
const hashPassword = async (password) => `test-hash:${password}`;
const password = "fixture-password-123";

test("startup skips unconfigured accounts without touching the database", async () => {
  const pool = { query() { throw new Error("Unexpected query"); } };
  await ensureAdminAccount(pool, { log });
  await ensureFrnBranchAccounts(pool, { log });
  await ensurePlayReviewerAccount(pool, { log });
});

test("startup rejects weak bootstrap passwords before touching the database", async () => {
  const pool = { query() { throw new Error("Unexpected query"); } };
  await assert.rejects(ensureAdminAccount(pool, { email: "admin@example.test", password: "short", log }), /ADMIN_PASSWORD/);
  await assert.rejects(ensureFrnBranchAccounts(pool, { password: "short", log }), /FRN_BRANCH_PASSWORD/);
  await assert.rejects(ensurePlayReviewerAccount(pool, { password: "short", log }), /PLAY_REVIEWER_PASSWORD/);
});

test("existing admin credentials are never rehashed or overwritten at startup", async () => {
  let queries = 0;
  const pool = { async query() { queries++; return { rows: [{ username: "ADMIN" }] }; } };
  await ensureAdminAccount(pool, {
    email: "admin@example.test", password, log,
    hashPassword() { throw new Error("Existing password must not be rehashed"); },
  });
  assert.equal(queries, 1);
});

test("all startup account paths work with the imported Neon schema", {
  skip: !process.env.BOOTSTRAP_TEST_DATABASE_URL,
}, async (t) => {
  const url = new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  // This test owns and replaces its fixture tables. Never accept a production
  // URL; CI supplies a dedicated local Postgres service and database.
  assert.ok(["localhost", "127.0.0.1"].includes(url.hostname));
  assert.equal(url.pathname, "/hasani_bootstrap_test");
  const { default: pg } = await import("pg");
  const pool = new pg.Pool({ connectionString: url.toString() });
  try {
    await pool.query(`
      CREATE TABLE public.employees (employee_id text PRIMARY KEY);
      CREATE TABLE public.app_user (
        username text PRIMARY KEY,
        role text NOT NULL CHECK (role IN ('admin', 'branch', 'employee')),
        branch_id text, employee_id text REFERENCES public.employees(employee_id),
        display_name text NOT NULL DEFAULT '', is_active boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
        first_login boolean NOT NULL DEFAULT true, email text, "passwordHash" text,
        must_change_password boolean NOT NULL DEFAULT false, password_changed_at timestamptz,
        temporary_password_expires_at timestamptz, "otpHash" text, "otpExpiresAt" timestamptz,
        "otpAttempts" integer NOT NULL DEFAULT 0, "otpLastSentAt" timestamptz, "otpVerifiedAt" timestamptz
      );
    `);
    const adminOptions = { email: "admin@example.test", password, hashPassword, log };
    const branchOptions = { password, hashPassword, log };
    const reviewOptions = {
      username: "googleplayreviewer", email: "reviewer@example.test",
      employeeId: "PLAY_REVIEWER", password, hashPassword, log,
    };
    await t.test("creates an admin without an id or camelCase metadata columns", async () => {
      await ensureAdminAccount(pool, adminOptions);
      const { rows: [admin] } = await pool.query("SELECT * FROM public.app_user WHERE username = 'ADMIN'");
      assert.equal(admin.role, "admin");
      assert.equal(admin.passwordHash, `test-hash:${password}`);
      assert.equal(admin.first_login, false);
      assert.equal(admin.must_change_password, false);
      assert.ok(admin.password_changed_at);
    });
    await t.test("creates branch accounts and preserves a changed password and disabled state", async () => {
      await ensureFrnBranchAccounts(pool, branchOptions);
      await pool.query(`UPDATE public.app_user SET "passwordHash" = 'user-changed-hash', is_active = false WHERE username = 'HBSPFRN'`);
      await ensureFrnBranchAccounts(pool, branchOptions);
      const { rows: [branch] } = await pool.query("SELECT * FROM public.app_user WHERE username = 'HBSPFRN'");
      assert.equal(branch.passwordHash, "user-changed-hash");
      assert.equal(branch.is_active, false);
      assert.equal(branch.role, "branch");
      assert.equal((await pool.query("SELECT * FROM public.app_user WHERE role = 'branch'")).rowCount, 10);
    });
    await t.test("reviewer inserts and updates respect the employee foreign key", async () => {
      await ensurePlayReviewerAccount(pool, reviewOptions);
      let { rows: [reviewer] } = await pool.query("SELECT * FROM public.app_user WHERE username = 'googleplayreviewer'");
      assert.equal(reviewer.employee_id, null);
      assert.equal(reviewer.role, "employee");
      await pool.query("INSERT INTO public.employees(employee_id) VALUES ('PLAY_REVIEWER')");
      await ensurePlayReviewerAccount(pool, reviewOptions);
      ({ rows: [reviewer] } = await pool.query("SELECT * FROM public.app_user WHERE username = 'googleplayreviewer'"));
      assert.equal(reviewer.employee_id, "PLAY_REVIEWER");
      assert.equal(reviewer.must_change_password, false);
    });
    await t.test("restarting does not overwrite an existing admin password", async () => {
      await pool.query(`UPDATE public.app_user SET "passwordHash" = 'changed-admin-hash' WHERE username = 'ADMIN'`);
      await ensureAdminAccount(pool, adminOptions);
      const { rows: [admin] } = await pool.query("SELECT * FROM public.app_user WHERE username = 'ADMIN'");
      assert.equal(admin.passwordHash, "changed-admin-hash");
    });
  } finally {
    await pool.query("DROP TABLE IF EXISTS public.app_user; DROP TABLE IF EXISTS public.employees");
    await pool.end();
  }
});
