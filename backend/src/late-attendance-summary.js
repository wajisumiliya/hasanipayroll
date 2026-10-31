import PDFDocument from 'pdfkit';
import {fileURLToPath} from 'node:url';

const navy='#073D68', blue='#1687FF', red='#FFDADD';
export const hhmm = minutes => minutes == null ? '—' : `${String(Math.floor(minutes/60)).padStart(2,'0')}:${String(Math.round(minutes%60)).padStart(2,'0')}`;
export function attendanceSummaryRows(data) {
  return data.reports.filter(r=>(Number(r.arrival_count)||0)+(Number(r.break_count)||0)>=3).map(r=>{
    const total=type=>{
      const events=r.events.filter(e=>e.type===type);
      return events.some(e=>e.minutes==null)?null:events.reduce((sum,e)=>sum+e.minutes,0);
    };
    return {...r,arrival_minutes:total('arrival'),break_minutes:total('break')};
  });
}
export async function renderAttendanceSummary(data) {
  const rows=attendanceSummaryRows(data);
  const doc=new PDFDocument({size:'A4',layout:'landscape',margin:18,bufferPages:true});
  const chunks=[];
  const done=new Promise((resolve,reject)=>{doc.on('data',c=>chunks.push(c));doc.once('end',()=>resolve(Buffer.concat(chunks)));doc.once('error',reject);});
  doc.registerFont('Body',fileURLToPath(new URL('../assets/fonts/DejaVuSans.ttf',import.meta.url)));
  doc.registerFont('Bold',fileURLToPath(new URL('../assets/fonts/DejaVuSans-Bold.ttf',import.meta.url)));
  const x=18,w=doc.page.width-36;
  const widths=[34,80,133,92,85,95,89,99,99].map(v=>v/806*w);
  const period=new Date(Date.UTC(data.year,data.month-1,1));
  const month=period.toLocaleDateString('en-GB',{month:'long',year:'numeric',timeZone:'UTC'});
  const shortMonth=period.toLocaleDateString('en-GB',{month:'short',year:'numeric',timeZone:'UTC'});
  const generated=new Intl.DateTimeFormat('en-GB',{day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit',hour12:true,timeZone:'Asia/Kuala_Lumpur'}).format(new Date()).replace(',','');
  function text(value,left,top,width,{bold=false,size=8,color='#102943',align='left'}={}) {
    doc.font(bold?'Bold':'Body').fontSize(size).fillColor(color).text(String(value),left,top,{width,align,lineGap:1});
  }
  function header() {
    for(let i=0;i<4;i++)doc.rect(x+i*8,40-(i+1)*7,6,(i+1)*7).fill(i%2?blue:'#0069DC');
    text('HASANI PAYROLL',x+46,11,300,{bold:true,size:18});
    text('Employee Attendance Report',x+46,33,300,{size:10});
    text('LATE ATTENDANCE EMPLOYEES (3 AND ABOVE)',x+380,15,w-380,{bold:true,size:11,align:'right'});
    doc.moveTo(x+480,43).lineTo(x+w,43).strokeColor(blue).lineWidth(1).stroke();
    doc.moveTo(x,52).lineTo(x+w,52).strokeColor(blue).lineWidth(.7).stroke();
    text('Payroll Month   :',x,61,85,{bold:true});text(month,x+88,61,300);
    text('Generated On   :',x,75,85,{bold:true});text(generated,x+88,75,300);
    text('Total Employees :',x+w-164,61,100,{bold:true});text(rows.length,x+w-62,61,62);
    text('Branch                 :',x+w-164,75,100,{bold:true});text(data.branchLabel,x+w-62,75,62,{size:7});
    let left=x;
    const labels=['No.','Employee ID','Employee Name','Branch','Payroll Month','Main Exceed Time\n(HH:MM)','Count Late Main','Break Exceed Time\n(HH:MM)','Count Exceed Break'];
    labels.forEach((label,i)=>{doc.rect(left,95,widths[i],32).fillAndStroke(navy,'#A5BBD0');text(label,left+3,103,widths[i]-6,{bold:true,size:7,color:'white',align:'center'});left+=widths[i];});
    return 127;
  }
  let y=header();
  for(let index=0;index<rows.length;index++) {
    const row=rows[index];
    const cells=[index+1,row.employee_id,row.name,data.branches[String(row.branch_id).trim().toUpperCase()]??row.branch_id,
      shortMonth,hhmm(row.arrival_minutes),row.arrival_count,hhmm(row.break_minutes),row.break_count];
    let height=22;
    cells.forEach((cell,i)=>{doc.font('Body').fontSize(8);height=Math.max(height,doc.heightOfString(String(cell),{width:widths[i]-8})+10);});
    if(y+height>doc.page.height-95){doc.addPage();y=header();}
    let left=x;
    cells.forEach((cell,i)=>{
      doc.rect(left,y,widths[i],height).fillAndStroke(i===6||i===8?red:index%2?'#F1F2F4':'#FFFFFF','#B8C8D8');
      text(cell,left+4,y+6,widths[i]-8,{size:8,align:i===2?'left':'center',color:i===6||i===8?'#B00014':'#102943'});
      left+=widths[i];
    });
    y+=height;
  }
  if(y+75>doc.page.height-20){doc.addPage();y=header();}
  const total=field=>rows.some(r=>r[field]==null)?null:rows.reduce((sum,r)=>sum+r[field],0);
  const merged=widths.slice(0,5).reduce((a,b)=>a+b,0);
  doc.rect(x,y,merged,24).fillAndStroke('#D7E8FA','#A3BDDA');text('TOTAL',x,y+6,merged,{bold:true,size:10,align:'center'});
  let left=x+merged;
  [hhmm(total('arrival_minutes')),total('arrival_count'),hhmm(total('break_minutes')),total('break_count')].forEach((value,i)=>{
    doc.rect(left,y,widths[i+5],24).fillAndStroke(i%2?'#FFC6CD':'#D7E8FA','#A3BDDA');
    text(value,left,y+6,widths[i+5],{bold:true,size:10,align:'center'});left+=widths[i+5];
  });
  y+=32;
  text('Note:',x,y,w,{bold:true,size:7});
  text('1. This report shows employees with 3 or more combined main late and excess-break occurrences in the selected payroll month.',x,y+11,w,{size:7});
  text('2. Main exceed time and break exceed time are total accumulated time for the selected month.',x,y+21,w,{size:7});
  if(rows.some(r=>r.arrival_minutes==null))text('3. — indicates a recorded late status with no retained roster/timing. Unknown durations are not estimated.',x,y+31,w,{size:7});
  if(!rows.length)text('No employees meet the selected monthly threshold.',x,y+31,w,{size:8});
  const range=doc.bufferedPageRange();
  for(let i=0;i<range.count;i++) {doc.switchToPage(i);text(`Page ${i+1} of ${range.count}`,x,doc.page.height-28,w,{size:7,align:'right'});}
  doc.end();return done;
}

export async function renderStatusSummary(data) {
  const doc=new PDFDocument({size:'A4',layout:'landscape',margin:24,bufferPages:true});
  const chunks=[];const done=new Promise((resolve,reject)=>{doc.on('data',c=>chunks.push(c));doc.once('end',()=>resolve(Buffer.concat(chunks)));doc.once('error',reject);});
  doc.registerFont('Body',fileURLToPath(new URL('../assets/fonts/DejaVuSans.ttf',import.meta.url)));
  doc.registerFont('Bold',fileURLToPath(new URL('../assets/fonts/DejaVuSans-Bold.ttf',import.meta.url)));
  const label=data.status==='MC'?'MC':'UNPAID';
  const month=new Date(Date.UTC(data.year,data.month-1,1)).toLocaleDateString('en-GB',{month:'long',year:'numeric',timeZone:'UTC'});
  const width=doc.page.width-48,cols=[35,95,190,115,60,width-495];
  function text(v,x,y,w,bold=false,size=8){doc.font(bold?'Bold':'Body').fontSize(size).fillColor('#102943').text(String(v),x,y,{width:w});}
  function header() {
    text('HASANI PAYROLL',24,18,350,true,18);text(`${label} ATTENDANCE REPORT`,420,22,width-396,true,13);
    text(`${month} · ${data.branchLabel} · ${data.reports.length} employees`,24,48,width,false,10);
    let x=24;['No.','Employee ID','Employee Name','Branch','Days',`${label} dates`].forEach((v,i)=>{
      doc.rect(x,72,cols[i],26).fill(navy);doc.font('Bold').fontSize(8).fillColor('white').text(v,x+5,80,{width:cols[i]-10});x+=cols[i];
    });return 98;
  }
  let y=header();
  for(let i=0;i<data.reports.length;i++) {
    const r=data.reports[i],cells=[i+1,r.employee_id,r.name,data.branches[String(r.branch_id).trim().toUpperCase()]??r.branch_id,r.count,r.dates.join(', ')];
    let height=25;
    cells.forEach((v,j)=>{doc.font('Body').fontSize(8);height=Math.max(height,doc.heightOfString(String(v),{width:cols[j]-10})+12);});
    if(y+height>doc.page.height-70){doc.addPage();y=header();}
    let x=24;cells.forEach((v,j)=>{doc.rect(x,y,cols[j],height).fillAndStroke(i%2?'#F1F3F6':'#FFFFFF','#B8C8D8');text(v,x+5,y+6,cols[j]-10);x+=cols[j];});y+=height;
  }
  if(y+50>doc.page.height-30){doc.addPage();y=header();}
  text(`TOTAL: ${data.reports.length} employees · ${data.reports.reduce((sum,r)=>sum+r.count,0)} ${label} days`,24,y+12,width,true,10);
  text('Source: saved attendance records for the selected month. Duplicate dates are counted once per employee and branch.',24,y+32,width,false,8);
  if(!data.reports.length)text(`No ${label} attendance records for this selection.`,24,y+46,width);
  const range=doc.bufferedPageRange();for(let i=0;i<range.count;i++){doc.switchToPage(i);text(`Page ${i+1} of ${range.count}`,doc.page.width-100,doc.page.height-25,80);}
  doc.end();return done;
}
