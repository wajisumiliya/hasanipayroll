import dns from 'node:dns';
import pg from 'pg';

dns.setDefaultResultOrder('ipv4first');

const { Pool } = pg;
const source = new Pool({
  connectionString: process.env.SUPABASE_SOURCE_DATABASE_URL,
  connectionTimeoutMillis: 10000,
});
const target = new Pool({
  connectionString: process.env.NEON_DATABASE_URL,
  connectionTimeoutMillis: 10000,
});

try {
  const sourceRows = await source.query('SELECT username FROM public.app_user');
  const targetRows = await target.query('SELECT username FROM public.app_user');
  const current = new Set(targetRows.rows.map((row) => row.username.toLowerCase()));
  const missing = sourceRows.rows.filter((row) => !current.has(row.username.toLowerCase()));
  console.log(JSON.stringify({
    sourceCount: sourceRows.rowCount,
    neonCount: targetRows.rowCount,
    missingAccounts: missing.length,
  }));
  if (missing.length) process.exitCode = 2;
} catch (error) {
  if (error.code === 'ENETUNREACH' || error.code === 'ETIMEDOUT') {
    console.error('Database network unreachable. Check that both database URLs use IPv4-reachable pooled endpoints.');
  } else {
    console.error('Account coverage check failed:', error.code || error.name || 'UNKNOWN');
  }
  process.exitCode = 1;
} finally {
  await source.end();
  await target.end();
}
