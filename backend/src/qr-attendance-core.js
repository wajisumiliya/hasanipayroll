import crypto from 'node:crypto';
export const hashQr = value => crypto.createHash('sha256').update(value).digest('hex');
export const credential = () => 'HBQR1_' + crypto.randomBytes(32).toString('base64url');
export const validQr = value => /^HBQR1_[A-Za-z0-9_-]{43}$/.test(value);
export const validUuid = value => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value??''));
export const dayMY = value => new Date(new Date(value).getTime()+8*3600000).toISOString().slice(0,10);
export const clockMY = value => new Date(new Date(value).getTime()+8*3600000).toISOString().slice(11,19);
export const bool = value => value===true || String(value).toLowerCase()==='true';
export class QrError extends Error {
  constructor(code,message,status=409) { super(message);this.code=code;this.status=status; }
}
export function nextPunch(last,now,policy) {
  const date = dayMY(now);
  if (last) {
    const elapsed = new Date(now)-new Date(last.scanned_at);
    if (elapsed < policy.min_interval_seconds*1000) throw new QrError('RAPID_SCAN','Rapid repeated scan blocked. Wait before scanning again.',429);
    if (last.action==='IN') {
      if (String(last.branch_id).toUpperCase()!==String(policy.branch_id).toUpperCase()) throw new QrError('OPEN_OTHER_BRANCH','An open session belongs to another branch. Request an administrator correction.');
      if (elapsed > policy.max_open_hours*3600000) throw new QrError('AMBIGUOUS_SESSION','An older IN has no OUT. Request a supervisor correction before scanning.');
      return {action:'OUT',work_date:String(last.work_date).slice(0,10),paired_event_id:last.raw_id??null};
    }
    if (!policy.allow_multiple_sessions && String(last.work_date).slice(0,10)===date) throw new QrError('DAY_COMPLETE','This station permits one session per work date.');
  }
  return {action:'IN',work_date:date,paired_event_id:null};
}
// Clock pairs in the existing sheet are BREAK intervals, not work sessions.
// Working IN/OUT cover the day; extra breaks require manual review to avoid
// populating overtime fields without an existing OT approval.
export function attendanceProposal(events) {
  const ordered=[...events].sort((a,b)=>new Date(a.scanned_at)-new Date(b.scanned_at)||String(a.event_key).localeCompare(String(b.event_key)));
  const fingerprint=hashQr(JSON.stringify(ordered.map(e=>[e.event_key,e.action,new Date(e.scanned_at).toISOString(),e.correction_id??null])));
  if (!ordered.length) return {valid:false,issues:['No punches'],fingerprint};
  const issues=[];
  for (let i=0;i<ordered.length;i++) {
    if (ordered[i].action!==(i%2?'OUT':'IN')) issues.push('Non-alternating IN/OUT sequence');
    if (i && new Date(ordered[i].scanned_at)<=new Date(ordered[i-1].scanned_at)) issues.push('Overlapping or equal punch timestamps');
  }
  if (ordered.length%2) issues.push('Missing OUT');
  if (ordered.length>6) issues.push('More than two breaks requires manual Attendance Sheet review');
  if (new Date(ordered.at(-1).scanned_at)-new Date(ordered[0].scanned_at)>=24*3600000) issues.push('Workday spans 24 hours or more; sheet clock times are ambiguous');
  if (issues.length) return {valid:false,issues:[...new Set(issues)],fingerprint};
  const gross=Math.floor((new Date(ordered.at(-1).scanned_at)-new Date(ordered[0].scanned_at))/60000);
  let net=0;
  for(let i=0;i<ordered.length;i+=2) net+=(new Date(ordered[i+1].scanned_at)-new Date(ordered[i].scanned_at))/60000;
  net=Math.floor(net);
  const fields={check_in:clockMY(ordered[0].scanned_at),check_out:clockMY(ordered.at(-1).scanned_at),
    work_minutes:gross,net_working_minutes:net,break_minutes:gross-net};
  const slots=[['morning_in','morning_out'],['afternoon_in','afternoon_out']];
  for(let i=0;i<slots.length;i++) {
    fields[slots[i][0]]=ordered[2*i+1]&&ordered[2*i+2]?clockMY(ordered[2*i+1].scanned_at):null;
    fields[slots[i][1]]=ordered[2*i+1]&&ordered[2*i+2]?clockMY(ordered[2*i+2].scanned_at):null;
  }
  return {valid:true,issues:[],fingerprint,fields};
}

export function newWorkDate(now,previousRoster) {
  const day=dayMY(now);
  if (!previousRoster || ['OFF','MC','AL','EL','PL','UNPAID','UL','UL-UNPAID','PH-OFF'].includes(String(previousRoster.assignment_type??'').toUpperCase())) return day;
  const parse=value=>{const m=/^(\d{1,2}):(\d{2})/.exec(String(value??''));return m&&+m[1]<24&&+m[2]<60?+m[1]*60 + +m[2]:null;};
  const start=parse(previousRoster.shift_start),end=parse(previousRoster.shift_end),actual=parse(clockMY(now));
  if (start!=null&&end!=null&&end<start&&actual<=end) return new Date(Date.parse(day)-86400000).toISOString().slice(0,10);
  return day;
}
