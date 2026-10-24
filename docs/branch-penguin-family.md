# Branch penguin family

[Watch the complete habitat highlights](previews/complete-penguin-habitat.mp4).

The branch habitat contains exactly two adults, one juvenile and one downy baby.
It appears only after the existing branch server-clock hatch. Public reveal
metadata and employees' independent personal pets are unchanged.

## Completed behavior

The adults keep stable identities and share duties over a continuous 160-second
routine. Adult A fishes while B watches the children, then B fishes while A
watches. Each fishing trip has walking, gradual water entry, swimming, a return
onto the ice, eating its catch, rest and feather grooming. The second adult uses
a separate ice path behind the family. Both are home during reunions.

The children walk gradually between parents during the reunion instead of
jumping when duties switch. The youngster follows, briefly explores and plays,
and makes small head/eyelid and flipper gestures while standing. The baby takes
small real steps into a huddle by the caregiver's legs, looks up, briefly explores
and returns. A nearby parent remains on the ice throughout. Neither child swims.

All three age groups have quiet head and blink poses, interspersed with long
still pauses. The adults have a dedicated grooming sequence with the bill
turned into shoulder/flank feathers, rather than reusing an eating pose.
Foreground scaling, cool overcast lighting, small foot-contact shadows and soft
cast shadows ground them in the photographic-style landscape.

The waterline, wake and foot shadow change gradually over two-second entry and
exit sequences. Cloud texture drifts only in a faded sky region; mountains stay
fixed. Small moving reflection strokes are clipped to the open bay. A sparse
25-second simulated snow flurry fades in and out once per 180 scene seconds;
it is decorative polar weather, not a live weather report. Reduced motion
freezes travel, head gestures, breathing, clouds, reflections and snow together.

## Feeding

The fishing adult's returned catch is visible during its eating poses and
disappears as it swallows. **Feed fish** offers one additional silver herring to
the adult currently on caregiving duty, on whichever side it is staying.
That adult notices the fish for 1.2 seconds, approaches, bends down, opens/closes
its bill, swallows, then smoothly rejoins its own route. Fish orientation and
placement follow the adult's facing direction, with the fish head towards the
bill. The baby is not redirected into water or given a whole fish.

A meal keeps the selected adult's stable identity even if duties change while it
is feeding. Size-aware approach time is capped so it can finish and rejoin the
ice path before that adult's next water entry. Food is placed on clear foreground ice away from the youngster. Approach
footsteps use horizontal and depth travel, including near-vertical approaches.
The other family members continue their activities. The button stays disabled through the sequence, preventing
stacked fish. Accessible status changes announce notice, approach, eating and
return. Reduced motion completes an offered meal immediately with a result count.

The count tracks offered meals in the current scene/session, not wild catches,
backend hunger or employee data. It resets for a different branch/controller.
No payroll, notification or adoption records are changed.

## Assets and rendering

Ten generated PNG pose sheets contain sixteen poses each: adult walk, swim,
entry, eat, idle and preen; juvenile walk and idle; baby walk and idle. These are
generated photographic-style animation frames, not recorded wildlife footage or
a real-time 3D simulation. Walking uses changing leg/flipper poses rather than a
translated rigid photo. Direction changes mirror symmetric side/three-quarter
poses. Source PNGs are kept unmodified under `assets/penguins/family/`.

Entry, idle and grooming sheets have a one-time connected-silhouette scan for
actual bounds, masks, foot anchors and torso rows. This handles unequal spacing,
excludes neighboring fragments even where bounding boxes overlap, and keeps feet
planted while heads turn. Swim poses anchor to their torso row at the waterline.
Each decoded sheet is shared between the scene's animals; images and the ticker
are released with the widget. Canvas redraws are limited to about 30fps without
discarding elapsed scene time. The rest of the dashboard does not rebuild for
every frame.

The original Blender herring can be regenerated with:

```sh
blender -b -t 4 --python tools/penguin_family/render_herring.py -- \
  --output assets/penguins/family/herring.png
```

`render_family.py` is the legacy rounded-model source, not the generator for the
current photographic-style poses.

## Verification

Tests cover exact family count, both adults' duties over two cycles, continuous
handover paths, nearby adult supervision, dry-ice restrictions, swimming direction,
continuous immersion, isolated sprite geometry, changing poses, grooming and quiet
motions, sparse weather fades, mobile layout, reduced motion, server-controlled
hatching, one-click feeding, duplicate-tap blocking, both caregivers and feeding
across duty boundaries at mobile, desktop and wide-screen sizes.
