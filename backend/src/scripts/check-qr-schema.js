// Read-only preflight. Never creates or migrates production tables.
import 'dotenv/config';
import pg from 'pg';
const baseOnly=process.argv.includes('--base-only');
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL});
try {
  const columns=(await pool.query(`SELECT table_name,column_name,data_type FROM information_schema.columns WHERE table_schema='public'
    AND table_name IN ('employees','attendance','branches','daily_rosters','monthly_rosters','qr_attendance_credentials','qr_attendance_events','qr_attendance_stations','qr_attendance_sessions','qr_attendance_presence','qr_attendance_attempts','qr_attendance_verifications','qr_attendance_corrections','qr_attendance_reconciliations','qr_attendance_audit')`)).rows;
  const required={employees:['employee_id','branch_id','is_active','name','address'],branches:['id','name'],
    attendance:['employee_id','branch_id','attendance_date','check_in','check_out','morning_in','morning_out','afternoon_in','afternoon_out','work_minutes','break_minutes','net_working_minutes','is_submitted','ot_authorized','approved_ot_minutes'],
    daily_rosters:['roster_date','employee_id','branch_id','shift_start','shift_end'],monthly_rosters:['roster_year','roster_month','week_number','employee_id','branch_id'],
    qr_attendance_credentials:['employee_id','token_hash','issued_by','expires_at'],qr_attendance_events:['session_id','request_id','work_date','paired_event_id','verified_by'],
    qr_attendance_stations:['min_interval_seconds','verification_required'],qr_attendance_sessions:['operator','expires_at'],qr_attendance_presence:['employee_id','action','raw_id','event_key'],
    qr_attendance_attempts:['request_id','status','credential_hash'],qr_attendance_verifications:['ticket_hash','used_at'],qr_attendance_corrections:['status','corrected_at'],
    qr_attendance_reconciliations:['source_events','previous_attendance'],qr_attendance_audit:['action','operator']};
  const missing=[];
  for(const [table,fields] of Object.entries(required).filter(([table])=>!baseOnly||!table.startsWith('qr_')))for(const field of fields)if(!columns.some(c=>c.table_name===table&&c.column_name===field))missing.push(table+'.'+field);
  const unique=(await pool.query(`SELECT indexdef FROM pg_indexes WHERE schemaname='public' AND tablename='attendance'`)).rows;
  if(!unique.some(r=>/UNIQUE/.test(r.indexdef)&&/\(employee_id, attendance_date\)/.test(r.indexdef)))missing.push('attendance UNIQUE(employee_id,attendance_date)');
  const times=columns.filter(c=>c.table_name==='attendance'&&['check_in','check_out','morning_in','morning_out','afternoon_in','afternoon_out'].includes(c.column_name));
  if(times.some(c=>!['text','character varying','time without time zone'].includes(c.data_type)))missing.push('attendance clock column types need review');
  const locks=columns.filter(c=>c.table_name==='attendance'&&['is_submitted','ot_authorized'].includes(c.column_name));
  if(locks.some(c=>c.data_type!=='boolean'))missing.push('attendance lock fields must be boolean');
  if(!baseOnly) {
  const effective=(await pool.query("SELECT to_regclass('public.qr_attendance_effective_events') IS NOT NULL AS present")).rows[0].present;
  if(!effective)missing.push('qr_attendance_effective_events view');
  const indexes=(await pool.query("SELECT indexname FROM pg_indexes WHERE schemaname='public' AND tablename LIKE 'qr_attendance_%'")).rows.map(row=>row.indexname);
  for(const name of ['qr_event_request_idx','qr_presence_open_idx','qr_correction_event_latest_idx'])if(!indexes.includes(name))missing.push(name);
  const immutable=(await pool.query("SELECT 1 FROM pg_trigger WHERE tgrelid=to_regclass('public.qr_attendance_events') AND tgname='qr_events_immutable' AND tgenabled IN ('O','A')")).rowCount;
  if(!immutable)missing.push('raw event immutability trigger');
  }
  console.log(JSON.stringify({phase:baseOnly?'existing attendance schema':'QR schema',compatible:!missing.length,review_required:missing},null,2));
  if(missing.length)process.exitCode=1;
} catch(error){console.error('QR schema preflight failed:',error.code??'connection unavailable');process.exitCode=1;}finally{await pool.end();}
