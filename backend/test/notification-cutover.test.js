import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = readFileSync(new URL("../../../lib/services/notification_service.dart", import.meta.url), "utf8");

test("notification device registration remains on Supabase until separate cutover", () => {
  assert.match(source, /SupabaseService\.client\.rpc\(\s*'register_notification_device'/);
  assert.doesNotMatch(source, /SupabaseService\.database\.rpc\(\s*'register_notification_device'/);
});

test("notification dispatch remains on existing Supabase function", () => {
  assert.match(source, /SupabaseService\.client\.functions\.invoke/);
});
