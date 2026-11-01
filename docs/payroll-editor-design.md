# Edit Payroll dialog design

Edit Payroll follows the supplied cream/navy reference, with the existing original
Hasani Books asset in the header (`assets/hasani_books_logo.jpg`). Field groups have
navy headers, gold section/field icons, white rounded inputs and compact labels.
On wide screens, earnings share a row with the Payroll Summary; on smaller screens
the summary stacks below. The summary reads existing totals and updates on edits,
loads and statutory recalculation, displaying Total Earnings, Total Deductions
and Net Payroll. The redundant bottom total chips are removed. Employer
contribution inputs and remarks remain available further down the form.

Reset restores the loaded payroll snapshot (zero/blank for a new record), asks
before discarding unsaved edits and invalidates pending statutory calculation
revisions. It does not save or modify database records. Existing save validation,
confirmation, employee/month navigation, contribution overrides and calculations
are retained. The footer separates Reset from Cancel/Save, with wrapping available
for narrow dialogs. No backend or migration changes are needed.

Dart formatter/parser and diff checks passed. A Flutter widget test covers summary
values updating on rebuild; Flutter execution is unavailable in the workspace.
Rebuild Flutter web to apply the design.
