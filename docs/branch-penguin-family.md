# Branch penguin family

[Watch the 30-second natural family routine preview](previews/natural-penguin-family.mp4).

After the existing server-clock reveal, the branch habitat shows exactly four
penguins: two adults, one juvenile, and one downy baby. The public reveal clock
and employees' separate pet adoption are unchanged by this visual revision.
Before reveal, four golden eggs continue to show the branch countdown.

The family follows an 80-second routine with long genuine pauses between short
walks. One adult watches the family, walks to the shore, swims out and back, then
returns to feed and rest. The caregiver stays on dry ice, taking just a few steps
before stopping again to observe, rest, or make a brief beak-down grooming gesture.
The youngster follows after three seconds and explores a short distance before
returning; the baby follows after two seconds and stays beside its caregiver.
The caregiver is stationary for more than two thirds of its routine. All paths
remain continuous through the loop, and the animals have distinct timings.

Foreground animals render larger than animals near the distant waterline.
Three soft shadow layers place weight under the feet and a faint cast on the
snow. A subtle cool lighting tint matches the overcast scene. Resting animals
have barely perceptible breathing; reduced motion freezes this as well as travel.
Grooming uses the initial beak-down poses of the existing adult animation rather
than introducing another asset set. The feeding spot is near the caregiver,
keeping the baby close and leaving space between the adults.

## Photoreal assets

The old rounded orange-capped models are replaced by generated photoreal emperor
penguin animation atlases: natural black/white/amber adults, a grey-throated
juvenile, and a fluffy silver-grey chick with white cheeks and a dark cap. Five
4-by-4 PNG atlases contain sixteen distinct poses each: adult walk, swim and eat,
juvenile walk, and baby walk. The actual pixels are generated wildlife-style
artwork, not recorded wildlife footage or a real-time 3D wildlife simulation.
Walking uses changing leg/flipper poses, rather than translating a rigid photo.
Direction changes mirror these symmetric side/three-quarter poses.

The photographic-style coastline and atlases were created with the image
creation tool. Source PNGs are retained unmodified in `assets/penguins/family/`.
The painter handles rectangular cells, preserves image proportions, and anchors
swimming frames by their opaque torso row so changing flipper extents do not
move the body above or below the waterline. Clipping, ripples, and snow contact
shadows ground the animals. `render_family.py` is the legacy version's mesh
source; it does not regenerate the current photoreal atlases.

The separate herring is an original Blender mesh and can be regenerated:

```sh
blender -b -t 4 --python tools/penguin_family/render_herring.py -- \
  --output assets/penguins/family/herring.png
```

## Feed fish

After hatch and asset loading, the **Feed fish** button tosses one visible silver
herring onto the ice. The adult already on dry ice approaches it at a size-aware
walking speed, bends down, opens/closes its bill, swallows the fish, then smoothly
rejoins its normal route. The fish disappears during swallowing. The other three
animals continue their activities. Feeding never redirects the baby into water.

The button stays disabled until this sequence finishes, preventing stacked fish
and overlapping meals. A live accessible status announces the result. With
reduced motion, feeding completes immediately with the same visible count and
no animated travel. The count belongs to the current scene/session; no backend
pet hunger, payroll, notification, or employee records are changed. It resets
when a different branch/controller is supplied.

One decoded atlas set is shared by all animals in a habitat and released when
the widget is disposed. The canvas repaints independently of the dashboard.
Tests cover continuous routes, exact family count, terrain restrictions, reveal
behavior, mobile layout, reduced motion, one-click feeding and blocked repeated
clicks, swallowing timing, and a continuous return to the family route.
