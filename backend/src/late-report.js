// One occurrence per late arrival and per exceeded daily break allowance.
const nonWorking = new Set(['OFF','MC','PL','AL','EL','PH','PH-OFF','PH-SPL','UNPAID']);
const key = (...parts) => parts.map(v => String(v ?? '').trim().toUpperCase()).join('|');
const dateOnly = v => String(v ?? '').slice(0, 10);
function clock(value) {
  const match = /^(\d{1,2}):(\d{2})(?::\d{2})?$/.exec(String(value ?? '').trim());
  if (!match || +match[1] > 23 || +match[2] > 59) return null;
  return +match[1] * 60 + +match[2];
}
function duration(start, end) {
  const a = clock(start), b = clock(end);
  return a == null || b == null ? null : (b - a + 1440) % 1440;
}
export function buildLateReport({ attendance, daily, monthly, employees, year, month }) {
  const prefix = `${year}-${String(month).padStart(2, '0')}-`;
  const dailyByKey = new Map(daily.map(r => [key(r.branch_id,r.employee_id,dateOnly(r.roster_date)),r]));
  const weeklyByKey = new Map(monthly.filter(r => +r.roster_year === year && +r.roster_month === month)
    .map(r => [key(r.branch_id,r.employee_id,r.week_number),r]));
  const names = new Map(employees.map(r => [key(r.employee_id),r.name]));
  const grouped = new Map();
  let missingSchedules = 0;
  const missingByBranch = {};
  const seen = new Set();
  for (const row of attendance) {
    const date = dateOnly(row.attendance_date);
    if (!date.startsWith(prefix)) continue;
    const identity = key(row.branch_id,row.employee_id,date);
    if (seen.has(identity)) continue;
    seen.add(identity);
    const roster = dailyByKey.get(identity) ?? weeklyByKey.get(key(row.branch_id,row.employee_id,Math.floor((+date.slice(8)-1)/7)+1));
    if (nonWorking.has(key(row.status)) || nonWorking.has(key(roster?.assignment_type))) continue;
    const actual = clock(row.check_in ?? row.working_in);
    const pairs = [['morning_in','morning_out'],['afternoon_in','afternoon_out'],['overtime_in','overtime_out']];
    const measured = pairs.map(([a,b]) => duration(row[a],row[b]));
    const hasBreak = measured.some(v => v != null) || row.break_minutes != null;
    if (actual == null && !hasBreak) continue;
    if (!roster || clock(roster.shift_start) == null || roster.break_minutes == null) {
      missingSchedules++;
      missingByBranch[row.branch_id] = (missingByBranch[row.branch_id] ?? 0) + 1;
      continue;
    }
    const shift = clock(roster.shift_start);
    // A near-midnight arrival belongs to an overnight shift, not a 23-hour delay.
    let delay = actual == null ? 0 : actual - shift;
    const shiftEnd = clock(roster.shift_end);
    if (shiftEnd != null && shiftEnd < shift && actual != null && actual <= shiftEnd) delay += 1440;
    const breaks = measured.some(v => v != null)
      ? measured.reduce((sum,v) => sum + (v ?? 0),0)
      : Math.max(0,Number(row.break_minutes) || 0);
    const allocated = Math.max(0,Number(roster.break_minutes) || 0);
    const events = [];
    if (delay > 0) events.push({date,type:'arrival',minutes:delay,scheduled:roster.shift_start,actual:row.check_in ?? row.working_in});
    if (breaks > allocated) events.push({date,type:'break',minutes:breaks-allocated,allocated_minutes:allocated,actual_minutes:breaks});
    if (!events.length) continue;
    const groupKey = key(row.branch_id,row.employee_id);
    if (!grouped.has(groupKey)) grouped.set(groupKey,{
      branch_id:row.branch_id,employee_id:row.employee_id,
      name:names.get(key(row.employee_id)) ?? row.employee_id,events:[]});
    grouped.get(groupKey).events.push(...events);
  }
  const reports = [...grouped.values()].map(r => ({...r,
    events:r.events.sort((a,b)=>a.date.localeCompare(b.date)||a.type.localeCompare(b.type)),
    arrival_count:r.events.filter(e=>e.type==='arrival').length,
    break_count:r.events.filter(e=>e.type==='break').length,
    count:r.events.length,total_minutes:r.events.reduce((sum,e)=>sum+e.minutes,0),
  })).filter(r=>r.count>=3).sort((a,b)=>String(a.branch_id).localeCompare(String(b.branch_id))||b.count-a.count||String(a.name).localeCompare(String(b.name)));
  return {reports,missing_schedules:missingSchedules,missing_schedules_by_branch:missingByBranch,threshold:3};
}

export function installLateReportApi(app, { authenticate, pool }) {
  app.get('/api/attendance/late-report', authenticate, async (req,res) => {
    if (String(req.user?.role ?? '').toUpperCase() !== 'ADMIN') return res.status(403).json({ok:false,message:'Administrator access required.'});
    const year = Number(req.query.year), month = Number(req.query.month);
    if (!Number.isInteger(year)||year<2000||year>2100||!Number.isInteger(month)||month<1||month>12) return res.status(400).json({ok:false,message:'Invalid report month.'});
    const start = `${year}-${String(month).padStart(2,'0')}-01`;
    try {
      const [attendance,daily,monthly,employees] = await Promise.all([
        pool.query("SELECT to_jsonb(a) AS data FROM public.attendance a WHERE attendance_date >= $1::date AND attendance_date < ($1::date + INTERVAL '1 month') ORDER BY attendance_date, id",[start]),
        pool.query("SELECT to_jsonb(r) AS data FROM public.daily_rosters r WHERE roster_date >= $1::date AND roster_date < ($1::date + INTERVAL '1 month')",[start]),
        pool.query('SELECT to_jsonb(r) AS data FROM public.monthly_rosters r WHERE roster_year=$1 AND roster_month=$2',[year,month]),
        pool.query('SELECT employee_id,name FROM public.employees'),
      ]);
      return res.json({ok:true,...buildLateReport({attendance:attendance.rows.map(r=>r.data),daily:daily.rows.map(r=>r.data),monthly:monthly.rows.map(r=>r.data),employees:employees.rows,year,month})});
    } catch (error) {
      console.error('LATE REPORT ERROR:',error.message);
      return res.status(503).json({ok:false,message:'Unable to load late report. Please retry.'});
    }
  });
}
