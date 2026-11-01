# Attendance deduction hours and FRN rest-day overtime

Confirmed rules: FRN staff remain exempt from late/short-hours deductions. Local
late deduction means net-working-hours shortfall, including early checkout and
excess breaks, rather than arrival lateness alone. The existing 15-minute early
checkout grace, HED1007 exception, UNPAID/PH exclusions, RM10 monthly waiver and
ten-sen rounding remain. Actual arrival lateness can still appear in daily rows.

Payroll and both single/batch attendance print paths now call the same shortage
calculation. The summary pairs deductible shortfall hours with the late deduction
amount, rather than pairing raw arrival minutes with a shortage deduction. Thus
an on-time arrival with early checkout/excess breaks can show deductible hours;
late arrival made up by sufficient net work does not automatically create one.
FRN deductible minutes are zero. Saved monetary amounts remain authoritative for
existing payroll. If saved late pay is positive but current attendance has zero
deductible shortfall, the print marks the mismatch for review, rather than hiding
or inventing a charge. Historical saved payroll is not rewritten automatically.

FRN monthly rest entitlement is two OFF days. With complete month attendance and
the month at its last day or later (Malaysia date), one OFF taken produces one
rest-day OT day; zero taken produces two; two or more taken produce none from
unused entitlement. A missing/blank Present day does not prove a complete month.
The existing daily basis basic salary / 28 is retained and combined OT is rounded
to ten sen. Existing explicitly worked OFF days are retained and the new unused
entitlement tops up to the larger day count rather than double-paying it. The
HED1016 OT exclusion remains. An incomplete/in-progress month gets no inferred
unused-OFF bonus, while explicit worked-OFF payment follows the existing rule.

The rule applies in payroll generation and read-only pre-payroll estimates. Existing
approved-hours OT and unpaid deduction calculations are unchanged. Existing saved
months must be reviewed/regenerated with overwrite to apply the new rest-day OT;
printing alone does not alter payroll.

Added tests cover early checkout with no arrival lateness, made-up arrival time,
printed-versus-payroll shortage consistency, FRN exemption, unused OFF entitlement,
no double count, incomplete months and the OT employee exclusion. Dart formatting/
parser and diff checks pass. Flutter execution is unavailable in this workspace;
tests must run locally/CI. Rebuild Flutter web to apply the calculation/display
changes; no database migration is needed.
