import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { installPenguinPetApi } from '../src/penguin-pet-api.js';

const now = new Date('2026-10-21T12:00:00.000Z');
const day = 24 * 60 * 60 * 1000;

function harness({ active = ['E001', 'E002'], adoptedAt, lastFedAt, failConnect = false, authenticate } = {}) {
  const routes = [];
  const rows = new Map();
  let queue = Promise.resolve();
  let releaseCount = 0;
  const calls = [];
  const pool = {
    async connect() {
      if (failConnect) throw new Error('database offline');
      return {
        unlock: null,
        async query(sql, values = []) {
          calls.push({ sql, values });
          if (sql === 'BEGIN') return { rowCount: null };
          if (sql === 'COMMIT' || sql === 'ROLLBACK') {
            this.unlock?.();
            this.unlock = null;
            return { rowCount: null };
          }
          if (sql.includes('FROM public.employees')) {
            const previous = queue;
            let unlock;
            queue = new Promise((resolve) => { unlock = resolve; });
            await previous;
            this.unlock = unlock;
            const id = values[0];
            return { rowCount: active.includes(id) ? 1 : 0 };
          }
          if (sql.startsWith('INSERT INTO app_private.employee_penguin_pets')) {
            const id = values[0];
            if (!rows.has(id)) {
              rows.set(id, {
                employee_id: id,
                adopted_at: adoptedAt ?? new Date(now.getTime() - 2 * day).toISOString(),
                nickname: 'Pingu',
                last_fed_at: lastFedAt ?? null,
                last_played_at: null,
                updated_at: now.toISOString(),
              });
            }
            return { rowCount: 1 };
          }
          if (sql.startsWith('UPDATE app_private.employee_penguin_pets')) {
            const field = sql.match(/SET (last_fed_at|last_played_at)=/)?.[1];
            const row = rows.get(values[0]);
            if (!row[field] || new Date(row[field]).getTime() <= now.getTime() - day) {
              row[field] = now.toISOString();
              row.updated_at = now.toISOString();
              return { rowCount: 1 };
            }
            return { rowCount: 0 };
          }
          if (sql.startsWith('SELECT *, now() AS server_now')) {
            return { rows: [{ ...rows.get(values[0]), server_now: now.toISOString() }], rowCount: 1 };
          }
          throw new Error(`Unexpected SQL: ${sql}`);
        },
        release() { releaseCount += 1; },
      };
    },
  };
  const auth = authenticate ?? ((_req, _res, next) => next());
  const app = {
    get: (...route) => routes.push(route),
    post: (...route) => routes.push(route),
  };
  installPenguinPetApi(app, { pool, authenticate: auth });
  return {
    routes, rows, calls,
    get releaseCount() { return releaseCount; },
    async request(path, user, auth = {}, body = {}) {
      const route = routes.find((candidate) => candidate[0] === path);
      assert.ok(route, `route registered: ${path}`);
      let status = 200;
      let result;
      const response = {
        status(code) { status = code; return this; },
        set() { return this; },
        json(data) { result = data; return this; },
      };
      await route[2]({ user, auth, body }, response);
      return { status, body: result };
    },
  };
}

test('every penguin endpoint is behind the injected authentication middleware', () => {
  const app = { get: (...args) => routes.push(args), post: (...args) => routes.push(args) };
  const routes = [];
  const auth = (_req, _res, next) => next();
  installPenguinPetApi(app, { pool: {}, authenticate: auth });
  assert.deepEqual(routes.map((route) => route[0]), [
    '/api/employee/penguin',
    '/api/employee/penguin/feed',
    '/api/employee/penguin/play',
  ]);
  assert.ok(routes.every((route) => route[1] === auth));
});

test('a signed JWT is required before an employee pet handler runs', async () => {
  const secret = 'test-only-jwt-secret-with-at-least-32-characters';
  const authenticate = (req, res, next) => {
    try {
      const token = req.headers?.authorization?.slice(7) ?? '';
      const [header, encodedPayload, signature] = token.split('.');
      if (!header || !encodedPayload || !signature) throw new Error('malformed token');
      const signingInput = `${header}.${encodedPayload}`;
      const expected = createHmac('sha256', secret).update(signingInput).digest('base64url');
      if (signature.length !== expected.length || !timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
        throw new Error('invalid signature');
      }
      const payload = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString());
      if (payload.iss !== 'hasani-payroll' || payload.aud !== 'authenticated' || payload.exp <= Date.now() / 1000) {
        throw new Error('invalid claims');
      }
      if (payload.type !== 'access') throw new Error('not an access token');
      req.auth = payload;
      req.user = { role: payload.role, employeeId: payload.employee_id };
      next();
    } catch {
      res.status(401).json({ ok: false, message: 'Authentication required' });
    }
  };
  const h = harness({ authenticate });
  const route = h.routes.find((candidate) => candidate[0] === '/api/employee/penguin');

  const send = async (token) => {
    const req = { headers: { authorization: token ? `Bearer ${token}` : '' }, body: {} };
    let status = 200;
    let body;
    const res = {
      status(code) { status = code; return this; },
      set() { return this; },
      json(value) { body = value; return this; },
    };
    await new Promise((resolve) => {
      route[1](req, res, () => Promise.resolve(route[2](req, res)).finally(resolve));
      if (status === 401) resolve();
    });
    return { status, body };
  };

  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const claims = Buffer.from(JSON.stringify({
    type: 'access', role: 'employee', employee_id: 'E001',
    iss: 'hasani-payroll', aud: 'authenticated', exp: Math.floor(Date.now() / 1000) + 300,
  })).toString('base64url');
  const signingInput = `${header}.${claims}`;
  const valid = `${signingInput}.${createHmac('sha256', secret).update(signingInput).digest('base64url')}`;
  assert.equal((await send(valid)).status, 200);
  assert.equal((await send('not-a-jwt')).status, 401);
  assert.deepEqual([...h.rows.keys()], ['E001']);
});

test('non-employees, reviewers and restricted staff scopes never touch the database', async () => {
  const app = { get: (...args) => routes.push(args), post: (...args) => routes.push(args) };
  const routes = [];
  installPenguinPetApi(app, {
    pool: { connect: () => { throw new Error('database should not be called'); } },
    authenticate: (_req, _res, next) => next(),
  });
  for (const [user, auth] of [
    [{ role: 'ADMIN', employeeId: 'E001' }, {}],
    [{ role: 'employee', employeeId: 'PLAY_REVIEWER' }, { app_metadata: { is_reviewer: true } }],
    [{ role: 'employee', employeeId: 'E001' }, { app_metadata: { staff_scope: 'attendance' } }],
    [{ role: 'employee' }, {}],
  ]) {
    for (const route of routes) {
      let status;
      const response = { status(code) { status = code; return this; }, json() { return this; } };
      await route[2]({ user, auth }, response);
      assert.equal(status, 403);
    }
  }
});

test('employee identity comes from authenticated claims, never a request body employee id', async () => {
  const h = harness();
  const result = await h.request('/api/employee/penguin', { role: 'employee', employeeId: 'E001' }, {}, { employee_id: 'E002' });
  assert.equal(result.status, 200);
  assert.equal(result.body.pet.nickname, 'Pingu');
  assert.deepEqual([...h.rows.keys()], ['E001']);
  assert.ok(h.calls.filter((call) => call.values.length).every((call) => call.values[0] === 'E001'));
});

test('inactive employee is rejected and transaction is rolled back', async () => {
  const h = harness({ active: ['E001'] });
  const result = await h.request('/api/employee/penguin', { role: 'employee', employeeId: 'E002' });
  assert.equal(result.status, 403);
  assert.equal(result.body.message, 'Employee unavailable');
  assert.ok(h.calls.some((call) => call.sql === 'ROLLBACK'));
  assert.equal(h.rows.size, 0);
  assert.equal(h.releaseCount, 1);
});

test('growth is derived from server time so offline time advances the pet', async () => {
  const h = harness({ adoptedAt: new Date(now.getTime() - 51 * day).toISOString() });
  const result = await h.request('/api/employee/penguin', { role: 'employee', employeeId: 'E001' });
  assert.equal(result.body.pet.ageDays, 51);
  assert.equal(result.body.pet.stage, 'adult');
});

test('feed cooldown blocks repeat actions and reports the existing cooldown state', async () => {
  const h = harness({ lastFedAt: new Date(now.getTime() - 2 * 60 * 60 * 1000).toISOString() });
  const result = await h.request('/api/employee/penguin/feed', { role: 'employee', employeeId: 'E001' });
  assert.equal(result.status, 200);
  assert.equal(result.body.pet.fedToday, true);
  assert.equal(new Date(h.rows.get('E001').last_fed_at).getTime(), now.getTime() - 2 * 60 * 60 * 1000);
});

test('concurrent feed requests serialize on employee row and cannot extend cooldown twice', async () => {
  const h = harness();
  const user = { role: 'employee', employeeId: 'E001' };
  const [first, second] = await Promise.all([
    h.request('/api/employee/penguin/feed', user),
    h.request('/api/employee/penguin/feed', user),
  ]);
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.equal(h.rows.get('E001').last_fed_at, now.toISOString());
  assert.equal(h.calls.filter((call) => call.sql.startsWith('UPDATE app_private.employee_penguin_pets')).length, 2);
});

test('database connection failures return a safe service error', async () => {
  const h = harness({ failConnect: true });
  const result = await h.request('/api/employee/penguin', { role: 'employee', employeeId: 'E001' });
  assert.equal(result.status, 503);
  assert.deepEqual(result.body, { ok: false, message: 'Penguin pet temporarily unavailable' });
  assert.equal(h.releaseCount, 0);
});
