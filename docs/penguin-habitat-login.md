# Penguin habitat login scenes

The desktop web and compact Android/web login share 28 bundled photorealistic
Antarctic habitat backgrounds. The Hasani Books logo, sign-in form, golden egg,
countdown and hatched penguin keep their existing layout and behaviour.

| Day | Habitat |
| --- | --- |
| Monday | Glacier Bay |
| Tuesday | Nesting Beach |
| Wednesday | Mountain Valley |
| Thursday | Snow Dunes |
| Friday | Fractured Sea Ice |
| Saturday | Rocky Cove |
| Sunday | Ice Arch |

Every habitat has four separate images. Times use Malaysia's fixed UTC+8 offset,
regardless of the device timezone:

| Period | Malaysia time |
| --- | --- |
| Morning | 06:00–11:59 |
| Afternoon | 12:00–16:59 |
| Evening | 17:00–19:59 |
| Night | 20:00–05:59 |

## Reveal-day exception

On the public campaign's hatch day, the login switches to that weekday's evening
image as soon as the shared server controller confirms the hatch. It stays in
evening until 20:00 Malaysia time, then changes to night. The next day follows the
normal slots. For the currently scheduled reveal, this means Friday evening
starts at the confirmed **23 October 2026, 15:39:11 Malaysia time** reveal.

The app does not reveal an egg or force the early evening from an unconfirmed
device countdown. Once loaded, server time plus monotonic elapsed time supplies
the background clock. If launch metadata has never loaded, the normal time slots
use the device instant converted to Malaysia time; the hatch-day exception waits
for a server-confirmed reveal. The controller refreshes on resume and periodically.
The login also rebuilds every second so time changes need no reload.

Only the current image and the day's evening image are preloaded. The current
background remains visible while the next scene decodes. No UI, text, or egg is
baked into the image. Assets use `assets/login_habitats/<weekday>_<period>.png`.

## Release

Deploy the new web build and distribute Android 1.0.17+24 or newer for this new
28-scene capability. Existing installations cannot gain bundled images and new
selection logic through a backend-only deployment. After the update, the scenes
switch automatically without further daily app updates. The existing backend
reveal schedule and three-minute notification reminder remain unchanged.

Tests cover all four period boundaries, Malaysia date rollover, 28 unique asset
selections, the confirmed hatch-time switch, night at 20:00, normal slots on the
next day, and compact login logo/form placement.

## Natural login refinement (1.0.25+32)

All seven morning photos now use cool daylight rather than sunrise lighting.
The Malaysia time boundaries and confirmed reveal-day exception are unchanged.
The background uses bottom-left cover alignment to retain foreground terrain.
Each scene has its own authored walking trail; see `login-penguin-walking.md`.
The mobile layout keeps its below-form penguin slot on a photographed snow perch.
