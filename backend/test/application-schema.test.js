import assert from 'node:assert/strict';
import test from 'node:test';
import { ensureApplicationSchema } from '../src/application-schema.js';

test('application startup applies the penguin migration once and records it', async () => {
  const applied = new Set();
  const executed = [];
  const client = {
    async query(sql, values = []) {
      executed.push(sql);
      if (sql.startsWith('SELECT 1 FROM app_private.schema_migrations')) {
        return { rowCount: applied.has(values[0]) ? 1 : 0, rows: [] };
      }
      if (sql.startsWith('INSERT INTO app_private.schema_migrations')) {
        applied.add(values[0]);
      }
      return { rowCount: 1, rows: [] };
    },
    release() {},
  };
  const pool = { async connect() { return client; } };

  await ensureApplicationSchema(pool);

  assert.ok(applied.has('20261026_late_report_reviews_v1'));
  assert.ok(executed.some(sql => sql.includes('CREATE TABLE IF NOT EXISTS app_private.late_report_reviews')));
  const penguinVersion = '20261021_employee_penguin_pet_v1';
  assert.ok(applied.has(penguinVersion));
  assert.ok(executed.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS app_private.employee_penguin_pets')));
  assert.ok(applied.has('20261023_birthday_wishes_v1'));
  assert.ok(applied.has('20261023_anniversary_wishes_v1'));
  assert.ok(applied.has('20261023_mystery_egg_reveal_hour_v1'));
  assert.ok(executed.some((sql) => sql.includes("timestamptz '2026-10-23 07:39:11+00'")));
  assert.ok(executed.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS app_private.anniversary_wishes')));
  assert.ok(executed.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS app_private.birthday_wishes')));

  executed.length = 0;
  await ensureApplicationSchema(pool);
  assert.ok(!executed.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS app_private.employee_penguin_pets')));
  assert.ok(!executed.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS app_private.birthday_wishes')));
  assert.ok(!executed.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS app_private.anniversary_wishes')));
  assert.ok(!executed.some((sql) => sql.includes('UPDATE app_private.mystery_egg_campaign')));
  assert.ok(!executed.some(sql => sql.includes('CREATE TABLE IF NOT EXISTS app_private.late_report_reviews')));
});
