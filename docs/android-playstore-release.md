# Android Play Store release: 1.0.5 (12)

The payslip yearly summary uses responsive cards and complete wrapping amounts.
Version code 12 follows the user's current Play Console version code 11.
The application ID remains `com.hasani.payroll`.

## Required signing key

An update to the existing Play listing needs the upload key already registered
with that application. An arbitrary new keystore will not be accepted.
The regular Android CI builds unsigned release artifacts when no key is present;
those are compilation checks and must not be described as Play-ready files.

Recover the original `.jks` / `.keystore` from the computer or developer that
created previous Play uploads. If it is lost and Google Play App Signing is
enabled, the account owner must follow Play Console's upload-key reset process.
A signing-key reset is separate from this code change; do not generate a random
key and assume Google Play will accept it. Do not post passwords in chat or
commit the private key or `key.properties` to GitHub.

## Signed workflow

After the correct upload key is available, add these repository Actions secrets:

| Secret | Value |
| --- | --- |
| ANDROID_KEYSTORE_BASE64 | Base64 of the original upload keystore bytes, as one line. |
| ANDROID_KEY_ALIAS | Existing key alias in that keystore. |
| ANDROID_KEY_PASSWORD | Password for the existing key. |
| ANDROID_STORE_PASSWORD | Password for the keystore. |

After merge, open Actions -> Signed Android Play Store bundle -> Run workflow,
select the branch that contains the accepted release code, and run it. The
workflow refuses to build a publishable artifact if signing secrets are missing.
It uses the existing Gradle release signing configuration and checks the final
AAB signature before uploading artifacts. Private signing files are deleted from
the runner and never uploaded as artifacts.

Download `HASANI-PAYROLL-PLAYSTORE-SIGNED-1.0.5-12`. It contains:

- `hasani-payroll-1.0.5-12.aab`: the Play Console upload file.
- The public upload certificate and its details for comparison with Play Console.
- SHA256SUMS.txt for the bundle download.

Compare the certificate SHA-256 fingerprint with the upload certificate shown
under Play Console app signing/app integrity before uploading. If Play rejects
version code 12 as already used, increase `version: ...+12` in pubspec.yaml and
update release artifact names before building again.

Upload the AAB to the existing application's intended testing/production track.
The workflow does not publish automatically. Confirm the full gross, net and
deduction values on the resulting app before rolling out to employees.
