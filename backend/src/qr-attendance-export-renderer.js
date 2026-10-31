import PDFDocument from 'pdfkit';
import ExcelJS from 'exceljs';
import {fileURLToPath} from 'node:url';
const columns=['Employee ID','Employee','Branch','State','First IN (UTC)','Last punch (UTC)','Punches','Net minutes','Late minutes','Missing OUT'];
const cells=e=>[e.employee_id,e.name,e.branch_id,e.action,String(e.first_in),String(e.last_punch),e.punch_count,e.net_minutes??'Review',e.late_minutes??'Not established',e.missing_out?'Yes':'No'];
export async function renderQrAttendance(data) {
  if(data.format==='xlsx') {
    const book=new ExcelJS.Workbook();book.creator='Hasani Payroll';
    const summary=book.addWorksheet('Attendance');summary.addRows([['QR Attendance',data.date,data.branch],columns,...data.employees.map(cells)]);
    const events=book.addWorksheet('Punches');events.addRows([['Employee ID','Branch','Action','Timestamp UTC','Work date','Original event','Correction'],...data.events.map(e=>[e.employee_id,e.branch_id,e.action,String(e.scanned_at),e.work_date,e.raw_id,e.correction_id])]);
    const attempts=book.addWorksheet('Scan attempts');attempts.addRows([['Employee ID','Branch','Result','Reason','Timestamp UTC','Operator'],...data.attempts.map(a=>[a.employee_id,a.branch_id,a.status,a.code,String(a.attempted_at),a.operator])]);
    for(const sheet of book.worksheets){sheet.columns.forEach(c=>{c.width=24;});sheet.views=[{state:'frozen',ySplit:1}];}
    return book.xlsx.writeBuffer();
  }
  const doc=new PDFDocument({size:'A4',layout:'landscape',margin:28,bufferPages:true});
  doc.registerFont('Body',fileURLToPath(new URL('../assets/fonts/DejaVuSans.ttf',import.meta.url)));
  doc.registerFont('Bold',fileURLToPath(new URL('../assets/fonts/DejaVuSans-Bold.ttf',import.meta.url)));
  const chunks=[];const done=new Promise((resolve,reject)=>{doc.on('data',c=>chunks.push(c));doc.on('end',()=>resolve(Buffer.concat(chunks)));doc.on('error',reject);});
  const heading=()=>{doc.font('Bold').fontSize(17).text('HASANI PAYROLL · LIVE QR ATTENDANCE');doc.font('Body').fontSize(10).text(`${data.date} · ${data.branch} · Malaysia work dates; timestamps shown in Malaysia time`);doc.moveDown();};
  const my=value=>new Date(value).toLocaleString('en-GB',{timeZone:'Asia/Kuala_Lumpur',hour12:true});
  heading();
  doc.font('Body').fontSize(9).text(`IN: ${data.totals.in} · OUT: ${data.totals.out} · Punches: ${data.totals.punches} · Missing OUT: ${data.totals.missing} · Late: ${data.totals.late} · Rejected: ${data.totals.rejected}`);doc.moveDown();
  for(const e of data.employees) {
    if(doc.y>doc.page.height-110){doc.addPage();heading();}
    doc.font('Bold').fontSize(10).text(`${e.employee_id} · ${e.name} · ${e.branch_id} · ${e.action}`);
    doc.font('Body').fontSize(9).text(`First IN: ${my(e.first_in)} | Last: ${my(e.last_punch)} | Net: ${e.net_minutes??'Review'} min | Late: ${e.late_minutes??'Not established'} | ${e.missing_out?'Missing OUT':'No historical missing OUT'}`);
    if(e.issues.length)doc.text('Review: '+e.issues.join('; '));doc.moveDown(.6);
  }
  if(!data.employees.length)doc.font('Body').fontSize(10).text('No punches for this selection.');
  doc.moveDown();doc.font('Body').fontSize(8).text('QR cards identify a credential, not the person. Raw events and corrections remain separate. Payroll uses only reviewed attendance submitted through the existing workflow.');
  const pages=doc.bufferedPageRange();
  for(let i=0;i<pages.count;i++){doc.switchToPage(i);doc.font('Body').fontSize(8).text(`${i+1} / ${pages.count}`,28,doc.page.height-22,{lineBreak:false});}
  doc.end();return done;
}
