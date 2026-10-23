# Automatic work-anniversary wishes

The backend checks at startup and every minute. Active employees whose joining
month and day match today's date in `Asia/Kuala_Lumpur` receive a wish at or after
09:00 Malaysia time. At least one completed year is required; new joiners, future
joining dates, missing dates, and inactive employees are excluded.

The scheduler catches up later on the same day, including immediately after a
late deployment. It does not backfill past days. February 29 joining dates match
on leap days. Years of service are calculated from the stored joining date.

Each automatic wish is saved to the employee's inbox and Firebase push delivery
is attempted using the existing notification sender. One automatic wish per
employee per year is enforced by `app_private.anniversary_wishes`. The annual
claim and inbox insert are atomic across concurrent instances and restarts.
Manual admin sends remain separate explicit actions and use the same wording.

Example:

> 🎉 Happy Work Anniversary, Amina! 🏆
> Congratulations on completing 5 years with Hasani Books. Thank you for your
> dedication, hard work, and the difference you make every day. Wishing you
> continued growth and success!
> — From all of us at Hasani Books 💙

Deploy the latest backend to activate this worker; its database migration runs
at startup. Keep the backend running so checks can execute. Firebase requires the
existing server credential and an employee device registered with notification
permission. Push delivery is best effort and not retried after the inbox commits;
missing configuration or failed push does not remove the inbox wish.

The integration tests use a separate local fixture database and stub push so no
employees are contacted. They cover the time boundary, eligibility, years of
service and singular grammar, concurrent deduplication, next-year sending,
same-day catch-up, atomic rollback, and retained inbox wishes on push failure.
