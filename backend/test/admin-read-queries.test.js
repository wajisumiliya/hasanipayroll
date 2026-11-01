import test from 'node:test';
import assert from 'node:assert/strict';
import pg from 'pg';
import {dashboardPayrollQuery,payrollAttendanceQuery,expandAttendanceCounts} from '../src/admin-read-queries.js';

test('smaller admin queries preserve history amounts and attendance frequencies', {skip:!process.env.BOOTSTRAP_TEST_DATABASE_URL},async()=>{
  const url=new URL(process.env.BOOTSTRAP_TEST_DATABASE_URL);
  assert.ok(['localhost','127.0.0.1'].includes(url.hostname));assert.equal(url.pathname,'/hasani_bootstrap_test');
  const bootstrap=new pg.Pool({connectionString:url.toString()});
  await bootstrap.query('CREATE DATABASE hasani_read_queries_test');url.pathname='/hasani_read_queries_test';
  const pool=new pg.Pool({connectionString:url.toString()});
  try {
    await pool.query(`CREATE TABLE payroll(employee_id text,period date,basic_salary numeric,net_pay numeric,remarks text);
      CREATE TABLE attendance(employee_id text,branch_id text,attendance_date date);
      INSERT INTO payroll VALUES
      ('E1','2026-10-01',2050,1800,repeat('current',1000)),
      ('E1','2026-09-01',2000,1750,repeat('history',1000)),
      ('E1','2026-02-01',1900,1600,'outside'),('E1','2026-11-01',2100,1900,'future');
      INSERT INTO attendance SELECT 'E1','A',d::date FROM generate_series('2026-10-01'::date,'2026-10-20'::date,'1 day') d;
      INSERT INTO attendance VALUES('E1','B','2026-10-21'),('E1','A','2026-09-30'),('E1','B','2026-11-01');`);
    const full=(await pool.query(`SELECT to_jsonb(p) AS row FROM payroll p WHERE period>='2026-03-01' AND period<'2026-11-01' ORDER BY period`)).rows.map(r=>r.row);
    const compact=(await pool.query(dashboardPayrollQuery,[2026,10])).rows;
    assert.equal(compact.length,2);
    for(const {row,selected} of compact){
      const original=full.find(r=>r.period===row.period);
      assert.equal(row.basic_salary,original.basic_salary);assert.equal(row.net_pay,original.net_pay);
      if(selected)assert.deepEqual(row,original);
      else {const {remarks,...expected}=original;assert.deepEqual(row,expected);}
    }
    assert.ok(Buffer.byteLength(JSON.stringify(compact))<Buffer.byteLength(JSON.stringify(full))*0.65);
    const grouped=(await pool.query(payrollAttendanceQuery,[2026,10])).rows;
    assert.equal(grouped.length,2);assert.equal(grouped.find(r=>r.branch_id==='A').attendance_count,20);
    assert.equal(grouped.find(r=>r.branch_id==='B').attendance_count,1);
    assert.equal(grouped.reduce((sum,r)=>sum+r.attendance_count,0),21);
    const wireRows=(await pool.query("SELECT employee_id,branch_id FROM attendance WHERE attendance_date>='2026-10-01' AND attendance_date<'2026-11-01'")).rows;
    const sort=rows=>rows.map(r=>JSON.stringify(r)).sort();
    assert.deepEqual(sort(expandAttendanceCounts(grouped)),sort(wireRows));
  } finally {
    await pool.end();await bootstrap.query('DROP DATABASE hasani_read_queries_test WITH (FORCE)');await bootstrap.end();
  }
});
