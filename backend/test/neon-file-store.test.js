import test from "node:test";
import assert from "node:assert/strict";
import { validatePayrollFile, storePayrollFile, getPayrollFile } from "../src/neon-file-store.js";

const png = Buffer.from([137,80,78,71,13,10,26,10,0]);
test("validates actual file signatures", () => {
  assert.doesNotThrow(() => validatePayrollFile({bytes:png,contentType:"image/png"}));
  assert.throws(() => validatePayrollFile({bytes:png,contentType:"application/pdf"}), /signature/);
  assert.throws(() => validatePayrollFile({bytes:Buffer.alloc(0),contentType:"image/png"}), /nonempty/);
  assert.throws(() => validatePayrollFile({bytes:Buffer.alloc(5242881),contentType:"image/png"}), /larger/);
});
test("inserts only parameterized bytes and employee ID", async () => {
  const calls=[];
  const db={query:async (...args)=>{calls.push(args);return {rows:[]};}};
  const id=await storePayrollFile(db,{ownerEmployeeId:" EMP001 ",bytes:png,contentType:"image/png"});
  assert.match(id,/^[0-9a-f-]{36}$/);
  assert.equal(calls[0][1][1],"EMP001");
  assert.equal(calls[0][1][3],png);
});
test("reads only within specified employee scope", async () => {
  const db={query:async (sql,args)=>{assert.match(sql,/owner_employee_id = \$2/);assert.deepEqual(args,["123e4567-e89b-12d3-a456-426614174000","EMP001"]);return {rows:[]};}};
  assert.equal(await getPayrollFile(db,{id:"123e4567-e89b-12d3-a456-426614174000",ownerEmployeeId:"EMP001"}),null);
});
