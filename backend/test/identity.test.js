import assert from "node:assert/strict";
import test from "node:test";

import {
  findActiveEmployeeIdentity,
  normalizeIdentityNumber,
} from "../src/identity.js";

test("normalizeIdentityNumber ignores case, spaces, and hyphens", () => {
  assert.equal(normalizeIdentityNumber("  ae-21 4357 "), "AE214357");
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
  assert.match(capturedQuery, /is_active IS TRUE/);
  assert.deepEqual(capturedValues, ["EMP-001"]);
});

test("findActiveEmployeeIdentity returns null when no employee matches", async () => {
  const pool = { query: async () => ({ rows: [] }) };

  assert.equal(await findActiveEmployeeIdentity(pool, "EMP-404"), null);
});
