import { readFile } from 'node:fs/promises';
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
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK'); throw error;
  } finally { client.release(); }
}
