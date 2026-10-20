// PostgREST-shaped adapter for the operations used by the existing Flutter
// client. SQL identifiers come from a fixed table list plus schema metadata;
// values are always parameters. PostgreSQL RLS authorizes every table query.
const TABLES = new Set([
  'employees', 'payroll', 'attendance', 'branches', 'employee_salary_defaults',
  'monthly_rosters', 'daily_rosters', 'employee_requests', 'overtime_requests',
  'leave_requests', 'employee_ea_forms', 'branch_activity_logs',
  'app_notifications', 'notification_reads', 'daily_reports', 'staff_transfer_history',
]);
const RPCS = new Set([
  'admin_branch_activity_logs', 'approve_employee_request', 'change_daily_report_pin',
  'get_employee_garden', 'record_employee_garden_visit', 'register_notification_device',
  'schedule_monthly_payslip_release', 'set_employee_active_status', 'tend_employee_garden',
  'transfer_staff', 'verify_daily_report_pin',
]);
const OPTIONS = new Set(['select', 'order', 'limit', 'offset', 'on_conflict', 'columns']);
const q = (name) => '"' + name.replaceAll('"', '""') + '"';
export class DataApiError extends Error {
  constructor(message, status = 400, code = 'PGRST100') { super(message); this.status = status; this.code = code; }
}
function requireColumn(name, columns) {
  if (!columns.has(name)) throw new DataApiError(`Unknown or unavailable column: ${name}`, 400, 'PGRST204');
  return q(name);
}
export function splitTerms(value) {
  const terms = []; let start = 0, depth = 0, quoted = false, escaped = false;
  for (let i = 0; i < value.length; i++) {
    const char = value[i];
    if (escaped) { escaped = false; continue; }
    if (char === '\\') { escaped = true; continue; }
    if (char === '"') quoted = !quoted;
    if (!quoted && char === '(') depth++;
    if (!quoted && char === ')') depth--;
    if (depth < 0) throw new DataApiError('Unbalanced filter');
    if (!quoted && depth === 0 && char === ',') { terms.push(value.slice(start, i)); start = i + 1; }
  }
  if (quoted || depth) throw new DataApiError('Unbalanced filter');
  terms.push(value.slice(start));
  return terms.filter(Boolean);
}
function unquote(value) {
  if (value.startsWith('"') && value.endsWith('"')) return value.slice(1, -1).replace(/\\(.)/g, '$1');
  return value;
}
function predicate(column, expression, columns, values) {
  const field = requireColumn(column, columns);
  let negate = false;
  if (expression.startsWith('not.')) { negate = true; expression = expression.slice(4); }
  const dot = expression.indexOf('.');
  if (dot < 0) throw new DataApiError('Invalid filter');
  const op = expression.slice(0, dot), raw = expression.slice(dot + 1);
  let sql;
  if (op === 'is') {
    const literals = { null: 'NULL', true: 'TRUE', false: 'FALSE', unknown: 'UNKNOWN' };
    if (!(raw in literals)) throw new DataApiError('Invalid IS filter');
    sql = `${field} IS ${literals[raw]}`;
  } else if (op === 'in') {
    if (!raw.startsWith('(') || !raw.endsWith(')')) throw new DataApiError('Invalid IN filter');
    const items = splitTerms(raw.slice(1, -1));
    if (items.length > 2000) throw new DataApiError('Too many filter values');
    const placeholders = items.map((item) => { values.push(unquote(item)); return '$' + values.length; });
    sql = placeholders.length ? `${field} IN (${placeholders.join(',')})` : 'FALSE';
  } else {
    const operators = { eq: '=', neq: '<>', gt: '>', gte: '>=', lt: '<', lte: '<=', like: 'LIKE', ilike: 'ILIKE' };
    if (!operators[op]) throw new DataApiError('Unsupported filter operator');
    values.push(['like', 'ilike'].includes(op) ? unquote(raw).replaceAll('*', '%') : unquote(raw));
    sql = `${field} ${operators[op]} $${values.length}`;
  }
  return negate ? `NOT (${sql})` : sql;
}
function logic(expression, columns, values, depth = 0) {
  if (depth > 8) throw new DataApiError('Filter nesting is too deep');
  const match = /^(and|or)\((.*)\)$/s.exec(expression);
  if (match) return '(' + splitTerms(match[2]).map((term) => logic(term, columns, values, depth + 1)).join(match[1] === 'and' ? ' AND ' : ' OR ') + ')';
  const dot = expression.indexOf('.');
  if (dot < 0) throw new DataApiError('Invalid logical filter');
  return predicate(expression.slice(0, dot), expression.slice(dot + 1), columns, values);
}
export function compileWhere(params, columns, values) {
  const terms = [];
  for (const [name, expression] of params) {
    if (OPTIONS.has(name)) continue;
    if (name === 'or' || name === 'and') {
      if (!expression.startsWith('(') || !expression.endsWith(')')) throw new DataApiError('Invalid logical filter');
      terms.push(logic(name + expression, columns, values));
    } else terms.push(predicate(name, expression, columns, values));
  }
  return terms.length ? ' WHERE ' + terms.join(' AND ') : '';
}
function integer(value, fallback, max) {
  if (value === null) return fallback;
  if (!/^\d+$/.test(value)) throw new DataApiError('Invalid query range');
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number > max) throw new DataApiError('Query range too large');
  return number;
}
function projection(params, columns) {
  const selected = params.get('select') || '*';
  const names = selected === '*' ? [...columns.keys()] : splitTerms(selected);
  if (!names.length) throw new DataApiError('No columns selected');
  return names.map((name) => requireColumn(name, columns)).join(',');
}
function orderBy(params, columns) {
  if (!params.get('order')) return '';
  return ' ORDER BY ' + splitTerms(params.get('order')).map((term) => {
    const [name, direction = 'asc', nulls] = term.split('.');
    if (!['asc', 'desc'].includes(direction) || (nulls && !['nullsfirst', 'nullslast'].includes(nulls))) throw new DataApiError('Invalid ordering');
    return `${requireColumn(name, columns)} ${direction.toUpperCase()}${nulls ? (nulls === 'nullsfirst' ? ' NULLS FIRST' : ' NULLS LAST') : ''}`;
  }).join(',');
}
function bodyValue(value, type) { return ['json', 'jsonb'].includes(type) && value !== null ? JSON.stringify(value) : value; }
export function compileTableQuery({ table, method, params, body, columns, primaryKey = [], prefer = '' }) {
  if (!TABLES.has(table)) throw new DataApiError('Table is not available', 404);
  const values = [], selected = projection(params, columns), target = `public.${q(table)}`;
  if (method === 'GET' || method === 'HEAD') {
    const where = compileWhere(params, columns, values);
    const limit = integer(params.get('limit'), 1000, 5000), offset = integer(params.get('offset'), 0, 10000000);
    return { sql: `SELECT to_jsonb(result) AS data FROM (SELECT ${selected} FROM ${target}${where}${orderBy(params, columns)} LIMIT ${limit} OFFSET ${offset}) AS result`, values };
  }
  let mutation;
  if (method === 'POST') {
    const rows = Array.isArray(body) ? body : [body];
    if (!rows.length) return { empty: true, values };
    if (rows.length > 2000 || rows.some((row) => !row || typeof row !== 'object' || Array.isArray(row))) throw new DataApiError('Invalid insert payload');
    const names = [...new Set(rows.flatMap(Object.keys))];
    if (!names.length) throw new DataApiError('Empty insert payload');
    names.forEach((name) => requireColumn(name, columns));
    const entries = rows.map((row) => '(' + names.map((name) => {
      if (!Object.hasOwn(row, name)) return 'DEFAULT';
      values.push(bodyValue(row[name], columns.get(name))); return '$' + values.length;
    }).join(',') + ')');
    mutation = `INSERT INTO ${target} (${names.map(q).join(',')}) VALUES ${entries.join(',')}`;
    if (prefer.includes('resolution=merge-duplicates') || prefer.includes('resolution=ignore-duplicates')) {
      const conflict = params.has('on_conflict') ? splitTerms(params.get('on_conflict')) : primaryKey;
      if (!conflict.length) throw new DataApiError('Upsert requires a conflict key');
      const keys = conflict.map((name) => requireColumn(name, columns)).join(',');
      const changes = names.filter((name) => !conflict.includes(name));
      mutation += ` ON CONFLICT (${keys}) ` + (prefer.includes('resolution=ignore-duplicates') || !changes.length ? 'DO NOTHING' : 'DO UPDATE SET ' + changes.map((name) => `${q(name)}=EXCLUDED.${q(name)}`).join(','));
    }
  } else if (method === 'PATCH') {
    if (!body || typeof body !== 'object' || Array.isArray(body) || !Object.keys(body).length) throw new DataApiError('Invalid update payload');
    const assignments = Object.entries(body).map(([name, value]) => {
      requireColumn(name, columns); values.push(bodyValue(value, columns.get(name))); return `${q(name)}=$${values.length}`;
    });
    const where = compileWhere(params, columns, values);
    if (!where) throw new DataApiError('Update requires a filter');
    mutation = `UPDATE ${target} SET ${assignments.join(',')}${where}`;
  } else if (method === 'DELETE') {
    const where = compileWhere(params, columns, values);
    if (!where) throw new DataApiError('Delete requires a filter');
    mutation = `DELETE FROM ${target}${where}`;
  } else throw new DataApiError('Method is not supported', 405);
  return { sql: `WITH changed AS (${mutation} RETURNING ${selected}) SELECT to_jsonb(changed) AS data FROM changed`, values };
}
export async function withDatabaseIdentity(pool, claims, callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT set_config('request.jwt.claims', $1, true)", [JSON.stringify(claims)]);
    await client.query('SET LOCAL ROLE authenticated');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK'); throw error;
  } finally { client.release(); }
}
export function claimsForRequest(req) {
  const metadata = req.auth?.app_metadata || {};
  const role = String(req.user.role || '').toLowerCase();
  return { sub: String(req.user.username || req.auth.sub), role: 'authenticated', app_metadata: {
    ...metadata,
    app_role: metadata.staff_scope === 'requests' ? 'request_admin' : role,
    employee_id: req.user.employeeId || req.user.employee_id || null,
    branch_id: req.user.branch_id || req.user.branchId || metadata.branch_id || null,
  } };
}
function sendError(res, error) {
  const status = error.status || (error.code === '42501' ? 403 : ['23503', '23505', '23514'].includes(error.code) ? 409 : 503);
  const message = error instanceof DataApiError ? error.message : status === 403 ? 'Access denied.' : status === 409 ? 'This change conflicts with existing records or database rules.' : 'Unable to complete the database request.';
  res.status(status).json({ code: error.code || 'DATABASE_UNAVAILABLE', message, details: null, hint: null });
}
export function installDataApi(app, { pool, authenticate }) {
  const metadataCache = new Map();
  async function metadata(table, req) {
    let schema = metadataCache.get(table);
    if (!schema || schema.expiresAt < Date.now()) {
      const result = await pool.query(`SELECT column_name, udt_name FROM information_schema.columns WHERE table_schema='public' AND table_name=$1 ORDER BY ordinal_position`, [table]);
      const pk = await pool.query(`SELECT a.attname FROM pg_index i JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum=ANY(i.indkey) WHERE i.indrelid=to_regclass($1) AND i.indisprimary ORDER BY a.attnum`, ['public.' + table]);
      schema = { columns: new Map(result.rows.map((row) => [row.column_name, row.udt_name])), primaryKey: pk.rows.map((row) => row.attname), expiresAt: Date.now() + 60000 };
      metadataCache.set(table, schema);
    }
    const columns = new Map(schema.columns);
    // Imported branch credentials are not part of any frontend data contract.
    for (const name of ['password', 'passwordHash', 'password_hash', 'otpHash']) columns.delete(name);
    if (req.auth?.app_metadata?.staff_scope === 'attendance' && table === 'employees') {
      for (const name of ['new_ic_no','bank_code','bank_account','epf_no','socso_no','address','birthday','email','phone']) columns.delete(name);
    }
    return { ...schema, columns };
  }
  app.post('/api/data/rpc/:name', authenticate, async (req, res) => {
    try {
      const name = req.params.name;
      if (!RPCS.has(name)) throw new DataApiError('RPC is not available', 404);
      if (req.auth?.app_metadata?.is_reviewer || req.auth?.app_metadata?.staff_scope === 'attendance') throw new DataApiError('Access denied', 403);
      const functionInfo = await pool.query(`SELECT p.proargnames, p.proretset FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname=$1`, [name]);
      if (functionInfo.rowCount !== 1) throw new DataApiError('RPC migration is not installed', 503);
      const params = req.body || {}, names = Object.keys(params);
      if (!params || typeof params !== 'object' || Array.isArray(params) || names.some((key) => !functionInfo.rows[0].proargnames?.includes(key))) throw new DataApiError('Invalid RPC arguments');
      const values = names.map((key) => typeof params[key] === 'object' && params[key] !== null ? JSON.stringify(params[key]) : params[key]);
      const call = `public.${q(name)}(${names.map((key, i) => q(key) + ' => $' + (i + 1)).join(',')})`;
      const sql = functionInfo.rows[0].proretset ? `SELECT to_jsonb(r) AS data FROM ${call} AS r` : `SELECT to_jsonb(${call}) AS data`;
      const result = await withDatabaseIdentity(pool, claimsForRequest(req), (client) => client.query(sql, values));
      res.set('Cache-Control', 'no-store');
      res.json(functionInfo.rows[0].proretset ? result.rows.map((row) => row.data) : result.rows[0]?.data ?? null);
    } catch (error) { console.error('DATA RPC ERROR:', error.code || 'rpc_error'); sendError(res, error); }
  });
  app.all('/api/data/:table', authenticate, async (req, res) => {
    try {
      const table = req.params.table;
      if (!TABLES.has(table)) throw new DataApiError('Table is not available', 404);
      const readOnly = ['GET', 'HEAD'].includes(req.method);
      if (req.auth?.app_metadata?.is_reviewer) throw new DataApiError('Reviewer uses the synthetic preview API', 403);
      if (req.auth?.app_metadata?.staff_scope === 'attendance' && !['attendance','employees','branches','monthly_rosters','daily_rosters'].includes(table)) throw new DataApiError('Access denied', 403);
      if (req.auth?.app_metadata?.staff_scope === 'attendance' && !readOnly && table !== 'attendance') throw new DataApiError('Access denied', 403);
      const schema = await metadata(table, req);
      const params = new URL(req.originalUrl, 'http://api.invalid').searchParams;
      const prefer = String(req.get('Prefer') || '');
      const query = compileTableQuery({ table, method: req.method, params, body: req.body, ...schema, prefer });
      const rows = query.empty ? [] : await withDatabaseIdentity(pool, claimsForRequest(req), async (client) => (await client.query(query.sql, query.values)).rows.map((row) => row.data));
      res.set('Cache-Control', 'no-store');
      if (String(req.get('Accept')).includes('application/vnd.pgrst.object+json')) {
        if (rows.length !== 1) throw new DataApiError('JSON object requested, multiple (or no) rows returned', 406, 'PGRST116');
        return res.json(rows[0]);
      }
      if (!readOnly && !prefer.includes('return=representation')) return res.status(req.method === 'POST' ? 201 : 204).end();
      return res.status(req.method === 'POST' ? 201 : 200).json(rows);
    } catch (error) { console.error('DATA API ERROR:', error.code || 'data_error'); sendError(res, error); }
  });
}
