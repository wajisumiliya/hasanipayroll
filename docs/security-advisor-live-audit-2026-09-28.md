# Live Supabase Security Advisor Audit — 2026-09-28

Project: Hasani Payroll (qychfoxygqzmtsqtxihp)

The live Supabase security advisor reported seven SECURITY DEFINER functions executable by anon. The application migrations indicate these functions are intended for authenticated users, so the new hardening migration explicitly revokes public/anon execution and grants execution to authenticated.

Affected RPCs:
- apply_employee_aquarium_decay(text)
- change_daily_report_pin(text,text)
- clean_employee_aquarium()
- feed_employee_aquarium()
- get_employee_aquarium()
- record_employee_aquarium_login()
- verify_daily_report_pin(text)

The advisor also reported two unindexed foreign keys on leave_requests. The migration adds covering indexes for branch_approved_by and admin_approved_by.

The advisor reported 11 RLS-enabled tables with no policies. These include intentionally client-inaccessible staging/audit/security tables such as historical import tables, payroll_import_audit, daily_report_branch_pins, notification_devices and employee_aquarium_logins. No permissive client policies were added merely to silence the advisory notice.

The advisor reported multiple permissive policies on several role-scoped tables. These are performance notices, not proof of unauthorized access; they were not mechanically consolidated because doing so without role-by-role testing could change access semantics.

Employee photos remain public-read by explicit application design and are documented separately.

No payroll calculation formula is changed by this migration.
