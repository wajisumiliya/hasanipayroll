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
  try {
    const input = await request.json();
    const title = String(input.title ?? '').trim();
    const body = String(input.body ?? '').trim();
    const audience = String(input.audience ?? 'all');
    if (!title || !body || !['all', 'branch', 'employee'].includes(audience)) {
      return json({ error: 'Invalid notification request.' }, 400);
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    let query = supabase.from('notification_devices').select('token');
    if (audience === 'branch') query = query.eq('branch_id', input.branch_id);
    if (audience === 'employee') query = query.eq('employee_id', input.employee_id);
    const { data: devices, error } = await query;
    if (error) throw error;

    const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!);
    const accessToken = await firebaseAccessToken(serviceAccount);
    const tokens = [...new Set((devices ?? []).map((row) => row.token))];
    const results = await Promise.all(tokens.map((token) => fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ message: {
          token,
          notification: { title, body },
          data: {
            type: String(input.type ?? 'information'),
            audience,
            branch_id: String(input.branch_id ?? ''),
            employee_id: String(input.employee_id ?? ''),
          },
          webpush: { fcm_options: { link: '/' } },
        }}),
      },
    )));

    await supabase.from('app_notifications').insert({
      title, body,
      notification_type: input.type ?? 'information',
      audience,
      branch_id: input.branch_id || null,
      employee_id: input.employee_id || null,
    });
    return json({ sent: results.filter((result) => result.ok).length, total: tokens.length });
  } catch (error) {
    return json({ error: String(error) }, 500);
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
