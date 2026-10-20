import jwt from 'jsonwebtoken';
import { DataApiError } from './data-api.js';
function admin(req) {
  if (String(req.user.role).toLowerCase() !== 'admin' || req.auth?.app_metadata?.is_reviewer || ['attendance','requests'].includes(req.auth?.app_metadata?.staff_scope)) throw new DataApiError('Administrator access required',403);
}
function fail(res,error) {
  res.status(error.status || 503).json({ok:false,message:error instanceof DataApiError ? error.message : 'Unable to send notification.'});
}
let firebaseToken;
async function pushNotifications(pool, input) {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT || process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) return { sent: 0, pushConfigured: false };
  const account = JSON.parse(raw);
  const now = Math.floor(Date.now() / 1000);
  if (!firebaseToken || firebaseToken.email !== account.client_email || firebaseToken.expiresAt < now + 60) {
    const assertion = jwt.sign({ scope: 'https://www.googleapis.com/auth/firebase.messaging' }, account.private_key, {
      algorithm: 'RS256', issuer: account.client_email, subject: account.client_email,
      audience: 'https://oauth2.googleapis.com/token', expiresIn: '1h',
    });
    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) throw new Error('Push authentication failed');
    const token = await response.json();
    firebaseToken = { email: account.client_email, token: token.access_token, expiresAt: now + Number(token.expires_in || 3600) };
  }
  const devices = await pool.query(`SELECT DISTINCT token, employee_id FROM public.notification_devices
    WHERE ($1='all' OR ($1='branch' AND branch_id=$2) OR ($1='employee' AND employee_id=ANY($3::text[]))) LIMIT 1000`, [input.audience, input.branchId, input.employeeIds]);
  let sent = 0;
  for (let offset = 0; offset < devices.rows.length; offset += 50) {
    const results = await Promise.allSettled(devices.rows.slice(offset, offset+50).map((device) => fetch(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`, {
        method: 'POST', headers: { Authorization: `Bearer ${firebaseToken.token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: { token: device.token, notification: { title: input.title, body: input.body }, data: {
          type: input.type, audience: input.audience, branch_id: input.branchId || '', employee_id: device.employee_id || '', tax_year: input.taxYear,
        }, webpush: { fcm_options: { link: '/' } } } }), signal: AbortSignal.timeout(10000),
      },
    )));
    sent += results.filter((r) => r.status === 'fulfilled' && r.value.ok).length;
  }
  return { sent, pushConfigured: true };
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
      let push={sent:0,pushConfigured:false};
      try { push=await pushNotifications(pool,{title,body,audience,type,branchId,employeeIds,taxYear:String(input.tax_year||'')}); }
      catch { console.error('Push delivery unavailable; notification saved to inbox.'); }
      res.json({ok:true,inbox:notifications.length,...push});
    } catch(error) {fail(res,error);}
  });
}
