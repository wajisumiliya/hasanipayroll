// Safe configuration metadata only: never return service-account keys or tokens.
export function firebaseConfigurationStatus(env=process.env) {
  const raw=env.FIREBASE_SERVICE_ACCOUNT || env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) return {status:'not_configured'};
  try {
    let account=JSON.parse(raw);
    if (typeof account==='string') account=JSON.parse(account);
    if (!account?.project_id || !account.client_email || !account.private_key)
      return {status:'invalid_configuration'};
    return {status:account.project_id==='hasani-payroll'?'configured':'project_mismatch'};
  } catch { return {status:'invalid_configuration'}; }
}
