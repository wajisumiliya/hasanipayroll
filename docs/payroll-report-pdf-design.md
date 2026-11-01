# Payroll report PDF presentation and approved OT report

Late, MC, Unpaid, Increment Eligibility and Increment Payroll Comparison PDFs use
white body cells throughout. Alternating row fills, highlighted count columns,
comparison result fills and shaded total cells are removed; existing table rules,
column headings and values remain. Titles include the selected payroll month in
short form, e.g. `Increment Eligibility Report - Oct'26`. The detailed late PDF
export also uses the month-labelled title and revised footer.

The previous footer notes/page labels are replaced by blank `Approved by` and
`Date` fields. Totals remain attached to the table. Notes are not printed in the
footer; generated-on metadata remains in headers where it already existed.

## Approved OT

The Attendance Late card adds an `OT Print` button alongside Late, MC and Unpaid.
It prints employee ID, employee name, total approved overtime (HH:MM), and OT
amount RM, plus totals. It captures the selected month, branch and employee scope
before loading, with the same direct-print/busy behavior as the existing buttons.

`GET /api/attendance/approved-ot-report` is authenticated and admin-only, including
attendance administrators. Reviewer/request-only accounts are denied. Local or
foreign staff scopes are enforced, and month, branch and employee selections are
validated and passed into the SQL query. The endpoint is read-only and returns
JSON or a worker-generated PDF. It does not generate/save payroll or change OT
approval, attendance, salary or increment metadata.

Only saved `approved_ot_minutes` of at least 30 minutes are included; requested,
unauthorized or legacy duration-only OT is not inferred as approved. Employee/date
pairs are deduplicated and the established HED1016 exclusion is retained. Amounts
are calculated for approved minutes only using the payroll period's basic salary
when saved, otherwise the salary default, divided by 26 and the matching weekly
roster's net target, multiplied by 1.5. Payroll salary-rule fallback targets,
per-day RM5 payment threshold and final ten-sen rounding are retained. Unrelated
foreign worked-OFF-day earnings are not included in the approved-hours amount.
Missing/invalid salary data prints `Not set`, rather than fabricated zero pay.

## Verification

Focused tests cover approval-only aggregation, duplicate dates, unknown salary,
overnight/weekly rates, payment thresholds, staff/branch/employee scope, access and
input guards, PDF output and dense/empty one-page selections. A real PostgreSQL
fixture verifies the actual joins/week selection and payroll-versus-default basic
salary. Regression tests render all six summary variants and inspect PDF drawing
commands to ensure the former alternating/result fill colors are absent. Sample
PDFs were rendered to images and visually checked; extracted text confirms titles
and approval/date fields.

Flutter button tests now include OT direct printing and the new card action;
Dart formatter/parser checks pass. Flutter execution is unavailable in this
workspace and must run locally/CI. Deploy the backend for PDF changes, and rebuild
Flutter web for the new OT button (tracked old bundles do not contain the button).

Final backend validation: all 178 tests passed with the bootstrap PostgreSQL
fixture enabled and serial test execution; zero failures or skips.

## Supplied Hasani Payroll logo

Report headers now embed the exact artwork uploaded as
`assets/Hasani Payroll Logo.png`, replacing the text brand and the Late report's
chart icon. A byte-identical copy lives at `backend/assets/hasani_payroll_logo.png`
so backend-only deployments contain the image. The shared branding helper clips
only the source image's outer whitespace in the PDF viewport and preserves the
artwork's proportions and colors. All six summary variants and the detailed Late
PDF use the logo; month-labelled titles and approval/date fields are retained.

Validation: 34 focused report/PDF tests passed, including embedded-image checks
for all six summary variants. One PostgreSQL-specific OT test was skipped because
no test database was started for this image/layout-only change. JavaScript syntax
and diff checks passed; Late and OT PDF samples were rendered and visually checked.
Deploy the backend to apply this change; no Flutter rebuild is required.
