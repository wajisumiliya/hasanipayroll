# Golden mystery egg hatching

The public login egg and all six branch dashboard eggs share one launch clock.
The original campaign used a 72-hour launch delay. The approved one-time
reschedule now sets the public hatch to **23 October 2026 at 15:39:11 Malaysia
time (07:39:11 UTC)**, one hour after the request. The migration adjusts the saved
launch timestamp to preserve the existing API contract for installed clients.
This is a fixed deadline, not one hour after each deployment or restart.
A visible countdown updates every second in days, hours, minutes and seconds.
It uses the saved server deadline and elapsed timer ticks, not the device wall
clock. If timing has not loaded, the UI says so instead of inventing a deadline.
At zero it shows “Hatching…” until the server confirms the reveal.

The final five minutes show cracks and a stronger wobble; the hatch reveals a
small chick with a brief transition. Hatch-day size is 30% of the mature bird.
Size increases each completed day after hatching, reaching full size after 42
days (45 days after adoption/launch). Daily size changes animate gently, and the
chick-to-juvenile artwork change on adoption day 15 does not jump its scale.
The existing personal employee pet uses the same daily size curve. Server age
and saved adoption/launch timestamps determine growth, not app-open time.

Startup stores one launch timestamp in `app_private.mystery_egg_campaign`.
Initialization uses the application's existing transaction and advisory lock;
restarts and multiple backend instances do not reset it. New devices and
reinstalls see the same public campaign state. Personal employee adoption
records are independent and unchanged.

`GET /api/mystery-eggs` exposes only launch time, hatch time, server time and
growth stage. It is available without signing in, contains no employee or
account data, sends `Cache-Control: no-store`, and accepts no reset/write action.

The frontend shares requests across the six eggs, refreshes on app resume and
every five minutes while visible, and requests confirmation at the hatch
boundary. It does not decide a reveal from the device's wall clock. If the API
is unavailable, an unconfirmed egg stays sealed until a successful retry.
Reduced-motion settings disable movement without preventing hatching.

Deploy the updated backend before the scheduled event. Existing web/Android
clients already read this deadline; the reschedule does not require an app update.
Clients refresh within five minutes or immediately on resume. Backend startup log dates are not the hatch date;
the endpoint's `hatchAt` is the authoritative time. The web and Android login
page use the configured `API_BASE_URL`, which must point to that backend.


## Three-minute reminder

At **15:36:11 Malaysia time (07:36:11 UTC)** a ten-second backend check becomes
eligible to save one `mystery_egg_reveal` notification with audience `all` and
attempt FCM push for all registered Android and browser devices. The inbox and
push message says the golden egg is hatching in a few minutes and invites everyone
to open Hasani Books. Push delivery requires working Firebase server configuration,
registered devices and notification permission; acceptance/arrival is best effort.

`app_private.mystery_egg_reminders` deduplicates by hatch deadline. The claim and
inbox insert are atomic, including across multiple instances. A late startup
inside the final three minutes catches up; startup after the hatch does not send
an expired reminder. The backend must be running during the reminder window.
If deployment is delayed beyond the event, the reveal still uses the fixed date
and the reminder is skipped. Neither production deployment nor live device
arrival can be inferred from a successful Git push.

Personal employee adoption/pet clocks are independent and are not reset by this
public campaign reschedule.
