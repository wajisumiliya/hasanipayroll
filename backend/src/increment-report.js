import {renderLateReport} from './late-report-export.js';

const key = value => String(value ?? '').trim().toUpperCase();
const money = value => Math.round((value + Number.EPSILON) * 100) / 100;
const fields = ['basic_salary', 'elaun_kedatangan', 'elaun_perkhidmatan', 'elaun_kerajinan'];
const monthKey = (year, month) => year * 12 + month;
function periodKey(value) {
  const match = /^(\d{4})-(\d{2})(?:-|$)/.exec(String(value ?? ''));
  if (!match || Number(match[2]) < 1 || Number(match[2]) > 12) return null;
  return monthKey(Number(match[1]), Number(match[2]));
}
function amounts(row) {
  const values = fields.map(field => Number(row[field] ?? 0));
  return values.every(value => Number.isFinite(value) && value >= 0) ? values : null;
}
export function incrementEligibility(value, year, month) {
  const text = key(value);
  const match = /^([A-Z]{3,4})[-/](\d{4}|\d{2})(?:\D|$)/.exec(text);
  const months = {JAN:1,FEB:2,MAR:3,APR:4,MAY:5,JUN:6,JUL:7,AUG:8,SEP:9,SEPT:9,OCT:10,NOV:11,DEC:12};
  if (!match) return null;
  const scheduleYear = Number(match[2]) + (match[2].length === 2 ? 2000 : 0);
  const separator = text.lastIndexOf('/');
  const amount = separator < 0 ? NaN : Number(text.slice(separator + 1).trim());
  const lastMonth = months[match[1]];
  if (!lastMonth) return null;
  const dueKey = monthKey(scheduleYear,lastMonth) + 6;
  if (dueKey !== monthKey(year,month)) return null;
  const dueDate = new Date(Date.UTC(scheduleYear,lastMonth - 1 + 6,1)).toISOString().slice(0,10);
  return {last_increment_month:`${scheduleYear}-${String(lastMonth).padStart(2,'0')}-01`,eligible_from:dueDate,
    last_amount:Number.isFinite(amount) && separator >= 0 && text.slice(separator+1).trim() !== '' && amount >= 0 ? amount : null};
}

// Keep the established increment basis: positive changes in each of the four
// salary fields against their highest normal values over seven prior months.
// Unlike the display helper, retain non-RM50 changes so exceptions cannot vanish.
export function payrollIncrementEvidence(history, year, month) {
  const selected = monthKey(year, month);
  const currentRows = history.filter(row => periodKey(row.period) === selected);
  if (!currentRows.length) return {state:'no_payroll', actual:null, previous_total:null, current_total:null};
  if (currentRows.length !== 1) return {state:'duplicate_payroll', actual:null, previous_total:null, current_total:null};
  const current = amounts(currentRows[0]);
  if (!current) return {state:'invalid_payroll', actual:null, previous_total:null, current_total:null};
  const previous = history.filter(row => {
    const period = periodKey(row.period);
    return period != null && period >= selected - 7 && period < selected;
  }).map(amounts).filter(Boolean);
  const currentTotal = money(current.reduce((sum, value) => sum + value, 0));
  if (!previous.length) return {state:'no_baseline', actual:null, previous_total:null, current_total:currentTotal};
  const baseline = fields.map((_, index) => Math.max(...previous.map(values => values[index])));
  return {state:'compared', actual:money(current.reduce((sum, value, index) => sum + Math.max(0, value - baseline[index]), 0)),
    previous_total:money(baseline.reduce((sum, value) => sum + value, 0)), current_total:currentTotal,
    previous_fields:Object.fromEntries(fields.map((field, index) => [field, baseline[index]])),
    current_fields:Object.fromEntries(fields.map((field, index) => [field, current[index]]))};
}

export function buildIncrementReport({employees, payroll, year, month, mode, branchId='', staffScope=''}) {
  const histories = new Map();
  for (const row of payroll) {
    const id = key(row.employee_id);
    if (!histories.has(id)) histories.set(id, []);
    histories.get(id).push(row);
  }
  const rows = [];
  for (const employee of employees) {
    const id = key(employee.employee_id);
    if (!id || (branchId && key(employee.branch_id) !== key(branchId))) continue;
    const foreign = key(employee.address).includes('FRN');
    if ((staffScope === 'local' && foreign) || (staffScope === 'foreign' && !foreign)) continue;
    const eligibility = key(employee.is_active) === 'TRUE' ? incrementEligibility(employee.inc_details, year, month) : null;
    const salaryValue=value=>value==null?null:(Number.isFinite(Number(value))&&Number(value)>=0?Number(value):null);
    const allowanceFields=['elaun_kedatangan','elaun_perkhidmatan','elaun_kerajinan','elaun_makanan'];
    const basicSalary=salaryValue(employee.basic_salary);
    const totalAllowances=allowanceFields.some(field=>Object.hasOwn(employee,field))?money(allowanceFields.reduce((sum,field)=>sum+(salaryValue(employee[field])??0),0)):null;
    const evidence = payrollIncrementEvidence(histories.get(id) ?? [], year, month);
    let result;
    if (mode === 'eligible') {
      if (!eligibility) continue;
      result = 'Eligible';
    } else {
      if (!eligibility && (evidence.state === 'no_payroll' || (evidence.state === 'compared' && evidence.actual === 0))) continue;
      if (evidence.state === 'no_payroll') result = 'Payroll not generated';
      else if (evidence.state === 'no_baseline') result = 'Review: no prior payroll';
      else if (evidence.state === 'duplicate_payroll') result = 'Review: duplicate payroll';
      else if (evidence.state === 'invalid_payroll') result = 'Review: invalid salary';
      else if (!eligibility) result = 'Additional: not eligible';
      else if (evidence.actual === 0) result = 'Not received';
      else result = 'Received';
    }
    rows.push({employee_id:id,name:employee.name ?? id,branch_id:employee.branch_id ?? '',
      eligible:eligibility != null,last_increment_month:eligibility?.last_increment_month??null,eligible_from:eligibility?.eligible_from??null,
      basic_salary:basicSalary,total_allowances:totalAllowances,...evidence,result});
  }
  rows.sort((a,b) => a.result.localeCompare(b.result) || key(a.branch_id).localeCompare(key(b.branch_id)) || key(a.name).localeCompare(key(b.name)));
  const counts = {};
  for (const row of rows) counts[row.result] = (counts[row.result] ?? 0) + 1;
  return {reports:rows,counts,eligible_count:rows.filter(row => row.eligible).length,
    basic_total:rows.some(row=>row.basic_salary==null)?null:money(rows.reduce((sum,row)=>sum+row.basic_salary,0)),
    allowance_total:rows.some(row=>row.total_allowances==null)?null:money(rows.reduce((sum,row)=>sum+row.total_allowances,0)),
    actual_total:money(rows.reduce((sum,row) => sum + (row.actual ?? 0),0))};
}

export function installIncrementReportApi(app, {authenticate, pool, renderExport=renderLateReport}) {
  app.get('/api/payroll/increment-report', authenticate, async (req,res) => {
    const scope = req.auth?.app_metadata?.staff_scope ?? '';
    if (key(req.user?.role) !== 'ADMIN' || req.auth?.app_metadata?.is_reviewer || ['requests','attendance'].includes(scope))
      return res.status(403).json({ok:false,message:'Payroll administrator access required.'});
    const year = Number(req.query.year), month = Number(req.query.month), mode = String(req.query.mode ?? '');
    const branchId = String(req.query.branch_id ?? '').trim(), format = String(req.query.format ?? '');
    if (!Number.isInteger(year) || year < 2000 || year > 2100 || !Number.isInteger(month) || month < 1 || month > 12 ||
        !['eligible','comparison'].includes(mode) || !['','pdf'].includes(format) || branchId.length > 100)
      return res.status(400).json({ok:false,message:'Invalid increment report selection.'});
    try {
      const [employeeRows, payrollRows, branchRows] = await Promise.all([
        pool.query(`SELECT e.employee_id, e.name, e.branch_id, e.is_active, e.address, d.inc_details,d.basic_salary,d.elaun_kedatangan,d.elaun_perkhidmatan,d.elaun_kerajinan,d.elaun_makanan
          FROM public.employees e LEFT JOIN public.employee_salary_defaults d ON d.employee_id=e.employee_id`),
        pool.query(`SELECT employee_id, period::text, basic_salary, elaun_kedatangan, elaun_perkhidmatan, elaun_kerajinan
          FROM public.payroll WHERE period >= (make_date($1,$2,1) - INTERVAL '7 months')::date
          AND period < (make_date($1,$2,1) + INTERVAL '1 month') ORDER BY period`, [year,month]),
        pool.query('SELECT id,name FROM public.branches'),
      ]);
      const branches = Object.fromEntries(branchRows.rows.map(row => [key(row.id),row.name]));
      if (branchId && !Object.hasOwn(branches,key(branchId))) return res.status(400).json({ok:false,message:'Unknown branch.'});
      const report = buildIncrementReport({employees:employeeRows.rows,payroll:payrollRows.rows,year,month,mode,branchId,staffScope:scope});
      const payload = {...report,year,month,mode,branches,branchLabel:branchId ? branches[key(branchId)] : 'All branches'};
      if (format === 'pdf') {
        const bytes = await renderExport({...payload,format:'pdf',view:'increment-summary'});
        return res.json({ok:true,file_base64:bytes.toString('base64')});
      }
      return res.json({ok:true,...payload});
    } catch (error) {
      console.error('INCREMENT REPORT ERROR:',error.message);
      return res.status(503).json({ok:false,message:'Unable to load increment report. Please retry.'});
    }
  });
}
