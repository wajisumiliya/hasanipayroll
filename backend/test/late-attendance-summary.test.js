import test from 'node:test';
import assert from 'node:assert/strict';
import {attendanceSummaryRows,hhmm} from '../src/late-attendance-summary.js';
test('summary separates arrival and break accumulated times and keeps unknown minutes unknown',()=>{
 const rows=attendanceSummaryRows({reports:[
   {arrival_count:3,events:[{type:'arrival',minutes:30},{type:'arrival',minutes:60},{type:'break',minutes:15}]},
   {arrival_count:3,events:[{type:'arrival',minutes:null},{type:'break',minutes:5}]},
   {arrival_count:2,events:[{type:'arrival',minutes:10},{type:'break',minutes:80}]},
 ]});
 assert.equal(rows.length,2);assert.equal(rows[0].arrival_minutes,90);assert.equal(rows[0].break_minutes,15);
 assert.equal(rows[1].arrival_minutes,null);assert.equal(rows[1].break_minutes,5);
 assert.equal(hhmm(90),'01:30');assert.equal(hhmm(null),'—');assert.equal(hhmm(1500),'25:00');
});

test('summary threshold combines main and break counts including break-only employees',()=>{
 const records=[[2,1],[1,2],[0,3],[3,0],[1,1]].map(([arrival_count,break_count])=>({arrival_count,break_count,events:[]}));
 assert.equal(attendanceSummaryRows({reports:records}).length,4);
});
