import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-supabase-api-version',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new Error('Notification service is not configured.');
    }

    // Authenticate with the caller's JWT first. Never authorize with the
    // service-role client, because it bypasses RLS.
    const authorization = request.headers.get('Authorization') ?? '';
    if (!authorization.startsWith('Bearer ')) {
      return json({ error: 'Authentication required.' }, 401);
    }
    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await caller.auth.getUser();
    if (userError || !userData.user) {
      return json({ error: 'Invalid or expired authentication token.' }, 401);
    }
    const appRole = String(
      userData.user.app_metadata?.app_role ?? userData.user.app_metadata?.role ?? '',
    ).trim().toLowerCase();
    if (appRole !== 'admin') {
      return json({ error: 'Administrator access required.' }, 403);
    }

    const input = await request.json();
    const title = String(input.title ?? '').trim();
    const body = String(input.body ?? '').trim();
    const audience = String(input.audience ?? 'all');
    if (!title || !body || title.length > 160 || body.length > 2000 ||
        !['all', 'branch', 'employee'].includes(audience)) {
      return json({ error: 'Invalid notification request.' }, 400);
    }

    const employeeIds = Array.isArray(input.employee_ids)
      ? [...new Set(input.employee_ids
        .map((value: unknown) => String(value).trim())
        .filter((value: string) => value.length > 0))]
      : [];
    if (employeeIds.length > 500) {
      return json({ error: 'Employee batch is too large.' }, 400);
    }
    if (employeeIds.length > 0 && audience !== 'employee') {
      return json({ error: 'Employee batches require employee audience.' }, 400);
    }
    if (audience === 'branch' && !String(input.branch_id ?? '').trim()) {
      return json({ error: 'Branch audience requires branch_id.' }, 400);
    }
    if (audience === 'employee' && employeeIds.length === 0 &&
        !String(input.employee_id ?? '').trim()) {
      return json({ error: 'Employee audience requires employee_id.' }, 400);
    }

    // Privileged client is created only after the caller has been authenticated
    // and authorized as an administrator.
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let query = supabase.from('notification_devices').select('token, employee_id');
    if (audience === 'branch') query = query.eq('branch_id', input.branch_id);
    if (audience === 'employee' && employeeIds.length > 0) {
      query = query.in('employee_id', employeeIds);
    } else if (audience === 'employee') {
      query = query.eq('employee_id', input.employee_id);
    }
    const { data: devices, error } = await query;
    if (error) throw error;

    const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!);
    const accessToken = await firebaseAccessToken(serviceAccount);
    const devicesByToken = new Map<string, string>();
    for (const device of devices ?? []) {
      if (!devicesByToken.has(device.token)) {
        devicesByToken.set(device.token, String(device.employee_id ?? ''));
      }
    }

    const results = await Promise.all([...devicesByToken.entries()].map(([token, employeeId]) => fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: {
          token,
          notification: { title, body },
          data: {
            type: String(input.type ?? 'information'),
            audience,
            branch_id: String(input.branch_id ?? ''),
            employee_id: employeeId || String(input.employee_id ?? ''),
            tax_year: String(input.tax_year ?? ''),
          },
          webpush: { fcm_options: { link: '/' } },
        }}),
      },
    )));

    const notifications = employeeIds.length > 0
      ? employeeIds.map((employeeId) => ({
        title, body, notification_type: input.type ?? 'information',
        audience: 'employee', branch_id: null, employee_id: employeeId,
      }))
      : [{
        title, body, notification_type: input.type ?? 'information', audience,
        branch_id: input.branch_id || null, employee_id: input.employee_id || null,
      }];

    const { error: notificationError } = await supabase
      .from('app_notifications').insert(notifications);
    if (notificationError) throw notificationError;

    return json({
      sent: results.filter((result) => result.ok).length,
      total: devicesByToken.size,
      inbox: notifications.length,
    });
  } catch (error) {
    console.error('send-notification failed:', error);
    return json({ error: 'Notification service failed.' }, 500);
  }
});

async function firebaseAccessToken(account: Record<string, string>) {
  const now = Math.floor(Date.now() / 1000);
  const key = await importPKCS8(account.private_key, 'RS256');
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }).setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.client_email).setSubject(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now).setExpirationTime(now + 3600).sign(key);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion,
    }),
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error_description ?? 'Firebase authentication failed.');
  return payload.access_token;
}

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}
