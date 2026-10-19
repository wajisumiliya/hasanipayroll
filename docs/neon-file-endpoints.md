# Neon file endpoint integration (not deployed)

The migration branch contains an opt-in file router in `backend/src/neon-file-router.js`.
It is **not mounted** on the running server. No schema or production database was changed.

Before mounting:

1. Apply `backend/sql/20261019_neon_file_objects.sql` to a disposable Neon staging branch and review grants.
2. Mount `createNeonFileRouter({ db, authorizeEmployee })` only **after** the existing verified JWT authentication middleware. The authorization callback must check employee self-access and privileged branch/role scope for both reads and writes, using trusted authenticated claims, not client-provided role data.
3. Test cross-employee access denial, upload size limits, file signatures, invalid IDs, and database failures.
4. Migrate existing employee photo objects and document metadata with a verified count/checksum reconciliation before switching Flutter photo URLs.
5. After rollout, migrate notifications and live updates, remove remaining Supabase code and package, then validate all workflows before retiring Supabase.

This module does not itself provide a complete migration, historical file transfer, or production-ready authorization.
