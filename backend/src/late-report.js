import { createHash } from 'node:crypto';

const nonWorking = new Set(['OFF', 'MC', 'PL', 'AL', 'EL', 'PH', 'PH-OFF', 'PH-SPL', 'UNPAID']);
const key = (...parts) => parts.map(v => String(v ?? '').trim().toUpperCase()).join('|');
const dateOnly = v => String(v ?? '').slice(0, 10);
const present = v => v != null && !['', '-', '--', '--:--'].includes(String(v).trim());
const statuses = new Set(['noted', 'approved', 'correction_required', 'pending']);
const reasons = new Set(['transport', 'approved_late', 'attendance_error', 'other']);
function clock(value) {
  const match = /^(\d{1,2}):(\d{2})(?::\d{2})?$/.exec(String(value ?? '').trim());
  if (!match || +match[1] > 23 || +match[2] > 59) return null;
  return +match[1] * 60 + +match[2];
}
function duration(start, end) {
  const a = clock(start), b = clock(end);
  return a == null || b == null ? null : (b - a + 1440) % 1440;
}
function validAllowance(value) {
  return present(value) && Number.isFinite(Number(value)) && Number(value) >= 0 && Number(value) <= 1440;
}
export function lateSeverity(count) {
  return count >= 7 ? 'high' : count >= 5 ? 'medium' : 'low';
}
function fingerprint(event) {
  return createHash('sha256').update(JSON.stringify(event)).digest('hex');
}

// Threshold applies per employee/recorded branch. Reviews never change raw totals.
export function buildLateReport({ attendance, daily, monthly, employees, year, month, reviews = [], minimum = 3 }) {
  const prefix = `${year}-${String(month).padStart(2, '0')}-`;
  const dailyByKey = new Map(daily.map(r => [key(r.branch_id, r.employee_id, dateOnly(r.roster_date)), r]));
  const weeklyByKey = new Map(monthly.filter(r => +r.roster_year === year && +r.roster_month === month)
    .map(r => [key(r.branch_id, r.employee_id, r.week_number), r]));
  const names = new Map(employees.map(r => [key(r.employee_id), r.name]));
  const reviewByKey = new Map();
  for (const review of reviews) {
    const id = key(review.branch_id, review.employee_id, dateOnly(review.event_date), review.event_type);
    if (!reviewByKey.has(id)) reviewByKey.set(id, []);
    reviewByKey.get(id).push(review);
  }
  for (const history of reviewByKey.values()) history.sort((a, b) => Number(b.id) - Number(a.id));
  const grouped = new Map(), missingRecords = [], seen = new Set();
  const missingByBranch = {};
  for (const row of attendance) {
    const date = dateOnly(row.attendance_date);
    if (!date.startsWith(prefix)) continue;
    const identity = key(row.branch_id, row.employee_id, date);
    if (seen.has(identity)) continue;
    seen.add(identity);
    const roster = dailyByKey.get(identity) ?? weeklyByKey.get(key(row.branch_id, row.employee_id, Math.floor((+date.slice(8) - 1) / 7) + 1));
    if (nonWorking.has(key(row.status)) || nonWorking.has(key(roster?.assignment_type))) continue;
    const actual = clock(row.check_in ?? row.working_in);
    const pairs = [['morning_in', 'morning_out'], ['afternoon_in', 'afternoon_out'], ['overtime_in', 'overtime_out']];
    const measured = pairs.map(([a, b]) => duration(row[a], row[b]));
    const incompleteBreak = pairs.some(([a, b]) => (present(row[a]) || present(row[b])) && duration(row[a], row[b]) == null);
    if (key(row.status) === 'ABSENT' && actual == null && !pairs.some(([a, b]) => present(row[a]) || present(row[b])) && !Number(row.break_minutes)) continue;
    // Completely blank days are not evidence of a missing working-day record.
    if (actual == null && !present(row.check_out) && !present(row.status) &&
        !pairs.some(([a, b]) => present(row[a]) || present(row[b])) && !Number(row.break_minutes)) continue;
    const issues = [];
    if (!roster) issues.push('Missing roster');
    else {
      if (clock(roster.shift_start) == null) issues.push('Missing or invalid shift start');
      if (!validAllowance(roster.break_minutes)) issues.push('Missing or invalid break allowance');
    }
    if (actual == null) issues.push('Missing or invalid check-in');
    if (incompleteBreak) issues.push('Incomplete break start/end');
    const hasPairs = measured.some(v => v != null);
    const hasBreakTotal = validAllowance(row.break_minutes);
    if (!hasPairs && !hasBreakTotal && !incompleteBreak) issues.push('Missing break duration');
    if (issues.length) {
      missingRecords.push({ branch_id: row.branch_id, employee_id: row.employee_id,
        name: names.get(key(row.employee_id)) ?? row.employee_id, date, issues });
      missingByBranch[row.branch_id] = (missingByBranch[row.branch_id] ?? 0) + 1;
    }
    const shift = clock(roster?.shift_start);
    let delay = actual == null || shift == null ? 0 : actual - shift;
    const shiftEnd = clock(roster?.shift_end);
    if (shift != null && shiftEnd != null && shiftEnd < shift && actual != null && actual <= shiftEnd) delay += 1440;
    const breaks = hasPairs ? measured.reduce((sum, v) => sum + (v ?? 0), 0) : Number(row.break_minutes);
    const events = [];
    if (delay > 0) events.push({ date, type: 'arrival', minutes: delay, scheduled: roster.shift_start, actual: row.check_in ?? row.working_in });
    if (roster && validAllowance(roster.break_minutes) && !incompleteBreak && (hasPairs || hasBreakTotal) && breaks > +roster.break_minutes) {
      events.push({ date, type: 'break', minutes: breaks - +roster.break_minutes, allocated_minutes: +roster.break_minutes, actual_minutes: breaks });
    }
    if (!events.length) continue;
    for (const event of events) {
      event.fingerprint = fingerprint({ branch_id: row.branch_id, employee_id: row.employee_id, ...event });
      const history = reviewByKey.get(key(row.branch_id, row.employee_id, date, event.type)) ?? [];
      event.review_history = history;
      // Latest revision applies only to the exact recorded timing reviewed.
      event.review = history[0]?.event_fingerprint === event.fingerprint ? history[0] : null;
      event.review_outdated = history.length > 0 && !event.review;
    }
    const groupKey = key(row.branch_id, row.employee_id);
    if (!grouped.has(groupKey)) grouped.set(groupKey, { branch_id: row.branch_id, employee_id: row.employee_id,
      name: names.get(key(row.employee_id)) ?? row.employee_id, events: [] });
    grouped.get(groupKey).events.push(...events);
  }
  const reports = [...grouped.values()].map(r => ({ ...r,
    events: r.events.sort((a, b) => a.date.localeCompare(b.date) || a.type.localeCompare(b.type)),
    arrival_count: r.events.filter(e => e.type === 'arrival').length,
    break_count: r.events.filter(e => e.type === 'break').length,
    count: r.events.length, severity: lateSeverity(r.events.length),
    total_minutes: r.events.reduce((sum, e) => sum + e.minutes, 0),
  })).filter(r => r.count >= minimum).sort((a, b) => String(a.branch_id).localeCompare(String(b.branch_id)) || b.count - a.count || String(a.name).localeCompare(String(b.name)));
  return { reports, missing_records: missingRecords, missing_schedules: missingRecords.length,
    missing_schedules_by_branch: missingByBranch, threshold: 3 };
}

async function loadPeriod(pool, year, month) {
  const start = `${year}-${String(month).padStart(2, '0')}-01`;
  const [attendance, daily, monthly, employees, reviews] = await Promise.all([
    pool.query("SELECT to_jsonb(a) AS data FROM public.attendance a WHERE attendance_date >= $1::date AND attendance_date < ($1::date + INTERVAL '1 month') ORDER BY attendance_date, id", [start]),
    pool.query("SELECT to_jsonb(r) AS data FROM public.daily_rosters r WHERE roster_date >= $1::date AND roster_date < ($1::date + INTERVAL '1 month')", [start]),
    pool.query('SELECT to_jsonb(r) AS data FROM public.monthly_rosters r WHERE roster_year=$1 AND roster_month=$2', [year, month]),
    pool.query('SELECT employee_id,name FROM public.employees'),
    pool.query("SELECT id,branch_id,employee_id,event_date::text,event_type,event_fingerprint,event_snapshot,status,reason_code,reason,reviewed_by,reviewed_at FROM app_private.late_report_reviews WHERE event_date >= $1::date AND event_date < ($1::date + INTERVAL '1 month') ORDER BY id DESC", [start]),
  ]);
  return buildLateReport({ attendance: attendance.rows.map(r => r.data), daily: daily.rows.map(r => r.data),
    monthly: monthly.rows.map(r => r.data), employees: employees.rows, reviews: reviews.rows, year, month, minimum: 0 });
}
const admin = req => String(req.user?.role ?? '').toUpperCase() === 'ADMIN' &&
  !req.auth?.app_metadata?.is_reviewer && req.auth?.app_metadata?.staff_scope !== 'requests';
const validPeriod = (year, month) => Number.isInteger(year) && year >= 2000 && year <= 2100 && Number.isInteger(month) && month >= 1 && month <= 12;

export function installLateReportApi(app, { authenticate, pool }) {
  app.get('/api/attendance/late-report', authenticate, async (req, res) => {
    if (!admin(req)) return res.status(403).json({ ok: false, message: 'Administrator access required.' });
    const year = Number(req.query.year), month = Number(req.query.month);
    if (!validPeriod(year, month)) return res.status(400).json({ ok: false, message: 'Invalid report month.' });
    try {
      const previousDate = new Date(Date.UTC(year, month - 2, 1));
      const [current, previous] = await Promise.all([loadPeriod(pool, year, month), loadPeriod(pool, previousDate.getUTCFullYear(), previousDate.getUTCMonth() + 1)]);
      const oldCounts = new Map(previous.reports.map(r => [key(r.branch_id, r.employee_id), r.count]));
      const reports = current.reports.filter(r => r.count >= 3).map(r => ({ ...r,
        previous_count: oldCounts.get(key(r.branch_id, r.employee_id)) ?? 0,
        change: r.count - (oldCounts.get(key(r.branch_id, r.employee_id)) ?? 0) }));
      return res.json({ ok: true, ...current, reports,
        previous_period: { year: previousDate.getUTCFullYear(), month: previousDate.getUTCMonth() + 1 },
        previous_missing_records: previous.missing_records });
    } catch (error) {
      console.error('LATE REPORT ERROR:', error.message);
      return res.status(503).json({ ok: false, message: 'Unable to load late report. Please retry.' });
    }
  });

  app.post('/api/attendance/late-report/reviews', authenticate, async (req, res) => {
    if (!admin(req)) return res.status(403).json({ ok: false, message: 'Administrator access required.' });
    const body = req.body ?? {};
    const date = String(body.date ?? '');
    const parsed = new Date(`${date}T00:00:00Z`);
    const reviewer = String(req.user.username ?? req.user.id ?? '').trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== date ||
        !validPeriod(parsed.getUTCFullYear(), parsed.getUTCMonth() + 1) ||
        !['arrival', 'break'].includes(body.type) || !statuses.has(body.status) || !reasons.has(body.reason_code) ||
        typeof body.reason !== 'string' || body.reason.trim().length < 3 || body.reason.trim().length > 1000 ||
        typeof body.branch_id !== 'string' || !body.branch_id.trim() || body.branch_id.length > 100 ||
        typeof body.employee_id !== 'string' || !body.employee_id.trim() || body.employee_id.length > 100 ||
        !/^[a-f0-9]{64}$/.test(String(body.fingerprint ?? ''))) {
      return res.status(400).json({ ok: false, message: 'Provide a valid event, review status, reason category, and reason (3–1000 characters).' });
    }
    if (!reviewer) return res.status(403).json({ ok: false, message: 'Reviewer identity is missing. Sign in again.' });
    try {
      const report = await loadPeriod(pool, parsed.getUTCFullYear(), parsed.getUTCMonth() + 1);
      const person = report.reports.find(r => key(r.branch_id, r.employee_id) === key(body.branch_id, body.employee_id));
      const event = person?.events.find(e => e.date === date && e.type === body.type);
      if (!event || event.fingerprint !== body.fingerprint) return res.status(409).json({ ok: false, message: 'Attendance has changed. Refresh the report before reviewing this event.' });
      const { review, review_history, review_outdated, ...snapshot } = event;
      const result = await pool.query(`INSERT INTO app_private.late_report_reviews
        (branch_id,employee_id,event_date,event_type,event_fingerprint,event_snapshot,status,reason_code,reason,reviewed_by)
        VALUES ($1,$2,$3::date,$4,$5,$6::jsonb,$7,$8,$9,$10) RETURNING id,reviewed_by,reviewed_at`,
      [person.branch_id, person.employee_id, date, body.type, event.fingerprint, JSON.stringify(snapshot), body.status, body.reason_code, body.reason.trim(), reviewer]);
      return res.json({ ok: true, review: result.rows[0] });
    } catch (error) {
      console.error('LATE REVIEW ERROR:', error.message);
      return res.status(503).json({ ok: false, message: 'Unable to save review. Please retry.' });
    }
  });
}
