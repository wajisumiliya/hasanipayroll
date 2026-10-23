import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import express from 'express';
import { ensureMysteryEggCampaign, installMysteryEggApi } from '../src/mystery-eggs.js';
import { sendDueMysteryEggReminder, REVEAL_REMINDER_TITLE, REVEAL_REMINDER_BODY } from '../src/mystery-egg-reminder.js';

test('rescheduled public hatch and reminder share one persisted deadline', {
  skip: !process.env.BOOTSTRAP_TEST_DATABASE_URL,
}, async () => {
  const url = new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['localhost', '127.0.0.1'].includes(url.hostname));
  assert.equal(url.pathname, '/hasani_bootstrap_test');
  const { default: pg } = await import('pg');
  const bootstrap = new pg.Pool({ connectionString: url.toString() });
  await bootstrap.query('CREATE DATABASE hasani_reveal_reminder_test');
  url.pathname = '/hasani_reveal_reminder_test';
  const pool = new pg.Pool({ connectionString: url.toString() });
  const calls = [];
  const push = async (_, input) => { calls.push(input); return { sent: 2, pushStatus: 'sent' }; };
  const run = now => sendDueMysteryEggReminder(pool, { now, push });
  let server;
  try {
    await pool.query(`CREATE SCHEMA app_private;
      CREATE TABLE app_notifications(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        title text, body text, notification_type text, audience text, employee_id text);`);
    await ensureMysteryEggCampaign(pool);
    await pool.query(await readFile(new URL('../migrations/20261023_mystery_egg_reveal_hour.sql', import.meta.url), 'utf8'));
    await ensureMysteryEggCampaign(pool); // Restart must preserve the changed timer.
    const app = express();
    installMysteryEggApi(app, { pool });
    server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/mystery-eggs`);
    assert.equal((await response.json()).egg.hatchAt, '2026-10-23T07:39:11.000Z');
    assert.equal((await run('2026-10-23T07:36:10.999Z')).reminders, 0);
    assert.equal((await run('2026-10-23T07:39:11Z')).reminders, 0); // No expired alerts.
    assert.equal((await run('2026-10-23T07:40:00Z')).reminders, 0);
    const concurrent = await Promise.all([run('2026-10-23T07:36:11Z'), run('2026-10-23T07:36:11Z')]);
    assert.deepEqual(concurrent.map(r => r.reminders).sort(), [0, 1]);
    assert.equal(calls.length, 1);
    assert.equal(calls[0].audience, 'all');
    assert.deepEqual(calls[0].employeeIds, []);
    const notifications = (await pool.query('SELECT * FROM app_notifications')).rows;
    assert.equal(notifications.length, 1);
    assert.equal(notifications[0].title, REVEAL_REMINDER_TITLE);
    assert.equal(notifications[0].body, REVEAL_REMINDER_BODY);
    assert.equal(notifications[0].audience, 'all');
    assert.equal(notifications[0].employee_id, null);
    assert.equal((await run('2026-10-23T07:38:00Z')).reminders, 0);

    // Inbox failure must roll back the claim, allowing a later tick to retry.
    await pool.query('TRUNCATE app_notifications, app_private.mystery_egg_reminders');
    await pool.query('ALTER TABLE app_notifications ADD CONSTRAINT test_reject CHECK (false)');
    await assert.rejects(run('2026-10-23T07:36:11Z'));
    assert.equal((await pool.query('SELECT * FROM app_private.mystery_egg_reminders')).rowCount, 0);
    await pool.query('ALTER TABLE app_notifications DROP CONSTRAINT test_reject');
    // Late startup inside the three-minute window still sends; failed push
    // cannot erase the inbox reminder or send it repeatedly.
    assert.equal((await sendDueMysteryEggReminder(pool, {
      now: '2026-10-23T07:38:00Z', push: async () => { throw new Error('offline'); },
    })).reminders, 1);
    assert.equal((await run('2026-10-23T07:38:10Z')).reminders, 0);
    assert.equal((await pool.query('SELECT * FROM app_notifications')).rowCount, 1);
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    await pool.end();
    await bootstrap.query('DROP DATABASE hasani_reveal_reminder_test WITH (FORCE)');
    await bootstrap.end();
  }
});
