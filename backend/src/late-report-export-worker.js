import { parentPort, workerData } from 'node:worker_threads';
import { fileURLToPath } from 'node:url';
import PDFDocument from 'pdfkit';
import ExcelJS from 'exceljs';

const status = value => ({noted:'Reviewed',approved:'Approved',correction_required:'Correction required'}[value] ?? 'Pending');
const category = value => ({transport:'Transport delay',approved_late:'Approved late arrival / break',attendance_error:'Incorrect attendance'}[value] ?? 'Other');
const severity = count => count >= 7 ? 'High' : count >= 5 ? 'Medium' : 'Low';
const time = value => value ? new Date(value).toLocaleString('en-GB', {timeZone:'Asia/Kuala_Lumpur',hour12:false})+' MYT' : '';
function sheets(data) {
  const {reports,year,month,branchLabel,branches} = data;
  const branch = id => branches[String(id).toUpperCase()] ?? id;
  const total = field => reports.reduce((sum,r)=>sum+r[field],0);
  return {
    Summary: [
      ['Hasani Books - Late Report',`${year}-${String(month).padStart(2,'0')}`,branchLabel],
      ['Flagged employees',reports.length],['Late arrivals',total('arrival_count')],
      ['Exceeded breaks',total('break_count')],['Excess minutes',total('total_minutes')],
      ['Policy','3+ combined occurrences per employee/branch. Reviews retain original totals.'],
      ['Comparison','Counts reflect saved attendance; the current month may still be in progress.'],
      ['Branch','Employee ID','Employee','Severity','Arrivals','Exceeded breaks','Total count','Excess minutes','Previous count','Change'],
      ...reports.map(r=>[branch(r.branch_id),r.employee_id,r.name,severity(r.count),r.arrival_count,r.break_count,r.count,r.total_minutes,r.previous_count,r.change]),
    ],
    Events: [
      ['Branch','Employee ID','Employee','Date','Issue','Scheduled / allowed','Actual / used','Excess minutes','Review status','Category','Reason','Reviewed by','Reviewed at (MYT)'],
      ...reports.flatMap(r=>r.events.map(e=>[branch(r.branch_id),r.employee_id,r.name,e.date,e.type==='arrival'?'Late arrival':'Break exceeded',e.type==='arrival'?e.scheduled:`${e.allocated_minutes} min`,e.type==='arrival'?e.actual:`${e.actual_minutes} min`,e.minutes,e.review_outdated?'Needs re-review':status(e.review?.status),e.review?category(e.review.reason_code):'',e.review?.reason??'',e.review?.reviewed_by??'',time(e.review?.reviewed_at)])),
    ],
    'Review history': [
      ['Branch','Employee ID','Employee','Event date','Issue','Status','Category','Reason','Reviewer','Reviewed at (MYT)','Reviewed excess minutes','Applies to current timing'],
      ...reports.flatMap(r=>r.events.flatMap(e=>(e.review_history??[]).map(h=>[branch(r.branch_id),r.employee_id,r.name,e.date,e.type,status(h.status),category(h.reason_code),h.reason,h.reviewed_by,time(h.reviewed_at),h.event_snapshot?.minutes??'',h.event_fingerprint===e.fingerprint?'Yes':'No']))),
    ],
  };
}
async function excel(data) {
  const book = new ExcelJS.Workbook();
  book.creator = 'Hasani Books';
  for (const [name,rows] of Object.entries(sheets(data))) {
    const sheet = book.addWorksheet(name);
    // Strings, including notes beginning '=', stay literal values (no formulas).
    sheet.addRows(rows);
    sheet.views = [{state:'frozen',ySplit:name==='Summary'?8:1}];
    sheet.columns.forEach((column,index)=>{column.width=index===2||index===6||index===10?32:22;});
    const header = sheet.getRow(name==='Summary'?8:1);
    header.font={bold:true,color:{argb:'FFFFFFFF'}};
    header.fill={type:'pattern',pattern:'solid',fgColor:{argb:'FF173B63'}};
    sheet.eachRow(row=>{row.alignment={vertical:'top',wrapText:true};});
  }
  return book.xlsx.writeBuffer();
}
async function pdf(data) {
  const doc = new PDFDocument({size:'A4',layout:'landscape',margin:30,bufferPages:true});
  const chunks=[];
  const done=new Promise((resolve,reject)=>{
    doc.on('data',chunk=>chunks.push(chunk));
    doc.once('end',()=>resolve(Buffer.concat(chunks)));
    doc.once('error',reject);
  });
  doc.registerFont('Body',fileURLToPath(new URL('../assets/fonts/DejaVuSans.ttf',import.meta.url)));
  doc.registerFont('Bold',fileURLToPath(new URL('../assets/fonts/DejaVuSans-Bold.ttf',import.meta.url)));
  const line = (text,bold=false,size=9) => {
    doc.font(bold?'Bold':'Body').fontSize(size).fillColor('#18344d').text(String(text),{paragraphGap:5});
  };
  line('Hasani Books - Late Report',true,20);
  line(`${data.year}-${String(data.month).padStart(2,'0')} | ${data.branchLabel}`,true,12);
  const total=field=>data.reports.reduce((sum,r)=>sum+r[field],0);
  line(`${data.reports.length} flagged employees | ${total('arrival_count')} late arrivals | ${total('break_count')} exceeded breaks | ${total('total_minutes')} excess minutes`);
  line('3+ combined occurrences per employee/branch. Reviews retain original totals. Counts reflect saved attendance.');
  for (const r of data.reports) {
    if(doc.y>doc.page.height-140) doc.addPage();
    doc.moveDown(.5);
    line(`${data.branches[String(r.branch_id).toUpperCase()]??r.branch_id} | ${r.name} (${r.employee_id})`,true,12);
    line(`${severity(r.count)} severity | ${r.count} this month / ${r.previous_count} previous month | ${r.total_minutes} excess minutes`,true);
    for(const e of r.events) {
      const arrival=e.type==='arrival';
      if(doc.y>doc.page.height-110) doc.addPage();
      line(`${e.date} | ${arrival?'Late arrival':'Break exceeded'} | ${arrival?`Scheduled ${e.scheduled} / arrived ${e.actual}`:`Allowed ${e.allocated_minutes} min / used ${e.actual_minutes} min`} | +${e.minutes} min`,true);
      line(`Review: ${e.review_outdated?'Needs re-review':status(e.review?.status)}`);
      if(e.review) line(`${category(e.review.reason_code)}: ${e.review.reason} | ${e.review.reviewed_by} | ${time(e.review.reviewed_at)}`);
      for(const h of e.review_history??[]) line(`History: ${status(h.status)} | ${category(h.reason_code)}: ${h.reason} | ${h.reviewed_by} | ${time(h.reviewed_at)}${h.event_fingerprint!==e.fingerprint?' | Previous timing':''}`,false,8);
    }
  }
  if(!data.reports.length) line('No employees meet the monthly threshold.');
  const range=doc.bufferedPageRange();
  for(let i=0;i<range.count;i++) {
    doc.switchToPage(i);
    doc.font('Body').fontSize(8).text(`Hasani Books | ${data.year}-${String(data.month).padStart(2,'0')} | ${i+1}/${range.count}`,30,doc.page.height-22,{lineBreak:false});
  }
  doc.end();
  return done;
}
try {
  if(!['pdf','xlsx'].includes(workerData.format)) throw new Error('Invalid report format.');
  const bytes=Uint8Array.from(await (workerData.format==='pdf'?pdf(workerData):excel(workerData)));
  parentPort.postMessage({bytes},[bytes.buffer]);
} catch(error) { parentPort.postMessage({error:error.message}); }
