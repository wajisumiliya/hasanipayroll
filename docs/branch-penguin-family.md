# Branch penguin family

After the existing branch server-clock reveal, the branch habitat shows exactly
four penguins: two adults, one juvenile, and one downy baby. The personal employee
pet, login animation, and public reveal dates are separate and unchanged here.
Before reveal, four golden eggs continue to show the branch countdown.

The family follows an 80-second continuous routine. One adult swims out and back,
walks up the shore, feeds the baby, then returns to the water's edge. The other
adult and juvenile move together on a gentle chase. The baby takes small steps
towards its feeding parent and stays on dry ice. Swimming is restricted to the
adult; the downy baby and young penguin never enter the water.

These are original articulated 3D renders, not wildlife video or a real-time 3D
simulation. Adult anatomy has a longer, sleeker torso and a smaller head than the
fluffy baby. The requested orange, slate, ivory and green character colors remain.
Actual joint poses animate feet, head, and flippers. Water clipping and expanding
wakes place the swimmer in the surface. Animation travel follows rendered stride
length; the routine uses the image's shoreline rather than terrain detection.
The adult's feeding bow and small fish represent feeding without graphic detail.

Six 768-pixel atlases add roughly 2.6 MB compressed. One decoded set is shared
between all four animals in a habitat; the baby reuses the login chick's two side
atlases. The canvas repaints without rebuilding the dashboard. Reduced motion
freezes the scene, decorative movement ignores taps, and images/ticker/listeners
are released with the widget. Scene load failure displays a recovery message.

Regenerate the original walk model first (see `tools/penguin_walk/README.md`), then:

```sh
blender -b -t 4 --python tools/penguin_family/render_family.py -- \
  --model /tmp/hasani-penguin-walk/penguin-walk.blend \
  --output assets/penguins/family
```

Use `--actions eat` to regenerate just the feeding poses. The Flutter tests cover
family count, movement continuity, terrain restrictions, all activity states,
server-controlled pre-hatch eggs, mobile layout, and reduced motion.
