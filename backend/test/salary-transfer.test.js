import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import pg from 'pg';
import { ensureApplicationSchema } from '../src/application-schema.js';
import { dropFixtureDatabase } from './fixtures/database-cleanup.js';

test('salary transfer migration defaults bank accounts to RHB and preserves explicit choices', {
  skip: !process.env.BOOTSTRAP_TEST_DATABASE_URL,
}, async () => {
  const url = new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['localhost', '127.0.0.1'].includes(url.hostname));
  assert.equal(url.pathname, '/hasani_bootstrap_test');
  const bootstrap = new pg.Pool({ connectionString: url.toString() });
  await bootstrap.query('CREATE DATABASE hasani_salary_transfer_test');
  url.pathname = '/hasani_salary_transfer_test';
  const pool = new pg.Pool({ connectionString: url.toString() });
  try {
    await pool.query(await readFile(new URL('./fixtures/neon-schema.sql', import.meta.url), 'utf8'));
    await pool.query(`INSERT INTO employees(employee_id,name,bank_account) VALUES
      ('BANK','Bank employee','0012345'),('BLANK','No bank','   ')`);
    await ensureApplicationSchema(pool);
    await ensureApplicationSchema(pool);
    const method = async id => (await pool.query('SELECT salary_transfer_method FROM employees WHERE employee_id=$1', [id])).rows[0].salary_transfer_method;
    assert.equal(await method('BANK'), 'rhb');
    assert.equal(await method('BLANK'), null);
    await pool.query(`INSERT INTO employees(employee_id,name,bank_account) VALUES ('NEW','New bank','000123')`);
    assert.equal(await method('NEW'), 'rhb');
    await pool.query(`UPDATE employees SET salary_transfer_method='instant' WHERE employee_id='BLANK'`);
    assert.equal(await method('BLANK'), 'instant');
    await pool.query(`UPDATE employees SET salary_transfer_method='cash' WHERE employee_id='BANK'`);
    await pool.query(`UPDATE employees SET bank_account='987654' WHERE employee_id='BANK'`);
    assert.equal(await method('BANK'), 'cash');
    await pool.query(`UPDATE employees SET bank_account='' WHERE employee_id='NEW'`);
    assert.equal(await method('NEW'), null);
    await pool.query(`UPDATE employees SET bank_account='00123' WHERE employee_id='NEW'`);
    assert.equal(await method('NEW'), 'rhb');
    await pool.query(`UPDATE employees SET salary_transfer_method='Cash' WHERE employee_id='BLANK'`);
    assert.equal(await method('BLANK'), 'cash');
    await assert.rejects(pool.query(`UPDATE employees SET salary_transfer_method='other' WHERE employee_id='BANK'`), { code: '23514' });
  } finally {
    await pool.end();
    await dropFixtureDatabase(bootstrap, 'hasani_salary_transfer_test');
    await bootstrap.end();
  }
});
