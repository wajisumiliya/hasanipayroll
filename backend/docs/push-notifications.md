# Checking missing payslip notifications

Deploy the latest backend before updating the Flutter web/Android app. Backend
startup applies the publication and registration-recovery migrations. The server
worker runs once a minute. Code deployment alone does not verify phone delivery.

## Check publication before checking the phone

Open Admin → Notifications, choose One employee, select the employee and click
**Check notification delivery**. This check sends no notification and returns no
salary, device token, private key or service-account email.

- Publication notifications not enabled: deploy the latest Node backend and check
  its startup succeeded. Updating only the static website does not update Node.
- Month not released: it is a draft or its scheduled Malaysia release time has
  not arrived. No new publication notice should exist yet.
- Released but no inbox or queue entry: if it was published before the feature
  was deployed, use the individual Publish action again. Publication creates a
  single employee/month notice transactionally. Do not edit payroll amounts.
- Inbox saved but the employee sees none: verify the signed-in employee identity
  matches the published payroll employee ID. Sign out/in after an ID/account
  change so the authentication claims refresh.
- Zero registered devices: the employee must open Notifications → **Enable
  notifications on this device**, allow permission and finish registration.
- `not_configured` / invalid configuration: set a valid Firebase service account
  on the Node service using `FIREBASE_SERVICE_ACCOUNT_JSON` or
  `FIREBASE_SERVICE_ACCOUNT`. Do not put that JSON into Flutter, GitHub or chat.
- `project_mismatch` / `SENDER_ID_MISMATCH`: the backend credentials and app must
  use the `hasani-payroll` Firebase project. Reinstall/update the Android app and
  register the device again after correcting the app configuration.
- `authentication_failed` / `PERMISSION_DENIED`: check service-account validity,
  Firebase Cloud Messaging API access and its permissions in that project.
- `sent`: Firebase accepted the push, not proof that Android displayed it. Check
  Android app notification permission, the Hasani notification channel, and
  Google Play services. Test foreground and background separately. Android
  force-stop can prevent delivery until the app is opened again.

Recent `no_devices` and failed/configuration deliveries (created within seven
days) are made eligible for another attempt when that verified employee registers
a device. Already successful or partially successful attempts do not replay.
Normal network/provider failures retain their existing exponential backoff.

## Read-only check for HED2073 / October 2026

```sql
SELECT
  (SELECT jsonb_agg(jsonb_build_object(
      'published',p.is_published,'release_at',p.release_at,'published_at',p.published_at))
   FROM public.payroll p WHERE p.employee_id='HED2073'
     AND p.period>=DATE '2026-10-01' AND p.period<DATE '2026-11-01') AS payroll,
  (SELECT count(*) FROM public.notification_devices
   WHERE employee_id='HED2073') AS registered_devices,
  (SELECT count(*) FROM public.app_notifications
   WHERE employee_id='HED2073' AND notification_type='payslip'
     AND body='Your October 2026 payslip is ready to view.') AS inbox_messages,
  EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.payroll'::regclass
    AND tgname='payslip_published_notice' AND tgenabled IN ('O','A'))
    AS publication_trigger_ready,
  to_regclass('app_private.payslip_notice_delivery') IS NOT NULL AS queue_exists;
```

If the queue exists, an owner can inspect delivery metadata without tokens:

```sql
SELECT payroll_month,last_status,last_error_codes,attempts,
       available_at,completed_at
FROM app_private.payslip_notice_delivery
WHERE employee_id='HED2073' AND payroll_month=DATE '2026-10-01';
```

The last query requires the registration-recovery migration for
`last_error_codes`. Before that migration, omit that column.
