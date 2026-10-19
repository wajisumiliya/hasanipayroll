import dns from 'node:dns';
import { promisify } from 'node:util';
import pg from 'pg';

dns.setDefaultResultOrder('ipv4first');
const lookup4 = promisify(dns.resolve4);
const { Pool } = pg;

async function check(label, secret) {
  if (!secret) throw new Error(label + ': missing GitHub secret');
  const url = new URL(secret);
  const hostname = url.hostname;
  let addresses = [];
  try {
    addresses = await lookup4(hostname);
  } catch (error) {
    console.error(label + ': IPv4 DNS lookup failed (' + (error.code || 'UNKNOWN') + ')');
  }
  console.log(label + ': IPv4 DNS ' + (addresses.length ? 'available' : 'unavailable'));
  if (!addresses.length) throw new Error(label + ': no IPv4 address; use an IPv4-capable pooler URL');
  const pool = new Pool({ connectionString: secret, connectionTimeoutMillis: 10000 });
  try {
    const result = await pool.query('SELECT username FROM public.app_user');
    console.log(label + ': connection succeeded');
    return result.rows;
  } catch (error) {
    throw new Error(label + ': connection failed (' + (error.code || 'UNKNOWN') + ')');
  } finally {
    await pool.end();
  }
}

try {
  const sourceRows = await check('Supabase source', process.env.SUPABASE_SOURCE_DATABASE_URL);
  const targetRows = await check('Neon target', process.env.NEON_DATABASE_URL);
  const existing = new Set(targetRows.map((row) => row.username.toLowerCase()));
  const missing = sourceRows.filter((row) => !existing.has(row.username.toLowerCase()));
  console.log(JSON.stringify({ sourceCount: sourceRows.length, neonCount: targetRows.length, missingAccounts: missing.length }));
  if (missing.length) process.exitCode = 2;
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
