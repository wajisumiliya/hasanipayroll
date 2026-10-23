import { pushNotifications } from './notification-api.js';

export const BIRTHDAY_TITLE = '🎂 Happy Birthday!';
export function birthdayMessage(name) {
  return `🎂 Happy Birthday, ${name}! 🎉\nWishing you good health, happiness, and a wonderful year ahead. Thank you for being part of the Hasani Books family. Enjoy your special day!\n— From all of us at Hasani Books 💙`;
}

// The database clock and Malaysia timezone are authoritative. Claiming the annual
// wish and saving its inbox notification happen in one atomic statement, including
// when multiple server instances start or tick together.
export async function sendDueBirthdayWishes(pool, {
  now = null, push = pushNotifications,
} = {}) {
  const result = await pool.query(`
    WITH local_clock AS (
      SELECT COALESCE($1::timestamptz, now()) AT TIME ZONE 'Asia/Kuala_Lumpur' AS today
    ), due AS (
      SELECT e.employee_id, COALESCE(NULLIF(trim(e.name), ''), 'Team Member') AS name,
             extract(year FROM c.today)::integer AS birthday_year
      FROM public.employees e CROSS JOIN local_clock c
      WHERE e.is_active = true AND e.birthday IS NOT NULL
        AND c.today::time >= time '09:00'
        AND extract(month FROM e.birthday) = extract(month FROM c.today)
        AND extract(day FROM e.birthday) = extract(day FROM c.today)
    ), claimed AS (
      INSERT INTO app_private.birthday_wishes(employee_id, birthday_year)
      SELECT employee_id, birthday_year FROM due
      ON CONFLICT DO NOTHING RETURNING employee_id
    )
    INSERT INTO public.app_notifications(title, body, notification_type, audience, employee_id)
    SELECT $2, replace($3, '{Name}', d.name), 'birthday', 'employee', d.employee_id
    FROM due d JOIN claimed c USING (employee_id)
    RETURNING employee_id, title, body
  `, [now, BIRTHDAY_TITLE, birthdayMessage('{Name}')]);

  for (const wish of result.rows) {
    try {
      const delivery = await push(pool, {
        title: wish.title, body: wish.body, audience: 'employee', type: 'birthday',
        employeeIds: [wish.employee_id], branchId: null, taxYear: '',
      });
      if (!delivery.pushConfigured) {
        console.warn('Birthday wish saved to inbox; Firebase push is not configured.');
      } else if (delivery.sent === 0) {
        console.warn('Birthday wish saved to inbox; no device accepted the push.');
      }
    } catch {
      // Never expose employee names, IDs, tokens, or provider credentials in logs.
      console.error('Birthday push unavailable; wish saved to inbox.');
    }
  }
  return result.rows.length;
}

export function startBirthdayWishWorker(pool) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try { await sendDueBirthdayWishes(pool); }
    catch { console.error('Automatic birthday wishes failed; retrying next minute.'); }
    finally { running = false; }
  };
  void tick();
  const timer = setInterval(tick, 60000);
  timer.unref();
  return () => clearInterval(timer);
}
