import { pushNotifications } from './push-sender.js';
export { pushNotifications } from './push-sender.js';
import { DataApiError } from './data-api.js';
function admin(req) {
  if (String(req.user.role).toLowerCase() !== 'admin' || req.auth?.app_metadata?.is_reviewer || ['attendance','requests'].includes(req.auth?.app_metadata?.staff_scope)) throw new DataApiError('Administrator access required',403);
}
function fail(res,error) {
  res.status(error.status || 503).json({ok:false,message:error instanceof DataApiError ? error.message : 'Unable to send notification.'});
}
export function installNotificationApi(app,{pool,authenticate}) {
  app.post('/api/notifications/send',authenticate,async(req,res)=>{
    try {
      admin(req);
      const input=req.body||{},title=String(input.title||'').trim(),body=String(input.body||'').trim();
      const audience=String(input.audience||'all'),type=String(input.type||'information').slice(0,64);
      const employeeIds=[...new Set((Array.isArray(input.employee_ids)?input.employee_ids:[input.employee_id]).map(v=>String(v||'').trim()).filter(Boolean))];
      const branchId=String(input.branch_id||'').trim()||null;
      if (!title||title.length>160||!body||body.length>2000||!['all','branch','employee'].includes(audience)||employeeIds.length>500||(audience==='employee'&&!employeeIds.length)||(audience==='branch'&&!branchId)) throw new DataApiError('Invalid notification');
      const notifications=(audience==='employee'?employeeIds:[null]).map(employee_id=>({title,body,notification_type:type,audience,branch_id:branchId,employee_id}));
      await pool.query(`INSERT INTO public.app_notifications(title,body,notification_type,audience,branch_id,employee_id)
        SELECT title,body,notification_type,audience,branch_id,employee_id FROM jsonb_to_recordset($1::jsonb) AS n(title text,body text,notification_type text,audience text,branch_id text,employee_id text)`,[JSON.stringify(notifications)]);
      let push={sent:0,pushConfigured:false,pushStatus:'unavailable',pushErrors:[]};
      try { push=await pushNotifications(pool,{title,body,audience,type,branchId,employeeIds,taxYear:String(input.tax_year||'')}); }
      catch { console.error('Push delivery unavailable; notification saved to inbox.'); }
      if (push.pushStatus !== 'sent') console.warn('Notification push status:', push.pushStatus, push.pushErrors?.join(',') || '');
      res.json({ok:true,inbox:notifications.length,...push});
    } catch(error) {fail(res,error);}
  });
}
