import test from 'node:test';
import assert from 'node:assert/strict';
import {inflateSync} from 'node:zlib';
import {renderLateReport} from '../src/late-report-export.js';
import {reportMonthLabel} from '../src/late-attendance-summary.js';
function streams(bytes){
  const text=bytes.toString('latin1'),result=[];
  for(const match of text.matchAll(/stream\r?\n([\s\S]*?)\r?\nendstream/g)){
    try{result.push(inflateSync(Buffer.from(match[1],'latin1')).toString('latin1'));}catch{}
  }
  return result.join('\n');
}
test('payroll month title labels use the requested short month and year',()=>{
  assert.equal(reportMonthLabel({year:2026,month:10}),"Oct'26");
  assert.equal(reportMonthLabel({year:2027,month:1}),"Jan'27");
});
test('all summary PDF variants have no alternating row or result-column fill colors',async()=>{
  const basic={employee_id:'E1',name:'Employee',branch_id:'A',count:3,arrival_count:2,break_count:1,
    events:[{type:'arrival',minutes:5},{type:'break',minutes:10}],dates:['2026-10-01'],inc_details:'APR-26/50',
    basic_salary:2000,total_allowances:300,approved_minutes:60,ot_amount:20,result:'Not received'};
  const views=[{view:'attendance-summary'},{view:'status-summary',status:'MC'},{view:'status-summary',status:'UNPAID'},
    {view:'increment-summary',mode:'eligible'},{view:'increment-summary',mode:'comparison'},{view:'ot-summary'}];
  const forbidden=['F1F2F4','F1F3F6','FFDADD','FFC6CD','D7E8FA','FFE5E5','D8F1E8'].map(hex=>[0,2,4].map(i=>parseInt(hex.slice(i,i+2),16)/255));
  for(const view of views){
    const bytes=await renderLateReport({format:'pdf',year:2026,month:10,branchLabel:'All branches',branches:{A:'Branch A'},
      reports:[basic,{...basic,employee_id:'E2',result:'Received'}],counts:{Eligible:2},eligible_count:2,basic_total:4000,allowance_total:600,...view});
    assert.match(bytes.toString('latin1'),/\/Subtype \/Image\b/,'supplied logo must be embedded in every report');
    const commands=streams(bytes);
    const colors=[...commands.matchAll(/\/DeviceRGB cs\s+([\d.]+) ([\d.]+) ([\d.]+) scn/g)].map(m=>m.slice(1).map(Number));
    assert.ok(colors.length>0);
    assert.ok(!colors.some(color=>forbidden.some(shade=>color.every((value,i)=>Math.abs(value-shade[i])<0.00001))),view.view);
    assert.equal((bytes.toString('latin1').match(/\/Type \/Page\b/g)??[]).length,1);
  }
});
