import {pushNotifications} from './push-sender.js';

// Short database claims keep concurrent Render workers from sending the same
// employee/month notice together. Never hold a DB transaction across Firebase.
export async function drainPayslipNotifications(pool, {send = pushNotifications, limit = 100} = {}) {
  let handled = 0;
  for (let index = 0; index < limit; index++) {
    const claimed = await pool.query(`WITH candidate AS (
      SELECT d.employee_id,d.payroll_month FROM app_private.payslip_notice_delivery d
      WHERE d.completed_at IS NULL AND d.notification_id IS NOT NULL
        AND d.available_at<=now() AND (d.claimed_until IS NULL OR d.claimed_until<=now())
        AND EXISTS (SELECT 1 FROM public.payroll p WHERE p.employee_id=d.employee_id
          AND date_trunc('month',p.period::timestamp)::date=d.payroll_month
          AND p.is_published AND (p.release_at IS NULL OR p.release_at<=now()))
      ORDER BY d.available_at,d.employee_id FOR UPDATE SKIP LOCKED LIMIT 1
    ) UPDATE app_private.payslip_notice_delivery d
      SET claim_token=gen_random_uuid(),claimed_until=now()+interval '5 minutes',attempts=d.attempts+1
      FROM candidate c,public.app_notifications n
      WHERE d.employee_id=c.employee_id AND d.payroll_month=c.payroll_month
        AND n.id=d.notification_id
      RETURNING d.employee_id,d.payroll_month,d.claim_token,n.title,n.body`);
    const row = claimed.rows[0];
    if (!row) break;
    let result;
    try {
      result = await send(pool, {title:row.title,body:row.body,type:'payslip',
        audience:'employee',branchId:null,employeeIds:[row.employee_id]});
    } catch {
      result = {pushStatus:'failed'};
    }
    // An inbox remains available even without a registered device. Retry total
    // transport/configuration failures, but avoid re-sending to successful devices
    // after a partial delivery. Provider acceptance does not prove device display.
    const status = ['sent','partial','no_devices','not_configured','invalid_configuration',
      'authentication_failed','failed'].includes(result?.pushStatus) ? result.pushStatus : 'failed';
    const complete = ['sent','partial','no_devices'].includes(status);
    await pool.query(`UPDATE app_private.payslip_notice_delivery
      SET completed_at=CASE WHEN $4 THEN now() ELSE NULL END,last_status=$5,
        available_at=now()+make_interval(secs=>LEAST(3600,60*power(2,LEAST(attempts,6)))::int),
        claim_token=NULL,claimed_until=NULL
      WHERE employee_id=$1 AND payroll_month=$2 AND claim_token=$3`,
    [row.employee_id,row.payroll_month,row.claim_token,complete,status]);
    handled++;
  }
  return handled;
}
