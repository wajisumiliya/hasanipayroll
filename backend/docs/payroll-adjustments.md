# Locked employer EPF adjustments

Deploy the backend before the Flutter web build. Startup applies
`20261114_payroll_employer_epf_adjustments.sql`; it changes no payroll amounts
and preserves the existing `protect_locked_payroll` trigger and its enabled state.

In Edit Payroll, change only EPF Employer for a locked row, select Save Payroll,
and enter a reason in Authorize employer EPF adjustment. The authenticated
`adjust_payroll_employer_epf` RPC records the actor, reason, old/new employer EPF,
employee, period and transaction in the private audit table. Its expected amount
check rejects stale edits. Repeating an already-applied amount creates no audit
entry or additional contribution.

Only payroll administrators within their staff scope may authorize adjustments.
Employee, branch, reviewer, request-only and attendance-only accounts cannot.
The adjustment changes only employer EPF. Employee deductions, net salaries,
publication, paid/finalized status and other values remain unchanged. Ordinary
edits and regeneration of locked payroll remain blocked by the original lock.
The audit authorization is bound to one payroll row, exact amounts and the current
database transaction, and is reset before the RPC returns.

Other financial corrections to locked payroll need a separately implemented
audited adjustment workflow. Do not disable the trigger, reopen payroll, or
rewrite saved amounts to install this feature.
