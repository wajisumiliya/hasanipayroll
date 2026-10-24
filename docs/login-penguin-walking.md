> Removed from the login screen in 1.0.28+35 at the user's request.
> The implementation notes below describe the archived login walker.
> Branch and employee dashboard penguins are unaffected.

# Login penguin walking

After server-confirmed hatching, the login uses photographic-style
penguin pose sheets. The login chick has dedicated natural-anatomy artwork;
young and adult stages share the branch family artwork. It is a frame animation,
not wildlife footage or real-time 3D. Baby, young and adult artwork changes at days 12 and 42;
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

Only the current age's walk/idle atlases and current photo are decoded. Walk and idle
poses use connected silhouette bounds and actual foot contact points to avoid
adjacent sprite fragments, floating feet and size changes when stopping. Image
loads are generation-checked and disposed on scene changes or close. Asset
failures never block sign-in. The former eight-view Blender assets are archived
in the renderer source and are no longer bundled.

Flutter tests cover all scene trails, cover projection, age stages, changing
rendered poses, reduced motion, username-only focus, compact adult rendering,
and safe scene changes. This feature requires the new web/client build; an old
Android installation cannot receive bundled artwork through a server-only change.

The revised chick (1.0.26+33) has smaller natural eyes, a narrower head,
scaly feet and irregular down feathers rather than smooth plush proportions.
Its new walking and quiet sheets are separate from the branch chick assets.

Color preservation (1.0.27+34): the detailed login chick retains the original
light silver-gray down, white cheek/belly and black crown, beak and feet.
The brown cast introduced with the anatomy revision is removed. Scene tinting
uses the original login lighting palette.
