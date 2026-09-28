# Free-plan backup setup

The scheduled workflow `.github/workflows/supabase-backup.yml` creates an encrypted backup of the PostgreSQL database and the private `employee-photos` Storage bucket every day at 02:15 Malaysia time.

The repository is public, so **never commit database URLs, service-role keys, passphrases, dumps, or decrypted backups**.

Before enabling/running the workflow, add these GitHub Actions repository secrets:

- `SUPABASE_DB_URL` — the Supabase database connection string (prefer the Session Pooler URI).
- `SUPABASE_SERVICE_ROLE_KEY` — the production service-role key, used only to read private Storage objects.
- `BACKUP_PASSPHRASE` — a long unique passphrase (32+ random characters) stored somewhere outside GitHub as well.

The workflow uploads only a GPG AES-256 encrypted artifact and retains it for 14 days. Download at least one backup periodically to a second private/off-site location. GitHub Actions artifacts are not a substitute for a long-term independent backup.

## Restore test

Do restore tests against a disposable/staging database, never directly against production.

Database archive:
`pg_restore --clean --if-exists --no-owner --no-acl --dbname="<TEST_DATABASE_URL>" database/database.dump`

Storage files are under `storage/` inside the decrypted archive and should be restored with a service-role authenticated Storage upload process.

Keep the backup passphrase separate from the encrypted backup. Losing the passphrase makes the encrypted backup unusable.
