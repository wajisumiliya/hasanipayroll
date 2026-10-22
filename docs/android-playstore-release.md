# Signed Google Play bundle

The `Signed Android Play Store bundle` GitHub Actions workflow builds the
`com.hasani.payroll` production app using the repository's Flutter version and
existing upload key. It does not publish an app or change a Play Console track.

## Required repository secrets

In GitHub Settings → Secrets and variables → Actions, configure:

- `ANDROID_KEYSTORE_BASE64`: single-line base64 of the existing upload keystore.
- `ANDROID_KEY_ALIAS`: alias of the existing upload key.
- `ANDROID_KEY_PASSWORD`: key password.
- `ANDROID_STORE_PASSWORD`: keystore password.

Keep these values out of source files, issues, logs and chat. For an existing
Play app, use its existing upload key, or a replacement approved through Play
Console's upload-key reset process. The public certificate in the build artifact
should match Play Console → App integrity → Upload key certificate.

## Build and download

The signed workflow runs when release configuration, signing helpers, or
`pubspec.yaml` changes on `main`. It can also be started through Actions →
Signed Android Play Store bundle → Run workflow → main.

Version name and code come from `pubspec.yaml`; artifact names use that same
metadata. Google Play requires a version code greater than every code previously
uploaded. The optional `build_number` manual input can supply a higher unused
code without changing source. It must be at least the repository version code.

The workflow validates required secrets before installing Flutter, runs the
format, analysis and test checks, builds the release AAB, verifies its signature
and upload certificate, and removes private signing files even if a step fails.
A missing upload key fails the job; it never creates a replacement key.

Download `HASANI-PAYROLL-PLAYSTORE-SIGNED-<version>-<code>` from the successful
workflow run's Artifacts section. It contains:

- `hasani-payroll-<version>-<code>.aab`
- `upload-certificate.pem` and public certificate details
- `SHA256SUMS.txt`

Upload the AAB to the intended Play Console testing or production release.
The production backend is `https://hasaniworkhub.onrender.com`.

Before rollout, check the seven daily mobile login scenes and golden mystery
eggs on a test device. Also retain the payroll regression check: verify complete
gross, net and deduction amounts in the yearly payslip summary.
