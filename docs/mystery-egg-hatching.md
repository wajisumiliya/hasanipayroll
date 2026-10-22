# Golden mystery egg hatching

The public login egg and all six branch dashboard eggs share one launch clock.
They hatch 72 hours after the updated backend first initializes the campaign.
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

Deploy the backend and updated web/Android client. The 72-hour countdown starts
when the backend creates the launch record, not when a commit is pushed or an
individual opens a screen. Backend startup log dates are not the hatch date;
the endpoint's `hatchAt` is the authoritative time. The web and Android login
page use the configured `API_BASE_URL`, which must point to that backend.
