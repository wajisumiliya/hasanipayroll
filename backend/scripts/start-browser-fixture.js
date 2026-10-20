// CI only: never accepts a production database URL.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import pg from 'pg';
import bcrypt from 'bcryptjs';
import { ensureApplicationSchema } from '../src/application-schema.js';

const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
assert.ok(['localhost','127.0.0.1'].includes(url.hostname));
assert.equal(url.pathname,'/hasani_bootstrap_test');
const bootstrap=new pg.Pool({connectionString:url.toString()});
await bootstrap.query('CREATE DATABASE hasani_browser_modules_test');
url.pathname='/hasani_browser_modules_test';
const pool=new pg.Pool({connectionString:url.toString()});
await pool.query(await readFile(new URL('../test/fixtures/neon-schema.sql',import.meta.url),'utf8'));
await ensureApplicationSchema(pool);
await pool.query(`INSERT INTO branches(id,name) VALUES('FIX_A','Fixture Branch');
  INSERT INTO employees(employee_id,name,branch_id,is_management_staff,new_ic_no,epf_no,socso_no,bank_account,bank_code)
  VALUES('FIX_E1','Fixture Employee','FIX_A',true,'900101011234','FIX-EPF','FIX-SOCSO','9876543210','RHB');
  INSERT INTO employee_salary_defaults(employee_id,basic_salary) VALUES('FIX_E1',2000);
  INSERT INTO payroll(id,employee_id,period)
  SELECT 'HIST-'||n,'FIX_E1',date '2000-01-01'+n FROM generate_series(1,1105) n;
  INSERT INTO branch_activity_logs(branch_id,action) VALUES('FIX_A','FIXTURE_LOGIN');
  INSERT INTO employee_requests(id,branch_id,name,designation,department,email,new_ic_no,bank_code,bank_account,address)
  VALUES('11111111-1111-4111-8111-111111111111','FIX_A','Fixture Request','','','fixture@example.test','','','','');
  INSERT INTO overtime_requests(id,employee_id,employee_name,branch_id,overtime_date,overtime_start,overtime_end,requested_minutes,reason,status,branch_approved_at,branch_approved_name)
  VALUES('22222222-2222-4222-8222-222222222222','FIX_E1','Fixture Employee','FIX_A','2026-10-01','18:00','19:00',60,'Fixture OT','pending_admin',now(),'Fixture Approver');`);
await pool.query(`INSERT INTO app_user(username,role,"passwordHash",is_active,first_login,must_change_password)
  VALUES('FIX_ADMIN','admin',$1,true,false,false)`,[await bcrypt.hash('browser-fixture-password',4)]);
await pool.end();
const backend=spawn(process.execPath,['src/server.js'],{
  cwd:new URL('../',import.meta.url),stdio:'inherit',env:{...process.env,
    DATABASE_URL:url.toString(),PORT:'3501',FRONTEND_URL:'http://localhost:3001',
    JWT_SECRET:'local-browser-fixture-signing-secret-only-2026',
    ADMIN_EMAIL:'',ADMIN_PASSWORD:'',FRN_BRANCH_PASSWORD:'',PLAY_REVIEWER_PASSWORD:'',
    DATA_API_JWT_PRIVATE_KEY:'',FIREBASE_SERVICE_ACCOUNT:'',FIREBASE_SERVICE_ACCOUNT_JSON:'',
  },
});
let stopping=false;
async function stop(){
  if(stopping)return;stopping=true;
  if(backend.exitCode===null){backend.kill('SIGTERM');await once(backend,'exit');}
  await bootstrap.query('DROP DATABASE hasani_browser_modules_test');
  await bootstrap.end();process.exit(0);
}
process.on('SIGTERM',()=>void stop());
process.on('SIGINT',()=>void stop());
backend.on('exit',code=>{if(!stopping){console.error('Fixture backend exited:',code);process.exit(1);}});
