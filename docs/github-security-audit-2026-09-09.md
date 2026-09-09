# GitHub repository security audit

**Audit date:** 2026-09-09  
**Scope:** tracked repository contents, Flutter and Node manifests, GitHub
Actions, authentication safeguards, and Supabase migrations.

## Executive summary

The repository already has useful application-level controls: the API refuses
to start without sufficiently long JWT secrets, uses Helmet and explicit CORS
origins, rate-limits authentication routes, hashes passwords, and the database
migrations enable row-level security for sensitive tables.

The audit found no committed backend `.env` file or obvious private signing key
in the current tree. Firebase client API keys are tracked; these are identifiers
distributed with every client build rather than server secrets, but their API
and domain restrictions must be configured in the Firebase/Google consoles.

The largest repository-level gap was supply-chain and merge protection: CI only
built on pushes to `main`, Actions used mutable major-version tags, and no
automated dependency-update configuration or vulnerability-reporting policy was
present. This audit remediates those repository-controlled gaps.

## Findings and remediation

### GH-01 — Pull requests were not validated (high, remediated)

The Android workflow ran only after code reached `main`. It now runs formatting,
static analysis, tests, APK compilation, and app-bundle compilation on pull
requests and pushes. Configure the `build` job as a required status check in the
GitHub branch protection or ruleset for `main`; that setting cannot be changed
from repository files alone.

### GH-02 — Actions were referenced by mutable tags (high, remediated)

Mutable action tags can be retargeted after review. All workflow actions are now
pinned to full commit SHAs, with release comments retained for readability.
Dependabot is configured to propose future GitHub Actions updates.

### GH-03 — Dependency monitoring was absent (medium, remediated)

Dependabot now checks the root Dart/Flutter dependencies, backend npm
dependencies, and GitHub Actions every week. Maintainers should also enable
Dependabot alerts and security updates in repository settings.

### GH-04 — No private disclosure guidance (medium, remediated)

`SECURITY.md` now directs reporters to GitHub private vulnerability reporting,
sets expectations, and warns against placing payroll or employee data in public
issues.

### GH-05 — Generated web output is versioned (medium, open)

Approximately 44 MB of generated `build/web` output is tracked. Generated
JavaScript and WebAssembly make reviews noisy and can drift from source. Move
deployment to a reproducible GitHub Actions/Firebase pipeline, then remove the
generated directory from Git. This was not changed because the current hosting
process is not documented and removing it could interrupt deployment.

### GH-06 — Firebase client configuration needs console-side restrictions
(medium, external action required)

Firebase configuration is necessarily present in Flutter and web client code.
Confirm that each API key is limited to the required Google APIs and appropriate
Android package/SHA, Apple bundle ID, or web referrers. Review Firebase Security
Rules, authorized domains, App Check enforcement, and quota alerts. Rotate only
if a key was mistakenly granted access to non-client APIs.

### GH-07 — Limited automated test coverage (medium, open)

The test suite contains a single startup widget test. Add focused tests for
payroll calculations, authorization boundaries, first-login password changes,
OTP expiry and attempt limits, branch isolation, and Supabase RLS policies.

### GH-08 — Git history and hosted settings were not fully inspectable
(informational)

This local audit cannot verify GitHub organization/repository settings, leaked
secrets in forks or logs, protection rules, collaborator permissions, deployed
environments, or audit-log events. The package-registry advisory endpoint was
also unavailable from the audit environment. Run GitHub secret scanning across
full history and rerun `npm audit --omit=dev` in trusted CI.

## Recommended GitHub settings checklist

1. Protect `main`: require a pull request, one approving review, conversation
   resolution, the Android `build` check, and no force pushes or deletions.
2. Enable secret scanning and push protection, including non-provider patterns
   for the deployment platform's JWT and database credentials.
3. Enable Dependabot alerts/security updates and private vulnerability
   reporting.
4. Restrict Actions to trusted actions, retain read-only default workflow-token
   permissions, and require SHA pinning through organization policy if possible.
5. Use protected environments for production deployments, with required
   reviewers and environment-scoped secrets.
6. Review collaborators, deploy keys, webhooks, installed GitHub Apps, inactive
   branches, and repository visibility at least quarterly.

## Validation performed

- Searched tracked paths and source for common credential and unsafe-access
  patterns.
- Confirmed backend JavaScript parses with `node --check`.
- Reviewed GitHub Actions permissions and triggers.
- Attempted Flutter analysis/tests and npm advisory checks; see GH-08 for the
  environment limitations.
