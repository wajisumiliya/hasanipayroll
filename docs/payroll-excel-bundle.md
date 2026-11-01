# Payroll Excel generation dialog

The RHB Layout menu opens the rounded pale-lavender Generate Payroll Excel Files
dialog, with white Year/Month selectors, Cancel and a navy Generate 4 Excel Files
button. Generation remains in the dialog, locks the period/actions, prevents
repeat submissions, and shows progress. Failure/no payroll leaves the dialog open
for correction/retry; successful downloads close it. Closing/back is disabled
during generation. Month/year selection uses the existing saved-payroll month
query. This is an export, not payroll generation.

The combined action encodes four real Excel workbooks: one consolidated RHB
salary workbook, EPF, EIS and SOCSO. They are downloaded as one ZIP, avoiding
browser restrictions on multiple automatic downloads. The individual RHB export
retains branch-specific filenames/files; other individual statutory exports
continue to download XLSX. Existing identity/text formatting, contribution/net
calculations, missing-account exclusions and statutory layouts are retained.
Success is shown after the file saver completes, rather than after unawaited
per-workbook download triggers. No database values are modified.

Dart formatter/parser and diff checks passed. Flutter widget tests cover period
capture, duplicate-click prevention, success dismissal and retry after failure;
Flutter execution is unavailable in the workspace. No backend/migration change
is needed. Rebuild Flutter web and permit the ZIP download in the browser.
