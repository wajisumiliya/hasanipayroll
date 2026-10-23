import { pushNotifications } from './push-sender.js';

export const REVEAL_REMINDER_TITLE = '🥚 Your surprise is almost here!';
export const REVEAL_REMINDER_BODY = 'The golden mystery egg is hatching in a few minutes! Open Hasani Books on web or Android to watch the reveal. ✨';
export const BRANCH_REMINDER_TITLE = '🥚 The branch penguin crew is almost here!';
export const BRANCH_REMINDER_BODY = 'The branch dashboard golden eggs are hatching in a few minutes! Open the branch dashboard on web or Android to watch the crew reveal. ✨';

export async function sendDueMysteryEggReminder(pool, { now = null, push = pushNotifications } = {}) {
  // Claim and inbox insert are atomic, so concurrent instances and restarts
  // cannot send another reminder for the same hatch. Never send after hatching.
  const { rows } = await pool.query(`
    WITH campaign AS (
      SELECT started_at + interval '72 hours' + s.delay AS hatch_at, s.scope,
             COALESCE($1::timestamptz, now()) AS server_now
      FROM app_private.mystery_egg_campaign
      CROSS JOIN (VALUES ('login', interval '0'), ('branch', interval '1 hour')) AS s(scope, delay)
      WHERE id = 1
    ), claimed AS (
      INSERT INTO app_private.mystery_egg_reminders(hatch_at)
      SELECT hatch_at FROM campaign
      WHERE server_now >= hatch_at - interval '3 minutes' AND server_now < hatch_at
      ON CONFLICT DO NOTHING RETURNING hatch_at
    )
    INSERT INTO public.app_notifications(title, body, notification_type, audience)
    SELECT CASE WHEN c.scope = 'branch' THEN $4 ELSE $2 END,
           CASE WHEN c.scope = 'branch' THEN $5 ELSE $3 END,
           CASE WHEN c.scope = 'branch' THEN 'branch_egg_reveal' ELSE 'mystery_egg_reveal' END,
           'all' FROM claimed JOIN campaign c USING (hatch_at)
    RETURNING id, title, body, notification_type
  `, [now, REVEAL_REMINDER_TITLE, REVEAL_REMINDER_BODY, BRANCH_REMINDER_TITLE, BRANCH_REMINDER_BODY]);
  if (!rows.length) return { reminders: 0 };
  let delivery;
  for (const row of rows) {
    try {
      delivery = await push(pool, {
        title: row.title, body: row.body,
        type: row.notification_type, audience: 'all', employeeIds: [], branchId: null, taxYear: '',
      });
      console.info('Mystery egg reminder push status:', delivery.pushStatus || 'unavailable', delivery.sent || 0, delivery.pushErrors?.join(',') || '');
    } catch {
      console.error('Mystery egg reminder push unavailable; reminder saved to everyone’s inbox.');
    }
  }
  return { reminders: rows.length, delivery };
}

export function startMysteryEggReminderWorker(pool) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try { await sendDueMysteryEggReminder(pool); }
    catch { console.error('Mystery egg reminder check failed; retrying in ten seconds.'); }
    finally { running = false; }
  };
  void tick();
  const timer = setInterval(tick, 10000);
  timer.unref();
  return () => clearInterval(timer);
}
