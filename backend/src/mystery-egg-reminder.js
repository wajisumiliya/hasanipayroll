import { pushNotifications } from './push-sender.js';

export const REVEAL_REMINDER_TITLE = '🥚 Your surprise is almost here!';
export const REVEAL_REMINDER_BODY = 'The golden mystery egg is hatching in a few minutes! Open Hasani Books on web or Android to watch the reveal. ✨';

export async function sendDueMysteryEggReminder(pool, { now = null, push = pushNotifications } = {}) {
  // Claim and inbox insert are atomic, so concurrent instances and restarts
  // cannot send another reminder for the same hatch. Never send after hatching.
  const { rows } = await pool.query(`
    WITH campaign AS (
      SELECT started_at + interval '72 hours' AS hatch_at,
             COALESCE($1::timestamptz, now()) AS server_now
      FROM app_private.mystery_egg_campaign WHERE id = 1
    ), claimed AS (
      INSERT INTO app_private.mystery_egg_reminders(hatch_at)
      SELECT hatch_at FROM campaign
      WHERE server_now >= hatch_at - interval '3 minutes' AND server_now < hatch_at
      ON CONFLICT DO NOTHING RETURNING hatch_at
    )
    INSERT INTO public.app_notifications(title, body, notification_type, audience)
    SELECT $2, $3, 'mystery_egg_reveal', 'all' FROM claimed
    RETURNING id
  `, [now, REVEAL_REMINDER_TITLE, REVEAL_REMINDER_BODY]);
  if (!rows.length) return { reminders: 0 };
  let delivery;
  try {
    delivery = await push(pool, {
      title: REVEAL_REMINDER_TITLE, body: REVEAL_REMINDER_BODY,
      type: 'mystery_egg_reveal', audience: 'all', employeeIds: [], branchId: null, taxYear: '',
    });
    console.info('Mystery egg reminder push status:', delivery.pushStatus || 'unavailable', delivery.sent || 0, delivery.pushErrors?.join(',') || '');
  } catch {
    console.error('Mystery egg reminder push unavailable; reminder saved to everyone’s inbox.');
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
