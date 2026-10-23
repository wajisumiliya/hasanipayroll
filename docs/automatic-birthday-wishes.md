# Automatic birthday wishes

The backend checks once on startup and every minute for active employees whose
stored birthday matches today's month and day in `Asia/Kuala_Lumpur`. It sends
at the first check at or after 09:00 Malaysia time. The admin dashboard does not
need to be open. If the server wakes later that day, it catches up; it does not
send belated wishes for past dates. February 29 birthdays match on leap days.

Each wish is saved to `public.app_notifications` for that employee, and Firebase
push delivery is attempted through the same sender used for manual notifications.
The approved message is also used by the admin's manual birthday send action.

`app_private.birthday_wishes` records one automatic wish per employee per year.
Its unique key prevents duplicates across restarts and simultaneous server
instances. The annual record and inbox notification are inserted atomically;
database failures can retry on the next minute without losing the wish.
Manual sends remain explicit admin actions and can be sent separately.

## Deployment and push delivery

Deploy the backend from main. Startup automatically applies the birthday migration
before starting the worker. No separate cron service is required, but the backend
must be running for the scheduler to execute.

Firebase push requires the existing `FIREBASE_SERVICE_ACCOUNT` (or
`FIREBASE_SERVICE_ACCOUNT_JSON`) server configuration and a registered employee
device with notification permission. Keep the credential in the hosting service's
secret environment settings, never in the repository or chat. Server access to
`oauth2.googleapis.com` and `fcm.googleapis.com` is required.

Missing Firebase configuration, rejected device pushes, and provider errors leave
the inbox wish intact and log a message without employee data. Push is best effort:
it is not retried after the inbox wish commits, avoiding repeated birthday alerts.
Push arrival is not guaranteed if a device is offline or permissions are disabled.

## Verification

Run the backend suite with `BOOTSTRAP_TEST_DATABASE_URL` pointing to the local
`hasani_bootstrap_test` fixture database. Birthday integration coverage checks the
09:00 Malaysia boundary, inactive/missing/other-date birthdays, concurrent runs,
same-year deduplication, next-year delivery, late startup, atomic rollback on inbox
failure, and durable inbox delivery when push fails. Tests stub push delivery and
do not contact employees.
