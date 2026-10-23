import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { sendDueBirthdayWishes, birthdayMessage } from '../src/birthday-wishes.js';

test('birthday message uses the approved wording', () => {
  assert.equal(birthdayMessage('Amina'), '🎂 Happy Birthday, Amina! 🎉\nWishing you good health, happiness, and a wonderful year ahead. Thank you for being part of the Hasani Books family. Enjoy your special day!\n— From all of us at Hasani Books 💙');
});

test('automatic birthday wishes use Malaysia time and atomic annual deduplication', {
  skip: !process.env.BOOTSTRAP_TEST_DATABASE_URL,
}, async () => {
  const url = new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['localhost', '127.0.0.1'].includes(url.hostname));
  assert.equal(url.pathname, '/hasani_bootstrap_test');
  const { default: pg } = await import('pg');
  const bootstrap = new pg.Pool({ connectionString: url.toString() });
  await bootstrap.query('CREATE DATABASE hasani_birthday_test');
  url.pathname = '/hasani_birthday_test';
  const pool = new pg.Pool({ connectionString: url.toString() });
  const pushes = [];
  const push = async (_, input) => { pushes.push(input); return { pushConfigured: true }; };
  const run = now => sendDueBirthdayWishes(pool, { now, push });
  try {
    await pool.query(`CREATE SCHEMA app_private;
      CREATE TABLE employees(employee_id text PRIMARY KEY, name text, birthday date, is_active boolean);
      CREATE TABLE app_notifications(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        title text NOT NULL, body text NOT NULL, notification_type text, audience text, employee_id text);`);
    const migration = await readFile(new URL('../migrations/20261023_birthday_wishes.sql', import.meta.url), 'utf8');
    await pool.query(migration);
    await pool.query(migration);
    await pool.query(`INSERT INTO employees VALUES
      ('active','Amina','1990-10-23',true), ('inactive','Former','1991-10-23',false),
      ('tomorrow','Later','1992-10-24',true), ('unknown','Unknown',null,true),
      ('yesterday','Earlier','1992-10-22',true);`);
    assert.equal(await run('2026-10-23T00:59:59Z'), 0); // 08:59:59 Malaysia
    assert.deepEqual(await Promise.all([run('2026-10-23T01:00:00Z'), run('2026-10-23T01:00:00Z')]).then(a => a.sort()), [0, 1]);
    assert.equal(pushes.length, 1);
    assert.deepEqual(pushes[0].employeeIds, ['active']);
    const rows = (await pool.query('SELECT * FROM app_notifications')).rows;
    assert.equal(rows.length, 1);
    assert.equal(rows[0].body, birthdayMessage('Amina'));
    assert.equal(rows[0].audience, 'employee');
    assert.equal(rows[0].notification_type, 'birthday');
    assert.equal(await run('2026-10-23T15:59:59Z'), 0); // same day after restart
    assert.equal(await run('2026-10-23T16:00:00Z'), 0); // midnight next day in Malaysia
    assert.equal(await run('2026-10-24T04:00:00Z'), 1); // catch up at noon
    assert.equal(await run('2027-10-23T01:00:00Z'), 1); // next year permitted

    // A failed inbox insert must not consume the annual claim.
    await pool.query("ALTER TABLE app_notifications ADD CONSTRAINT reject_test CHECK (employee_id <> 'rollback')");
    await pool.query("INSERT INTO employees VALUES ('rollback','Retry','1990-10-25',true)");
    await assert.rejects(run('2026-10-25T01:00:00Z'));
    assert.equal((await pool.query("SELECT count(*)::int AS count FROM app_private.birthday_wishes WHERE employee_id='rollback'")).rows[0].count, 0);
    await pool.query('ALTER TABLE app_notifications DROP CONSTRAINT reject_test');
    assert.equal(await run('2026-10-25T02:00:00Z'), 1);

    // Push failure cannot lose the durable inbox notification or create duplicates.
    await pool.query("INSERT INTO employees VALUES ('offline','Offline','1990-10-26',true)");
    assert.equal(await sendDueBirthdayWishes(pool, { now: '2026-10-26T01:00:00Z', push: async () => { throw new Error('offline'); } }), 1);
    assert.equal(await run('2026-10-26T02:00:00Z'), 0);
    assert.equal((await pool.query("SELECT count(*)::int AS count FROM app_notifications WHERE employee_id='offline'")).rows[0].count, 1);
  } finally {
    await pool.end();
    await bootstrap.query('DROP DATABASE hasani_birthday_test WITH (FORCE)');
    await bootstrap.end();
  }
});
