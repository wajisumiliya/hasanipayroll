# Push notification delivery

The inbox and device push are separate. The admin notification composer and
birthday/work-anniversary send actions now report the inbox result and Firebase
push result separately. `sent` means FCM accepted the request, not that a person
has seen it. The backend returns only safe status codes, never device tokens,
service-account credentials, employee names, or raw provider errors.

## Production configuration

- Deploy the latest backend and web build; publish/install the updated Android
  release for client registration and channel changes.
- In the Firebase project used by the clients (`hasani-payroll`), open Project
  settings → Service accounts. Use a service account authorized to send Firebase
  Cloud Messaging messages, and ensure the HTTP v1 FCM API is enabled.
- Store the service-account JSON securely in Render's
  `FIREBASE_SERVICE_ACCOUNT_JSON` (or `FIREBASE_SERVICE_ACCOUNT`) environment
  setting. Do not paste it into chat or commit it. This is different from the
  public client configuration in `google-services.json` and `firebase_options.dart`.
- Optional `FIREBASE_WEB_APP_URL` is the absolute HTTPS frontend URL used on web
  notification clicks. Relative URLs such as `/` are omitted because FCM requires
  HTTPS links. Both Android and web pushes previously included that invalid link.
- If using a project-specific browser push key, build web with
  `--dart-define=FIREBASE_WEB_VAPID_KEY=<public Web Push certificate key>` from
  Firebase Project settings → Cloud Messaging → Web Push certificates. The public
  key must belong to the same Firebase project. No private key belongs in a build.
- The backend needs HTTPS access to `oauth2.googleapis.com` and
  `fcm.googleapis.com`. Web clients need Firebase/browser push connectivity.

## Check with an employee device

Sign in to the updated client and allow notifications. Registration happens after
normal login, after first-password setup, and for restored sessions. A token
refresh uses the current signed-in identity. Foreground listeners are installed
independently of registration success. For Android, ensure the Hasani Payroll
Notifications channel is enabled in system settings. For web, use HTTPS and allow
notifications in browser site settings.

Send one test from the admin notification composer. Check its displayed result:

| Status | Action |
| --- | --- |
| `not_configured` | Add the server service-account setting and redeploy. |
| `invalid_configuration` | Check that the setting contains valid service-account JSON. |
| `authentication_failed` | Check the private key, account permissions, and OAuth network access. |
| `no_devices` | Employee signs in and grants notifications on the target device. |
| `SENDER_ID_MISMATCH` | Server credentials and device token must use the same Firebase project; register again. |
| `PERMISSION_DENIED` | Check the FCM API and service-account permissions. |
| `UNREGISTERED` | Stale token is removed; sign in on the employee device to register again. |
| `DELIVERY_UNAVAILABLE` | Check provider/network availability. |

Partial delivery reports accepted device counts. Invalid-argument tokens are not
deleted, because the payload itself may be the cause. Background web notification
payloads are displayed by Firebase once; the custom handler only displays data-only
messages. Employee/payroll payloads are not written to the browser console.

Existing birthday and anniversary inbox wishes are retained. This change does not
replay earlier failed pushes or bypass annual duplicate protection. A manual test
or resend is an explicit separate admin action.

## Validation limits

Automated tests use generated test signing keys and mocked FCM/OAuth responses.
They exercise missing/invalid configuration, unregistered devices, payload validity,
HTTPS links, private-key normalization, provider errors, partial delivery and
OAuth-token reuse. They do not contact real employees. Production credentials and
an actual Android/browser device are required to verify live arrival.
