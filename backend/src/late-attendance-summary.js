import PDFDocument from 'pdfkit';
import {fileURLToPath} from 'node:url';

const navy='#073D68', blue='#1687FF', red='#FFDADD';
export const hhmm = minutes => minutes == null ? '—' : `${String(Math.floor(minutes/60)).padStart(2,'0')}:${String(Math.round(minutes%60)).padStart(2,'0')}`;
export function attendanceSummaryRows(data) {
  return data.reports.filter(r=>(Number(r.arrival_count)||0)+(Number(r.break_count)||0)>=3).map(r=>{
    const total=type=>{
      const events=r.events.filter(e=>e.type===type);
      const known=events.filter(e=>e.minutes!=null);
      return events.length && !known.length ? null : known.reduce((sum,e)=>sum+e.minutes,0);
    };
    return {...r,arrival_minutes:total('arrival'),break_minutes:total('break'),
      arrival_minutes_partial:r.events.some(e=>e.type==='arrival'&&e.minutes==null),
      break_minutes_partial:r.events.some(e=>e.type==='break'&&e.minutes==null)};
  });
}

const a4 = {portrait: [595.28,841.89], landscape: [841.89,595.28]};
export function chooseA4Layout(width,height) {
  const options=Object.entries(a4).map(([layout,[pageWidth,pageHeight]])=>({layout,pageWidth,pageHeight,
    scale:Math.min(1,(pageWidth-28)/width,(pageHeight-44)/height)}));
  if(width<=600 && options[0].scale>=options[1].scale*.9)return options[0];
  return options.sort((a,b)=>b.scale-a.scale)[0];
}
function registerFonts(doc) {
  doc.registerFont('Body',fileURLToPath(new URL('../assets/fonts/DejaVuSans.ttf',import.meta.url)));
  doc.registerFont('Bold',fileURLToPath(new URL('../assets/fonts/DejaVuSans-Bold.ttf',import.meta.url)));
}
function measureRows(rows,widths,size,padding,minHeight) {
  const measure=new PDFDocument({size:'A4'});measure.resume();registerFonts(measure);
  const heights=rows.map(cells=>Math.max(minHeight,...cells.map((value,i)=>
    measure.font('Body').fontSize(size).heightOfString(String(value),{width:widths[i]-padding})+padding)));
  measure.end();return heights;
}
function onePage(width,height) {
  const fit=chooseA4Layout(width,height);
  const doc=new PDFDocument({size:'A4',layout:fit.layout,margin:14});
  registerFonts(doc);
  // The entire measured table is transformed into the printable A4 region.
  // Extend only text-flow space, not the actual A4 MediaBox, to prevent auto-pagination.
  doc.page.margins.bottom=doc.page.height-height-32;
  doc.save().translate((doc.page.width-width*fit.scale)/2,14).scale(fit.scale);
  const chunks=[];
  const done=new Promise((resolve,reject)=>{doc.on('data',c=>chunks.push(c));doc.once('end',()=>resolve(Buffer.concat(chunks)));doc.once('error',reject);});
  return {doc,done};
}
function finishOnePage(doc) {
  doc.restore();doc.page.margins.bottom=0;
  doc.font('Body').fontSize(7).fillColor('#102943').text('Page 1 of 1',14,doc.page.height-22,{width:doc.page.width-28,align:'right',lineBreak:false});
  doc.end();
}
export async function renderAttendanceSummary(data) {
  const rows=attendanceSummaryRows(data);
  const x=18,w=806;
  const widths=[34,80,133,92,85,95,89,99,99];
  const shortMonthLabel=new Date(Date.UTC(data.year,data.month-1,1)).toLocaleDateString('en-GB',{month:'short',year:'numeric',timeZone:'UTC'});
  const cellsFor=(row,index)=>[index+1,row.employee_id,row.name,data.branches[String(row.branch_id).trim().toUpperCase()]??row.branch_id,
    shortMonthLabel,hhmm(row.arrival_minutes)+(row.arrival_minutes!=null&&row.arrival_minutes_partial?'*':''),row.arrival_count,hhmm(row.break_minutes)+(row.break_minutes!=null&&row.break_minutes_partial?'*':''),row.break_count];
  const heights=measureRows(rows.map(cellsFor),widths,8,10,22);
  const {doc,done}=onePage(842,127+heights.reduce((a,b)=>a+b,0)+88);
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
      shortMonth,hhmm(row.arrival_minutes)+(row.arrival_minutes!=null&&row.arrival_minutes_partial?'*':''),row.arrival_count,hhmm(row.break_minutes)+(row.break_minutes!=null&&row.break_minutes_partial?'*':''),row.break_count];
    const height=heights[index];
    let left=x;
    cells.forEach((cell,i)=>{
      doc.rect(left,y,widths[i],height).fillAndStroke(i===6||i===8?red:index%2?'#F1F2F4':'#FFFFFF','#B8C8D8');
      text(cell,left+4,y+6,widths[i]-8,{size:8,align:i===2?'left':'center',color:i===6||i===8?'#B00014':'#102943'});
      left+=widths[i];
    });
    y+=height;
  }
  const total=field=>rows.length && rows.every(r=>r[field]==null)?null:rows.reduce((sum,r)=>sum+(r[field]??0),0);
  const merged=widths.slice(0,5).reduce((a,b)=>a+b,0);
  doc.rect(x,y,merged,24).fillAndStroke('#D7E8FA','#A3BDDA');text('TOTAL',x,y+6,merged,{bold:true,size:10,align:'center'});
  let left=x+merged;
  [hhmm(total('arrival_minutes'))+(total('arrival_minutes')!=null&&rows.some(r=>r.arrival_minutes_partial)?'*':''),total('arrival_count'),hhmm(total('break_minutes'))+(total('break_minutes')!=null&&rows.some(r=>r.break_minutes_partial)?'*':''),total('break_count')].forEach((value,i)=>{
    doc.rect(left,y,widths[i+5],24).fillAndStroke(i%2?'#FFC6CD':'#D7E8FA','#A3BDDA');
    text(value,left,y+6,widths[i+5],{bold:true,size:10,align:'center'});left+=widths[i+5];
  });
  y+=32;
  text('Note:',x,y,w,{bold:true,size:7});
  text('1. This report shows employees with 3 or more combined main late and excess-break occurrences in the selected payroll month.',x,y+11,w,{size:7});
  text('2. Main exceed time and break exceed time are total accumulated time for the selected month.',x,y+21,w,{size:7});
  if(rows.some(r=>r.arrival_minutes_partial||r.break_minutes_partial))text('3. * Partial total of recorded minutes. — means no recorded duration. Missing times are not estimated.',x,y+31,w,{size:7});
  if(!rows.length)text('No employees meet the selected monthly threshold.',x,y+31,w,{size:8});
  finishOnePage(doc);return done;
}

export async function renderStatusSummary(data) {
  const label=data.status==='MC'?'MC':'UNPAID';
  const month=new Date(Date.UTC(data.year,data.month-1,1)).toLocaleDateString('en-GB',{month:'long',year:'numeric',timeZone:'UTC'});
  const isMc=data.status==='MC';
  const longDates=isMc||data.reports.some(r=>r.dates.join(', ').length>40);
  const canvasWidth=longDates?842:595;
  const width=canvasWidth-48;
  const weights=isMc?[30,75,145,90,65,60,65,264]:longDates?[35,95,190,115,60,299]:[25,65,120,80,35,222];
  const cols=weights.map(v=>v/weights.reduce((a,b)=>a+b,0)*width);
  const dayValue=value=>value==null?'Not set':String(Number(value));
  const cellsFor=(r,i)=>[i+1,r.employee_id,r.name,r.branch_names??data.branches[String(r.branch_id).trim().toUpperCase()]??r.branch_id,
    ...(isMc?[dayValue(r.opening_mc),r.mc_taken??r.count,dayValue(r.closing_mc)]:[r.count]),r.dates.join(', ')];
  const heights=measureRows(data.reports.map(cellsFor),cols,8,12,25);
  const {doc,done}=onePage(canvasWidth,98+heights.reduce((a,b)=>a+b,0)+78);
  function text(v,x,y,w,bold=false,size=8){doc.font(bold?'Bold':'Body').fontSize(size).fillColor('#102943').text(String(v),x,y,{width:w});}
  function header() {
    text('HASANI PAYROLL',24,18,width*.52,true,canvasWidth<600?14:18);text(`${label} ATTENDANCE REPORT`,24+width*.55,22,width*.45,true,canvasWidth<600?10:13);
    text(`${month} · ${data.branchLabel} · ${data.reports.length} employees`,24,48,width,false,10);
    let x=24;['No.','Employee ID','Employee Name','Branch',...(isMc?['Opening MC','MC Taken','Closing MC']:['Days']),`${label} dates`].forEach((v,i)=>{
      doc.rect(x,72,cols[i],26).fill(navy);doc.font('Bold').fontSize(8).fillColor('white').text(v,x+5,78,{width:cols[i]-10});x+=cols[i];
    });return 98;
  }
  let y=header();
  for(let i=0;i<data.reports.length;i++) {
    const r=data.reports[i],cells=cellsFor(r,i);
    const height=heights[i];
    let x=24;cells.forEach((v,j)=>{doc.rect(x,y,cols[j],height).fillAndStroke(i%2?'#F1F3F6':'#FFFFFF','#B8C8D8');text(v,x+5,y+6,cols[j]-10);x+=cols[j];});y+=height;
  }
  text(`TOTAL: ${data.reports.length} employees · ${data.reports.reduce((sum,r)=>sum+(isMc?(r.mc_taken??r.count):r.count),0)} ${label} days`,24,y+12,width,true,10);
  text(isMc?'Opening MC minus MC taken = Closing MC (days). Balances include MC at every branch; duplicate employee dates count once.':'Source: saved attendance records for the selected month. Duplicate dates are counted once per employee and branch.',24,y+32,width,false,8);
  if(isMc&&data.reports.some(r=>r.opening_mc==null))text('Not set: no opening MC balance is recorded for this report month.',24,y+44,width,false,7);
  if(!data.reports.length)text(`No ${label} attendance records for this selection.`,24,y+46,width);
  finishOnePage(doc);return done;
}

export async function renderIncrementSummary(data) {
  const comparison=data.mode==='comparison';
  const cash=value=>value==null?'—':Number(value).toFixed(2);
  const title=comparison?'INCREMENT PAYROLL COMPARISON':'INCREMENT ELIGIBILITY REPORT';
  const month=new Date(Date.UTC(data.year,data.month-1,1)).toLocaleDateString('en-GB',{month:'long',year:'numeric',timeZone:'UTC'});
  const widths=comparison?[26,65,150,78,75,75,70,70,65,150]:[30,85,220,115,170,174];
  const tableWidth=widths.reduce((sum,value)=>sum+value,0),canvasWidth=tableWidth+48;
  const labels=comparison?['No.','Employee ID','Employee Name','Branch','Previous base','Current base','Expected RM','Actual RM','Diff. RM','Result']:
    ['No.','Employee ID','Employee Name','Branch','Maintained schedule','Expected increment RM'];
  const cellsFor=(row,index)=>[index+1,row.employee_id,row.name,data.branches[String(row.branch_id).trim().toUpperCase()]??row.branch_id,
    ...(comparison?[cash(row.previous_total),cash(row.current_total),cash(row.expected),cash(row.actual),cash(row.variance),row.result]:[row.schedule,cash(row.expected)])];
  const rows=data.reports.map(cellsFor);
  const heights=measureRows(rows,widths,8,12,26);
  const countText=Object.entries(data.counts).map(([status,count])=>`${status}: ${count}`).join(' · ')||'No matching employees';
  const summaryHeight=measureRows([[countText]],[tableWidth],9,10,24)[0];
  const tableTop=102+summaryHeight;
  const {doc,done}=onePage(canvasWidth,tableTop+30+heights.reduce((sum,value)=>sum+value,0)+126);
  const text=(value,x,y,w,{bold=false,size=8,color='#102943'}={})=>doc.font(bold?'Bold':'Body').fontSize(size).fillColor(color).text(String(value),x,y,{width:w});
  text('HASANI PAYROLL',24,18,tableWidth*.4,{bold:true,size:18});
  text(title,24+tableWidth*.43,23,tableWidth*.57,{bold:true,size:12});
  text(`${month} · ${data.branchLabel} · ${data.eligible_count} eligible · ${data.reports.length} report rows`,24,50,tableWidth,{size:10});
  text(`Expected: RM ${cash(data.expected_total)}${comparison?` · Verified increases: RM ${cash(data.actual_total)}`:''}`,24,69,tableWidth,{bold:true,size:10});
  const generated=new Intl.DateTimeFormat('en-GB',{day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit',hour12:false,timeZone:'Asia/Kuala_Lumpur'}).format(new Date());
  text(`Generated: ${generated} MYT`,24+tableWidth*.68,69,tableWidth*.32,{size:8});
  text(countText,24,89,tableWidth,{size:9});
  let x=24;
  labels.forEach((label,index)=>{doc.rect(x,tableTop,widths[index],30).fill(navy);text(label,x+5,tableTop+7,widths[index]-10,{bold:true,color:'white'});x+=widths[index];});
  let y=tableTop+30;
  rows.forEach((cells,index)=>{
    let left=24;
    const row=data.reports[index];
    const flagged=comparison&&row.result!=='Received';
    cells.forEach((value,column)=>{
      const fill=comparison&&column===9?(flagged?'#FFE5E5':'#D8F1E8'):(index%2?'#F1F3F6':'#FFFFFF');
      doc.rect(left,y,widths[column],heights[index]).fillAndStroke(fill,'#B8C8D8');
      text(value,left+5,y+6,widths[column]-10,{bold:comparison&&column===9});
      left+=widths[column];
    });
    y+=heights[index];
  });
  if(!rows.length){text('No matching employees for this selection.',24,y+12,tableWidth);y+=22;}
  const notes=comparison?[
    'Basis: Basic salary + Elaun Kedatangan + Elaun Perkhidmatan + Elaun Kerajinan. RM amounts; other earnings are excluded.',
    'Actual increment = sum of positive increases per field versus its highest saved value in the preceding seven calendar months. Reductions do not offset increases.',
    'Expected = maintained increment schedule for the selected month. Diff. = actual minus expected. Additional means an increase without eligibility.',
    'Review means missing prior payroll, invalid values or duplicate payroll; no increment is assumed. Unverified amounts are excluded from verified totals.',
    'Eligibility uses current active employees and current maintained schedules. This report is read-only; it does not award increments or freeze earlier schedules.',
  ]:[
    'Source: current active employees and maintained salary-default increment schedules for the selected month (valid RM50 steps from RM50 to RM1,000).',
    'This is the scheduled eligibility list before payroll generation. It does not confirm payment or change any salary values.',
    'After generating payroll, print the comparison report to check recipients, missing or different amounts, and additional increases.',
  ];
  notes.forEach((note,index)=>text(note,24,y+16+index*17,tableWidth,{size:7}));
  finishOnePage(doc);return done;
}
