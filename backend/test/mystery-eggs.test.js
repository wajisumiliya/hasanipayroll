import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import { ensureMysteryEggCampaign, installMysteryEggApi } from '../src/mystery-eggs.js';

const start = new Date('2026-10-22T00:00:00Z');
const day = 86400000;
async function serve(pool, run) {
  const app = express();
  installMysteryEggApi(app, { pool });
  const server = await new Promise(resolve => {
    const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
  });
  try { await run(`http://127.0.0.1:${server.address().port}/api/mystery-eggs`); }
  finally { await new Promise(resolve => server.close(resolve)); }
}

test('public golden eggs hatch at exactly 72 server hours and expose only launch metadata', async () => {
  let now = new Date(start.getTime() + 3 * day - 1);
  const pool = { async query() { return { rows: [{ started_at: start, server_now: now }] }; } };
  await serve(pool, async url => {
    const before = await fetch(url);
    assert.equal(before.status, 200);
    assert.equal(before.headers.get('cache-control'), 'no-store');
    const { egg } = await before.json();
    assert.equal(egg.stage, 'egg');
    assert.equal(egg.hatchAt, '2026-10-25T00:00:00.000Z');
    assert.deepEqual(Object.keys(egg).sort(), ['hatchAt', 'serverNow', 'stage', 'startedAt']);
    now = new Date(start.getTime() + 3 * day);
    assert.equal((await (await fetch(url)).json()).egg.stage, 'chick');
    now = new Date(start.getTime() + 15 * day);
    assert.equal((await (await fetch(url)).json()).egg.stage, 'juvenile');
    now = new Date(start.getTime() + 45 * day);
    assert.equal((await (await fetch(url)).json()).egg.stage, 'adult');
    assert.equal((await fetch(url, { method: 'POST' })).status, 404);
  });
});

test('missing campaign or unavailable database never leaks details or invents a hatch date', async () => {
  for (const pool of [
    { async query() { return { rows: [] }; } },
    { async query() { throw new Error('private-connection-details'); } },
  ]) {
    await serve(pool, async url => {
      const response = await fetch(url);
      assert.equal(response.status, 503);
      assert.deepEqual(await response.json(), { ok: false, message: 'Surprise temporarily unavailable' });
    });
  }
});

test('campaign clock survives initialization twice and cannot be reset through the public API', {
  skip: !process.env.BOOTSTRAP_TEST_DATABASE_URL,
}, async () => {
  const url = new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['localhost', '127.0.0.1'].includes(url.hostname));
  assert.equal(url.pathname, '/hasani_bootstrap_test');
  const { default: pg } = await import('pg');
  const bootstrap = new pg.Pool({ connectionString: url.toString() });
  await bootstrap.query('CREATE DATABASE hasani_mystery_eggs_test');
  url.pathname = '/hasani_mystery_eggs_test';
  const pool = new pg.Pool({ connectionString: url.toString() });
  try {
    await pool.query('CREATE SCHEMA app_private');
    await ensureMysteryEggCampaign(pool);
    const first = await pool.query('SELECT started_at FROM app_private.mystery_egg_campaign');
    await ensureMysteryEggCampaign(pool);
    const second = await pool.query('SELECT started_at FROM app_private.mystery_egg_campaign');
    assert.equal(second.rowCount, 1);
    assert.equal(first.rows[0].started_at.toISOString(), second.rows[0].started_at.toISOString());
    await pool.query("UPDATE app_private.mystery_egg_campaign SET started_at = now() - interval '72 hours'");
    await ensureMysteryEggCampaign(pool);
    await serve(pool, async endpoint => {
      const login = (await (await fetch(endpoint)).json()).egg;
      const branch = (await (await fetch(endpoint + '?scope=branch')).json()).egg;
      assert.equal(login.stage, 'chick');
      assert.equal(branch.stage, 'egg');
      assert.equal(Date.parse(branch.hatchAt) - Date.parse(login.hatchAt), 3600000);
      assert.equal((await fetch(endpoint + '?scope=invalid')).status, 400);
      assert.equal((await fetch(endpoint, { method: 'DELETE' })).status, 404);
    });
  } finally {
    await pool.end();
    await bootstrap.query('DROP DATABASE hasani_mystery_eggs_test');
    await bootstrap.end();
  }
});
