import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = readFileSync(new URL("../../../lib/screens/supabase_service.dart", import.meta.url), "utf8");

test("Neon migration builds can require database configuration", () => {
  assert.match(source, /'REQUIRE_NEON_DATABASE'/);
  assert.match(source, /if \(requireNeonDatabase && !usesNeonDatabase\)/);
  assert.match(source, /Refusing to fall back to Supabase/);
});

test("startup validates Neon configuration before initializing legacy storage client", () => {
  assert.match(source, /static Future<void> initialize\(\) async \{\s*validateDatabaseConfiguration\(\);/);
});
