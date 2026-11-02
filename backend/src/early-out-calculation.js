import {createHash} from 'node:crypto';
export const key=v=>String(v??'').trim().toUpperCase();
export const truth=v=>v===true||['TRUE','YES','1'].includes(key(v));
export function minutes(value){
 const m=/^(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?\s*(AM|PM)?$/i.exec(String(value??'').trim());
 if(!m||+m[2]>59||(m[3]!=null&&+m[3]>59))return null;
 let h=+m[1];if(m[4]){if(h<1||h>12)return null;h=h%12+(m[4].toUpperCase()==='PM'?12:0);}else if(h>23)return null;
 return h*60 + +m[2];
}
const clockText=v=>v==null?'':`${String(Math.floor(v/60)).padStart(2,'0')}:${String(v%60).padStart(2,'0')}`;

export function earlyOutEvent({attendance:a,employee:e,salary:s={},roster:r={},decision=null}){
 const start=minutes(r.shift_start??a.scheduled_shift_start),end=minutes(r.shift_end??a.scheduled_shift_end),out=minutes(a.check_out??a.working_out);
 const incomplete=end==null||out==null;
 if(incomplete&&!key(a.status).includes('EARLY OUT'))return null;
 let early=incomplete?0:end-out;if(early < -720)early+=1440;if(!incomplete&&(early<=0||early>720))return null;
 const required=start!=null&&end!=null?(((end-start+1440)%1440)||1440)-Number(r.break_minutes??0):key(s.epf_category)==='NORMAL1'||!['FALSE','0','NO','N','NOT APPLICABLE'].includes(key(s.eis_applicable))?450:630;
 const duration=String(a.work_duration??'').split(':');const legacy=duration.length===2?Number(duration[0])*60+Number(duration[1]):Math.round(Number(a.work_duration??0)*60);
 const gross=Number(a.work_minutes??0)>0?Number(a.work_minutes):legacy;
 const worked=Number(a.net_working_minutes??0)>0?Number(a.net_working_minutes):Math.min(1440,Math.max(0,gross-Number(a.break_minutes??0)));
 if(!Number.isFinite(required)||required<=0||required>1440||!Number.isFinite(worked)||worked<0||worked>1440)return null;
 const grace=Math.min(early,15),shortage=Math.max(0,required-worked-grace);
 const exempt=truth(e.is_management_staff)||truth(e.is_temp_staff)||truth(e.is_support_staff)||key(e.employee_id)==='HED1007'||/FRN|FOREIGN/.test(key(e.address)+' '+key(s.address))||truth(a.is_unpaid)||truth(a.is_public_holiday)||['OFF','MC','MEDICAL LEAVE','PL','AL','EL','PH','PH-OFF','PH-SPL','PH-GANTI','PH-GUNTI','UL','UL-UNPAID','UNPAID'].includes(key(a.status))||['OFF','MC','MEDICAL LEAVE','PL','AL','EL','PH','PH-OFF','PH-SPL','PH-GANTI','UL-UNPAID','UNPAID'].includes(key(r.assignment_type))||worked<=0;
 const attributable=exempt||incomplete?0:Math.min(shortage,Math.max(0,early-grace));
 const evidence={employee_id:e.employee_id,attendance_date:String(a.attendance_date).slice(0,10),branch_id:a.branch_id,
   check_in:clockText(minutes(a.check_in??a.working_in)),check_out:clockText(out),required_minutes:required,worked_minutes:worked,
   shift_start:clockText(start),shift_end:clockText(end),
   break_allowance:Number(r.break_minutes??0),status:a.status,is_unpaid:truth(a.is_unpaid),is_public_holiday:truth(a.is_public_holiday),
   deduction_eligible:!exempt,early_minutes:early,short_hours_minutes:Math.max(0,required-worked),shortage_minutes:exempt?0:shortage,eligible_early_minutes:attributable,is_submitted:truth(a.is_submitted)};
 const fingerprint=createHash('sha256').update(JSON.stringify(evidence)).digest('hex');
 const matched=decision?.fingerprint===fingerprint;
 return {...evidence,review_blocked_reason:incomplete?'Assign a valid shift and checkout before approval.':'',foreign:/FRN|FOREIGN/.test(key(e.address)+' '+key(s.address)),fingerprint,name:e.name??e.employee_id,current_branch_id:e.branch_id,
   approval_status:matched?decision.status:'PENDING',revision:decision?String(decision.id):'0',approval_outdated:!!decision&&!matched,
   approved_minutes:matched&&decision.status==='APPROVED'?Math.min(attributable,Number(decision.approved_minutes)):0,
   approved_by:matched?decision.approver_user_id:null,approver_role:matched?decision.approver_role:null,
   approval_date:matched?decision.approved_at:null,remarks:matched?decision.remarks:'',decision_id:matched?String(decision.id):null};
}
export function buildEarlyOutEvents({attendance,employees,salaries=[],daily=[],monthly=[],decisions=[]}){
 const people=new Map(employees.map(e=>[key(e.employee_id),e]));const defaults=new Map(salaries.map(e=>[key(e.employee_id),e]));
 return attendance.map(a=>{
  const e=people.get(key(a.employee_id));if(!e)return null;const date=String(a.attendance_date).slice(0,10),week=Math.floor((+date.slice(8)-1)/7)+1;
  const roster=daily.find(r=>key(r.employee_id)===key(a.employee_id)&&key(r.branch_id)===key(a.branch_id)&&String(r.roster_date).slice(0,10)===date)
    ??monthly.find(r=>key(r.employee_id)===key(a.employee_id)&&key(r.branch_id)===key(a.branch_id)&&Number(r.week_number)===week);
  const history=decisions.filter(d=>key(d.employee_id)===key(a.employee_id)&&String(d.attendance_date).slice(0,10)===date).sort((x,y)=>Number(y.id)-Number(x.id));
  return earlyOutEvent({attendance:a,employee:e,salary:defaults.get(key(a.employee_id)),roster,decision:history[0]});
 }).filter(Boolean);
}
export function approverRole(req){
 if(req.auth?.app_metadata?.is_reviewer||req.auth?.app_metadata?.staff_scope==='requests')return null;
 const role=key(req.user?.role);if(['ACCOUNTS','ACCOUNT'].includes(role))return 'ACCOUNTS';
 if(role!=='ADMIN')return null;
 return req.auth?.app_metadata?.staff_scope==='attendance'||['ACCOUNT','ACCOUNT@ATTENDANCE.LOCAL'].includes(key(req.user?.username))?'ACCOUNTS':'ADMIN';
}
