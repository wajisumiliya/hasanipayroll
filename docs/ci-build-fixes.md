# PR CI build fixes

## Android artifact lookup

Flutter's root Gradle project is the `android/` directory. The customized default
used `rootProject.file("../../build")`, which resolves to a sibling outside the
Flutter project. Gradle could finish assembleRelease while Flutter looked in the
project's own build directory and reported no APK.

The default is now `rootProject.file("../build")`. The app subproject therefore
writes into `<flutter-project>/build/app`, matching Flutter's APK/AAB lookup and
both CI artifact paths. Explicit `flutterBuildDir` overrides are preserved. No
signing, Kotlin-plugin, release-build or CI failure checks were disabled.

The directory resolution was checked locally and against Flutter 3.47.0's
artifact lookup. A full Android APK/AAB build still needs confirmation from the
rerun GitHub Android job; this environment does not have its complete toolchain.

## Fresh PostgreSQL role assumptions

The birthday/anniversary migrations revoked permissions from `anon` and
`authenticated` unconditionally. On a fresh CI cluster, their tests can run before
the application migration creates those cluster-global roles, producing error
42704 (`role "anon" does not exist`). This reproduced the two supplied failures.

Both migrations still always revoke PUBLIC access and now revoke the two named
roles only when they exist. They do not create global roles or grant any access.
Existing production migration state does not need changing to address this CI
initialization issue; no production database was touched.

Validation on a disposable PostgreSQL 17 cluster:

- Birthday/anniversary tests run first without either legacy role: 4 passed.
- Full Backend CI test configuration with BOOTSTRAP_TEST_DATABASE_URL: 151 passed,
  0 failed, 1 skipped (the separate QR PostgreSQL fixture was not enabled).
- Birthday/anniversary tests rerun after roles exist: 4 passed. Regression checks
  grant/revoke fixture-table SELECT permissions to verify PUBLIC and existing
  browser roles remain denied after migration reapplication.
- Production dependency audit reports no high/critical issues (11 moderate issues
  remain in existing Excel dependencies); the CI high-severity threshold passes.

GitHub API access is unavailable here, so final Android and Backend check statuses
must be observed on the PR after the branch push. No main merge or deployment is
part of these fixes.
