# Login penguin walking

After server-confirmed hatching, the login uses the same photographic-style
penguin pose sheets as the branch family. It is a frame animation, not wildlife
footage or real-time 3D. Baby, young and adult artwork changes at days 12 and 42;
the existing daily growth scale starts at 30% and reaches full size on day 42.
The branch crew and personal employee pet remain separate widgets.

Each of the 28 login photographs has an authored dry-ground trail in
`login_penguin_terrain.dart`. The background and trail share a bottom-left cover
projection so foreground rocks and ice stay aligned on different screen sizes.
The penguin walks back and forth, pauses at either end, and stays clear of the
sign-in card. These are hand-inspected routes, not automatic terrain detection.
Scenes with little land use a short route on one ledge or floe.

The compact login keeps the existing below-form slot and paints a photographed
snow perch there, preventing the penguin from walking on a portrait crop of open
water. Scene lighting tints the character; contact and diffuse shadows anchor
its feet. Its walking cycle remains 0.4 seconds, preserving the requested speed.
At night it rests longer. Reduced motion freezes the penguin and ambient effects.

Focusing the username field triggers a brief pause facing the form. The walker
receives only a focus boolean, never username or password text. Password entry
has no animation listener. Subtle cloud drift and water highlights are confined
to the landscape, away from the form. The Hasani Books logo and card retain their
layout; field contrast is stronger and the purple accents are softer.

Only the current age's walk/idle atlases and current photo are decoded. Quiet
poses use connected silhouette bounds to avoid adjacent sprite fragments. Image
loads are generation-checked and disposed on scene changes or close. Asset
failures never block sign-in. The former eight-view Blender assets are archived
in the renderer source and are no longer bundled.

Flutter tests cover all scene trails, cover projection, age stages, changing
rendered poses, reduced motion, username-only focus, compact adult rendering,
and safe scene changes. This feature requires the new web/client build; an old
Android installation cannot receive bundled artwork through a server-only change.
