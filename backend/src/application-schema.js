import { readFile } from 'node:fs/promises';
import { ensureMysteryEggCampaign } from './mystery-eggs.js';
const VERSION = '20261020_neon_application_api_v1';
export async function ensureApplicationSchema(pool) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT pg_advisory_xact_lock(hashtext('hasani-application-schema'))");
    await client.query('CREATE SCHEMA IF NOT EXISTS app_private');
    await client.query('REVOKE ALL ON SCHEMA app_private FROM PUBLIC');
    await client.query(`CREATE TABLE IF NOT EXISTS app_private.schema_migrations (
      version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now()
    )`);
    const existing = await client.query('SELECT 1 FROM app_private.schema_migrations WHERE version=$1', [VERSION]);
    if (!existing.rowCount) {
      let sql = await readFile(new URL('../migrations/20261020_neon_application_api.sql', import.meta.url), 'utf8');
      sql = sql.replace('\nBEGIN;\n', '\n').replace(/\nCOMMIT;\s*$/, '\n');
      await client.query(sql);
      await client.query('REVOKE ALL ON SCHEMA app_private FROM anon,authenticated');
      await client.query('REVOKE ALL ON ALL TABLES IN SCHEMA app_private FROM PUBLIC,anon,authenticated');
      await client.query('INSERT INTO app_private.schema_migrations(version) VALUES ($1)', [VERSION]);
    }
    const photoVersion = '20261020_neon_employee_photos_v1';
    const photoMigration = await client.query('SELECT 1 FROM app_private.schema_migrations WHERE version=$1', [photoVersion]);
    if (!photoMigration.rowCount) {
      await client.query(await readFile(new URL('../migrations/20261020_neon_employee_photos.sql', import.meta.url), 'utf8'));
      await client.query('INSERT INTO app_private.schema_migrations(version) VALUES ($1)', [photoVersion]);
    }
    const penguinVersion = '20261021_employee_penguin_pet_v1';
    const penguinMigration = await client.query('SELECT 1 FROM app_private.schema_migrations WHERE version=$1', [penguinVersion]);
    if (!penguinMigration.rowCount) {
      await client.query(await readFile(new URL('../migrations/20261021_employee_penguin_pet.sql', import.meta.url), 'utf8'));
      await client.query('INSERT INTO app_private.schema_migrations(version) VALUES ($1)', [penguinVersion]);
    }
    const birthdayVersion = '20261023_birthday_wishes_v1';
    const birthdayMigration = await client.query('SELECT 1 FROM app_private.schema_migrations WHERE version=$1', [birthdayVersion]);
    if (!birthdayMigration.rowCount) {
      await client.query(await readFile(new URL('../migrations/20261023_birthday_wishes.sql', import.meta.url), 'utf8'));
      await client.query('INSERT INTO app_private.schema_migrations(version) VALUES ($1)', [birthdayVersion]);
    }
    const anniversaryVersion = '20261023_anniversary_wishes_v1';
    const anniversaryMigration = await client.query('SELECT 1 FROM app_private.schema_migrations WHERE version=$1', [anniversaryVersion]);
    if (!anniversaryMigration.rowCount) {
      await client.query(await readFile(new URL('../migrations/20261023_anniversary_wishes.sql', import.meta.url), 'utf8'));
      await client.query('INSERT INTO app_private.schema_migrations(version) VALUES ($1)', [anniversaryVersion]);
    }
    await ensureMysteryEggCampaign(client);
    const revealVersion = '20261023_mystery_egg_reveal_hour_v1';
    const revealMigration = await client.query('SELECT 1 FROM app_private.schema_migrations WHERE version=$1', [revealVersion]);
    if (!revealMigration.rowCount) {
      await client.query(await readFile(new URL('../migrations/20261023_mystery_egg_reveal_hour.sql', import.meta.url), 'utf8'));
      await client.query('INSERT INTO app_private.schema_migrations(version) VALUES ($1)', [revealVersion]);
    }
    const lateReviewVersion = '20261026_late_report_reviews_v1';
    const lateReviewMigration = await client.query('SELECT 1 FROM app_private.schema_migrations WHERE version=$1', [lateReviewVersion]);
    if (!lateReviewMigration.rowCount) {
      await client.query(await readFile(new URL('../migrations/20261026_late_report_reviews.sql', import.meta.url), 'utf8'));
      await client.query('INSERT INTO app_private.schema_migrations(version) VALUES ($1)', [lateReviewVersion]);
    }
    const leaveBalanceVersion = '20261031_employee_leave_balances_v1';
    const leaveBalanceMigration = await client.query('SELECT 1 FROM app_private.schema_migrations WHERE version=$1', [leaveBalanceVersion]);
    if (!leaveBalanceMigration.rowCount) {
      await client.query(await readFile(new URL('../migrations/20261031_employee_leave_balances.sql', import.meta.url), 'utf8'));
      await client.query('INSERT INTO app_private.schema_migrations(version) VALUES ($1)', [leaveBalanceVersion]);
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK'); throw error;
  } finally { client.release(); }
}

// Replaces the former provider's pg_cron job. The SQL function locks pending
// schedules with SKIP LOCKED, so overlapping Render instances are safe.
export function startPayslipReleaseWorker(pool) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try { await pool.query('SELECT public.release_due_payslips()'); }
    catch (error) { console.error('PAYSLIP RELEASE ERROR:', error.code || 'release_error'); }
    finally { running = false; }
  };
  void tick();
  const timer = setInterval(tick, 60000);
  timer.unref();
  return () => clearInterval(timer);
}
