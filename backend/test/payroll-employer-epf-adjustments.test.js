import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import pg from 'pg';
import express from 'express';
import {ensureApplicationSchema} from '../src/application-schema.js';
import {installDataApi,withDatabaseIdentity} from '../src/data-api.js';
import {dropFixtureDatabase} from './fixtures/database-cleanup.js';

test('locked employer EPF adjustments require an administrator, reason and transaction-bound audit', {skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL}, async()=>{
  const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['127.0.0.1','localhost'].includes(url.hostname));
  assert.equal(url.pathname,'/hasani_bootstrap_test');
  const bootstrap=new pg.Pool({connectionString:url.toString()});
  await bootstrap.query('CREATE DATABASE hasani_payroll_adjustment_test');
  url.pathname='/hasani_payroll_adjustment_test';
  const pool=new pg.Pool({connectionString:url.toString()});let server;
  try {
    await pool.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
    await pool.query('CREATE SCHEMA IF NOT EXISTS app_private');
    await pool.query(await readFile(new URL('./fixtures/protect-locked-payroll.sql',import.meta.url),'utf8'));
    await ensureApplicationSchema(pool);await ensureApplicationSchema(pool);
    await pool.query(`ALTER TABLE payroll ADD COLUMN is_paid boolean DEFAULT false, ADD COLUMN is_finalized boolean DEFAULT false,
      ADD COLUMN gross_salary numeric, ADD COLUMN total_deductions numeric, ADD COLUMN net_salary numeric;
      INSERT INTO employees(employee_id,name,address) VALUES ('BLK011','Local','LOCAL'),('F001','Foreign','FRN');
      INSERT INTO payroll(id,employee_id,period,basic_salary,epf_employee,epf_employer,is_published,is_paid,is_finalized) VALUES
      ('LOCKED','BLK011','2026-10-01',2500,0,0,true,true,true),
      ('FOREIGN','F001','2026-10-01',2000,40,40,true,false,false);`);
    const before=(await pool.query("SELECT to_jsonb(p) AS row FROM payroll p WHERE id='LOCKED'")).rows[0].row;
    const identities={admin:{username:'ADMIN',role:'admin'},employee:{username:'EMP',role:'employee',employee_id:'BLK011'},
      branch:{username:'A',role:'branch',branch_id:'A'},local:{username:'LOCAL_ADMIN',role:'admin',scope:'local'},
      foreign:{username:'FRN_ADMIN',role:'admin',scope:'foreign'},requests:{username:'REQUESTS',role:'admin',scope:'requests'}};
    const app=express();app.use(express.json());
    installDataApi(app,{pool,authenticate:(req,res,next)=>{const u=identities[req.get('Authorization')];
      if(!u)return res.sendStatus(401);req.user=u;req.auth={sub:u.username,app_metadata:{staff_scope:u.scope}};next();}});
    server=await new Promise(resolve=>{const s=app.listen(0,'127.0.0.1',()=>resolve(s));});
    const base=`http://127.0.0.1:${server.address().port}/api/data`;
    const params={p_payroll_id:'LOCKED',p_amount:100,p_expected_amount:0,p_reason:'BLK011 monthly employer EPF addition'};
    const rpc=(identity,body=params)=>fetch(base+'/rpc/adjust_payroll_employer_epf',{method:'POST',headers:{Authorization:identity,'Content-Type':'application/json'},body:JSON.stringify(body)});
    for(const identity of ['employee','branch','foreign','requests']) assert.equal((await rpc(identity)).status,403,identity);
    assert.equal((await rpc('admin',{...params,p_reason:''})).status,409);
    assert.equal((await rpc('admin',{...params,p_amount:-1})).status,409);
    assert.equal((await rpc('admin',{...params,p_amount:100.001})).status,409);
    const ordinary=await fetch(base+'/payroll?id=eq.LOCKED',{method:'PATCH',headers:{Authorization:'admin','Content-Type':'application/json'},body:JSON.stringify({epf_employer:100})});
    assert.equal(ordinary.status,409);
    assert.equal((await ordinary.json()).code,'P0001');
    const adjusted=await rpc('local');assert.equal(adjusted.status,200);
    const after=await adjusted.json();assert.equal(Number(after.epf_employer),100);
    for(const [key,value] of Object.entries(before)) if(!['epf_employer','updated_at'].includes(key))assert.deepEqual(after[key],value,key);
    const audit=(await pool.query('SELECT * FROM app_private.payroll_employer_epf_adjustments')).rows;
    assert.equal(audit.length,1);assert.equal(audit[0].adjusted_by,'LOCAL_ADMIN');
    assert.equal(Number(audit[0].old_amount),0);assert.equal(Number(audit[0].new_amount),100);
    assert.equal(audit[0].reason,params.p_reason);
    assert.equal((await rpc('admin')).status,409,'stale expected amount');
    assert.equal((await rpc('admin',{...params,p_expected_amount:100})).status,200,'idempotent retry');
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM app_private.payroll_employer_epf_adjustments')).rows[0].n,1);
    await assert.rejects(pool.query("UPDATE payroll SET is_published=false WHERE id='LOCKED'"),{code:'P0001'});
    await assert.rejects(pool.query("UPDATE payroll SET basic_salary=9999 WHERE id='LOCKED'"),{code:'P0001'});
    const claims={sub:'ADMIN',app_metadata:{app_role:'admin'}};
    await assert.rejects(withDatabaseIdentity(pool,claims,async client=>{
      await client.query("SELECT set_config('app.payroll_adjustment_id',$1,true)",[audit[0].id]);
      await client.query("UPDATE payroll SET epf_employer=200 WHERE id='LOCKED'");
    }),{code:'P0001'});
    await assert.rejects(withDatabaseIdentity(pool,claims,client=>client.query('INSERT INTO app_private.payroll_employer_epf_adjustments DEFAULT VALUES')),{code:'42501'});
    const foreign=await rpc('admin',{...params,p_payroll_id:'FOREIGN',p_expected_amount:40,p_amount:140});assert.equal(foreign.status,200);
    assert.equal(Number((await foreign.json()).epf_employee),40);
    // A failed payroll write rolls back its audit entry atomically.
    await pool.query(`CREATE FUNCTION public.reject_epf_test() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN IF NEW.epf_employer=999 THEN RAISE EXCEPTION 'fixture failure'; END IF; RETURN NEW; END $$;
      CREATE TRIGGER reject_epf_test AFTER UPDATE ON payroll FOR EACH ROW EXECUTE FUNCTION public.reject_epf_test();`);
    const count=(await pool.query('SELECT count(*)::int AS n FROM app_private.payroll_employer_epf_adjustments')).rows[0].n;
    assert.equal((await rpc('admin',{...params,p_expected_amount:100,p_amount:999})).status,503);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM app_private.payroll_employer_epf_adjustments')).rows[0].n,count);
    assert.equal(Number((await pool.query("SELECT epf_employer FROM payroll WHERE id='LOCKED'")).rows[0].epf_employer),100);
    // Concurrent corrections cannot both overwrite the same saved amount.
    const race=await Promise.all([150,160].map(amount=>rpc('admin',{...params,p_expected_amount:100,p_amount:amount})));
    assert.deepEqual(race.map(r=>r.status).sort(),[200,409]);
    // General financial edits use the same locked-row guarantees with full snapshots.
    const current=(await pool.query("SELECT to_jsonb(p) AS row FROM payroll p WHERE id='LOCKED'")).rows[0].row;
    const body={p_payroll_id:'LOCKED',p_expected:current,p_reason:'Correct salary, overtime and EPF',
      p_changes:{basic_salary:3000,overtime:100,bonus:25,epf_employee:50,gross_salary:3125.0000000001,total_deductions:50.00000000000001,net_salary:3075,remarks:'Reviewed correction'}};
    const general=(identity,payload=body)=>fetch(base+'/rpc/adjust_payroll',{method:'POST',headers:{Authorization:identity,'Content-Type':'application/json'},body:JSON.stringify(payload)});
    for(const identity of ['employee','branch','foreign','requests']) assert.equal((await general(identity)).status,403);
    for(const key of ['id','employee_id','period','is_published','is_paid','is_finalized','release_at','bank_account']) {
      assert.equal((await general('admin',{...body,p_changes:{[key]:null}})).status,409,key);
    }
    assert.equal((await general('admin',{...body,p_changes:{basic_salary:-1}})).status,409);
    assert.equal((await general('admin',{...body,p_changes:{basic_salary:3000.001}})).status,409);
    assert.equal((await general('admin',{...body,p_changes:{basic_salary:'NaN'}})).status,409);
    assert.equal((await general('admin',{...body,p_reason:''})).status,409);
    const corrected=await general('local');assert.equal(corrected.status,200);
    const row=await corrected.json();
    assert.equal(row.basic_salary,3000);assert.equal(row.overtime,100);assert.equal(row.bonus,'25');
    assert.equal(row.epf_employee,50);assert.equal(row.net_salary,3075);
    for(const key of ['id','employee_id','period','created_at','is_published','is_paid','is_finalized','release_at']) assert.deepEqual(row[key],current[key],key);
    const history=(await pool.query('SELECT * FROM app_private.payroll_adjustments')).rows;
    assert.equal(history.length,1);assert.equal(history[0].adjusted_by,'LOCAL_ADMIN');
    assert.equal(history[0].before_row.basic_salary,2500);assert.equal(history[0].after_row.basic_salary,3000);
    assert.equal((await general('admin')).status,409,'reject stale full snapshot');
    const noChange=await general('admin',{...body,p_expected:row,p_changes:{basic_salary:3000}});assert.equal(noChange.status,200);
    assert.equal((await pool.query('SELECT count(*)::int AS n FROM app_private.payroll_adjustments')).rows[0].n,1);
    await assert.rejects(pool.query("UPDATE payroll SET basic_salary=4000 WHERE id='LOCKED'"),{code:'P0001'});
    await assert.rejects(pool.query("UPDATE payroll SET is_published=false WHERE id='LOCKED'"),{code:'P0001'});
    await assert.rejects(withDatabaseIdentity(pool,claims,async client=>{
      await client.query("SELECT set_config('app.payroll_general_adjustment_id',$1,true)",[history[0].id]);
      await client.query("UPDATE payroll SET basic_salary=4000 WHERE id='LOCKED'");
    }),{code:'P0001'});
  }finally{
    if(server)await new Promise(resolve=>server.close(resolve));
    await pool.end();await dropFixtureDatabase(bootstrap,'hasani_payroll_adjustment_test');await bootstrap.end();
  }
});
