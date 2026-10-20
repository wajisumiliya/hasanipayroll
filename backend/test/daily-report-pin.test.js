import assert from 'node:assert/strict';
import test from 'node:test';
import { isDailyReportPin } from '../src/daily-report-pin.js';

test('daily report verification accepts four digits and leading zeroes',()=>{
  for(const pin of ['0000','0123','1234','2026','9999']) {
    assert.equal(isDailyReportPin(pin),true);
  }
});

test('daily report verification rejects malformed or non-string PINs',()=>{
  for(const pin of ['', '123','12345','abcd','12 3','1234\n','\\dddd',1234,null,undefined]) {
    assert.equal(isDailyReportPin(pin),false);
  }
});
