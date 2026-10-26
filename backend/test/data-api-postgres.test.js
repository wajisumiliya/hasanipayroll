import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { ensureApplicationSchema } from '../src/application-schema.js';
import { installLateReportApi } from '../src/late-report.js';
import { installDataApi } from '../src/data-api.js';
import { installNeonPhotoApi, MAX_PHOTO_BYTES } from '../src/neon-employee-photos.js';
import { copyPhotos } from '../scripts/copy-employee-photos-to-neon.js';

test('Neon migration and authenticated HTTP adapter enforce imported schema policies', {
  skip: !process.env.BOOTSTRAP_TEST_DATABASE_URL,
}, async (t) => {
  const url = new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['localhost', '127.0.0.1'].includes(url.hostname));
  assert.equal(url.pathname, '/hasani_bootstrap_test');
  const { default: pg } = await import('pg');
  const { default: express } = await import('express');
  const bootstrap = new pg.Pool({ connectionString: url.toString() });
  await bootstrap.query('CREATE DATABASE hasani_data_api_test');
  url.pathname = '/hasani_data_api_test';
  const pool = new pg.Pool({ connectionString: url.toString() });
  let server;
  try {
    await pool.query(await readFile(new URL('./fixtures/neon-schema.sql', import.meta.url), 'utf8'));
    await ensureApplicationSchema(pool);
    await ensureApplicationSchema(pool); // Restart is idempotent.
    await pool.query(`INSERT INTO employees(employee_id,name,branch_id) VALUES
      ('FIX_E1','Employee One','FIX_A'),('FIX_E2','Employee Two','FIX_B');
      INSERT INTO branches(id,name,password) VALUES ('FIX_A','Branch A','hidden'),('FIX_B','Branch B','hidden');
      INSERT INTO payroll(id,employee_id,period,basic_salary,is_published,release_at) VALUES
      ('FIX_P1','FIX_E1','2026-01-01',1234.50,true,now()-interval '1 day'),
      ('FIX_P2','FIX_E2','2026-01-01',2500,true,now()-interval '1 day'),
      ('FIX_P3','FIX_E1','2026-02-01',1500,false,null);`);
    const identities = {
      admin: { username: 'FIX_ADMIN', role: 'admin' },
      reviewer: { username: 'FIX_REVIEW', role: 'admin', metadata:{is_reviewer:true} },
      requests: { username: 'FIX_REQUEST', role: 'admin', metadata:{staff_scope:'requests'} },
      branch: { username: 'FIX_A', role: 'branch', branch_id: 'FIX_A' },
      employee: { username: 'FIX_EMPLOYEE', role: 'employee', employee_id: 'FIX_E1' },
    };
    const app = express();
    app.use(express.json());
    const authenticate = (req,res,next) => {
      const user = identities[String(req.get('Authorization') || '').replace('Bearer ', '')];
      if (!user) return res.status(401).json({message:'Authentication required'});
      req.user=user; req.auth={sub:user.username, app_metadata:user.metadata || {}}; next();
    };
    installDataApi(app, { pool, authenticate });
    installNeonPhotoApi(app, { pool, authenticate });
    installLateReportApi(app, { pool, authenticate });
    server = await new Promise(resolve => { const s=app.listen(0,'127.0.0.1',()=>resolve(s)); });
    const base=`http://127.0.0.1:${server.address().port}/api/data`;
    async function request(path, identity='admin', options={}) {
      return fetch(base+path,{...options,headers:{Authorization:'Bearer '+identity,'Content-Type':'application/json',...options.headers}});
    }
    await t.test('late report and durable admin review round trip preserve attendance and protect private history',async()=>{
      await pool.query(`INSERT INTO monthly_rosters(branch_id,employee_id,roster_year,roster_month,week_number,shift_start,shift_end,break_minutes)
        VALUES ('FIX_A','FIX_E1',2026,10,1,'09:00','18:00',60);
        INSERT INTO attendance(employee_id,branch_id,attendance_date,check_in,check_out,status,break_minutes)
        VALUES ('FIX_E1','FIX_A','2026-10-01','09:10','18:00','Late',75),
               ('FIX_E1','FIX_A','2026-10-02','09:05','18:00','Late',80);`);
      const endpoint=base.replace('/api/data','')+'/api/attendance/late-report';
      const reportResponse=await fetch(endpoint+'?year=2026&month=10',{headers:{Authorization:'Bearer admin'}});
      assert.equal(reportResponse.status,200);
      const report=await reportResponse.json();
      assert.equal(report.reports[0].count,4);
      const event=report.reports[0].events[0];
      const body={branch_id:'FIX_A',employee_id:'FIX_E1',date:event.date,type:event.type,fingerprint:event.fingerprint,status:'approved',reason_code:'transport',reason:'Train delayed'};
      const save=await fetch(endpoint+'/reviews',{method:'POST',headers:{Authorization:'Bearer admin','Content-Type':'application/json'},body:JSON.stringify(body)});
      assert.equal(save.status,200);
      const refreshed=await (await fetch(endpoint+'?year=2026&month=10',{headers:{Authorization:'Bearer admin'}})).json();
      assert.equal(refreshed.reports[0].count,4);assert.equal(refreshed.reports[0].events[0].review.reviewed_by,'FIX_ADMIN');
      assert.equal((await pool.query("SELECT check_in FROM attendance WHERE employee_id='FIX_E1' AND attendance_date='2026-10-01'")).rows[0].check_in,'09:10');
      assert.equal((await fetch(endpoint+'?year=2026&month=10',{headers:{Authorization:'Bearer employee'}})).status,403);
      assert.equal((await request('/late_report_reviews','employee')).status,404);
      const permissions=await pool.query("SELECT has_table_privilege('authenticated','app_private.late_report_reviews','SELECT') AS readable");
      assert.equal(permissions.rows[0].readable,false);
      await pool.query("UPDATE attendance SET check_in='09:15' WHERE employee_id='FIX_E1' AND attendance_date='2026-10-01'");
      const outdated=await fetch(endpoint+'/reviews',{method:'POST',headers:{Authorization:'Bearer admin','Content-Type':'application/json'},body:JSON.stringify(body)});
      assert.equal(outdated.status,409);
    });
    await t.test('requires authentication and never exposes accounts or passwords',async()=>{
      assert.equal((await request('/employees','unknown')).status,401);
      assert.equal((await request('/app_user')).status,404);
      const branches=await (await request('/branches')).json();
      assert.equal(branches.length,2);
      assert.ok(branches.every(row=>!Object.hasOwn(row,'password')));
      assert.equal((await request('/branches?select=password')).status,400);
    });
    await t.test('employee and branch cannot read another employee payroll or unpublished payslips',async()=>{
      const own=await (await request('/payroll?select=id,basic_salary','employee')).json();
      assert.deepEqual(own,[{id:'FIX_P1',basic_salary:1234.5}]);
      assert.deepEqual(await (await request('/payroll?employee_id=eq.FIX_E2','employee')).json(),[]);
      assert.deepEqual(await (await request('/employees?select=employee_id','branch')).json(),[{employee_id:'FIX_E1'}]);
      assert.deepEqual(await (await request('/employees?employee_id=eq.FIX_E2','branch')).json(),[]);
    });
    await t.test('blocked writes leave other employee records unchanged',async()=>{
      const blocked=await request('/employees?employee_id=eq.FIX_E2','employee',{method:'PATCH',body:JSON.stringify({name:'tampered'}),headers:{Prefer:'return=representation'}});
      assert.deepEqual(await blocked.json(),[]);
      assert.equal((await pool.query("SELECT name FROM employees WHERE employee_id='FIX_E2'")).rows[0].name,'Employee Two');
      const denied=await request('/payroll','employee',{method:'POST',body:JSON.stringify({employee_id:'FIX_E1',period:'2026-03-01'})});
      assert.equal(denied.status,403);
      assert.equal((await request('/rpc/set_employee_active_status','employee',{method:'POST',body:JSON.stringify({p_employee_id:'FIX_E2',p_is_active:false})})).status>=400,true);
    });
    await t.test('admin upserts, nested filters, numeric and JSON values match Flutter expectations',async()=>{
      const saved=await request('/employee_ea_forms?on_conflict=employee_id,tax_year','admin',{method:'POST',headers:{Prefer:'resolution=merge-duplicates,return=representation'},body:JSON.stringify({employee_id:'FIX_E1',tax_year:2026,form_data:{income:1234.5},generated_by:'FIX_ADMIN'})});
      assert.equal(saved.status,201);
      assert.deepEqual((await saved.json())[0].form_data,{income:1234.5});
      const filtered=await request('/employees?select=employee_id&or=(employee_id.eq.FIX_E1,employee_id.eq.FIX_E2)&order=employee_id.desc&limit=1');
      assert.deepEqual(await filtered.json(),[{employee_id:'FIX_E2'}]);
      const one=await request('/employees?employee_id=eq.FIX_E1','admin',{headers:{Accept:'application/vnd.pgrst.object+json'}});
      assert.equal((await one.json()).employee_id,'FIX_E1');
      assert.equal((await request('/employees?employee_id=eq.MISSING','admin',{headers:{Accept:'application/vnd.pgrst.object+json'}})).status,406);
    });
    await t.test('private Neon photos enforce authentication, RLS scope, input limits and atomic writes',async()=>{
      const photo = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC','base64');
      const photoUrl = base.replace('/api/data','/api/employee-photos/FIX_E1');
      const photoRequest = (identity,method='GET',body=undefined,type='image/png',id='FIX_E1') =>
        fetch(photoUrl.replace('/FIX_E1','/'+id),{method,body,headers:{Authorization:'Bearer '+identity,'Content-Type':type}});
      assert.equal((await photoRequest('unknown')).status,401);
      assert.equal((await photoRequest('admin')).status,404);
      assert.equal((await photoRequest('branch','PUT',photo)).status,403);
      assert.equal((await photoRequest('employee','PUT',photo)).status,403);
      assert.equal((await photoRequest('requests','PUT',photo)).status,403);
      assert.equal((await photoRequest('reviewer')).status,403);
      assert.equal((await photoRequest('admin','PUT',photo,'text/html')).status,400);
      assert.equal((await photoRequest('admin','PUT',Buffer.from('fake'),'image/png')).status,400);
      assert.equal((await photoRequest('admin','PUT',Buffer.alloc(MAX_PHOTO_BYTES+1))).status,413);
      const saved=await photoRequest('admin','PUT',photo);
      assert.equal(saved.status,200);
      assert.equal((await saved.json()).photoUrl,'neon-photo/FIX_E1');
      assert.equal((await pool.query("SELECT photo_url FROM employees WHERE employee_id='FIX_E1'")).rows[0].photo_url,'neon-photo/FIX_E1');
      const loaded=await photoRequest('employee');
      assert.equal(loaded.headers.get('content-type'),'image/png');
      assert.equal(loaded.headers.get('cache-control'),'private, no-store');
      assert.deepEqual(Buffer.from(await loaded.arrayBuffer()),photo);
      assert.equal((await photoRequest('branch')).status,200);
      assert.equal((await photoRequest('employee','GET',undefined,'image/png','FIX_E2')).status,403);
      assert.equal((await photoRequest('branch','GET',undefined,'image/png','FIX_E2')).status,403);
      assert.equal((await photoRequest('admin','PUT',photo)).status,200);
      assert.equal((await pool.query("SELECT count(*) FROM app_private.employee_photos WHERE employee_id='FIX_E1'")).rows[0].count,'1');
      assert.equal((await request('/employee_photos')).status,404);
      assert.equal((await pool.query("SELECT has_table_privilege('authenticated','app_private.employee_photos','SELECT') AS allowed")).rows[0].allowed,false);
      assert.equal((await photoRequest('employee','DELETE')).status,403);
      assert.equal((await photoRequest('admin','DELETE')).status,200);
      assert.equal((await photoRequest('admin')).status,404);
      assert.equal((await pool.query("SELECT photo_url FROM employees WHERE employee_id='FIX_E1'")).rows[0].photo_url,null);
      await pool.query("INSERT INTO employees(employee_id,name,branch_id) VALUES ('FIX_PHOTO_DELETE','Temporary photo employee','FIX_A')");
      await pool.query("INSERT INTO app_private.employee_photos(employee_id,content_type,photo_bytes) VALUES ('FIX_PHOTO_DELETE','image/png',$1)",[photo]);
      await pool.query("DELETE FROM employees WHERE employee_id='FIX_PHOTO_DELETE'");
      assert.equal((await pool.query("SELECT count(*) FROM app_private.employee_photos WHERE employee_id='FIX_PHOTO_DELETE'")).rows[0].count,'0');
    });
    await t.test('photo copy defaults to preview, copies atomically and never overwrites a Neon photo',async()=>{
      await pool.query("UPDATE employees SET photo_url='FIX_E1/profile' WHERE employee_id='FIX_E1'");
      const jpeg=Buffer.from([255,216,255,217]);
      let downloads=0;
      const options={pool,sourceKey:'synthetic-source-key',encode:async()=>jpeg,fetchPhoto:async(url,options)=>{
        downloads++;
        assert.equal(new URL(url).hostname,'qychfoxygqzmtsqtxihp.supabase.co');
        assert.equal(options.headers.Authorization,'Bearer synthetic-source-key');
        assert.equal(options.redirect,'error');
        return new Response(jpeg,{status:200});
      }};
      const preview=await copyPhotos(options);
      assert.equal(preview.ready,1); assert.equal(preview.copied,0);
      assert.equal((await pool.query('SELECT count(*) FROM app_private.employee_photos')).rows[0].count,'0');
      const applied=await copyPhotos({...options,apply:true});
      assert.equal(applied.copied,1);
      assert.deepEqual((await pool.query("SELECT photo_bytes FROM app_private.employee_photos WHERE employee_id='FIX_E1'")).rows[0].photo_bytes,jpeg);
      const repeated=await copyPhotos({...options,apply:true});
      assert.equal(repeated.alreadyPresent,1); assert.equal(downloads,2);
      await pool.query("DELETE FROM app_private.employee_photos WHERE employee_id='FIX_E1'");
      await pool.query("UPDATE employees SET photo_url='FIX_E1/profile' WHERE employee_id='FIX_E1'");
      const inaccessible=await copyPhotos({...options,apply:true,fetchPhoto:async()=>new Response('',{status:402})});
      assert.equal(inaccessible.failed,1);
      assert.equal((await pool.query("SELECT photo_url FROM employees WHERE employee_id='FIX_E1'")).rows[0].photo_url,'FIX_E1/profile');
    });
    await t.test('permitted RPC writes work and pooled sessions do not retain another identity',async()=>{
      const changed=await request('/rpc/set_employee_active_status','admin',{method:'POST',body:JSON.stringify({p_employee_id:'FIX_E2',p_is_active:false})});
      assert.equal(changed.status,200);
      assert.equal((await pool.query("SELECT is_active FROM employees WHERE employee_id='FIX_E2'")).rows[0].is_active,false);
      const employee=await (await request('/employees?select=employee_id','employee')).json();
      assert.deepEqual(employee,[{employee_id:'FIX_E1'}]);
      assert.equal((await pool.query('SELECT current_user AS role')).rows[0].role,'bootstrap_test');
    });
  } finally {
    if(server) await new Promise(resolve=>server.close(resolve));
    await pool.end();
    await bootstrap.query('DROP DATABASE hasani_data_api_test');
    await bootstrap.end();
  }
});
