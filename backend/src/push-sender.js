import jwt from 'jsonwebtoken';

const SAFE_CODES = new Set(['UNREGISTERED', 'SENDER_ID_MISMATCH', 'INVALID_ARGUMENT',
  'THIRD_PARTY_AUTH_ERROR', 'QUOTA_EXCEEDED', 'UNAVAILABLE', 'INTERNAL',
  'PERMISSION_DENIED', 'UNAUTHENTICATED', 'NOT_FOUND']);

// Dependencies are injectable so tests never contact Firebase or real devices.
export function createPushSender({ env = process.env, request = (...args) => fetch(...args), clock = Date.now } = {}) {
  let cached;
  return async function pushNotifications(pool, input) {
    const result = { sent: 0, attempted: 0, failed: 0, pushConfigured: false, pushStatus: 'not_configured', pushErrors: [] };
    const raw = env.FIREBASE_SERVICE_ACCOUNT || env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!raw) return result;
    result.pushConfigured = true;
    let account;
    try {
      account = JSON.parse(raw);
      if (typeof account === 'string') account = JSON.parse(account);
      if (!account.project_id || !account.client_email || !account.private_key) throw new Error();
      account.private_key = account.private_key.replace(/\\n/g, '\n');
    } catch { return { ...result, pushStatus: 'invalid_configuration' }; }

    const devices = await pool.query(`SELECT DISTINCT token, employee_id FROM public.notification_devices
      WHERE ($1='all' OR ($1='branch' AND branch_id=$2) OR ($1='employee' AND employee_id=ANY($3::text[])))`,
    [input.audience, input.branchId, input.employeeIds]);
    if (!devices.rows.length) return { ...result, pushStatus: 'no_devices' };

    const now = Math.floor(clock() / 1000);
    if (!cached || cached.email !== account.client_email || cached.key !== account.private_key || cached.expiresAt < now + 60) {
      try {
        const assertion = jwt.sign({ scope: 'https://www.googleapis.com/auth/firebase.messaging' }, account.private_key, {
          algorithm: 'RS256', issuer: account.client_email, subject: account.client_email,
          audience: 'https://oauth2.googleapis.com/token', expiresIn: '1h',
        });
        const response = await request('https://oauth2.googleapis.com/token', {
          method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
          signal: AbortSignal.timeout(10000),
        });
        if (!response.ok) return { ...result, pushStatus: 'authentication_failed' };
        const token = await response.json();
        if (!token.access_token) return { ...result, pushStatus: 'authentication_failed' };
        cached = { email: account.client_email, key: account.private_key, token: token.access_token, expiresAt: now + Number(token.expires_in || 3600) };
      } catch { return { ...result, pushStatus: 'authentication_failed' }; }
    }

    let webLink;
    try {
      const url = new URL(env.FIREBASE_WEB_APP_URL || '');
      if (url.protocol === 'https:') webLink = url.href;
    } catch { /* FCM rejects relative links; omit the optional link by default. */ }
    const accessToken = cached.token;
    const errors = new Set();
    for (let offset = 0; offset < devices.rows.length; offset += 50) {
      await Promise.all(devices.rows.slice(offset, offset + 50).map(async device => {
        result.attempted++;
        try {
          const response = await request(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`, {
            method: 'POST', headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ message: {
              token: device.token, notification: { title: input.title, body: input.body },
              data: { type: String(input.type || 'information'), audience: String(input.audience),
                branch_id: input.branchId || '', employee_id: device.employee_id || '', tax_year: String(input.taxYear || '') },
              android: { priority: 'HIGH', notification: { channel_id: 'hasani_notifications', sound: 'default' } },
              ...(webLink ? { webpush: { fcm_options: { link: webLink } } } : {}),
            } }), signal: AbortSignal.timeout(10000),
          });
          if (response.ok) { result.sent++; return; }
          let error;
          try { error = (await response.json()).error; } catch { /* safe fallback below */ }
          const detail = error?.details?.find(item => item['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError');
          const code = detail?.errorCode || error?.status;
          errors.add(SAFE_CODES.has(code) ? code : 'PROVIDER_REJECTED');
          if (code === 'UNREGISTERED') {
            // Do not delete INVALID_ARGUMENT tokens: that can mean a bad payload.
            await pool.query('DELETE FROM public.notification_devices WHERE token=$1', [device.token]);
          }
          if (response.status === 401) cached = undefined;
        } catch { errors.add('DELIVERY_UNAVAILABLE'); }
      }));
    }
    result.failed = result.attempted - result.sent;
    result.pushErrors = [...errors].sort();
    result.pushStatus = result.sent === result.attempted ? 'sent' : result.sent ? 'partial' : 'failed';
    return result;
  };
}

export const pushNotifications = createPushSender();
