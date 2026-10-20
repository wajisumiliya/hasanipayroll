# Employee login restoration, 20 October 2026

The separate `hasanihub` Supabase project's `public.app_user` contains the
original login hashes. GitHub's `SUPABASE_SOURCE_DATABASE_URL` was used only by
a preflight workflow; the application runtime reads Neon's `app_user`.

After user authorization, the source records were matched to Neon usernames,
emails and payroll employee IDs. The copy was tested on an isolated branch,
then applied to production in one transaction with a table lock and rollback
guards. No source records were modified. No hashes are included in this report,
repository, migration artifacts or application diagnostics.

- 192 existing Neon accounts received their missing hashes.
- 12 missing accounts were inserted.
- All 204 copied hashes and identities were verified against the source.
- All 12 pre-existing Neon password hashes were verified unchanged.
- All 193 Neon employee accounts now have password hashes.
- Existing inactive states and mandatory password setup were preserved.

The backend fix alongside this report supports the imported username primary
key, snake-case metadata and lowercase roles during account creation, password
reset and first-login setup. Exact username/email matches take priority over
employee-ID aliases so duplicate historical aliases cannot select another row.

Deploy the backend after merging. Employees can use their original usernames
and passwords. Those whose source accounts required a password change must
complete the existing first-login setup after this backend fix is deployed.

Nine branch aliases have no source password and were left unchanged. This does
not affect the restored employee accounts; configure those branch accounts
individually if they are still needed.
