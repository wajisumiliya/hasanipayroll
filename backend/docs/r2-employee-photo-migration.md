# R2 employee photos

Flutter now signs photo GET/PUT/DELETE requests through the authenticated Neon
backend and uses the returned R2 URL directly. See [NEON_DEPLOYMENT.md](../../NEON_DEPLOYMENT.md)
for Render configuration and existing-file migration.

The bucket stays private. Set `R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_ACCESS_KEY_ID`,
and `R2_SECRET_ACCESS_KEY` only on the Node service. Configure bucket CORS for
the frontend origins, GET/PUT/DELETE methods, and Content-Type header.

`POST /api/employee-photos/:employeeId/sign` returns a five-minute SigV4 URL
for `employee-photos/<employee_id>/profile`. Reads require visibility of the
employee under the Neon row policies; writes require a full administrator.
R2 credentials and the API bearer token are never included in storage uploads.
Successful uploads update the employee's Neon `photo_url` to the object key.

Existing storage files must be copied to those R2 keys or uploaded again.
Importing database tables does not copy image bytes. Legacy photo URLs are
resolved as R2 employee references; missing objects show the initials fallback.
