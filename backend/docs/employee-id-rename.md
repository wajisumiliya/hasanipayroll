# Rename an employee ID without disconnecting history

`backend/scripts/rename-employee-id.sql` is a manually run maintenance
transaction, currently prepared for **HED-TEMP-022 → INTN-AMJ-1001**. It is not a
startup migration and publishing the repository does not execute it.

Use the database owner's SQL editor during a quiet period. The transaction
briefly locks the affected tables; it fails after five seconds if locks cannot
be acquired. Run the complete file, not only the final employee UPDATE.

The script discovers actual tables in `public` and `app_private` containing
`employee_id`, `employeeId` or `assigned_employee_id`. It skips ordinary views,
which resolve the new identifiers from their source tables. It refuses to merge
an existing destination ID with another employee.

Foreign-key checks are deferred during the transaction and enforced before
commit. Business triggers are temporarily paused under table locks so an ID
change cannot recalculate salary increments or overwrite attendance snapshots.
Original constraint definitions and trigger enablement states are restored.
Each table's linked-row count and a digest of its non-ID fields must match
before commit. Valid Late Report approval fingerprints are re-keyed; the old
fingerprint and ID mapping remain in the review's snapshot audit metadata.

Unknown signed decision records (including fingerprint/signature columns in
other tables), unsupported review signatures, materialized views or unexpected
key layouts cause the transaction to stop for a specific migration plan. Do not
remove those checks to get past an error. The resulting transaction must be
rolled back; in an editor that leaves it open, run `ROLLBACK;` and retain the
reported error for investigation.

After a successful run, the result lists affected tables and renamed row counts.
Reload employee information and sign out/in to refresh employee-ID claims.
The employee's login username, password hash, classification, branch, payroll
amounts, payroll record IDs and original timestamps are preserved.

To copy the file from a Windows checkout into the SQL editor:

```powershell
Set-Location 'Z:\hasani_payroll'
Get-Content -Raw 'backend\scripts\rename-employee-id.sql' | Set-Clipboard
```

Paste the complete transaction into the database SQL editor and run it once.
If either ID needs to differ, review the two literal values at the top first.
