import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import pg from 'pg';
import {ensureApplicationSchema} from '../src/application-schema.js';
import {dropFixtureDatabase} from './fixtures/database-cleanup.js';
import {buildLateReport} from '../src/late-report.js';

const oldId='HED-TEMP-022', newId='INTN-AMJ-1001';
const hash=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
test('employee ID maintenance preserves linked history and restores schema guards', {
  skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL,
},async t=>{
  const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['localhost','127.0.0.1'].includes(url.hostname));
  assert.equal(url.pathname,'/hasani_bootstrap_test');
  const bootstrap=new pg.Pool({connectionString:url.toString()});
  await bootstrap.query('CREATE DATABASE hasani_employee_rename_test');
  url.pathname='/hasani_employee_rename_test';
  const pool=new pg.Pool({connectionString:url.toString()});
  const client=await pool.connect();
  const script=await readFile(new URL('../scripts/rename-employee-id.sql',import.meta.url),'utf8');
  try {
    await client.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
    await ensureApplicationSchema(pool);
    await client.query(`ALTER TABLE public.attendance ADD CONSTRAINT attendance_employee_fk FOREIGN KEY(employee_id) REFERENCES employees(employee_id) ON UPDATE CASCADE ON DELETE CASCADE;
      ALTER TABLE public.employee_salary_defaults ADD CONSTRAINT employee_salary_defaults_employee_fk FOREIGN KEY(employee_id) REFERENCES employees(employee_id) ON UPDATE CASCADE ON DELETE CASCADE;
      ALTER TABLE public.app_user ADD CONSTRAINT app_users_employee_fk FOREIGN KEY(employee_id) REFERENCES employees(employee_id) ON UPDATE CASCADE ON DELETE SET NULL;
      ALTER TABLE public.payroll ADD CONSTRAINT payroll_employee_fk FOREIGN KEY(employee_id) REFERENCES employees(employee_id) ON UPDATE CASCADE ON DELETE CASCADE;
      ALTER TABLE public.employee_ea_forms ADD CONSTRAINT employee_ea_forms_employee_id_fkey FOREIGN KEY(employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE;
      CREATE VIEW public.rename_preview AS SELECT employee_id,basic_salary FROM payroll;
      CREATE FUNCTION public.rename_must_not_recalculate() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Business recalculation ran'; END $$;
      CREATE TRIGGER rename_recalculation_guard BEFORE UPDATE OF employee_id ON public.payroll FOR EACH ROW EXECUTE FUNCTION public.rename_must_not_recalculate();
      CREATE TRIGGER rename_already_disabled BEFORE UPDATE ON public.payroll FOR EACH ROW EXECUTE FUNCTION public.rename_must_not_recalculate();
      ALTER TABLE public.payroll DISABLE TRIGGER rename_already_disabled;`);
    await client.query(`INSERT INTO employees(employee_id,name,branch_id,joining_date,medical_leave_balance,medical_leave_opening_month)
      VALUES($1,'Fixture employee','A','2026-01-01',10,'2026-10-01');
      `,[oldId]);
    await client.query(`INSERT INTO employee_salary_defaults(employee_id,basic_salary,inc_details) VALUES($1,2050,'APR-26/50');
      `,[oldId]);
    await client.query(`INSERT INTO payroll(id,employee_id,period,basic_salary,elaun_kedatangan) VALUES('P9',$1,'2026-09-01',2000,100),('P10',$1,'2026-10-01',2050,0)`,[oldId]);
    await client.query(`INSERT INTO employee_ea_forms(employee_id,tax_year,form_data) VALUES($1,2026,'{"amount":2050}');
      `,[oldId]);
    await client.query(`INSERT INTO app_user(username,role,employee_id,"passwordHash") VALUES('original-login','employee',$1,'unchanged-password-hash')`,[oldId]);
    await client.query(`INSERT INTO daily_rosters(branch_id,employee_id,roster_date,assignment_type,shift_start,shift_end,break_minutes)
      VALUES('A',$1,'2026-10-01','SHIFT','09:00','18:00',60)`,[oldId]);
    await client.query(`INSERT INTO attendance(employee_id,branch_id,attendance_date,check_in,check_out,status)
      VALUES($1,'A','2026-10-01','09:10','18:00','Late')`,[oldId]);
    await client.query(`INSERT INTO employee_requests(branch_id,name,assigned_employee_id) VALUES('A','Fixture request',$1)`,[oldId]);
    await client.query(`INSERT INTO app_private.employee_penguin_pets(employee_id,nickname) VALUES($1,'Keep nickname')`,[oldId]);
    await client.query(`INSERT INTO app_private.employee_photos(employee_id,content_type,photo_bytes) VALUES($1,'image/png',decode('89504e47','hex'))`,[oldId]);
    const event={date:'2026-10-01',type:'arrival',minutes:10,scheduled:'09:00:00',actual:'09:10'};
    const fingerprint=hash({branch_id:'A',employee_id:oldId,...event});
    await client.query(`INSERT INTO app_private.late_report_reviews(branch_id,employee_id,event_date,event_type,event_fingerprint,event_snapshot,status,reason_code,reason,reviewed_by)
      VALUES('A',$1,'2026-10-01','arrival',$2,$3,'approved','transport','Train delayed','Original reviewer')`,
      [oldId,fingerprint,JSON.stringify({...event,fingerprint})]);
    const guards=async()=>({
      constraints:(await client.query(`SELECT conrelid::regclass::text,conname,pg_get_constraintdef(oid) AS definition FROM pg_constraint WHERE confrelid='public.employees'::regclass ORDER BY conname`)).rows,
      triggers:(await client.query(`SELECT tgrelid::regclass::text,tgname,tgenabled FROM pg_trigger WHERE NOT tgisinternal ORDER BY tgrelid::regclass::text,tgname`)).rows,
    });
    const before=await guards();
    const oldPayroll=(await client.query('SELECT to_jsonb(p)-\'employee_id\' AS row FROM payroll p ORDER BY id')).rows;
    const oldDefaults=(await client.query('SELECT to_jsonb(d)-\'employee_id\' AS row FROM employee_salary_defaults d')).rows;
    await t.test('existing destination aborts every change',async()=>{
      await client.query(`INSERT INTO employees(employee_id,name) VALUES($1,'Existing destination')`,[newId]);
      try { await assert.rejects(client.query(script),/already has records/); }
      finally { await client.query('ROLLBACK'); }
      assert.equal((await client.query('SELECT count(*)::int AS n FROM payroll WHERE employee_id=$1',[oldId])).rows[0].n,2);
      assert.deepEqual(await guards(),before);
      await client.query('DELETE FROM employees WHERE employee_id=$1',[newId]);
    });
    await t.test('unsupported review signatures stop the rename without moving data',async()=>{
      await client.query("UPDATE app_private.late_report_reviews SET event_fingerprint=repeat('a',64) WHERE employee_id=$1",[oldId]);
      try { await assert.rejects(client.query(script),/unsupported signature/); }
      finally { await client.query('ROLLBACK'); }
      assert.equal((await client.query('SELECT count(*)::int AS n FROM employees WHERE employee_id=$1',[oldId])).rows[0].n,1);
      assert.deepEqual(await guards(),before);
      await client.query('UPDATE app_private.late_report_reviews SET event_fingerprint=$1 WHERE employee_id=$2',[fingerprint,oldId]);
    });
    await t.test('one rename moves FKs, unprotected references and review signatures atomically',async()=>{
      await client.query(script);
      assert.equal((await client.query('SELECT count(*)::int AS n FROM employees WHERE employee_id=$1',[oldId])).rows[0].n,0);
      assert.equal((await client.query('SELECT count(*)::int AS n FROM employees WHERE employee_id=$1',[newId])).rows[0].n,1);
      assert.deepEqual((await client.query('SELECT to_jsonb(p)-\'employee_id\' AS row FROM payroll p ORDER BY id')).rows,oldPayroll);
      assert.deepEqual((await client.query('SELECT to_jsonb(d)-\'employee_id\' AS row FROM employee_salary_defaults d')).rows,oldDefaults);
      for(const table of ['payroll_increment_state','employee_mc_openings','employee_photos','employee_penguin_pets']) {
        assert.ok((await client.query(`SELECT count(*)::int AS n FROM app_private.${table} WHERE employee_id=$1`,[newId])).rows[0].n>0,table);
      }
      assert.equal((await client.query('SELECT assigned_employee_id FROM employee_requests')).rows[0].assigned_employee_id,newId);
      assert.equal((await client.query('SELECT employee_id FROM daily_rosters')).rows[0].employee_id,newId);
      assert.equal((await client.query('SELECT employee_id FROM rename_preview LIMIT 1')).rows[0].employee_id,newId);
      const account=(await client.query('SELECT username,"passwordHash",employee_id FROM app_user')).rows[0];
      assert.deepEqual(account,{username:'original-login',passwordHash:'unchanged-password-hash',employee_id:newId});
      const review=(await client.query('SELECT * FROM app_private.late_report_reviews')).rows[0];
      assert.equal(review.event_fingerprint,hash({branch_id:'A',employee_id:newId,...event}));
      assert.equal(review.event_snapshot.employee_id_rename.previous_fingerprint,fingerprint);
      assert.equal(review.reason,'Train delayed');
      const attendance=(await client.query('SELECT *,attendance_date::text FROM attendance')).rows;
      const daily=(await client.query('SELECT *,roster_date::text FROM daily_rosters')).rows;
      const report=buildLateReport({attendance,daily,monthly:[],employees:[],reviews:[{...review,event_date:'2026-10-01'}],year:2026,month:10,minimum:0,includeApprovedArrivals:true});
      assert.equal(report.reports[0].events[0].review.status,'approved');
      assert.deepEqual(await guards(),before);
    });
    await t.test('a repeated run fails safely without losing renamed history',async()=>{
      try { await assert.rejects(client.query(script),/Source employee/); }
      finally { await client.query('ROLLBACK'); }
      assert.equal((await client.query('SELECT count(*)::int AS n FROM payroll WHERE employee_id=$1',[newId])).rows[0].n,2);
      assert.deepEqual(await guards(),before);
    });
    await t.test('other signed decisions require explicit support before another rename',async()=>{
      await client.query('CREATE TABLE app_private.early_out_decisions(employee_id text,event_fingerprint text)');
      await client.query("INSERT INTO app_private.early_out_decisions VALUES($1,repeat('b',64))",[newId]);
      const another=script.replace("('HED-TEMP-022', 'INTN-AMJ-1001')", "('INTN-AMJ-1001', 'INTN-AMJ-1002')");
      try { await assert.rejects(client.query(another),/Signed records/); }
      finally { await client.query('ROLLBACK'); }
      assert.equal((await client.query('SELECT count(*)::int AS n FROM payroll WHERE employee_id=$1',[newId])).rows[0].n,2);
      assert.deepEqual(await guards(),before);
    });
  } finally {
    await client.query('ROLLBACK');client.release();await pool.end();
    await dropFixtureDatabase(bootstrap,'hasani_employee_rename_test');await bootstrap.end();
  }
});
