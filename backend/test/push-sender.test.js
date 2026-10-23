import assert from 'node:assert/strict';
import test from 'node:test';
import { generateKeyPairSync } from 'node:crypto';
import { createPushSender } from '../src/push-sender.js';

const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const account = { project_id: 'test-project', client_email: 'test@test-project.iam.gserviceaccount.com',
  private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString() };
const input = { title: 'Test', body: 'Test body', audience: 'employee', type: 'birthday', employeeIds: ['TEST_EMP'], branchId: null };
function setup({ env = {}, deviceRows = [{ token: 'TEST_DEVICE_TOKEN', employee_id: 'TEST_EMP' }], fcm, notification = input } = {}) {
  const requests = [], queries = [];
  const pool = { async query(sql, values) { queries.push({ sql, values }); return { rows: deviceRows }; } };
  const send = createPushSender({ env: { FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify(account), ...env }, request: async (url, options) => {
    requests.push({ url, options });
    if (url.includes('oauth2')) return { ok: true, async json() { return { access_token: 'TEST_OAUTH', expires_in: 3600 }; } };
    return fcm ? fcm(url, options) : { ok: true };
  } });
  return { send: () => send(pool, notification), requests, queries };
}

test('push explains absent/invalid credentials without contacting Firebase', async () => {
  for (const [value, status] of [['', 'not_configured'], ['{invalid', 'invalid_configuration'], ['{}', 'invalid_configuration']]) {
    const t = setup({ env: { FIREBASE_SERVICE_ACCOUNT_JSON: value } });
    assert.equal((await t.send()).pushStatus, status);
    assert.equal(t.requests.length, 0);
  }
});
test('no registered device is a distinct result and does not request an OAuth token', async () => {
  const t = setup({ deviceRows: [] });
  assert.equal((await t.send()).pushStatus, 'no_devices');
  assert.equal(t.requests.length, 0);
});
test('valid FCM payload omits relative web links and uses Android notification channel', async () => {
  const t = setup({ env: { FIREBASE_WEB_APP_URL: '/' } });
  assert.equal((await t.send()).pushStatus, 'sent');
  const message = JSON.parse(t.requests[1].options.body).message;
  assert.equal(message.webpush, undefined);
  assert.equal(message.android.notification.channel_id, 'hasani_notifications');
  assert.equal(message.data.tax_year, '');
  assert.equal(message.token, 'TEST_DEVICE_TOKEN');
  await t.send();
  assert.equal(t.requests.filter(r => r.url.includes('oauth2')).length, 1);
});
test('only absolute HTTPS web click URLs are sent', async () => {
  const t = setup({ env: { FIREBASE_WEB_APP_URL: 'https://test.example/login' } });
  await t.send();
  assert.equal(JSON.parse(t.requests[1].options.body).message.webpush.fcm_options.link, 'https://test.example/login');
});
test('escaped private key newlines are normalized', async () => {
  const t = setup({ env: { FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({ ...account, private_key: account.private_key.replace(/\n/g, '\\n') }) } });
  assert.equal((await t.send()).sent, 1);
});
test('rejected FCM pushes expose safe codes and remove only unregistered tokens', async () => {
  for (const code of ['UNREGISTERED', 'INVALID_ARGUMENT', 'SENDER_ID_MISMATCH', 'PERMISSION_DENIED']) {
    const t = setup({ fcm: () => ({ ok: false, status: 400, async json() { return { error: { message: 'PRIVATE_PROVIDER_DETAILS', status: code,
      details: [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode: code }] } }; } }) });
    const result = await t.send();
    assert.equal(result.pushStatus, 'failed');
    assert.equal(result.failed, 1);
    assert.deepEqual(result.pushErrors, [code]);
    assert.equal(JSON.stringify(result).includes('PRIVATE_PROVIDER_DETAILS'), false);
    assert.equal(t.queries.some(q => q.sql.startsWith('DELETE')), code === 'UNREGISTERED');
  }
});
test('partial failure counts accepted devices accurately', async () => {
  const t = setup({ deviceRows: [{ token: 'good' }, { token: 'bad' }], fcm: (_, opts) => {
    if (JSON.parse(opts.body).message.token === 'good') return { ok: true };
    throw new Error('PRIVATE_NETWORK_DETAILS');
  } });
  const result = await t.send();
  assert.equal(result.pushStatus, 'partial');
  assert.equal(result.sent, 1);
  assert.equal(result.failed, 1);
  assert.deepEqual(result.pushErrors, ['DELIVERY_UNAVAILABLE']);
});
test('invalid signing key is reported as authentication failure', async () => {
  const t = setup({ env: { FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({ ...account, private_key: 'invalid' }) } });
  assert.equal((await t.send()).pushStatus, 'authentication_failed');
  assert.equal(t.requests.length, 0);
});

test('all-device broadcast is not silently limited to the first 1000 devices', async () => {
  const t = setup({ deviceRows: Array.from({ length: 1001 }, (_, i) => ({ token: `TEST_${i}` })), notification: { ...input, audience: 'all', employeeIds: [] } });
  const result = await t.send();
  assert.equal(result.sent, 1001);
  assert.equal(result.attempted, 1001);
  assert.equal(t.queries[0].values[0], 'all');
  assert.ok(!t.queries[0].sql.includes('LIMIT 1000'));
});
