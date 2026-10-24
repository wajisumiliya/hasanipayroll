# Silent employee penguin companion

The employee dashboard offers Feed, Play, Pet and Rest/Wake. There is no Talk
button, microphone, recording, voice playback or audio permission in this feature.
The login and branch dashboard also offer a public companion. The branch family
and Pingu share one habitat and one set of care controls.

The existing orange crown, green bill/feet and gray-white body are retained.
Chick and adult reaction sheets contain four expressions for each care action.
The character uses pose animation, not wildlife video or a live 3D model.
Daily growth and server-confirmed hatching still determine its size and stage.

The first Feed/Play action saves through the existing employee-only API.
Its 24-hour care records and daily growth rules are unchanged. Subsequent
Feed/Play clicks are visual interactions and do not issue extra care writes.
Pet and Rest are local interactions. No care animations or success messages
are started on a failed request, and pending writes disable the controls.

Speech bubbles, a small fish, a snowball and hearts explain the responses.
Happiness is derived from daily feeding/play plus local petting; energy shows
a ready/resting state. These are illustrative care indicators, not stored game
currency or medical measurements. Local petting/rest resets with the card.
Rest lasts until Wake, tapping the sleeping pet, feeding or playing.
Reaction timers cannot wake a resting pet; they are cancelled on replacement
and disposal. The reaction atlas is reused between consecutive interactions.
Reduced motion displays a static expressive pose and static care props.

Tests cover four silent controls, care failures, duplicate request protection,
sealed eggs, pose isolation, daily-care repeat interactions, and rest cancellation.
Android clients need the new build for these bundled controls and artwork.

## Public companions (1.0.30+37)

Login uses the public login hatch clock; the branch companion uses the branch
hatch clock. They attach to existing shared controllers, so no extra polling
loop or private employee API call is introduced. Hatch confirmation and growth
come from public server metadata. Before confirmation, the egg stays sealed.
Feed/Play/Pet/Rest are page-local on these screens and reset on leaving.
The login card uses a compact view below the mobile form or in the desktop
left panel; the sign-in form and logo remain accessible and unobstructed.

## Login habitat refinement (1.0.31+38)

Only the login companion uses the immersive treatment: slate/warm dusk panels,
quiet gold controls and thin mood indicators replace the bright white sections.
Its habitat photo follows the exact same weekday/period as the login background.
The penguin stands on the photographed dry-ground trail using the shared
bottom-left cover projection, with planted feet and consistent idle/care pose
scales. The original orange/green/gray-white palette and daily growth remain.
Idle uses a resting open-eyed pose from the care sheet, avoiding a size/texture
change when interacting. Employee and branch companion layouts are unchanged.

## Joined branch habitat (1.0.32+39)

The branch dashboard has one card: the original two adults, young penguin and
baby live alongside Pingu in the same coastal scene. Pingu keeps the orange
crown, green bill/feet and gradual growth. One Feed/Play/Pet/Rest dock controls
Pingu; Feed also starts the existing family feeding sequence when available.
The embedded family hides its duplicate header/feed button and shows feeding
status in the scene. Family swimming, walking and caregiving continue.
Login and employee dashboard layouts are unchanged.
