# Security and Repository Audit — 2026-09-28

## Scope

This audit covers GitHub protections/CI, backend dependency validation, Git-history secret detection, Supabase RLS/storage authorization, payroll regression coverage, repository size and Flutter analyzer enforcement.

## GitHub main-branch protection

At audit time `main` is **not protected** and the repository has no rulesets. The desired control is:

- require pull requests before merge;
- require the Android and Backend CI checks that apply to the change;
- block force pushes and branch deletion;
- require conversations to be resolved;
- do not allow bypass for ordinary contributors.

This setting must be applied in GitHub repository settings/rulesets. It cannot be safely represented as application source code.

## Backend CI

Backend CI now validates the locked dependency installation with `npm ci`, Prisma client generation, Node tests, and `npm audit --omit=dev --audit-level=high`. Third-party Actions remain pinned to commit SHAs and workflow permissions remain read-only.

## Git-history secret audit

`.github/workflows/security-history.yml` checks the complete Git history (`fetch-depth: 0`) for a deliberately narrow set of high-confidence private-key/token/password patterns. It does not print matching secret values.

A passing scan is evidence against the covered patterns, not proof that no secret has ever existed. GitHub Secret Scanning should also be enabled where available. Any confirmed historical credential must be rotated before history cleanup.

## Supabase RLS/storage review

### Core role model

| Domain | Admin | Branch | Employee |
| --- | --- | --- | --- |
| employees | full | own branch read/update subject to policies | self read |
| attendance | full | own branch | self read |
| payroll | full | own branch read | self read |
| monthly/daily rosters | full | branch-scoped policies | role/policy dependent |
| OT / leave requests | review | branch workflow | own request workflow |
| salary defaults | admin-only policy | denied | denied |
| branch activity logs | read | own branch insert/update | denied |
| EA forms | admin/foreign-admin | denied | self read |
| notifications | role/audience controlled | scoped | own audience/read state |

The 2026-09-03 lockdown migration removes anonymous access from the core payroll/HR tables and rebuilds policies around trusted JWT `app_metadata` claims. Later migrations add role-specific policies for rosters, requests, reports, notifications and EA forms.

### Storage

The `employee-photos` bucket is intentionally configured for **public read** while insert/update/delete are authenticated admin operations. Public read means anyone who knows an object URL can retrieve the image. This is a privacy decision, not merely a performance setting.

If employee photos must become private, change the bucket policy and client retrieval design together. Do not change only one side.

### Items to keep under review

- Branch `employees` update access is broad at row level; column-level business intent should be reviewed before narrowing it because branch workflows may rely on it.
- Security-definer RPCs must derive identity/role from trusted JWT claims and set a controlled `search_path`.
- New tables must enable RLS before production use and should revoke anonymous privileges explicitly.
- Legacy permissive policies in early migrations are superseded by later lockdown migrations; production migration order must remain intact.
- Notification device registration is hardened by `20261015_harden_notification_device_registration.sql`, deriving ownership from trusted JWT metadata instead of caller-supplied identity.

## Payroll regression coverage

Regression tests now cover:

- local salary and FW salary source selection;
- duplicate/historical FW salary protection;
- differing historical FW/basic values;
- blank salary behavior;
- gross/net calculations;
- UNPAID and late deduction components;
- PH pay including multiple and zero-day cases;
- approved OT, minute conversion and negative/zero OT;
- shortage exclusion for UNPAID, PH and non-worked rows;
- EPF/SOCSO/EIS/PCB deduction aggregation;
- zero-EIS representation;
- cents preservation for historical imported payroll.

Schedule lookup behavior remains covered separately by statutory tests such as `socso_contribution_test.dart`. Database-backed end-to-end payroll generation should continue to be validated against known historical payroll samples before statutory/business-rule changes.

## Repository size

GitHub reports the repository at roughly 299 MB including history. The current tree inspected during this audit contains about 127.5 MB of blobs.

The largest concentration is committed `build/web` output (CanvasKit/WASM, compiled `main.dart.js`, copied assets and symbols). This is generated content, but the existing `.gitignore` intentionally keeps `build/web`, so it may be part of the current deployment workflow. It was **not removed** automatically.

Five legacy login image files totaling roughly 12 MB were not declared in `pubspec.yaml` and had no code references, so they were removed from the current branch:

- `assets/login_cat_open_eyes1.png`
- `assets/login_cat_open_eyes2.png`
- `assets/login_cat_cutout1.png`
- `assets/login_cat_cutout2.png`
- `assets/login_cat_hero.png`

Deleting files from the current tree does not remove their historical blobs. Shrinking the full 299 MB repository requires an intentional history rewrite (for example with `git filter-repo`), which changes commit SHAs and should only be done with a coordinated backup/migration window.

## Flutter analyzer

Android CI now runs plain `flutter analyze`; warnings and infos are no longer explicitly downgraded by CI flags. If this exposes existing analyzer debt, fix the reported source issues rather than restoring broad `--no-fatal-warnings` suppression.

## Follow-up validation

Before merging this audit branch:

1. Android CI must pass with strict analyzer behavior and expanded payroll tests.
2. Backend CI must pass tests, Prisma generation and production dependency audit.
3. Security History Audit must pass or any finding must be investigated and credentials rotated.
4. Review the employee-photo public-read privacy decision separately if private photos are required.
5. Configure the `main` GitHub ruleset after the required check names are confirmed by successful CI.
