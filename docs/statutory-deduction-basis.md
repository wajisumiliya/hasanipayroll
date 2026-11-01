# Statutory salary basis

Local EPF, SOCSO and EIS use basic salary minus the payable late deduction minus
unpaid deduction. The existing late waiver/rounding is applied before calculating
this basis. The RM500 contribution eligibility threshold uses this same adjusted
amount. Payroll generation, live editor recalculation and EPF report salary use
the combined deductions. Explicit unpaid leave remains its own payroll field;
late and unpaid amounts are each deducted only once from net pay.

FRN EPF/SOCSO retain their existing full-basic basis, and FRN late exemption is
unchanged. Existing EIS settings, wage tables and fixed SOCSO employee overrides
are unchanged. Saved payroll requires review/regeneration to update contributions.

A unit test verifies both deductions reduce local statutory wage. Dart parsing,
formatting and diff checks pass. Flutter execution requires local verification.
