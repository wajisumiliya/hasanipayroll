import test from 'node:test';
import assert from 'node:assert/strict';
import ExcelJS from 'exceljs';
import { renderLateReport } from '../src/late-report-export.js';

function payload(format, people=1) {
  return {format,year:2026,month:10,branchLabel:'ALOR SETAR',branches:{A:'ALOR SETAR'},
    // Old or unexpected incomplete data must never become exported rows.
    missing_records:Array.from({length:5000},()=>({name:'Do not export',issues:['Missing roster']})),
    reports:Array.from({length:people},(_,i)=>({branch_id:'A',employee_id:`E${i}`,name:`Employee ${i}`,count:4,arrival_count:2,break_count:2,total_minutes:50,previous_count:7,change:-3,
      events:[
        {date:'2026-10-01',type:'arrival',scheduled:'09:00',actual:'09:10',minutes:10,fingerprint:'new',review_outdated:true,
          review_history:[{status:'approved',reason_code:'transport',reason:'=HYPERLINK("example")',reviewed_by:'admin1',reviewed_at:'2026-10-26T01:00:00Z',event_fingerprint:'old',event_snapshot:{minutes:5}}]},
        {date:'2026-10-02',type:'break',allocated_minutes:60,actual_minutes:80,minutes:20,review:{status:'noted',reason_code:'other',reason:'Manager reviewed',reviewed_by:'admin2',reviewed_at:'2026-10-26T02:00:00Z'}},
      ]})),
  };
}
test('worker generates real Excel without incomplete sheets and preserves literal review notes',async()=>{
  const bytes=await renderLateReport(payload('xlsx'));
  const book=new ExcelJS.Workbook();await book.xlsx.load(bytes);
  assert.deepEqual(book.worksheets.map(s=>s.name),['Summary','Events','Review history']);
  assert.equal(book.getWorksheet('Events').rowCount,3);
  assert.equal(book.getWorksheet('Events').getCell('A2').value,'ALOR SETAR');
  assert.equal(book.getWorksheet('Events').getCell('I2').value,'Needs re-review');
  assert.equal(book.getWorksheet('Events').getCell('K3').value,'Manager reviewed');
  assert.equal(book.getWorksheet('Review history').getCell('H2').value,'=HYPERLINK("example")');
  assert.equal(book.getWorksheet('Review history').getCell('J2').value,'26/10/2026, 09:00:00 MYT');
  for(const sheet of book.worksheets) sheet.eachRow(row=>assert.ok(!JSON.stringify(row.values).includes('Missing roster')));
});
test('PDF worker renders multiple pages while main event loop remains responsive',async()=>{
  let ticks=0;const timer=setInterval(()=>ticks++,2);
  let bytes;
  try {bytes=await renderLateReport(payload('pdf',50));}finally{clearInterval(timer);}
  assert.equal(bytes.subarray(0,5).toString(),'%PDF-');
  assert.ok((bytes.toString('latin1').match(/\/Type \/Page\b/g)??[]).length>1);
  assert.ok(ticks>5,`event-loop heartbeats: ${ticks}`);
});
test('empty report is a valid downloadable file in each format',async()=>{
  for(const format of ['pdf','xlsx']) {
    const data=payload(format);data.reports=[];
    const bytes=await renderLateReport(data);assert.ok(bytes.length>500);
  }
});
test('worker timeout rejects and frees capacity for subsequent export',async()=>{
  await assert.rejects(renderLateReport(payload('pdf'),{timeoutMs:1}),/timed out/);
  assert.ok((await renderLateReport(payload('xlsx'))).length>500);
});

test('attendance summary PDF always fits empty and dense selections on one A4 page',async()=>{
 for(const count of [0,1,60]) {
   const data=payload('pdf',count);data.view='attendance-summary';
   for(const r of data.reports)r.arrival_count=3;
   const bytes=await renderLateReport(data);
   assert.equal(bytes.subarray(0,5).toString(),'%PDF-');
   assert.equal((bytes.toString('latin1').match(/\/Type \/Page\b/g)??[]).length,1);
 }
});
