import test from "node:test";
import assert from "node:assert/strict";
import { createNeonFileRouter } from "../src/neon-file-router.js";

test("requires authorization callback before constructing routes", () => {
  assert.throws(() => createNeonFileRouter({ db: { query() {} } }), /Authorization callback required/);
});
test("requires a database query interface", () => {
  assert.throws(() => createNeonFileRouter({ authorizeEmployee() { return false; } }), /Database client required/);
});
test("registers opt-in GET and POST routes without mounting on the application", () => {
  const router = createNeonFileRouter({
    db: { async query() { return { rows: [] }; } },
    authorizeEmployee: async () => false,
  });
  assert.equal(typeof router, "function");
  assert.ok(router.stack.length >= 3);
});
