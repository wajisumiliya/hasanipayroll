# Employee directory presentation

The Employees page follows the supplied compact blue/white reference: pale blue
canvas, grouped heading icon, navy Add Employee action, rounded status filters,
white search field, slim branch pills and one continuous rounded white list.
Desktop rows group photo/name/identity at the left, center the calendar-labelled
payroll coverage badges, and keep distinct active/vacation/departed status pills
and existing view/edit/more controls. Mobile keeps the compact action menu and
stacked coverage badges. Existing employee actions and coverage calculations
are preserved. Branch-specific management grids remain available as before.

Pagination now has clickable page numbers, an ellipsis for omitted ranges,
previous/next controls, a selected-page highlight and a compact small-screen
variant. Search/status/branch changes reset to page one. The 24-employee page
size and lazy data loading remain. The old redundant Employee List title inside
the outer list is removed. Refresh is retained beside Add Employee.

The branch-pill styling is opt-in for this directory, so shared controls on
other pages retain their styling. The main app header/navigation is unchanged.
No backend queries, permissions or stored employee/payroll values are changed.
Dart formatter/parser and diff checks passed. Pagination widget tests cover page
selection, bounds, ellipsis and compact last-page behavior; Flutter execution is
unavailable in the workspace. Rebuild Flutter web to apply this design.
