import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {ensureApplicationSchema} from '../src/application-schema.js';
import {drainPayslipNotifications} from '../src/payslip-notifications.js';
import {installNotificationApi} from '../src/notification-api.js';
import {dropFixtureDatabase} from './fixtures/database-cleanup.js';

const fixture = process.env.BOOTSTRAP_TEST_DATABASE_URL;
test('payslip notifications follow actual publication, are scoped, durable and deduplicated', {skip:!fixture}, async t=>{
  const {default:pg}=await import('pg');
  const url=new URL(fixture);
  assert.ok(['localhost','127.0.0.1'].includes(url.hostname));assert.equal(url.pathname,'/hasani_bootstrap_test');
  const bootstrap=new pg.Pool({connectionString:url.toString()});
  await bootstrap.query('CREATE DATABASE hasani_payslip_notice_test');url.pathname='/hasani_payslip_notice_test';
  const pool=new pg.Pool({connectionString:url.toString()});
  try {
    await pool.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
    await pool.query(`INSERT INTO branches(id,name) VALUES('A','A');
      INSERT INTO employees(employee_id,name,branch_id) VALUES('E1','One','A'),('E2','Two','A'),('E3','Three','A');
      INSERT INTO payroll(id,employee_id,period,is_published,release_at) VALUES
        ('OLD','E1','2026-01-01',true,now()-interval '1 day'),
        ('P1','E1','2026-10-01',false,NULL),('P2','E2','2026-10-01',false,NULL),
        ('FUTURE','E3','2026-11-01',false,NULL);`);
    await ensureApplicationSchema(pool);
    const count=async()=>Number((await pool.query("SELECT count(*) FROM app_notifications WHERE notification_type='payslip'")).rows[0].count);
    await t.test('migration and idle worker do not send historical notices',async()=>{
      assert.equal(await count(),0);
      assert.equal(await drainPayslipNotifications(pool,{send:async()=>assert.fail('No push expected')}),0);
    });
    await t.test('drafts and future releases do not create premature notices',async()=>{
      await pool.query("UPDATE payroll SET is_published=true,release_at=now()+interval '1 day' WHERE id='FUTURE'");
      assert.equal(await count(),0);
    });
    await t.test('single publication commits its inbox message and queued delivery together',async()=>{
      const admin=await pool.connect();
      try {
        await admin.query('BEGIN');await admin.query('SET LOCAL ROLE authenticated');
        await admin.query("SELECT set_config('request.jwt.claims',$1,true)",[JSON.stringify({role:'authenticated',app_metadata:{role:'admin'}})]);
        await admin.query("UPDATE payroll SET is_published=true,release_at=now() WHERE id='P1'");
        await admin.query('COMMIT');
      }finally{admin.release();}
      const notices=(await pool.query('SELECT * FROM app_notifications')).rows;
      assert.equal(notices.length,1);assert.equal(notices[0].employee_id,'E1');
      assert.equal(notices[0].audience,'employee');assert.equal(notices[0].title,'New Payslip Available');
      assert.equal(notices[0].body,'Your October 2026 payslip is ready to view.');
      assert.equal((await pool.query('SELECT notification_id FROM app_private.payslip_notice_delivery')).rows[0].notification_id,notices[0].id);
      const client=await pool.connect();
      try {
        await client.query('BEGIN');
        await client.query("UPDATE payroll SET is_published=true,release_at=now() WHERE id='P2'");
        await client.query('ROLLBACK');
      }finally{client.release();}
      assert.equal(await count(),1);
    });
    await t.test('repeated and concurrent publishing creates one message per employee/month',async()=>{
      await Promise.all([pool.query("UPDATE payroll SET is_published=true,release_at=now() WHERE id='P1'"),
        pool.query("UPDATE payroll SET is_published=true,release_at=now() WHERE id='P1'")]);
      assert.equal(await count(),1);
    });
    await t.test('legacy browser callback cannot duplicate the inbox or push',async()=>{
      let handler;
      installNotificationApi({get(){},post(path,auth,fn){handler=fn;}},{pool,authenticate:()=>{}});
      const res={status(code){this.code=code;return this;},json(body){this.body=body;return this;}};
      await handler({user:{role:'admin'},auth:{app_metadata:{}},body:{title:'New Payslip Available',
        body:'Your October 2026 payslip is ready to view.',type:'payslip',audience:'employee',employee_id:'E1'}},res);
      assert.equal(res.body.ok,true);assert.equal(res.body.inbox,0);assert.equal(res.body.pushStatus,'already_saved');
      assert.equal(await count(),1);
    });
    await t.test('failed push leaves the inbox available and retries later',async()=>{
      const result=await drainPayslipNotifications(pool,{send:async(_pool,input)=>{
        assert.deepEqual(input.employeeIds,['E1']);assert.equal(input.type,'payslip');
        return {pushStatus:'not_configured'};
      }});
      assert.equal(result,1);assert.equal(await count(),1);
      const row=(await pool.query('SELECT * FROM app_private.payslip_notice_delivery')).rows[0];
      assert.equal(row.completed_at,null);assert.equal(row.attempts,1);assert.equal(row.last_status,'not_configured');
      assert.equal(row.claim_token,null);assert.ok(row.available_at>new Date());
      assert.equal(await drainPayslipNotifications(pool,{send:async()=>assert.fail('Retry is not due')}),0);
    });
    await t.test('parallel workers claim a notice once and successful delivery is not repeated',async()=>{
      await pool.query("UPDATE app_private.payslip_notice_delivery SET available_at=now()-interval '1 second'");
      let calls=0;const send=async()=>{calls++;return {pushStatus:'sent'};};
      await Promise.all([drainPayslipNotifications(pool,{send}),drainPayslipNotifications(pool,{send})]);
      assert.equal(calls,1);
      assert.equal(await drainPayslipNotifications(pool,{send}),0);
      assert.equal(calls,1);
    });
    await t.test('expired worker leases are recoverable without losing the inbox',async()=>{
      await pool.query("UPDATE payroll SET is_published=true,release_at=now() WHERE id='P2'");
      await pool.query("UPDATE app_private.payslip_notice_delivery SET claimed_until=now()-interval '1 second',claim_token=gen_random_uuid() WHERE employee_id='E2'");
      const sent=[];
      await drainPayslipNotifications(pool,{send:async(_pool,input)=>{sent.push(input.employeeIds[0]);return {pushStatus:'no_devices'};}});
      assert.deepEqual(sent,['E2']);assert.equal(await count(),2);
      assert.equal(await drainPayslipNotifications(pool,{send:async()=>assert.fail('No-device inbox is complete')}),0);
    });
    await t.test('scheduled release waits until due and notifies each employee only once',async()=>{
      await pool.query(`INSERT INTO payslip_release_schedules(payroll_month,release_at,scheduled_by)
        VALUES('2026-11-01',now()+interval '1 day','admin');`);
      await pool.query('SELECT release_due_payslips()');assert.equal(await count(),2);
      await pool.query("UPDATE payslip_release_schedules SET release_at=now()-interval '1 second' WHERE payroll_month='2026-11-01'");
      await pool.query('SELECT release_due_payslips()');
      assert.equal(await count(),3);
      assert.equal((await pool.query("SELECT body FROM app_notifications WHERE employee_id='E3'")).rows[0].body,'Your November 2026 payslip is ready to view.');
      await pool.query('SELECT release_due_payslips()');assert.equal(await count(),3);
      const sent=[];
      await drainPayslipNotifications(pool,{send:async(_pool,input)=>{sent.push(input.employeeIds[0]);return {pushStatus:'sent'};}});
      assert.deepEqual(sent,['E3']);
    });
    await t.test('employee inbox RLS isolates recipients and queue remains private',async()=>{
      const client=await pool.connect();
      try {
        await client.query('BEGIN');await client.query('SET LOCAL ROLE authenticated');
        await client.query("SELECT set_config('request.jwt.claims',$1,true)",[JSON.stringify({role:'authenticated',app_metadata:{role:'employee',employee_id:'E2'}})]);
        const rows=(await client.query('SELECT employee_id FROM public.app_notifications')).rows;
        assert.deepEqual(rows.map(r=>r.employee_id),['E2']);
        assert.equal((await client.query("UPDATE public.payroll SET is_published=true WHERE id='FUTURE'")).rowCount,0);
        await assert.rejects(client.query('SELECT * FROM app_private.payslip_notice_delivery'),{code:'42501'});
        await client.query('ROLLBACK');
      }finally{client.release();}
    });
    await t.test('new device registration retries a recent no-device delivery once for its verified owner',async()=>{
      const client=await pool.connect();
      try {
        await client.query('BEGIN');await client.query('SET LOCAL ROLE authenticated');
        await client.query("SELECT set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:'test-user',role:'authenticated',app_metadata:{role:'employee',employee_id:'E2',branch_id:'A'}})]);
        await client.query("SELECT public.register_notification_device($1,'E1','B','android')",['TEST_DEVICE_TOKEN_FOR_EMPLOYEE_TWO']);
        await client.query('COMMIT');
      }finally{client.release();}
      const device=(await pool.query('SELECT employee_id FROM public.notification_devices')).rows[0];
      assert.equal(device.employee_id,'E2');
      const sent=[];
      await drainPayslipNotifications(pool,{send:async(_pool,input)=>{sent.push(input.employeeIds[0]);return {pushStatus:'sent'};}});
      assert.deepEqual(sent,['E2']);assert.equal(await count(),3);
      await pool.query("UPDATE public.notification_devices SET employee_id=employee_id");
      assert.equal(await drainPayslipNotifications(pool,{send:async()=>assert.fail('Successful delivery must not replay')}),0);
    });
    await t.test('migration is idempotent and does not duplicate deliveries',async()=>{
      await ensureApplicationSchema(pool);assert.equal(await count(),3);
    });
    await t.test('withdrawn payslips are not pushed until published again',async()=>{
      await pool.query("INSERT INTO payroll(id,employee_id,period,is_published,release_at) VALUES('DEC','E1','2026-12-01',true,now())");
      await pool.query("UPDATE payroll SET is_published=false WHERE id='DEC'");
      assert.equal(await drainPayslipNotifications(pool,{send:async()=>assert.fail('Withdrawn payslip is not available')}),0);
      await pool.query("UPDATE payroll SET is_published=true WHERE id='DEC'");
      assert.equal(await drainPayslipNotifications(pool,{send:async()=>({pushStatus:'partial'})}),1);
      assert.equal(await drainPayslipNotifications(pool,{send:async()=>assert.fail('Do not re-send successful devices')}),0);
      assert.equal(await count(),4);
    });
    await t.test('unexpected push exceptions keep a recoverable queue entry',async()=>{
      await pool.query("INSERT INTO payroll(id,employee_id,period,is_published,release_at) VALUES('JAN','E1','2027-01-01',true,now())");
      assert.equal(await drainPayslipNotifications(pool,{send:async()=>({pushStatus:'failed',pushErrors:['SENDER_ID_MISMATCH']})}),1);
      const row=(await pool.query("SELECT * FROM app_private.payslip_notice_delivery WHERE payroll_month='2027-01-01'")).rows[0];
      assert.equal(row.completed_at,null);assert.equal(row.last_status,'failed');assert.equal(row.claimed_until,null);
      assert.deepEqual(row.last_error_codes,['SENDER_ID_MISMATCH']);
      assert.equal(await count(),5);
    });
  }finally{await pool.end();await dropFixtureDatabase(bootstrap,'hasani_payslip_notice_test');await bootstrap.end();}
});
