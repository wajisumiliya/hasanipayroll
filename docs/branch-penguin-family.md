# Branch penguin family

[Watch the 22-second click-to-feed preview](previews/photoreal-penguin-feeding.mp4).

After the existing server-clock reveal, the branch habitat shows exactly four
penguins: two adults, one juvenile, and one downy baby. The public reveal clock
and employees' separate pet adoption are unchanged by this visual revision.
Before reveal, four golden eggs continue to show the branch countdown.

The family follows an 80-second routine. One adult swims out and back, walks up
the shore, feeds the baby, then returns to the water's edge. The other adult and
juvenile move together on a gentle chase. The baby takes little steps towards
its feeding parent and stays on the ice. Only the adult enters the water.

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
