# Employee photos in Neon

The app stores small image bytes in `app_private.employee_photos`, outside the
public Data API allowlist. GET, PUT and DELETE use the existing backend JWT.
Employee/branch read scope is checked against `employees` using RLS; writes
require an administrator and a visible employee. Reviewer accounts cannot read.
No new Render secrets, R2 bucket or public image links are needed.

Deploy the backend before the frontend. The backend startup applies the additive
photo table migration. New app uploads work immediately; old files require copy.

## Copy the existing private Supabase files

1. In GitHub repository Settings → Secrets and variables → Actions, add
   `SUPABASE_SOURCE_SERVICE_ROLE_KEY` from the old **Hasani Payroll** project
   `qychfoxygqzmtsqtxihp`. Never add it to Flutter or paste it into chat.
2. Keep the existing `NEON_DATABASE_URL` GitHub secret for `hasani_payroll`.
3. After this PR is merged, open Actions → **Copy employee photos to Neon** →
   Run workflow. Leave `apply` false first to preview. Deploy the backend first
   so the private photo table exists for the read-only preview.
4. If the preview reports all photos ready, run again with `apply` true.
5. Refresh the app. Remove the source service-role GitHub secret after completion.

Only employee rows with a photo reference are considered. Existing Neon photos
are skipped and concurrent changes are preserved. Each copied file is resized
and encoded as a small JPEG before a transaction saves its bytes and updates its
reference. Old Supabase files and rows are never modified or deleted. Logs show
counts only. Missing, inaccessible or invalid files fail the job visibly; a
partially completed job can be retried without overwriting existing Neon photos.

If Supabase Storage is blocked by the quota, the copy cannot read those bytes.
Restore source Storage access or upload the existing images again through the
app. Table import alone does not contain the original image bytes.

For a trusted machine with both database credentials and source key configured:

```sh
flutter pub get --enforce-lockfile
dart compile exe tool/encode_employee_photo.dart -o /tmp/encode-employee-photo
export PHOTO_OPTIMIZER_PATH=/tmp/encode-employee-photo
node backend/scripts/copy-employee-photos-to-neon.js
node backend/scripts/copy-employee-photos-to-neon.js --apply
```

The default command validates downloads and prints counts without changing data.
The `--apply` mode can create the private photo table if needed. The source host
is fixed to the original project, redirects are refused, download size is bounded
and secrets never go into URLs or logs.
