import test from 'node:test';
import assert from 'node:assert/strict';
import {buildIncrementReport, payrollIncrementEvidence, incrementEligibility, installIncrementReportApi} from '../src/increment-report.js';
import {renderLateReport} from '../src/late-report-export.js';

const employee=(id,extra={})=>({employee_id:id,name:`Employee ${id}`,branch_id:'A',is_active:true,inc_details:'APR-26/100',basic_salary:2000,elaun_kedatangan:200,elaun_perkhidmatan:100,elaun_kerajinan:50,elaun_makanan:25,...extra});
const pay=(id,period,basic=2000,extra={})=>({employee_id:id,period,basic_salary:basic,elaun_kedatangan:200,elaun_perkhidmatan:100,elaun_kerajinan:50,...extra});
const build=(employees,payroll,mode='comparison',extra={})=>buildIncrementReport({employees,payroll,mode,year:2026,month:10,...extra});
const response=()=>({code:200,status(code){this.code=code;return this;},json(body){this.body=body;return this;}});

test('eligibility includes only the exact six-month cohort and excludes overdue employees',()=>{
  assert.equal(incrementEligibility('Jan-26/50',2026,6),null);
  assert.deepEqual(incrementEligibility('Jan-26/50',2026,7),{
    last_increment_month:'2026-01-01',eligible_from:'2026-07-01',last_amount:50});
  assert.equal(incrementEligibility('Jan-26/50',2026,10),null);
  assert.equal(incrementEligibility('APR-26/50',2026,10).eligible_from,'2026-10-01');
  assert.equal(incrementEligibility('MAR-26/50',2026,10),null);
  assert.equal(incrementEligibility('SEPT-26/125',2027,2),null);
  assert.equal(incrementEligibility('SEPT-26/125',2027,3).last_amount,125);
  assert.equal(incrementEligibility('JUL/2026/100',2027,1).eligible_from,'2027-01-01');
  assert.equal(incrementEligibility('JAN-26/not recorded',2026,7).last_amount,null);
  for(const value of ['MAY-26/100','JAN-27/100','BAD-26/100','bad',''])
    assert.equal(incrementEligibility(value,2026,10),null);
});

test('eligibility PDF list exists before payroll, scopes branches and excludes inactive employees',()=>{
  const report=build([employee('E1'),employee('E2',{branch_id:'B'}),employee('E3',{is_active:false}),employee('E4',{inc_details:'MAY-26/100'})],[],'eligible',{branchId:'a'});
  assert.deepEqual(report.reports.map(row=>row.employee_id),['E1']);
  assert.equal(report.basic_total,2000);assert.equal(report.allowance_total,375);assert.equal(report.eligible_count,1);
  assert.equal(report.reports[0].result,'Eligible');
});

test('comparison separates paid, missed, different, additional and not-generated payroll',()=>{
  const ids=['MATCH','MISS','LESS','MORE','ADDITIONAL','PENDING','CLEAN'];
  const employees=ids.map(id=>employee(id,{inc_details:['ADDITIONAL','CLEAN'].includes(id)?'MAY-26/100':'APR-26/100'}));
  const rows=ids.map(id=>pay(id,'2026-09-01'));
  for(const [id,increase] of [['MATCH',100],['MISS',0],['LESS',50],['MORE',150],['ADDITIONAL',25],['CLEAN',0]]) rows.push(pay(id,'2026-10-01',2000+increase));
  const report=build(employees,rows);
  const byId=Object.fromEntries(report.reports.map(row=>[row.employee_id,row]));
  assert.equal(byId.MATCH.result,'Received');
  assert.equal(byId.MISS.result,'Not received');
  assert.equal(byId.LESS.result,'Received');assert.equal(byId.LESS.actual,50);
  assert.equal(byId.MORE.result,'Received');assert.equal(byId.MORE.actual,150);
  assert.equal(byId.ADDITIONAL.result,'Additional: not eligible');assert.equal(byId.ADDITIONAL.actual,25);
  assert.equal(byId.PENDING.result,'Payroll not generated');assert.equal(byId.PENDING.actual,null);
  assert.equal(byId.CLEAN,undefined);
  assert.equal(report.eligible_count,5);assert.equal(report.basic_total,12000);assert.equal(report.allowance_total,2250);assert.equal(report.actual_total,325);
});

test('unknown historical amount does not remove date-based eligibility or imply a future award amount',()=>{
  const report=build([employee('E',{inc_details:'APR-26/unknown'})],[pay('E','2026-09-01'),pay('E','2026-10-01',2075)]);
  assert.equal(report.eligible_count,1);
  assert.equal(report.reports[0].result,'Received');
  assert.equal(report.reports[0].basic_salary,2000);
  assert.equal(report.reports[0].total_allowances,375);
  assert.equal(Object.hasOwn(report.reports[0],'last_amount'),false);
  assert.equal(Object.hasOwn(report.reports[0],'expected'),false);
  assert.equal(report.reports[0].eligible_from,'2026-10-01');
});

test('highest prior values ignore partial-pay rebounds and do not let allowance forfeiture hide a basic increment',()=>{
  const history=[pay('E','2026-08-01'),pay('E','2026-09-01',1000,{elaun_kedatangan:0,elaun_perkhidmatan:0}),
    pay('E','2026-10-01',2100,{elaun_kedatangan:0})];
  const evidence=payrollIncrementEvidence(history,2026,10);
  assert.equal(evidence.actual,100);assert.equal(evidence.previous_total,2350);assert.equal(evidence.current_total,2250);
  assert.equal(evidence.previous_fields.elaun_kedatangan,200);
  assert.equal(payrollIncrementEvidence([...history.slice(0,2),pay('E','2026-10-01')],2026,10).actual,0);
});

test('missing history, invalid salary and duplicates are review cases, never assumed paid or missed',()=>{
  for(const eligible of [true,false]) {
    const e=employee('E',{inc_details:eligible?'APR-26/100':'MAY-26/100'});
    for(const [rows,result] of [
      [[pay('E','2026-10-01')],'Review: no prior payroll'],
      [[pay('E','2026-10-01',-1)],'Review: invalid salary'],
      [[pay('E','2026-10-01'),pay('E','2026-10-01')],'Review: duplicate payroll'],
    ]) {
      const row=build([e],rows).reports[0];assert.equal(row.result,result);assert.equal(row.actual,null);
    }
  }
});

test('history uses seven calendar months, handles year rollover, and ignores future payroll',()=>{
  assert.equal(payrollIncrementEvidence([pay('E','2026-02-01'),pay('E','2026-10-01',2100)],2026,10).state,'no_baseline');
  assert.equal(payrollIncrementEvidence([pay('E','2026-03-01'),pay('E','2026-10-01',2100),pay('E','2026-11-01',9000)],2026,10).actual,100);
  assert.equal(payrollIncrementEvidence([pay('E','2026-12-01'),pay('E','2027-01-01',2100)],2027,1).actual,100);
});

test('inactive recipients can still be detected as additional; scopes do not include other employee groups',()=>{
  const employees=[employee('E1',{address:'FRN'}),employee('E2',{is_active:false}),employee('E3',{branch_id:'B'})];
  const payroll=employees.flatMap(e=>[pay(e.employee_id,'2026-09-01'),pay(e.employee_id,'2026-10-01',2100)]);
  const report=build(employees,payroll,'comparison',{staffScope:'local',branchId:'A'});
  assert.equal(report.reports.length,1);assert.equal(report.reports[0].employee_id,'E2');assert.equal(report.reports[0].result,'Additional: not eligible');
});

function api(options={}) {
  let handler;const calls=[];
  installIncrementReportApi({get(path,auth,callback){assert.equal(path,'/api/payroll/increment-report');handler=callback;}},{
    authenticate:()=>{},pool:{query:async(sql,params)=>{
      calls.push({sql,params});
      if(sql.includes('FROM public.employees'))return {rows:[employee('E1')]};
      if(sql.includes('FROM public.payroll'))return {rows:[pay('E1','2026-09-01'),pay('E1','2026-10-01',2100)]};
      return {rows:[{id:'A',name:'ALOR SETAR'}]};
    }},...options});
  return {handler,calls};
}
const query={year:'2026',month:'10',mode:'comparison'};
test('API protects salary reports and validates input before any queries',async()=>{
  const {handler,calls}=api();
  for(const req of [{user:{role:'BRANCH'}},{user:{role:'EMPLOYEE'}},{user:{role:'ADMIN'},auth:{app_metadata:{is_reviewer:true}}},
    ...['requests','attendance'].map(staff_scope=>({user:{role:'ADMIN'},auth:{app_metadata:{staff_scope}}}))]) {
    const res=response();await handler({...req,query},res);assert.equal(res.code,403);
  }
  for(const invalid of [{month:13},{year:'x'},{mode:'raw'},{format:'xlsx'}]) {
    const res=response();await handler({user:{role:'ADMIN'},query:{...query,...invalid}},res);assert.equal(res.code,400);
  }
  assert.equal(calls.length,0);
});

test('API returns fresh comparison and sends the same scoped report to the PDF worker',async()=>{
  let payload;
  const {handler,calls}=api({renderExport:async data=>{payload=data;return Buffer.from('pdf');}});
  const req={user:{role:'ADMIN'},query:{...query,branch_id:'A'}};
  const res=response();await handler(req,res);
  assert.equal(res.body.reports[0].result,'Received');
  assert.match(calls.find(call=>call.sql.includes('FROM public.employees')).sql,/employee_salary_defaults/);
  assert.deepEqual(calls.find(call=>call.sql.includes('FROM public.payroll')).params,[2026,10]);
  const pdf=response();await handler({...req,query:{...req.query,format:'pdf'}},pdf);
  assert.deepEqual(payload.reports,res.body.reports);assert.equal(payload.view,'increment-summary');
  assert.equal(payload.branchLabel,'ALOR SETAR');assert.equal(pdf.body.file_base64,Buffer.from('pdf').toString('base64'));
  const bad=response();await handler({...req,query:{...req.query,branch_id:'unknown'}},bad);assert.equal(bad.code,400);
});

test('API reports database failure instead of inventing an empty eligibility list',async()=>{
  const {handler}=api({pool:{query:async()=>{throw Error('offline');}}});
  const res=response();await handler({user:{role:'ADMIN'},query},res);assert.equal(res.code,503);assert.equal(res.body.ok,false);
});

test('both PDF modes render empty and dense selections on a real single A4 page',async()=>{
  for(const mode of ['eligible','comparison']) for(const count of [0,100]) {
    const employees=Array.from({length:count},(_,i)=>employee(`E${i}`));
    const payroll=employees.flatMap(e=>[pay(e.employee_id,'2026-09-01'),pay(e.employee_id,'2026-10-01',2100)]);
    const report=build(employees,payroll,mode);
    const bytes=await renderLateReport({...report,mode,year:2026,month:10,view:'increment-summary',format:'pdf',branches:{A:'ALOR SETAR'},branchLabel:'All branches'});
    assert.equal(bytes.subarray(0,5).toString(),'%PDF-');
    const content=bytes.toString('latin1');
    assert.equal((content.match(/\/Type \/Page\b/g)??[]).length,1);
    assert.match(content,/\/MediaBox \[0 0 (595\.28 841\.89|841\.89 595\.28)\]/);
  }
});
