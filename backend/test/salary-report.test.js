import test from 'node:test';
import assert from 'node:assert/strict';
import ExcelJS from 'exceljs';
import {readFile} from 'node:fs/promises';
import {buildSalaryReport,salaryReportAmount,installSalaryReportApi} from '../src/salary-report.js';
import {renderLateReport} from '../src/late-report-export.js';
import {salarySheetName,salaryReportRows} from '../src/salary-report-export.js';
import {dropFixtureDatabase} from './fixtures/database-cleanup.js';
const employee=(id,extra={})=>({employee_id:id,name:`Employee ${id}`,branch_id:'A',is_active:true,joining_date:'2024-01-01',...extra});
const pay=(id,period,basic=2500,extra={})=>({employee_id:id,period,basic_salary:basic,...extra});
const build=(payroll,employees=[employee('E1')],branches=[{id:'A',name:'Branch A'}],extra={})=>buildSalaryReport({startYear:2025,payroll,employees,branches,...extra});
test('requested salary example excludes exactly EPF, EIS and SOCSO',()=>{
 const row={basic_salary:2000,elaun_perkhidmatan:250,late_deduction:50,epf_employee:220,eis_employee:4,socso_employee:11,epf_employer:260};
 assert.equal(salaryReportAmount(row),2200);assert.equal(salaryReportAmount({...row,pcb:10,zakat:5}),2185);
});
test('all earnings and other deductions are included without double-counting FW base',()=>{
 assert.equal(salaryReportAmount({basic_salary:2000,fw_salary:2000,elaun_kedatangan:100,elaun_perkhidmatan:150,elaun_kerajinan:25,elaun_makanan:50,
 housing_allowance:40,travel_allowance:60,overtime:75,bonus:80,commission:90,other_earnings:20,cuti_umum:30,
 pcb:10,zakat:20,advance:30,loan_deduction:40,unpaid_deduction:50,late_deduction:60,other_deduction:70,epf_employee:999,eis_employee:999,socso_employee:999}),2440);
 assert.equal(salaryReportAmount({basic_salary:0,fw_salary:1700,elaun_makanan:'100.25'}),1800.25);
 assert.equal(salaryReportAmount({basicSalary:'2,000.00',elaunMakanan:250,unpaidLeave:50}),2200);
 assert.equal(salaryReportAmount({basic_salary:0,advance:50}),-50);
 assert.throws(()=>salaryReportAmount({employee_id:'E1',bonus:'bad'}),/Invalid bonus/);
});
test('July-June boundary, blank months and a saved zero remain distinct',()=>{
 const report=build([pay('E1','2025-06-30',999),pay('E1','2025-07-01',2200),pay('E1','2025-09-01',0),pay('E1','2026-06-30',2300),pay('E1','2026-07-01',999)]);
 assert.deepEqual(report.months.map(m=>m.label),['Jul 2025','Aug 2025','Sep 2025','Oct 2025','Nov 2025','Dec 2025','Jan 2026','Feb 2026','Mar 2026','Apr 2026','May 2026','Jun 2026']);
 assert.deepEqual(report.branches[0].rows[0].values,[2200,null,0,null,null,null,null,null,null,null,null,2300]);
});
test('historical employment eligibility and saved/current payroll branches are respected',()=>{
 const r=build([pay('E1','2025-07-01',10),pay('E1','2026-01-01',20),pay('E2','2025-07-01',30),pay('E2','2026-01-01',40),pay('E3','2025-07-01',50)],
 [employee('E1',{payroll_branch_id:'B'}),employee('E2',{is_active:false,resigned_at:'2025-12-01'}),employee('E3',{joining_date:'2025-08-01'})],
 [{id:'A',name:'Branch A'},{id:'B',name:'Branch B'}]);
 assert.equal(r.branches[0].rows[0].employee_id,'E2');assert.equal(r.branches[0].rows[0].values[6],null);assert.equal(r.branches[1].rows[0].employee_id,'E1');
 const moved=build([pay('E1','2025-07-01',10,{branch_id:'A'}),pay('E1','2026-01-01',20,{branch_id:'B'})], [employee('E1')],[{id:'A',name:'A'},{id:'B',name:'B'}]);
 assert.equal(moved.employee_count,1);assert.equal(moved.branches.length,2);assert.equal(moved.branches[0].rows[0].values[6],null);
 assert.equal(build([pay('E1','2025-07-01')],undefined,undefined,{branchId:'OTHER'}).branches.length,0);
});
const correctedBranches=[{id:'BR-AMJ',name:'AMANJAYA'},{id:'BR-GRN',name:'GURUN'}];
const correctedEmployees=[employee('BAS025',{branch_id:'BR-AMJ',payroll_branch_id:'BR-AMJ'}),employee('OTHER',{branch_id:'BR-AMJ'})];
function correctedReport(extra={}){
 const months=Array.from({length:12},(_,i)=>new Date(Date.UTC(2025,6+i,1)).toISOString().slice(0,10));
 const rows=months.map((period,i)=>pay('BAS025',period,2000+i,{branch_id:'BR-AMJ',payroll_branch_id:'BR-AMJ'}));
 rows.push(pay('OTHER','2025-07-01',3000));
 return build(rows,correctedEmployees,correctedBranches,{...extra,assignments:rows.filter(r=>r.employee_id==='BAS025').map(r=>({employee_id:r.employee_id,month:r.period.slice(0,7),branch_id:'BR-GRN'}))});
}
test('BAS025 historical correction places all twelve months in GURUN exactly once',()=>{
 const before=JSON.stringify(correctedEmployees);
 const r=correctedReport();
 const gurun=r.branches.find(b=>b.id==='BR-GRN'),amanjaya=r.branches.find(b=>b.id==='BR-AMJ');
 assert.deepEqual(gurun.rows.map(r=>r.employee_id),['BAS025']);
 assert.deepEqual(gurun.rows[0].values,Array.from({length:12},(_,i)=>2000+i));
 assert.deepEqual(gurun.totals,gurun.rows[0].values);
 assert.deepEqual(amanjaya.rows.map(r=>r.employee_id),['OTHER']);
 assert.equal(r.employee_count,2);
 assert.equal(JSON.stringify(correctedEmployees),before);
 assert.deepEqual(correctedReport({branchId:'BR-GRN'}).branches[0].rows[0].values,gurun.rows[0].values);
 assert.deepEqual(correctedReport({branchId:'BR-AMJ'}).branches[0].rows.map(r=>r.employee_id),['OTHER']);
 const later=build([pay('BAS025','2026-07-01')],correctedEmployees,correctedBranches,{startYear:2026});
 assert.equal(later.branches[0].id,'BR-AMJ');
});
test('unknown branches and overlapping assignment data fail closed',()=>{
 const row=pay('BAS025','2025-07-01');
 assert.throws(()=>build([row],correctedEmployees,correctedBranches,{assignments:[{employee_id:'BAS025',month:'2025-07',branch_id:'UNKNOWN'}]}),/Invalid report branch assignment/);
 const assignment={employee_id:'BAS025',month:'2025-07',branch_id:'BR-GRN'};
 assert.throws(()=>build([row],correctedEmployees,correctedBranches,{assignments:[assignment,assignment]}),/Invalid report branch assignment/);
});
test('an employee can move between branches by month without duplicate salary or changed totals',()=>{
 const rows=['2025-07-01','2025-08-01','2025-09-01'].map(p=>pay('E1',p,2200));
 const report=build(rows,[employee('E1')],[{id:'A',name:'A'},{id:'B',name:'B'}],{
   assignments:[{employee_id:'E1',month:'2025-08',branch_id:'B'}]});
 assert.equal(report.employee_count,1);
 assert.deepEqual(report.branches[0].rows[0].values.slice(0,3),[2200,null,2200]);
 assert.deepEqual(report.branches[1].rows[0].values.slice(0,3),[null,2200,null]);
 assert.equal(report.branches.flatMap(b=>b.totals).reduce((a,b)=>a+b,0),6600);
});
test('corrected branch is used by real Excel sheets and PDF pages',async()=>{
 const report=correctedReport();
 const bytes=await renderLateReport({view:'salary-report',format:'xlsx',report});
 const book=new ExcelJS.Workbook();await book.xlsx.load(bytes);
 const gurun=book.worksheets.find(s=>s.name==='GURUN');
 assert.ok(gurun);assert.equal(gurun.getCell('B6').value,'BAS025');
 assert.equal(gurun.getCell('D6').value,2000);assert.equal(gurun.getCell('O6').value,2011);
 assert.equal(book.worksheets.find(s=>s.name==='AMANJAYA').getCell('B6').value,'OTHER');
 const pdf=await renderLateReport({view:'salary-report',format:'pdf',report});
 assert.equal(pdf.subarray(0,5).toString(),'%PDF-');
 assert.equal((pdf.toString('latin1').match(/\/Type \/Page\b/g)??[]).length,2);
});
test('duplicates fail closed and totals retain cents',()=>{
 assert.throws(()=>build([pay('E1','2025-07-01'),pay('E1','2025-07-15')]),/Duplicate payroll/);
 assert.throws(()=>build([pay('E1','2025-07-01',1,{branch_id:'A'}),pay('E1','2025-07-15',2,{branch_id:'B'})],undefined,undefined,{branchId:'A'}),/Duplicate payroll/);
 const r=build([pay('E1','2025-07-01',100.1),pay('E2','2025-07-01',200.2)],[employee('E1'),employee('E2')]);
 assert.equal(r.branches[0].totals[0],300.3);assert.equal(build([]).branches.length,0);
});
test('real Excel has separate branch sheets, twelve numeric months, blank cells and totals',async()=>{
 const r=build([pay('E1','2025-07-01',2200),pay('E1','2025-09-01',0),pay('E2','2026-06-01',100.25)],
 [employee('E1',{name:'=1+1'}),employee('E2',{branch_id:'B'})],[{id:'A',name:'A/Branch'},{id:'B',name:'A?Branch'}]);
 const bytes=await renderLateReport({view:'salary-report',format:'xlsx',report:r});const b=new ExcelJS.Workbook();await b.xlsx.load(bytes);
 assert.equal(b.worksheets.length,2);assert.notEqual(b.worksheets[0].name,b.worksheets[1].name);
 const s=b.worksheets.find(s=>s.getCell('B6').value==='E1');
 assert.equal(s.getCell('C6').value,'=1+1');assert.equal(s.getCell('D5').value,'Jul 2025');assert.equal(s.getCell('O5').value,'Jun 2026');
 assert.equal(s.getCell('D6').value,2200);assert.equal(s.getCell('E6').value,null);assert.equal(s.getCell('F6').value,0);
 assert.equal(s.getCell('D7').value,2200);assert.equal(s.getCell('C7').master.address,'A7');assert.equal(s.columnCount,15);assert.equal(s.getCell('D6').numFmt,'#,##0.00');assert.equal(s.pageSetup.orientation,'landscape');
});
test('worksheet names are valid, limited and unique ignoring case',()=>{
 const used=new Set();const names=['A/B','A?B','a b',"''",'x'.repeat(50),'x'.repeat(50)].map(n=>salarySheetName(n,used));
 assert.equal(new Set(names.map(n=>n.toLowerCase())).size,names.length);assert.ok(names.every(n=>n.length<=31&&!/[\\/*?:\[\]]/.test(n)));
});
test('PDF fits each branch on a separate landscape page including dense branches',async()=>{
 const es=Array.from({length:100},(_,i)=>employee(`E${i}`,{name:'Very long employee name for wrapping and full retention',branch_id:i<90?'A':'B'}));
 const r=build(es.map(e=>pay(e.employee_id,'2025-07-01',2200)),es,[{id:'A',name:'Branch A'},{id:'B',name:'Branch B'}]);
 assert.equal(salaryReportRows(r.branches[0]).length,90);const bytes=await renderLateReport({view:'salary-report',format:'pdf',report:r});
 assert.equal(bytes.subarray(0,5).toString(),'%PDF-');assert.equal((bytes.toString('latin1').match(/\/Type \/Page\b/g)??[]).length,2);
});
function api(pool,renderExport){let handler;installSalaryReportApi({get(path,auth,fn){assert.equal(path,'/api/reports/salary');handler=fn;}},{authenticate:()=>{},pool,renderExport});
 return async(user={role:'admin'},query={},app_metadata={})=>{const res={code:200,status(code){this.code=code;return this;},set(){return this;},json(body){this.body=body;return this;}};
 await handler({user,query,auth:{app_metadata}},res);return res;};}
test('unauthorized roles and invalid parameters cannot read payroll',async()=>{
 const run=api({query(){assert.fail('No query expected');}});for(const role of ['employee','branch','reviewer'])assert.equal((await run({role})).code,403);
 for(const m of [{is_reviewer:true},{staff_scope:'attendance'},{staff_scope:'requests'}])assert.equal((await run({role:'admin'},{},m)).code,403);
 for(const q of [{start_year:'2025 OR true'},{start_year:1999},{format:'csv'}])assert.equal((await run(undefined,q)).code,400);
});
test('actual SQL reads a full year and enforces local/foreign scopes',{skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL},async()=>{
 const {default:pg}=await import('pg');const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
 assert.ok(['localhost','127.0.0.1'].includes(url.hostname));assert.equal(url.pathname,'/hasani_bootstrap_test');
 const bootstrap=new pg.Pool({connectionString:url.toString()});await bootstrap.query('CREATE DATABASE hasani_salary_report_test');url.pathname='/hasani_salary_report_test';const pool=new pg.Pool({connectionString:url.toString()});
 try{await pool.query(await readFile(new URL('./fixtures/neon-schema.sql',import.meta.url),'utf8'));
 await pool.query('CREATE SCHEMA IF NOT EXISTS app_private');
 await pool.query(await readFile(new URL('../migrations/20261107_salary_report_branch_assignments.sql',import.meta.url),'utf8'));
 await pool.query(await readFile(new URL('../migrations/20261108_salary_report_temporary_payroll.sql',import.meta.url),'utf8'));
 await pool.query(`INSERT INTO branches(id,name) VALUES('A','Branch A'),('B','Branch B');
 INSERT INTO employees(employee_id,name,branch_id,joining_date,address) VALUES('E1','Local','A','2024-01-01',''),('E2','Foreign','B','2024-01-01','FRN');
 INSERT INTO payroll(id,employee_id,period,basic_salary,elaun_perkhidmatan,late_deduction,epf_employee) VALUES('P1','E1','2025-07-01',2000,250,50,220),('P2','E1','2026-06-01',2100,0,0,230),('P3','E2','2025-07-01',1700,0,0,34),('OUT','E1','2026-07-01',9999,0,0,0);`);
 const run=api(pool,renderLateReport),full=await run();assert.equal(full.code,200);assert.equal(full.body.report.employee_count,2);
 assert.equal(full.body.report.branches[0].rows[0].values[0],2200);assert.equal(full.body.report.branches[0].rows[0].values[11],2100);
 for(const scope of ['local','foreign']){const r=await run(undefined,{}, {staff_scope:scope});assert.equal(r.code,200);assert.equal(r.body.report.employee_count,1);assert.equal(r.body.report.branches[0].rows[0].employee_id,scope==='local'?'E1':'E2');}
 assert.equal((await run(undefined,{branch_id:'B'})).body.report.branches[0].id,'B');
 const excel=await run(undefined,{format:'xlsx'});assert.equal(excel.code,200);assert.ok(Buffer.from(excel.body.file_base64,'base64').length>500);
 assert.equal((await run(undefined,{start_year:2020,format:'pdf'})).code,400);
 }finally{await pool.end();await dropFixtureDatabase(bootstrap,'hasani_salary_report_test');await bootstrap.end();}
});
