# Locked payroll adjustments

Deploy the backend before the Flutter web build. Startup applies
`20261114_payroll_employer_epf_adjustments.sql` and
`20261114_payroll_component_adjustments.sql`; they change no payroll amounts
and preserves the existing `protect_locked_payroll` trigger and its enabled state.

In Edit Payroll, edit earnings, deductions, employer contributions or remarks,
select Save Payroll, and enter a reason in Authorize payroll adjustment.
The authenticated `adjust_payroll` RPC records the actor, reason, before/after
snapshots, employee, period and transaction in the private audit table. Its full
original-record check rejects stale edits. An unchanged record creates no audit
entry. The earlier employer-only RPC remains supported for older web builds.

Only payroll administrators within their staff scope may authorize adjustments.
Employee, branch, reviewer, request-only and attendance-only accounts cannot.
Only the editable component, remarks and existing financial snapshot columns
can change. The editor refreshes stored totals when earnings/deductions change.
Identity, period, publication and paid/finalized status remain unchanged.
Ordinary updates to locked financial data remain blocked by the original lock.
The audit authorization is bound to one payroll row, exact snapshots and the current
database transaction, and is reset before the RPC returns.

Payroll generation loads lock status and lists locked records as skipped,
continuing with eligible records. Corrections belong in Edit Payroll, not
regeneration. Do not disable the trigger, reopen payroll, or rewrite saved
amounts to install this feature.
