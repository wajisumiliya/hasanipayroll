import {firebaseConfigurationStatus} from './notification-status.js';
import { pushNotifications } from './push-sender.js';
export { pushNotifications } from './push-sender.js';
import { DataApiError } from './data-api.js';
function admin(req) {
  if (String(req.user.role).toLowerCase() !== 'admin' || req.auth?.app_metadata?.is_reviewer || ['attendance','requests'].includes(req.auth?.app_metadata?.staff_scope)) throw new DataApiError('Administrator access required',403);
}
function fail(res,error) {
  res.status(error.status || 503).json({ok:false,message:error instanceof DataApiError ? error.message : 'Unable to send notification.'});
}
export function installNotificationApi(app,{pool,authenticate,env=process.env}) {
  app.get('/api/notifications/status',authenticate,async(req,res)=>{
    try {
      admin(req);
      const employeeId=String(req.query.employee_id||'').trim();
      if (!employeeId || employeeId.length>100) throw new DataApiError('Select an employee',400);
      const employee=await pool.query('SELECT employee_id FROM public.employees WHERE employee_id=$1',[employeeId]);
      if (!employee.rows.length) throw new DataApiError('Employee not found',404);
      const [devices,recent,payroll,trigger]=await Promise.all([
        pool.query('SELECT platform,count(*)::int AS count FROM public.notification_devices WHERE employee_id=$1 GROUP BY platform',[employeeId]),
        pool.query(`SELECT to_char(payroll_month,'YYYY-MM') AS payroll_month,attempts,last_status,last_error_codes,
          available_at,completed_at FROM app_private.payslip_notice_delivery
          WHERE employee_id=$1 ORDER BY payroll_month DESC LIMIT 6`,[employeeId]),
        pool.query(`SELECT to_char(p.period,'YYYY-MM') AS payroll_month,p.is_published,p.release_at,
          (p.is_published AND (p.release_at IS NULL OR p.release_at<=now())) AS available,
          EXISTS(SELECT 1 FROM public.app_notifications n WHERE n.employee_id=p.employee_id
            AND n.audience='employee' AND n.notification_type='payslip'
            AND n.body=format('Your %s payslip is ready to view.',to_char(p.period,'FMMonth YYYY'))) AS inbox_saved,
          EXISTS(SELECT 1 FROM app_private.payslip_notice_delivery d WHERE d.employee_id=p.employee_id
            AND d.payroll_month=date_trunc('month',p.period::timestamp)::date) AS push_queued
          FROM public.payroll p WHERE p.employee_id=$1 ORDER BY p.period DESC LIMIT 6`,[employeeId]),
        pool.query(`SELECT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.payroll'::regclass
          AND tgname='payslip_published_notice' AND tgenabled IN ('O','A') AND NOT tgisinternal) AS ready`),
      ]);
      const counts={total:0,android:0,web:0};
      for (const row of devices.rows) {
        counts.total+=Number(row.count);
        if (row.platform==='android' || row.platform==='web') counts[row.platform]+=Number(row.count);
      }
      res.json({ok:true,employee_id:employeeId,firebase:firebaseConfigurationStatus(env),
        publication_notifications_ready:trigger.rows[0]?.ready===true,
        devices:counts,recent:recent.rows,payroll:payroll.rows});
    } catch(error) { fail(res,error); }
  });
  app.post('/api/notifications/send',authenticate,async(req,res)=>{
    try {
      admin(req);
      const input=req.body||{},title=String(input.title||'').trim(),body=String(input.body||'').trim();
      const audience=String(input.audience||'all'),type=String(input.type||'information').slice(0,64);
      const employeeIds=[...new Set((Array.isArray(input.employee_ids)?input.employee_ids:[input.employee_id]).map(v=>String(v||'').trim()).filter(Boolean))];
      const branchId=String(input.branch_id||'').trim()||null;
      if (!title||title.length>160||!body||body.length>2000||!['all','branch','employee'].includes(audience)||employeeIds.length>500||(audience==='employee'&&!employeeIds.length)||(audience==='branch'&&!branchId)) throw new DataApiError('Invalid notification');
      const notifications=(audience==='employee'?employeeIds:[null]).map(employee_id=>({title,body,notification_type:type,audience,branch_id:branchId,employee_id}));
      let newNotifications = notifications;
      if (type === 'payslip' && audience === 'employee') {
        // Older web builds still send a second request after publishing. The DB
        // already saved and queued that notice atomically; do not duplicate it.
        const inserted = await pool.query(`INSERT INTO public.app_notifications(title,body,notification_type,audience,branch_id,employee_id)
          SELECT title,body,notification_type,audience,branch_id,employee_id
          FROM jsonb_to_recordset($1::jsonb) AS n(title text,body text,notification_type text,audience text,branch_id text,employee_id text)
          WHERE NOT EXISTS (SELECT 1 FROM public.app_notifications prior
            WHERE prior.notification_type='payslip' AND prior.audience='employee'
              AND prior.employee_id=n.employee_id AND prior.body=n.body)
          RETURNING employee_id`,[JSON.stringify(notifications)]);
        newNotifications = inserted.rows;
        if (!newNotifications.length) {
          return res.json({ok:true,inbox:0,sent:0,pushStatus:'already_saved',pushErrors:[]});
        }
      } else {
        await pool.query(`INSERT INTO public.app_notifications(title,body,notification_type,audience,branch_id,employee_id)
          SELECT title,body,notification_type,audience,branch_id,employee_id FROM jsonb_to_recordset($1::jsonb) AS n(title text,body text,notification_type text,audience text,branch_id text,employee_id text)`,[JSON.stringify(notifications)]);
      }
      let push={sent:0,pushConfigured:false,pushStatus:'unavailable',pushErrors:[]};
      try { push=await pushNotifications(pool,{title,body,audience,type,branchId,employeeIds:audience==='employee'?newNotifications.map(n=>n.employee_id):employeeIds,taxYear:String(input.tax_year||'')}); }
      catch { console.error('Push delivery unavailable; notification saved to inbox.'); }
      if (push.pushStatus !== 'sent') console.warn('Notification push status:', push.pushStatus, push.pushErrors?.join(',') || '');
      res.json({ok:true,inbox:newNotifications.length,...push});
    } catch(error) {fail(res,error);}
  });
}
