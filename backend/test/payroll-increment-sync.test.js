import {dropFixtureDatabase} from './fixtures/database-cleanup.js';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import pg from 'pg';
import {ensureApplicationSchema} from '../src/application-schema.js';
import {withDatabaseIdentity} from '../src/data-api.js';
import {buildIncrementReport} from '../src/increment-report.js';

test('saved payroll maintains inc_details atomically and preserves eligibility', {skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL}, async t=>{
  const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['localhost','127.0.0.1'].includes(url.hostname));assert.equal(url.pathname,'/hasani_bootstrap_test');
  const bootstrap=new pg.Pool({connectionString:url.toString()});
  await bootstrap.query('CREATE DATABASE hasani_payroll_increment_test');url.pathname='/hasani_payroll_increment_test';
  const pool=new pg.Pool({connectionString:url.toString()});
  try {
    await pool.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
    // Existing current payroll is synchronized at migration without rewriting it.
    await pool.query("INSERT INTO employees(employee_id,name,joining_date) VALUES('EXISTING','Existing','2026-01-01'); INSERT INTO employee_salary_defaults(employee_id,inc_details) VALUES('EXISTING','APR-26/50'); INSERT INTO payroll(id,employee_id,period,basic_salary) VALUES('EXISTING9','EXISTING','2026-09-01',2000),('EXISTING10','EXISTING','2026-10-01',2050)");
    await ensureApplicationSchema(pool);await ensureApplicationSchema(pool);
    const details=async id=>(await pool.query('SELECT inc_details FROM employee_salary_defaults WHERE employee_id=$1',[id])).rows[0].inc_details;
    const seed=async(id,inc='APR-26/50',joined='2026-01-01')=>{
      await pool.query('INSERT INTO employees(employee_id,name,branch_id,joining_date,is_active) VALUES($1,$1,\'A\',$2,true)',[id,joined]);
      await pool.query('INSERT INTO employee_salary_defaults(employee_id,basic_salary,elaun_kedatangan,inc_details) VALUES($1,2000,200,$2)',[id,inc]);
    };
    const save=async(id,month,basic,attendance=200,client=pool)=>client.query(`INSERT INTO payroll(id,employee_id,period,basic_salary,elaun_kedatangan)
      VALUES($1,$2,$3,$4,$5) ON CONFLICT(employee_id,period) DO UPDATE SET basic_salary=EXCLUDED.basic_salary,elaun_kedatangan=EXCLUDED.elaun_kedatangan`,[id+month,id,month,basic,attendance]);
    await t.test('migration synchronizes latest existing records once',async()=>{
      assert.equal(await details('EXISTING'),'OCT-26/50');
      assert.equal((await pool.query("SELECT basic_salary::text FROM payroll WHERE id='EXISTING10'")).rows[0].basic_salary,'2050.00');
    });
    await t.test('authenticated admin save writes OCT-26/50, not repeated cumulative amounts',async()=>{
      await seed('ADMIN');await save('ADMIN','2026-09-01',2000);
      await withDatabaseIdentity(pool,{sub:'ADMIN',role:'authenticated',app_metadata:{app_role:'admin'}},client=>save('ADMIN','2026-10-01',2050,200,client));
      assert.equal(await details('ADMIN'),'OCT-26/50');
      await Promise.all([save('ADMIN','2026-10-01',2050),save('ADMIN','2026-10-01',2050)]);
      assert.equal(await details('ADMIN'),'OCT-26/50');
      assert.equal((await pool.query("SELECT count(*)::int AS n FROM app_private.payroll_increment_state WHERE employee_id='ADMIN' AND period='2026-10-01'")).rows[0].n,1);
    });
    await t.test('joining-date fallback remains eligible after the automatic last increment update',async()=>{
      await seed('JOIN',null,'2026-04-15');await save('JOIN','2026-09-01',2000);await save('JOIN','2026-10-01',2050);
      assert.equal(await details('JOIN'),'OCT-26/50');
      const e=(await pool.query("SELECT e.*,d.inc_details,to_jsonb(s) AS increment_snapshot FROM employees e JOIN employee_salary_defaults d USING(employee_id) LEFT JOIN app_private.payroll_increment_state s ON s.employee_id=e.employee_id AND s.period='2026-10-01' WHERE e.employee_id='JOIN'")).rows[0];
      const payroll=(await pool.query("SELECT *,period::text FROM payroll WHERE employee_id='JOIN'")).rows;
      const report=buildIncrementReport({employees:[e],payroll,year:2026,month:10,mode:'comparison'});
      assert.equal(report.reports[0].eligible,true);assert.equal(report.reports[0].result,'Received');assert.equal(report.reports[0].inc_details,'OCT-26/50');
      assert.equal(buildIncrementReport({employees:[e],payroll,year:2026,month:10,mode:'eligible'}).reports.length,1);
    });
    await t.test('correction removes an automatically recorded raise; deleting current payroll restores prior metadata',async()=>{
      await seed('CORRECT');await save('CORRECT','2026-09-01',2000);await save('CORRECT','2026-10-01',2050);
      assert.equal(await details('CORRECT'),'OCT-26/50');
      await save('CORRECT','2026-10-01',2000);assert.equal(await details('CORRECT'),'APR-26/50');
      await save('CORRECT','2026-10-01',2075.5);assert.equal(await details('CORRECT'),'OCT-26/75.5');
      await pool.query("DELETE FROM payroll WHERE employee_id='CORRECT' AND period='2026-10-01'");assert.equal(await details('CORRECT'),'APR-26/50');
    });
    await t.test('first payroll and partial-pay restoration never fabricate an increment',async()=>{
      await seed('FIRST',null,'2026-04-15');await save('FIRST','2026-10-01',2050);assert.equal(await details('FIRST'),null);
      await seed('RESTORE');await save('RESTORE','2026-08-01',2000);await save('RESTORE','2026-09-01',1000,0);await save('RESTORE','2026-10-01',2000);
      assert.equal(await details('RESTORE'),'APR-26/50');
      await save('RESTORE','2026-10-01',2050,0);assert.equal(await details('RESTORE'),'OCT-26/50');
    });
    await t.test('historical saves do not overwrite a later maintained increment',async()=>{
      await seed('FUTURE','JAN-27/100');await save('FUTURE','2026-09-01',2000);await save('FUTURE','2026-10-01',2050);
      assert.equal(await details('FUTURE'),'JAN-27/100');
    });
    await t.test('moving a payroll record to another month updates the recorded increment month',async()=>{
      await seed('MOVE');await save('MOVE','2026-09-01',2000);await save('MOVE','2026-10-01',2050);
      await pool.query("UPDATE payroll SET period='2026-11-01' WHERE employee_id='MOVE' AND period='2026-10-01'");
      assert.equal(await details('MOVE'),'NOV-26/50');
    });
    await t.test('payroll rollback also rolls back the default update and eligibility snapshot',async()=>{
      await seed('ROLLBACK');await save('ROLLBACK','2026-09-01',2000);
      const client=await pool.connect();try{await client.query('BEGIN');await save('ROLLBACK','2026-10-01',2050,200,client);await client.query('ROLLBACK');}finally{client.release();}
      assert.equal(await details('ROLLBACK'),'APR-26/50');
      assert.equal((await pool.query("SELECT count(*)::int AS n FROM app_private.payroll_increment_state WHERE employee_id='ROLLBACK' AND period='2026-10-01'")).rows[0].n,0);
    });
  } finally {await pool.end();await dropFixtureDatabase(bootstrap, 'hasani_payroll_increment_test');await bootstrap.end();}
});
