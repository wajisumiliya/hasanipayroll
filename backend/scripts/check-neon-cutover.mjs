// Read-only audit: database/auth/realtime must be moved to Neon/Render.
// Storage and notifications remain on Supabase until a later migration.
// Run from repository root: node backend/scripts/check-neon-cutover.mjs
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "../..");
const findings = [];
const patterns = [
  ["database", /Supabase\.instance\.client\.rest|\.client\.rest\b|\.from\s*\(|\.rpc\s*\(/],
  ["auth", /\.auth\.|Supabase\.initialize\s*\(/],
  ["realtime", /\.channel\s*\(|\.onPostgresChanges\s*\(|\.removeChannel\s*\(/],
];
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) { walk(file); continue; }
    if (!file.endsWith(".dart")) continue;
    fs.readFileSync(file, "utf8").split(/\r?\n/).forEach((line, index) => {
      for (const [category, pattern] of patterns) {
        if (pattern.test(line)) findings.push({
          path: path.relative(root, file).replaceAll("\\", "/"),
          line: index + 1,
          category,
          excerpt: line.trim().slice(0, 120),
        });
      }
    });
  }
}
walk(path.join(root, "lib"));
console.log(JSON.stringify({
  ready: findings.length === 0,
  note: "Conservative audit: .from/.rpc calls using Neon adapters can be false positives; review findings manually. Supabase Storage and notifications are excluded by agreement.",
  findings,
}, null, 2));
if (process.argv.includes("--strict") && findings.length) process.exitCode = 1;
