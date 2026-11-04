import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';
import {fileURLToPath} from 'node:url';
import {drawReportLogo} from './report-branding.js';

export const salaryReportHeaders=report=>['Sno','Employee ID','Employee Name',...report.months.map(m=>m.label)];
export const salaryReportRows=branch=>branch.rows.map((row,index)=>[index+1,row.employee_id,row.name,...row.values]);
export function salarySheetName(name,used){
  const base=(String(name).replace(/[\\/*?:\[\]]/g,' ').replace(/^'+|'+$/g,'').trim()||'Branch').slice(0,31);
  let result=base,index=2;
  while(used.has(result.toLowerCase())){const suffix=` (${index++})`;result=base.slice(0,31-suffix.length)+suffix;}
  used.add(result.toLowerCase());return result;
}
async function excel(report){
  const book=new ExcelJS.Workbook();book.creator='Hasani Books';
  const used=new Set();
  for(const branch of report.branches){
    const sheet=book.addWorksheet(salarySheetName(branch.name,used),{
      pageSetup:{paperSize:9,orientation:'landscape',fitToPage:true,fitToWidth:1,fitToHeight:1}});
    sheet.addRow(['Salary Report']);
    sheet.addRow([`${report.months[0].label} - ${report.months.at(-1).label}`,branch.name]);
    sheet.addRow([report.note]);sheet.addRow([report.branch_note]);
    sheet.addRow(salaryReportHeaders(report));
    sheet.addRows(salaryReportRows(branch));
    sheet.addRow(['TOTAL','','',...branch.totals]);
    sheet.mergeCells(`A${sheet.rowCount}:C${sheet.rowCount}`);
    sheet.mergeCells('A1:O1');sheet.mergeCells('A3:O3');sheet.mergeCells('A4:O4');
    sheet.views=[{state:'frozen',xSplit:3,ySplit:5}];
    sheet.columns.forEach((c,i)=>{c.width=i===0?6:i===1?18:i===2?34:15;});
    sheet.eachRow((row,index)=>{
      row.alignment={vertical:'middle',wrapText:true};
      row.height=index===3?32:index===4?30:index>=6&&index<sheet.rowCount?30:24;
      if(index===1||index===5||index===sheet.rowCount)row.font={bold:true};
      if(index===5){row.fill={type:'pattern',pattern:'solid',fgColor:{argb:'FF11345F'}};row.font={bold:true,color:{argb:'FFFFFFFF'}};}
      if(index>=6)for(let c=4;c<=15;c++){row.getCell(c).numFmt='#,##0.00';row.getCell(c).alignment={horizontal:'right',vertical:'middle'};}
    });
    sheet.autoFilter={from:'A5',to:`O${5+branch.rows.length}`};
  }
  return book.xlsx.writeBuffer();
}
async function pdf(report){
  const doc=new PDFDocument({size:'A4',layout:'landscape',margin:20,autoFirstPage:false});
  const parts=[],done=new Promise((resolve,reject)=>{doc.on('data',c=>parts.push(c));doc.once('end',()=>resolve(Buffer.concat(parts)));doc.once('error',reject);});
  doc.registerFont('Body',fileURLToPath(new URL('../assets/fonts/DejaVuSans.ttf',import.meta.url)));
  doc.registerFont('Bold',fileURLToPath(new URL('../assets/fonts/DejaVuSans-Bold.ttf',import.meta.url)));
  for(const branch of report.branches){
    doc.addPage();
    const width=doc.page.width-40,height=doc.page.height-40;
    const widths=[24,65,130,...Array(12).fill((width-219)/12)];
    const rows=[salaryReportHeaders(report),...salaryReportRows(branch).map(row=>row.map((v,i)=>i>=3&&v!=null?Number(v).toFixed(2):v??'')),['TOTAL','','',...branch.totals.map(v=>v.toFixed(2))]];
    const measure=(text,w,bold=false)=>{doc.font(bold?'Bold':'Body').fontSize(7);return doc.heightOfString(String(text),{width:w-6,lineGap:0});};
    const heights=rows.map((row,index)=>Math.max(18,...row.map((value,i)=>measure(value,index===rows.length-1&&i===0?219:widths[i],index===0||index===rows.length-1)+8)));
    const noteHeight=measure(report.note,width)+measure(report.branch_note,width)+16;
    const naturalHeight=70+heights.reduce((a,b)=>a+b,0)+noteHeight;
    const scale=Math.min(1,height/naturalHeight);
    doc.save().translate(20,20).scale(scale);
    drawReportLogo(doc,0,0,{width:115,height:24});
    doc.font('Bold').fontSize(15).text('Salary Report',130,0,{width:width-130,lineBreak:false});
    doc.font('Body').fontSize(10).text(`${report.months[0].label} - ${report.months.at(-1).label} | ${branch.name}`,0,32,{width,lineBreak:false});
    let y=62;
    for(let r=0;r<rows.length;r++){
      let x=0;const bold=r===0||r===rows.length-1;
      if(r===0)doc.rect(0,y,width,heights[r]).fill('#11345F');
      for(let c=0;c<widths.length;c++){
        if(r===rows.length-1&&(c===1||c===2))continue;
        const cellWidth=r===rows.length-1&&c===0?219:widths[c];
        doc.rect(x,y,cellWidth,heights[r]).lineWidth(.3).stroke('#8B96A8');
        doc.font(bold?'Bold':'Body').fontSize(7).fillColor(r===0?'#FFFFFF':'#111111');
        doc.text(String(rows[r][c]),x+3,y+4,{width:cellWidth-6,align:c>=3?'right':'left',lineGap:0,height:heights[r]-8});
        x+=cellWidth;
      }
      y+=heights[r];
    }
    doc.font('Body').fontSize(7).fillColor('#333333').text(report.note,0,y+8,{width,height:measure(report.note,width)+2});
    doc.text(report.branch_note,0,doc.y+4,{width,height:measure(report.branch_note,width)+2});
    doc.restore();
  }
  doc.end();return done;
}
export async function renderSalaryReport(report,format){
  if(!report.branches.length)throw Error('No salary rows to export.');
  return format==='pdf'?pdf(report):excel(report);
}
