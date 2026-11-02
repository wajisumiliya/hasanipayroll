# Late report corrections and submitted rosters

Late Report refreshes now bypass the client cache and any older in-flight request.
Report/export requests carry a fresh request identifier and the server marks the
responses no-store. Closing the employee's attendance calendar reloads the report.
The PDF is regenerated from attendance/rosters in the database on each export;
an already downloaded PDF must be regenerated after corrections.

Current daily roster times take precedence, followed by current weekly times.
Saved attendance shift snapshots are now fallback only when a current roster has
no valid time. Legacy recorded late evidence is retained when no timing basis is
available; no historical time is guessed. Exact corrected times update the event
fingerprint, making reviews of older timing explicitly outdated.

Admin and account (ADMIN/attendance scope) users can open the employee calendar
and select Edit shift roster after submission. Only changed assignments are
saved; blank/unmodified dates and attendance timestamps/status/submission flags
are not rewritten. The attendance view reloads after saving. Branch users remain
unable to correct submitted rosters, enforced server-side. Employees, reviewers,
and request-only administrators cannot use this roster write endpoint.

Deploy the backend and rebuild the frontend together. There is no migration and
no production record was modified by this code change. Regenerate the PDF after
refreshing; review individual event dates rather than relying on row positions.

Validation: 42 related Node tests and 15 Flutter tests passed. Backend syntax,
Dart formatting and analysis passed with existing unrelated diagnostics. Flutter
checks used the available 3.44 SDK and its local package resolution; the repository
lockfile is unchanged.

## Approved late arrivals

Late-arrival events with a current matching Approved review are excluded from
report counts, hours, severity, month comparisons, detailed exports and summary
PDFs. Exclusion is per event, not per employee or whole day: break overruns and
other unapproved dates still count. The three-event threshold is applied after
exclusion. A changed timing/fingerprint or a newer pending review restores the
event to the report. Approval audit records and attendance are retained.

The raw-evidence option is used by the existing attendance-allowance calculation
so this report-only change does not silently change payroll allowance rules.
Raw and filtered report caches have separate keys. Review writes load raw events
so existing approvals remain reviewable by the authenticated backend.
