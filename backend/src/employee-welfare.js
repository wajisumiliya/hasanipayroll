import ExcelJS from 'exceljs';
import {createHash} from 'node:crypto';
import {salaryReportAdmin,salaryReportScope} from './salary-report-assignments.js';
const clean=value=>String(value??'').trim().replace(/\s+/g,' ');
const column=value=>clean(value).toLowerCase().replace(/[^a-z0-9]/g,'');
const scoped=`($1::text IS NULL OR ((COALESCE(e.address,'')||' '||COALESCE(s.address,''))~*'FRN|FOREIGN')=($1='foreign'))`;
export async function previewWelfare(bytes,employees){
  if(!bytes.length||bytes.length>1024*1024)throw Error('Select an Excel workbook up to 1 MB.');
  const book=new ExcelJS.Workbook();await book.xlsx.load(bytes);
  const sheet=book.worksheets[0];if(!sheet||sheet.rowCount>5000)throw Error('Workbook must contain up to 4999 welfare entries.');
  const columns=new Map();sheet.getRow(1).eachCell((cell,index)=>columns.set(column(cell.text),index));
  const find=(...names)=>names.map(n=>columns.get(n)).find(Boolean);
  const positions={date:find('date'),employee:find('employeecode','employeeid'),name:find('name'),
    particulars:find('particulars','purticulars'),amount:find('amount'),reference:find('ref1','reference'),project:find('project')};
  if(['date','employee','particulars','amount'].some(k=>!positions[k]))throw Error('Expected Date, EMPLOYEE_CODE, Particulars and Amount columns in the first sheet.');
  const allowed=new Set(employees.filter(e=>e.in_scope!==false).map(e=>clean(e.employee_id).toUpperCase()));
  const names=new Map();
  for(const employee of employees){
    const name=clean(employee.name).toUpperCase();
    if(!name)continue;
    const ids=names.get(name)??new Set();ids.add(clean(employee.employee_id).toUpperCase());names.set(name,ids);
  }
  const entries=[],pending=[],occurrences=new Map();
  for(let rowNumber=2;rowNumber<=sheet.rowCount;rowNumber++){
    const row=sheet.getRow(rowNumber);if(!row.hasValues)continue;
    const value=key=>positions[key]?row.getCell(positions[key]).value:null;
    const text=key=>positions[key]?row.getCell(positions[key]).text:'';
    let employee=clean(text('employee')).toUpperCase();
    const name=clean(text('name'));
    if(!employee){const matches=names.get(name.toUpperCase());if(matches?.size===1)employee=[...matches][0];}
    const rawDate=value('date');let date;
    if(rawDate instanceof Date)date=rawDate.toISOString().slice(0,10);
    else {const raw=clean(rawDate);const match=/^(\d{2})\/(\d{2})\/(\d{4})$/.exec(raw);date=match?`${match[3]}-${match[2]}-${match[1]}`:raw;}
    const rawAmount=value('amount'),amount=typeof rawAmount==='number'?rawAmount:Number(clean(rawAmount).replaceAll(',',''));
    const particulars=clean(text('particulars')),reference=clean(text('reference')),project=clean(text('project'));
    const reasons=[];
    if(!employee)reasons.push('Missing employee code');else if(!allowed.has(employee))reasons.push('Employee code unavailable in your payroll scope');
    const parsed=new Date(`${date}T00:00:00Z`);
    if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||!Number.isFinite(parsed.getTime())||parsed.toISOString().slice(0,10)!==date)reasons.push('Invalid date');
    if(rawAmount==null||clean(rawAmount)===''||!Number.isFinite(amount)||amount<0||amount>=1e12||Math.abs(amount*100-Math.round(amount*100))>1e-5)reasons.push('Missing or invalid amount');
    if(!particulars||particulars.length>2000||reference.length>500||project.length>500)reasons.push('Missing or invalid particulars');
    if(reasons.length){pending.push({row:rowNumber,employee_id:employee,name,reasons});continue;}
    const canonical=JSON.stringify([employee,date,Math.round(amount*100),particulars,reference,project]);
    const occurrence=(occurrences.get(canonical)??0)+1;occurrences.set(canonical,occurrence);
    const source_key=createHash('sha256').update(canonical+'|'+occurrence).digest('hex');
    entries.push({source_key,employee_id:employee,payment_date:date,particulars,amount,reference,project});
  }
  return {entries,pending,total:entries.length+pending.length};
}
export function installEmployeeWelfareApi(app,{pool,authenticate}){
  app.get('/api/reports/employee-welfare',authenticate,async(req,res)=>{
    if(!salaryReportAdmin(req))return res.status(403).json({ok:false,message:'Payroll administrator access required.'});
    try {
      const result=await pool.query(`SELECT w.employee_id,to_char(w.payment_date,'YYYY-MM-DD') AS payment_date,w.particulars,w.amount::float8 AS amount,w.reference,w.project FROM app_private.employee_welfare w JOIN public.employees e ON e.employee_id=w.employee_id LEFT JOIN public.employee_salary_defaults s ON s.employee_id=e.employee_id WHERE ${scoped} ORDER BY w.payment_date,w.source_key`,[salaryReportScope(req)]);
      res.set?.('Cache-Control','no-store');return res.json({ok:true,entries:result.rows});
    }catch(error){console.error('WELFARE READ:',error.message);return res.status(503).json({ok:false,message:'Unable to load employee welfare. Please retry.'});}
  });
  app.post('/api/reports/employee-welfare/import',authenticate,async(req,res)=>{
    if(!salaryReportAdmin(req))return res.status(403).json({ok:false,message:'Payroll administrator access required.'});
    const encoded=req.body?.file_base64;
    if(typeof encoded!=='string'||encoded.length>1400000||!/^[A-Za-z0-9+/]*={0,2}$/.test(encoded))return res.status(400).json({ok:false,message:'Invalid welfare workbook.'});
    let client;
    try {
      client=await pool.connect();await client.query('BEGIN');
      const employees=await client.query(`SELECT e.employee_id,e.name,${scoped} AS in_scope FROM public.employees e LEFT JOIN public.employee_salary_defaults s ON s.employee_id=e.employee_id`,[salaryReportScope(req)]);
      const preview=await previewWelfare(Buffer.from(encoded,'base64'),employees.rows);
      if(req.body.commit!==true){await client.query('ROLLBACK');return res.json({ok:true,ready:preview.entries.length,pending:preview.pending,total:preview.total});}
      let imported=0;
      for(const row of preview.entries){
        const result=await client.query(`INSERT INTO app_private.employee_welfare(source_key,employee_id,payment_date,particulars,amount,reference,project,imported_by) VALUES($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT(source_key) DO NOTHING`,[row.source_key,row.employee_id,row.payment_date,row.particulars,row.amount,row.reference,row.project,String(req.user?.id??req.auth?.sub??'admin')]);
        imported+=result.rowCount;
      }
      await client.query('COMMIT');return res.json({ok:true,imported,already_imported:preview.entries.length-imported,pending:preview.pending,total:preview.total});
    }catch(error){if(client)await client.query('ROLLBACK');console.error('WELFARE IMPORT:',error.message);return res.status(400).json({ok:false,message:'Unable to import welfare. Check the workbook and retry.'});}
    finally{client?.release();}
  });
}
