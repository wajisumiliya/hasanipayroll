import pg from 'pg';
const { Pool } = pg;
const source = new Pool({ connectionString: process.env.SUPABASE_SOURCE_DATABASE_URL });
const target = new Pool({ connectionString: process.env.NEON_DATABASE_URL });
try {
  const sourceRows = await source.query('SELECT username FROM public.app_user');
  const targetRows = await target.query('SELECT username FROM public.app_user');
  const current = new Set(targetRows.rows.map(row => row.username.toLowerCase()));
  const missing = sourceRows.rows.filter(row => !current.has(row.username.toLowerCase()));
  console.log(JSON.stringify({
    sourceCount: sourceRows.rowCount,
    neonCount: targetRows.rowCount,
    missingAccounts: missing.length,
  }));
  if (missing.length) process.exitCode = 2;
} finally {
  await source.end();
  await target.end();
}
