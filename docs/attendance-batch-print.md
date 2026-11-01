# Attendance selection and combined printing

The selected-branch Attendance page adds Print beside Submitted/Pending/OT.
Print toggles a selection mode with checkboxes on employee cards. Clicking a
card toggles its selection instead of opening attendance/OT. Select visible adds
the current search/status result; Clear selection removes all choices. The
selected counter includes employees kept selected across search/status changes.
Changing branch or payroll month clears the selection. Cancel selection restores
the normal card actions. Print selected captures employee IDs, branch and month
before starting, disables repeat submissions, and opens one combined print job.
Up to 100 employees are accepted per job.

The existing AttendancePdfService template now supports a batch of sheets. Each
employee gets the existing front work-attendance and back break-attendance pages,
with their own identity, month, watermark, durations and RM values. Saved payroll
amounts are used where present; otherwise the established read-only payroll
preview calculates estimates. Printing does not create payroll, approve OT,
submit attendance or change increment details. Missing salary/duplicate payroll
fails visibly instead of silently omitting a selected employee.

A single authenticated /api/attendance-sheet/print-batch request loads selected
employees, month-specific attendance, rate inputs, saved monetary values, and
rosters. Admin users can select within the requested branch; branch users are
restricted to their own branch. All IDs must belong to that branch, and local/
foreign staff scope is enforced before financial reads. Employee logins cannot
use the batch endpoint. Selection count/month/branch are validated server-side.
The selected data is loaded with a fixed six-query batch rather than opening
individual attendance dialogs or making one request per employee.

Validation: all 182 backend tests passed with the PostgreSQL bootstrap fixture
and serial execution. The four focused batch tests also passed against real
PostgreSQL after final authorization guards were tightened. Dart formatter/parser
and diff checks passed. Added Flutter tests verify two selected employees produce
four pages and empty selections fail. Flutter execution could not run because
the temporary SDK image exceeded workspace disk capacity; failed image layers
were cleaned up automatically. Deploy the backend and rebuild Flutter web for
this feature. No database migration is needed.

## Attendance-only account late card

The `account` attendance administrator now has an Attendance Late sidebar entry
(page 19). It reuses the overview's Late card with its monthly selector, summary
metrics, employee detail/View All and Late/MC/Unpaid/OT print actions. A late-only
presentation flag hides increment, birthday and anniversary cards on this page.
The account still starts on Attendance; the navigation allowlist adds only this
new page to Attendance and Status View. Other administrative pages stay blocked.
The page loads only branch labels, selected employee identity/position fields and
the existing late-report API; it does not load the financial overview, payroll
history or salary defaults. Existing backend report permissions already accept
the attendance scope, so no wider role/database grants are introduced.
A Flutter widget regression test covers the standalone card and print buttons.
Dart formatter/parser checks pass; Flutter execution remains unavailable here.
Rebuild Flutter web to show the new navigation item.

## Duplex A4 preference

Both single and batch attendance PDFs now use PDF 1.7 ViewerPreferences with
DuplexFlipLongEdge and PrintScaling None. Employee page order is unchanged:
work/front, break/back, then the next employee's work/front and break/back. The
batch job uses the same A4 layoutPdf options as single-employee Print A4, and the
selection bar states the two-sided/long-edge setting. Browsers and printer drivers
can override or ignore PDF viewer preferences; physical duplex still requires
Two-sided / Flip on long edge in a duplex-capable printer's dialog. It cannot be
forced by the Flutter web API. The batch test also asserts the PDF preferences.
The PdfDict import is limited to the package's pinned 3.13.1 dictionary type;
that version's catalog.prepare retains these preferences. Dart formatter/parser
checks passed. Flutter execution remains unavailable in this workspace.
