import test from 'node:test';
import assert from 'node:assert/strict';
import {compileTableQuery} from '../src/data-api.js';
import {installQrAttendanceApi} from '../src/qr-attendance.js';
test('QR feature is disabled by default without touching the database',()=>{
  let route;
  installQrAttendanceApi({use(path,auth,callback){assert.equal(path,'/api/qr-attendance');route=callback;}},{query(){throw Error('must not query');}},()=>{});
  const res={status(code){this.code=code;return this;},json(data){this.data=data;return this;}};
  route({},res);assert.equal(res.code,503);assert.equal(res.data.code,'QR_DISABLED');
});

test('generic database API cannot expose QR credentials or mutate raw punches',()=>{
  for(const table of ['qr_attendance_credentials','qr_attendance_events','qr_attendance_sessions','qr_attendance_audit']) {
    assert.throws(()=>compileTableQuery({table,method:'GET',params:new URLSearchParams(),columns:new Map([['employee_id','text']])}));
    assert.throws(()=>compileTableQuery({table,method:'PATCH',params:new URLSearchParams({employee_id:'eq.E1'}),body:{employee_id:'E2'},columns:new Map([['employee_id','text']])}));
  }
});
