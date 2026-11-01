# Reducing Neon network transfer

The admin dashboard and payroll page now reuse successful read responses for
30 seconds in the backend. Identical simultaneous requests share one load. Each
cache key contains the verified user identity/scope and full request URL, and
authentication/authorization still runs before every hit. Responses carry
Cache-Control: no-store so browsers/intermediaries do not cache payroll data.
The in-memory cache holds at most 48 responses and 8 MiB, skips oversized results,
and does not cache errors.

Incoming mutation requests clear existing entries. Successful completion clears
again, so reads started before/during a save cannot repopulate an old snapshot.
This covers the generic data API writes/RPCs, salary and attendance edits,
payroll generation/saves, and the dedicated write endpoints on this process.
Direct SQL changes, background jobs, and writes handled by another backend
instance become visible on TTL expiry (up to 30 seconds). The cache is local to
each process; it does not add Redis or change database policies.

Two queries also return less data over the Neon connection:

- Dashboard historical payroll retains all numeric/identity fields for trends
  and increment comparisons, while omitting verbose generated remarks from the
  previous seven months. Selected-month records retain their complete data.
  No stored remarks or payroll amounts are modified.
- Payroll attendance is grouped by employee and branch in SQL with counts.
  The backend reconstructs the existing response shape, preserving branch
  frequency selection and compatibility with already-deployed Flutter clients.
  The database sends one row per employee/branch instead of one per day.

The full historical period remains because dashboard comparisons already use it;
removing it would change existing behavior. Employee defaults retain the fields
needed by the editor. This change does not alter payroll/increment eligibility,
permissions, publication, or attendance calculations.

Validation: 7 HTTP cache tests cover expiry, authorization/identity/query isolation,
coalescing, save invalidation, reads racing a save, failures and memory limits.
An actual PostgreSQL test verifies selected-month data equality, unchanged
historical monetary values and complete attendance frequency equivalence. Its
synthetic 21 attendance rows become 2 database result rows. This is a fixture,
not an estimate of production-wide savings. The full backend suite passes with
bootstrap database tests enabled (169 tests, zero failures/skips).

Deployment: deploy the updated Node backend. No migration or Flutter rebuild is
required for these optimizations. Neon usage already recorded is not reset;
compare subsequent transfer rates after deployment, allowing for metric delays.

A parallel full-suite repeat encountered pre-existing fixture cleanup errors
(`terminating connection due to administrator command`) in the mystery-egg
reminder/payroll increment database tests. The final serial run with
BOOTSTRAP_TEST_DATABASE_URL enabled passed all 169 tests, with no skips. No
reminder or increment fixture code was changed by this optimization.
