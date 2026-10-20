// Explicit one-time migration; never imported by the application server.
import 'dotenv/config';
import pg from 'pg';
import { readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { validatePhoto, MAX_PHOTO_BYTES } from '../src/neon-employee-photos.js';

const SOURCE_ORIGIN = 'https://qychfoxygqzmtsqtxihp.supabase.co';
const MARKERS = ['/storage/v1/object/public/employee-photos/',
  '/storage/v1/object/authenticated/employee-photos/', '/storage/v1/object/sign/employee-photos/'];
export function sourceObjectPath(reference) {
  let value = String(reference || '').trim();
  if (!value || value.startsWith('neon-photo/')) return null;
  if (/^https?:/i.test(value)) {
    const url = new URL(value);
    if (url.origin !== SOURCE_ORIGIN) throw new Error('Unexpected source host');
    const marker = MARKERS.find(prefix => url.pathname.startsWith(prefix));
    if (!marker) throw new Error('Unexpected source path');
    value = decodeURIComponent(url.pathname.slice(marker.length));
  } else {
    value = value.replace(/^employee-photos\//,'');
  }
  if (value.split('/').some(part => !part || part === '.' || part === '..') || /[?\\\x00-\x1f]/.test(value)) {
    throw new Error('Invalid source path');
  }
  return value;
}

async function readLimited(response) {
  if (!response.body) throw new Error('Empty photo');
  const chunks = []; let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > 5 * 1024 * 1024) throw new Error('Photo too large');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}
async function optimize(bytes) {
  const executable = process.env.PHOTO_OPTIMIZER_PATH;
  if (!executable) throw new Error('Missing photo optimizer');
  return new Promise((resolve,reject) => {
    const child = spawn(executable, [], {stdio:['pipe','pipe','pipe']});
    const chunks = []; let size = 0; let failed = false;
    const timer = setTimeout(() => { failed=true; child.kill(); }, 30000);
    child.stdout.on('data',chunk => {
      size += chunk.length;
      if (size > MAX_PHOTO_BYTES) { failed=true; child.kill(); } else chunks.push(chunk);
    });
    child.stderr.resume();
    child.stdin.on('error',()=>{});
    child.on('error',()=>{clearTimeout(timer);reject(new Error('Optimizer failed'));});
    child.on('close',code=>{
      clearTimeout(timer);
      if (code || failed) reject(new Error('Optimizer failed')); else resolve(Buffer.concat(chunks));
    });
    child.stdin.end(bytes);
  });
}

export async function copyPhotos({pool,sourceKey,apply=false,fetchPhoto=fetch,encode=optimize}) {
  const summary = {mode:apply?'apply':'dry-run',ready:0,copied:0,alreadyPresent:0,missing:0,failed:0,changed:0};
  const rows = await pool.query(`SELECT e.employee_id,e.photo_url FROM public.employees e
    WHERE e.photo_url IS NOT NULL AND trim(e.photo_url)<>'' ORDER BY e.employee_id`);
  for (const employee of rows.rows) {
    try {
      if ((await pool.query('SELECT 1 FROM app_private.employee_photos WHERE employee_id=$1',[employee.employee_id])).rowCount) {
        summary.alreadyPresent++; continue;
      }
      const path = sourceObjectPath(employee.photo_url);
      if (!path) { summary.failed++; continue; }
      const url = SOURCE_ORIGIN + '/storage/v1/object/authenticated/employee-photos/' + path.split('/').map(encodeURIComponent).join('/');
      const response = await fetchPhoto(url,{headers:{Authorization:'Bearer '+sourceKey,apikey:sourceKey},redirect:'error',signal:AbortSignal.timeout(30000)});
      if (response.status === 404) { summary.missing++; continue; }
      if (!response.ok) throw new Error('Source unavailable');
      const bytes = await encode(await readLimited(response));
      if (!validatePhoto(bytes,'image/jpeg')) throw new Error('Invalid optimized photo');
      summary.ready++;
      if (!apply) continue;
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const current = await client.query('SELECT photo_url FROM public.employees WHERE employee_id=$1 FOR UPDATE',[employee.employee_id]);
        if (!current.rowCount || current.rows[0].photo_url !== employee.photo_url) {
          await client.query('ROLLBACK'); summary.changed++; continue;
        }
        const saved = await client.query(`INSERT INTO app_private.employee_photos(employee_id,content_type,photo_bytes)
          VALUES ($1,'image/jpeg',$2) ON CONFLICT(employee_id) DO NOTHING RETURNING employee_id`,[employee.employee_id,bytes]);
        if (!saved.rowCount) { await client.query('ROLLBACK'); summary.alreadyPresent++; continue; }
        await client.query('UPDATE public.employees SET photo_url=$2 WHERE employee_id=$1',[employee.employee_id,'neon-photo/'+employee.employee_id]);
        await client.query('COMMIT'); summary.copied++;
      } catch (error) { await client.query('ROLLBACK'); throw error; }
      finally { client.release(); }
    } catch { summary.failed++; }
  }
  return summary;
}
async function main() {
  const sourceKey = process.env.SUPABASE_SOURCE_SERVICE_ROLE_KEY;
  const connectionString = process.env.NEON_DATABASE_URL;
  if (!sourceKey || !connectionString || !process.env.PHOTO_OPTIMIZER_PATH) {
    throw new Error('Set SUPABASE_SOURCE_SERVICE_ROLE_KEY, NEON_DATABASE_URL and PHOTO_OPTIMIZER_PATH.');
  }
  const pool = new pg.Pool({connectionString,max:2});
  try {
    const apply = process.argv.includes('--apply');
    // Only this small additive table is provisioned; do not run the full app bootstrap.
    if (apply) await pool.query(await readFile(new URL('../migrations/20261020_neon_employee_photos.sql',import.meta.url),'utf8'));
    const table = await pool.query("SELECT to_regclass('app_private.employee_photos') AS name");
    if (!table.rows[0].name) throw new Error('Deploy the photo backend, or run --apply to provision the photo table.');
    const summary = await copyPhotos({pool,sourceKey,apply});
    console.log(JSON.stringify(summary)); // Counts only: no identities, URLs, keys or image data.
    if (summary.failed || summary.missing || summary.changed) process.exitCode=1;
  } finally { await pool.end(); }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(()=>{console.error('Photo copy failed. Check the configured secrets, optimizer and source Storage availability.');process.exitCode=1;});
}
