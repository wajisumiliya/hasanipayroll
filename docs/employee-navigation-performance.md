# Employee navigation performance

The employee directory reuses the authenticated dashboard's employee rows and
full salary-default snapshots. It displays the last in-memory snapshot immediately
while an expired directory refresh is pending. A narrow progress bar indicates
refresh; errors retain the prior list with an explanatory message. Refresh and
mutation paths expire the data, and employee data is cleared on session changes.
A fresh snapshot avoids a duplicate directory request for 30 seconds.

Directory search and filtering cover all rows before pagination. Only 24 employee
cards/photos are built at a time in both the all-branch list and branch grid;
Previous/Next controls expose the remaining employees. Employee photo requests
share a four-request limiter instead of creating hundreds of parallel backend
requests. Photo bytes and pending operations remain session guarded, with the
existing bounded image cache and upload invalidation behavior retained.

Edit opens directly with salary defaults loaded within the last 30 seconds. If
fresh data is required it immediately opens a cancellable loading dialog and
calls the admin-only /api/admin/employees/:employeeId/edit-data endpoint, which
joins the profile and defaults in a single parameterized data query. It avoids
the generic adapter's schema-introspection round trips. Failure never opens an
editor with fabricated zero defaults. Canceled or old-session requests cannot
open the form later. Restricted admin scopes cannot access this endpoint.

Saves still wait for actual profile/default writes and status confirmations.
Acknowledged values update the visible snapshot. The subsequent global directory
reload runs in the background instead of delaying the success dialog. No payroll
calculation, save confirmation, authentication or account-status checks are skipped.

Validation: backend route tests check one-query reads, existing default values,
role/staff scope, and invalid IDs. The request limiter test checks concurrency and
slot release on error. Flutter execution and production timings need confirmation
in an environment with the Flutter SDK. A sleeping Render/Neon instance or slow
network can still delay a first uncached request; the UI does not promise instant
fresh server data. Deploy both backend and the rebuilt Flutter frontend.
