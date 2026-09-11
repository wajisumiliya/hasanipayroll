import assert from "node:assert/strict";
import test from "node:test";

import {
  findActiveEmployeeIdentity,
  findPasswordResetUser,
  normalizeIdentityNumber,
  resolvePasswordRecoveryEmployeeId,
} from "../src/identity.js";

test("normalizeIdentityNumber ignores case, spaces, and hyphens", () => {
  assert.equal(normalizeIdentityNumber("  ae-21 4357 "), "AE214357");
});

test("normalizeIdentityNumber ignores common IC formatting characters", () => {
  assert.equal(normalizeIdentityNumber(" 900101/02-1234 "), "900101021234");
});

test("password recovery uses linked employee ID when available", () => {
  assert.equal(
    resolvePasswordRecoveryEmployeeId({ employeeId: " emp-001 " }, "other"),
    "EMP-001",
  );
});

test("password recovery falls back to entered employee ID for legacy users", () => {
  assert.equal(
    resolvePasswordRecoveryEmployeeId({ employeeId: null }, " emp-002 "),
    "EMP-002",
  );
});

test("findActiveEmployeeIdentity queries the current employees schema", async () => {
  let capturedQuery;
  let capturedValues;
  const pool = {
    async query(query, values) {
      capturedQuery = query;
      capturedValues = values;
      return { rows: [{ new_ic_no: "AE214357" }] };
    },
  };

  const identity = await findActiveEmployeeIdentity(pool, " emp-001 ");

  assert.equal(identity, "AE214357");
  assert.match(capturedQuery, /FROM public\.employees/);
  assert.match(capturedQuery, /to_jsonb\(employee_row\) ->> 'new_ic_no'/);
  assert.match(capturedQuery, /to_jsonb\(employee_row\) ->> 'newIcNo'/);
  assert.match(capturedQuery, /to_jsonb\(employee_row\) ->> 'employee_id'/);
  assert.match(capturedQuery, /to_jsonb\(employee_row\) ->> 'is_active'/);
  assert.deepEqual(capturedValues, ["EMP-001"]);
});

test("findActiveEmployeeIdentity returns null when no employee matches", async () => {
  const pool = { query: async () => ({ rows: [] }) };

  assert.equal(await findActiveEmployeeIdentity(pool, "EMP-404"), null);
});

test("findPasswordResetUser tolerates legacy snake_case account columns", async () => {
  let capturedValues;
  const pool = {
    async query(_query, values) {
      capturedValues = values;
      return {
        rows: [{
          data: {
            id: "user-1",
            password_hash: "hash",
            password_changed_at: "2026-09-11T00:00:00.000Z",
            is_active: "t",
          },
        }],
      };
    },
  };

  const user = await findPasswordResetUser(pool, " user-1 ");

  assert.deepEqual(capturedValues, ["user-1"]);
  assert.equal(user.passwordHash, "hash");
  assert.equal(user.passwordChangedAt, "2026-09-11T00:00:00.000Z");
  assert.equal(user.isActive, true);
});

test("findPasswordResetUser returns null for a missing user", async () => {
  const pool = { query: async () => ({ rows: [] }) };

  assert.equal(await findPasswordResetUser(pool, "user-404"), null);
  assert.equal(await findPasswordResetUser(pool, "  "), null);
});
