import assert from 'node:assert/strict';
import test from 'node:test';
import { normalizeAccount,findAccountByLogin,provisionEmployeeAccount,saveAccountPassword } from '../src/employee-accounts.js';

test('imported accounts use a real username token subject and snake-case metadata',()=>{
  const user=normalizeAccount({username:'FIX_E1',employee_id:'FIX_E1',role:'employee',is_active:true,must_change_password:true});
  assert.equal(user.id,'FIX_E1');assert.equal(user.employeeId,'FIX_E1');
  assert.equal(user.mustChangePassword,true);assert.equal(user.isActive,true);
});

test('employee account provisioning and password completion work with imported Neon columns',{
  skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL,
},async(t)=>{
  const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['localhost','127.0.0.1'].includes(url.hostname));
  assert.equal(url.pathname,'/hasani_bootstrap_test');
  const {default:pg}=await import('pg');
  const {default:bcrypt}=await import('bcryptjs');
  const bootstrap=new pg.Pool({connectionString:url.toString()});
  await bootstrap.query('CREATE DATABASE hasani_employee_login_test');
  url.pathname='/hasani_employee_login_test';
  const pool=new pg.Pool({connectionString:url.toString()});
  const initial='temporary-fixture-password';
  const hashPassword=()=>bcrypt.hash(initial,4);
  const options={employeeId:'FIX_E1',email:'one@example.test',isActive:true,resetPassword:false,hashPassword};
  try {
    await pool.query(`CREATE TABLE employees(employee_id text PRIMARY KEY);
      CREATE TABLE app_user(username text PRIMARY KEY,employee_id text REFERENCES employees(employee_id),email text,
      role text NOT NULL CHECK(role IN ('admin','branch','employee')), "passwordHash" text,
      is_active boolean NOT NULL DEFAULT true,first_login boolean NOT NULL DEFAULT true,
      must_change_password boolean NOT NULL DEFAULT false,password_changed_at timestamptz,updated_at timestamptz DEFAULT now(),
      "otpHash" text,"otpExpiresAt" timestamptz,"otpAttempts" integer DEFAULT 0,"otpLastSentAt" timestamptz,"otpVerifiedAt" timestamptz);
      INSERT INTO employees VALUES('FIX_E1'),('FIX_E2');
      INSERT INTO app_user(username,employee_id,role) VALUES('FIX_E1','FIX_E1','employee');`);
    await t.test('admin initializes only the requested missing hash and preserves the employee username',async()=>{
      const result=await provisionEmployeeAccount(pool,options);
      assert.equal(result.created,false);assert.equal(result.passwordReset,true);assert.equal(result.username,'FIX_E1');
      const row=(await pool.query("SELECT * FROM app_user WHERE username='FIX_E1'")).rows[0];
      assert.equal(await bcrypt.compare(initial,row.passwordHash),true);
      assert.equal(row.must_change_password,true);assert.equal(row.role,'employee');
    });
    await t.test('first-login completion saves a working password, clears setup and rejects replay',async()=>{
      const newHash=await bcrypt.hash('new-personal-fixture-password',4);
      const user=await saveAccountPassword(pool,'FIX_E1',newHash,{firstLoginOnly:true});
      assert.equal(user.id,'FIX_E1');assert.equal(user.mustChangePassword,false);assert.ok(user.passwordChangedAt);
      assert.equal(await bcrypt.compare('new-personal-fixture-password',user.passwordHash),true);
      assert.equal(await saveAccountPassword(pool,'FIX_E1','must-not-save',{firstLoginOnly:true}),null);
      assert.equal((await pool.query("SELECT first_login FROM app_user WHERE username='FIX_E1'")).rows[0].first_login,false);
    });
    await t.test('routine provisioning never overwrites a personal password',async()=>{
      await provisionEmployeeAccount(pool,{...options,hashPassword(){throw new Error('must not rehash');}});
      const row=(await pool.query("SELECT * FROM app_user WHERE username='FIX_E1'")).rows[0];
      assert.equal(await bcrypt.compare('new-personal-fixture-password',row.passwordHash),true);
      assert.equal(row.must_change_password,false);
    });
    await t.test('explicit reset requires password setup again and account conflicts are rolled back',async()=>{
      assert.equal((await provisionEmployeeAccount(pool,{...options,resetPassword:true})).passwordReset,true);
      await assert.rejects(provisionEmployeeAccount(pool,{...options,employeeId:'FIX_E2'}),/another account/);
      assert.equal((await pool.query("SELECT employee_id FROM app_user WHERE username='FIX_E1'")).rows[0].employee_id,'FIX_E1');
      assert.equal((await pool.query('SELECT count(*)::int AS n FROM app_user')).rows[0].n,1);
    });
    await t.test('creates an employee without an id column or uppercase role',async()=>{
      const result=await provisionEmployeeAccount(pool,{...options,employeeId:'FIX_E2',email:'two@example.test'});
      assert.equal(result.created,true);assert.equal(result.username,'two@example.test');
    });
    await t.test('exact username and email take priority over employee-ID aliases',async()=>{
      await pool.query(`INSERT INTO app_user(username,employee_id,email,role,"passwordHash")
        VALUES('ALIAS_E1','FIX_E1','alias@example.test','employee','alias-hash')`);
      assert.equal((await findAccountByLogin(pool,'alias_e1')).username,'ALIAS_E1');
      assert.equal((await findAccountByLogin(pool,'ALIAS@EXAMPLE.TEST')).username,'ALIAS_E1');
      assert.equal((await findAccountByLogin(pool,'FIX_E1')).username,'FIX_E1');
      assert.equal((await findAccountByLogin(pool,'one@example.test')).username,'FIX_E1');
      assert.equal(await findAccountByLogin(pool,'missing-login'),null);
    });

  } finally {
    await pool.end();await bootstrap.query('DROP DATABASE hasani_employee_login_test WITH (FORCE)');await bootstrap.end();
  }
});
