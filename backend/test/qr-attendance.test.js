import test from 'node:test';
import assert from 'node:assert/strict';
import {credential,hashQr,validQr,nextPunch,attendanceProposal,dayMY,newWorkDate} from '../src/qr-attendance-core.js';
const policy={branch_id:'A',min_interval_seconds:60,max_open_hours:36,allow_multiple_sessions:true};
test('QR credentials are unpredictable, contain no employee identifier and hash deterministically',()=>{
  const a=credential(),b=credential();assert.ok(validQr(a));assert.notEqual(a,b);assert.equal(hashQr(a).length,64);assert.notEqual(hashQr(a),a);assert.ok(!validQr('EMP001'));
});
test('server timestamps toggle globally across midnight and preserve original work date',()=>{
  const last={action:'IN',branch_id:'A',work_date:'2026-10-31',scanned_at:'2026-10-31T15:00:00Z',raw_id:'1'};
  const out=nextPunch(last,new Date('2026-10-31T17:00:00Z'),policy);
  assert.equal(out.action,'OUT');assert.equal(out.work_date,'2026-10-31');assert.equal(dayMY('2026-10-31T17:00:00Z'),'2026-11-01');
  assert.equal(nextPunch({...last,action:'OUT'},new Date('2026-10-31T17:00:00Z'),policy).action,'IN');
});
test('double scans, ambiguous open sessions and wrong-branch open sessions cannot silently toggle',()=>{
  const last={action:'IN',branch_id:'A',work_date:'2026-10-31',scanned_at:'2026-10-31T00:00:00Z'};
  assert.throws(()=>nextPunch(last,new Date('2026-10-31T00:00:30Z'),policy),e=>e.code==='RAPID_SCAN');
  assert.throws(()=>nextPunch(last,new Date('2026-11-02T00:00:00Z'),policy),e=>e.code==='AMBIGUOUS_SESSION');
  assert.throws(()=>nextPunch({...last,branch_id:'B'},new Date('2026-10-31T01:00:00Z'),policy),e=>e.code==='OPEN_OTHER_BRANCH');
  assert.throws(()=>nextPunch({...last,action:'OUT'},new Date('2026-10-31T01:00:00Z'),{...policy,allow_multiple_sessions:false}),e=>e.code==='DAY_COMPLETE');
});
const event=(id,action,ts)=>({event_key:'E'+id,action,scanned_at:ts});
test('reconciliation maps gaps to existing BREAK pairs and never creates overtime authorization',()=>{
  const proposal=attendanceProposal([event(1,'IN','2026-10-31T01:00:00Z'),event(2,'OUT','2026-10-31T05:00:00Z'),event(3,'IN','2026-10-31T06:00:00Z'),event(4,'OUT','2026-10-31T10:00:00Z')]);
  assert.equal(proposal.valid,true);assert.equal(proposal.fields.check_in,'09:00:00');assert.equal(proposal.fields.check_out,'18:00:00');
  assert.equal(proposal.fields.morning_in,'13:00:00');assert.equal(proposal.fields.morning_out,'14:00:00');
  assert.equal(proposal.fields.work_minutes,540);assert.equal(proposal.fields.net_working_minutes,480);assert.equal(proposal.fields.break_minutes,60);
  assert.equal(proposal.fields.overtime_in,undefined);assert.equal(proposal.fields.ot_authorized,undefined);
});
test('incomplete, impossible and ambiguous workdays require review instead of overwriting sheets',()=>{
  for(const events of [[event(1,'IN','2026-10-31T01:00Z')],[event(1,'OUT','2026-10-31T01:00Z')],
    [event(1,'IN','2026-10-31T01:00Z'),event(2,'OUT','2026-11-01T02:00Z')]]) assert.equal(attendanceProposal(events).valid,false);
  const original=[event(1,'IN','2026-10-31T01:00Z'),event(2,'OUT','2026-10-31T10:00Z')];
  const changed=[original[0],{...original[1],scanned_at:'2026-10-31T11:00Z',correction_id:1}];
  assert.notEqual(attendanceProposal(original).fingerprint,attendanceProposal(changed).fingerprint);
});

test('a configured previous overnight roster anchors an after-midnight IN to its shift date',()=>{
  const roster={shift_start:'22:00',shift_end:'06:00',assignment_type:'SHIFT'};
  assert.equal(newWorkDate('2026-10-31T17:00:00Z',roster),'2026-10-31');
  assert.equal(newWorkDate('2026-10-31T23:00:00Z',roster),'2026-11-01');
  assert.equal(newWorkDate('2026-10-31T17:00:00Z',{...roster,assignment_type:'OFF'}),'2026-11-01');
  assert.equal(newWorkDate('2026-10-31T17:00:00Z',null),'2026-11-01');
});
