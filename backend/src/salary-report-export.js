import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';
import {fileURLToPath} from 'node:url';
import {drawReportLogo} from './report-branding.js';

export const salaryReportTotal=values=>Math.round(values.reduce((sum,value)=>sum+Math.round(Number(value??0)*100),0))/100;
export const salaryReportMonthLabel=month=>/^\d{4}-\d{2}$/.test(month.key??'')?`${month.key.slice(5)}/${month.key.slice(0,4)}`:month.label;
export const salaryReportTitle=(report,branch)=>`HASANI BOOKS STAFF SALARY REPORT JUL'${String(report.start_year).slice(-2)} TO JUN'${String(report.start_year+1).slice(-2)} - ${branch.name}`;
export const salaryReportHeaders=report=>['S.No','Employee ID','Employee Name',...report.months.map(salaryReportMonthLabel),'Annual Total'];
export const salaryReportRows=branch=>branch.rows.map((row,index)=>[index+1,row.employee_id,row.name,...row.values,salaryReportTotal(row.values)]);
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
    sheet.addRow([salaryReportTitle(report,branch)]);
    sheet.addRow([]);
    sheet.mergeCells('A1:P2');
    sheet.addRow(salaryReportHeaders(report));
    sheet.addRows(salaryReportRows(branch));
    branch.rows.forEach((row,index)=>{
      report.months.forEach((month,m)=>{
        if(row.temporary_months?.includes(month.key))sheet.getCell(index+4,m+4).note='Temporary historical reconciliation entry. Report only; not a payslip or bank payment.';
      });
      sheet.getCell(index+4,16).value={formula:`SUM(D${index+4}:O${index+4})`,result:salaryReportTotal(row.values)};
    });
    const totalRow=sheet.addRow(['GRAND TOTAL','','',...branch.totals,salaryReportTotal(branch.totals)]);
    sheet.mergeCells(`A${totalRow.number}:C${totalRow.number}`);
    for(let c=4;c<=16;c++){
      const letter=sheet.getColumn(c).letter;
      totalRow.getCell(c).value={formula:`SUM(${letter}4:${letter}${totalRow.number-1})`,result:c===16?salaryReportTotal(branch.totals):branch.totals[c-4]};
    }
    sheet.views=[{state:'frozen',xSplit:3,ySplit:3}];
    sheet.columns.forEach((c,i)=>{c.width=i===0?6:i===1?14:i===2?44:i===15?15:12;});
    sheet.eachRow((row,index)=>{
      row.alignment={vertical:'middle',wrapText:true};
      row.height=index===1||index===2?24:index===3?28:30;
      row.font={name:'Calibri',size:index===1?20:11,bold:index===1||index===3||index===sheet.rowCount};
      if(index===1)row.alignment={horizontal:'center',vertical:'middle',wrapText:true};
      if(index===3){row.fill={type:'pattern',pattern:'solid',fgColor:{argb:'FF15324D'}};row.font={name:'Calibri',size:11,bold:true,color:{argb:'FFFFFFFF'}};row.alignment={horizontal:'center',vertical:'middle'};}
      if(index>=3)row.eachCell({includeEmpty:true},cell=>{
        cell.border={top:{style:'thin',color:{argb:'FFAAAAAA'}},bottom:{style:'thin',color:{argb:'FFAAAAAA'}},left:{style:'thin',color:{argb:'FFAAAAAA'}},right:{style:'thin',color:{argb:'FFAAAAAA'}}};
      });
      if(index>=4)for(let c=4;c<=16;c++){row.getCell(c).numFmt='#,##0.00';row.getCell(c).alignment={horizontal:'right',vertical:'middle'};}
    });
    sheet.getCell('A1').font={name:'Calibri',size:20,bold:true};
    sheet.getCell('A1').alignment={horizontal:'center',vertical:'middle',wrapText:true};
    sheet.autoFilter={from:'A3',to:`P${3+branch.rows.length}`};
    sheet.pageSetup.printArea=`A1:P${sheet.rowCount}`;
    sheet.pageSetup.printTitlesRow='1:3';
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
    const widths=[24,58,128,...Array(12).fill((width-270)/12),60];
    const money=value=>Number(value).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
    const rows=[salaryReportHeaders(report),...salaryReportRows(branch).map((row,r)=>row.map((v,i)=>i>=3&&v!=null?money(v)+(i<15&&branch.rows[r].temporary_months?.includes(report.months[i-3].key)?'*':''):v??'')),['GRAND TOTAL','','',...branch.totals.map(money),money(salaryReportTotal(branch.totals))]];
    const measure=(text,w,bold=false)=>{doc.font(bold?'Bold':'Body').fontSize(6);return doc.heightOfString(String(text),{width:w-6,lineGap:0});};
    const heights=rows.map((row,index)=>Math.max(18,...row.map((value,i)=>measure(value,index===rows.length-1&&i===0?210:widths[i],index===0||index===rows.length-1)+8)));
    const note=report.temporary_count?'* Temporary historical reconciliation entry; report only.':'';
    const noteHeight=note?measure(note,width)+12:0;
    const naturalHeight=70+heights.reduce((a,b)=>a+b,0)+noteHeight;
    const scale=Math.min(1,height/naturalHeight);
    doc.save().translate(20,20).scale(scale);
    drawReportLogo(doc,0,0,{width:115,height:24});
    doc.font('Bold').fontSize(11).text(salaryReportTitle(report,branch),130,0,{width:width-130});
    doc.font('Body').fontSize(10).text(`${report.months[0].label} - ${report.months.at(-1).label} | ${branch.name}`,0,32,{width,lineBreak:false});
    let y=62;
    for(let r=0;r<rows.length;r++){
      let x=0;const bold=r===0||r===rows.length-1;
      if(r===0)doc.rect(0,y,width,heights[r]).fill('#11345F');
      for(let c=0;c<widths.length;c++){
        if(r===rows.length-1&&(c===1||c===2))continue;
        const cellWidth=r===rows.length-1&&c===0?210:widths[c];
        doc.rect(x,y,cellWidth,heights[r]).lineWidth(.3).stroke('#8B96A8');
        doc.font(bold?'Bold':'Body').fontSize(6).fillColor(r===0?'#FFFFFF':'#111111');
        doc.text(String(rows[r][c]),x+3,y+4,{width:cellWidth-6,align:c>=3?'right':'left',lineGap:0,height:heights[r]-8});
        x+=cellWidth;
      }
      y+=heights[r];
    }
    if(note)doc.font('Body').fontSize(6).fillColor('#333333').text(note,0,y+8,{width});
    doc.restore();
  }
  doc.end();return done;
}
export async function renderSalaryReport(report,format){
  if(!report.branches.length)throw Error('No salary rows to export.');
  return format==='pdf'?pdf(report):excel(report);
}
