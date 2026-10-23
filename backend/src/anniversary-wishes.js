import { pushNotifications } from './notification-api.js';

export const ANNIVERSARY_TITLE = '🎉 Happy Work Anniversary!';
export function anniversaryMessage(name, years, yearLabel = years === 1 ? 'year' : 'years') {
  return `🎉 Happy Work Anniversary, ${name}! 🏆\nCongratulations on completing ${years} ${yearLabel} with Hasani Books. Thank you for your dedication, hard work, and the difference you make every day. Wishing you continued growth and success!\n— From all of us at Hasani Books 💙`;
}

// The database clock and Malaysia timezone are authoritative. Claiming the annual
// wish and saving its inbox notification happen in one atomic statement, including
// when multiple server instances start or tick together.
export async function sendDueAnniversaryWishes(pool, {
  now = null, push = pushNotifications,
} = {}) {
  const result = await pool.query(`
    WITH local_clock AS (
      SELECT COALESCE($1::timestamptz, now()) AT TIME ZONE 'Asia/Kuala_Lumpur' AS today
    ), due AS (
      SELECT e.employee_id, COALESCE(NULLIF(trim(e.name), ''), 'Team Member') AS name,
             extract(year FROM c.today)::integer AS anniversary_year,
             (extract(year FROM c.today) - extract(year FROM e.joining_date))::integer AS years
      FROM public.employees e CROSS JOIN local_clock c
      WHERE e.is_active = true AND e.joining_date IS NOT NULL
        AND e.joining_date::date < c.today::date
        AND extract(year FROM c.today) > extract(year FROM e.joining_date)
        AND c.today::time >= time '09:00'
        AND extract(month FROM e.joining_date) = extract(month FROM c.today)
        AND extract(day FROM e.joining_date) = extract(day FROM c.today)
    ), claimed AS (
      INSERT INTO app_private.anniversary_wishes(employee_id, anniversary_year)
      SELECT employee_id, anniversary_year FROM due
      ON CONFLICT DO NOTHING RETURNING employee_id
    )
    INSERT INTO public.app_notifications(title, body, notification_type, audience, employee_id)
    SELECT $2, replace(replace(replace($3, '{Years}', d.years::text),
      '{YearLabel}', CASE WHEN d.years = 1 THEN 'year' ELSE 'years' END),
      '{Name}', d.name), 'work_anniversary', 'employee', d.employee_id
    FROM due d JOIN claimed c USING (employee_id)
    RETURNING employee_id, title, body
  `, [now, ANNIVERSARY_TITLE, anniversaryMessage('{Name}', '{Years}', '{YearLabel}')]);

  for (const wish of result.rows) {
    try {
      const delivery = await push(pool, {
        title: wish.title, body: wish.body, audience: 'employee', type: 'work_anniversary',
        employeeIds: [wish.employee_id], branchId: null, taxYear: '',
      });
      if (!delivery.pushConfigured) {
        console.warn('Anniversary wish saved to inbox; Firebase push is not configured.');
      } else if (delivery.sent === 0) {
        console.warn('Anniversary wish saved to inbox; no device accepted the push.');
      }
    } catch {
      // Never expose employee names, IDs, tokens, or provider credentials in logs.
      console.error('Anniversary push unavailable; wish saved to inbox.');
    }
  }
  return result.rows.length;
}

export function startAnniversaryWishWorker(pool) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try { await sendDueAnniversaryWishes(pool); }
    catch { console.error('Automatic anniversary wishes failed; retrying next minute.'); }
    finally { running = false; }
  };
  void tick();
  const timer = setInterval(tick, 60000);
  timer.unref();
  return () => clearInterval(timer);
}
