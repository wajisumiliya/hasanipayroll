import assert from "node:assert/strict";
import test from "node:test";
import {
  buildAttendanceUpserts,
  withCanonicalBranchId,
} from "../src/attendance-batch.js";

test("attendance days with matching fields use one parameterized multi-row upsert", () => {
  const rows = [
    { employee_id: "E-1", branch_id: "B-1", attendance_date: "2026-10-01", status: "Present" },
    { employee_id: "E-1", branch_id: "B-1", attendance_date: "2026-10-02", status: "Absent" },
  ];

  const [query] = buildAttendanceUpserts(rows);
  assert.match(query.sql, /VALUES \(\$1,\$2,\$3,\$4\),\(\$5,\$6,\$7,\$8\)/);
  assert.match(query.sql, /ON CONFLICT \(employee_id,attendance_date\) DO UPDATE SET status=EXCLUDED.status/);
  assert.deepEqual(query.values, [
    "E-1", "B-1", "2026-10-01", "Present",
    "E-1", "B-1", "2026-10-02", "Absent",
  ]);
  assert.ok(!query.sql.includes("E-1"));
});

test("rows with different optional fields are safely grouped", () => {
  const queries = buildAttendanceUpserts([
    { employee_id: "E-1", branch_id: "B-1", attendance_date: "2026-10-01", status: "Present" },
    { employee_id: "E-1", branch_id: "B-1", attendance_date: "2026-10-02", status: "Present", approved_ot_minutes: 30 },
  ]);

  assert.equal(queries.length, 2);
  assert.match(queries[0].sql, /SET status=EXCLUDED.status$/);
  assert.match(queries[1].sql, /SET status=EXCLUDED.status,approved_ot_minutes=EXCLUDED.approved_ot_minutes$/);
});

test("verified employee branch replaces stale or differently formatted client branch", () => {
  const trusted = withCanonicalBranchId(
    { employee_id: "E-1", branch_id: "Old display branch" },
    "BLJ033",
  );

  assert.equal(trusted.branch_id, "BLJ033");
  assert.equal(trusted.employee_id, "E-1");
});
