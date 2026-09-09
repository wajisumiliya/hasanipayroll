# Security policy

## Supported versions

Only the current `main` branch is supported with security fixes.

## Reporting a vulnerability

Do not disclose suspected vulnerabilities in a public issue. Use GitHub's
**Security** tab and select **Report a vulnerability** to open a private report.
Include affected versions, reproduction steps, impact, and any suggested
mitigation. Maintainers should acknowledge a report within seven days and keep
the reporter informed while it is investigated.

Never include production credentials, employee records, payroll data, or other
personal information in a report. Revoke and rotate a credential immediately if
it may have been exposed.

## Repository security expectations

- Store backend credentials only in the deployment platform's secret store.
- Keep `.env` files, signing keys, database exports, and private employee data
  out of Git.
- Treat Firebase client configuration as public identifiers and enforce access
  through Firebase rules, API restrictions, App Check where appropriate, and
  authorized-domain settings.
- Require pull-request review and passing CI checks before merging to `main`.
- Enable Dependabot alerts, secret scanning, push protection, and private
  vulnerability reporting in the repository settings when the GitHub plan
  supports them.
