# Cloudflare R2 employee photo migration (staged)

The Node API now provides `POST /api/employee-photos/:employeeId/sign` with the existing Hasani Payroll bearer JWT. The endpoint returns a 5-minute SigV4 URL for a single private R2 object: `employee-photos/{employeeId}/profile`. It does not return R2 secrets. `GET` is allowed for the employee's own photo or an admin; `PUT` is restricted to admins. The bucket must remain private.

## Render environment (server only)

Set `R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_ACCESS_KEY_ID`, and `R2_SECRET_ACCESS_KEY` on the Render Node service. Never put these values in GitHub, Flutter defines, or browser code. Grant the R2 key object read/write only for the designated bucket.

## Integration requirements before cutover

- Configure R2 bucket CORS for the deployed Flutter web origin and `GET`, `PUT`, and `Content-Type` requests.
- Update Flutter upload/download widgets to call the authenticated Node sign endpoint and upload directly to the returned URL using exactly the returned content type.
- After a successful upload, verify the object and update `public.employees.photo_url` in Neon to the R2 object key using an authenticated backend endpoint. The current code **does not** change the database photo path or migrate existing files.
- Copy existing private employee photos from Supabase Storage into R2 before switching reads; retain the old storage until parity checks and authorization tests pass.
- Add branch-manager photo permissions only after checking branch ownership on the server. The new endpoint deliberately denies branch-role access for now.
- Test cross-employee access denial, expiry, object overwrite rules, file size and actual image validation, and mobile/web display before production release.

This PR is **backend groundwork only**. It does not remove Supabase Storage from Flutter or complete the data migration. Do not disable Supabase.
