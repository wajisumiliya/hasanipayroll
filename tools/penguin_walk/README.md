# Original 3D walking penguin

`render_walk.py` authors the character from original meshes, procedural down,
vertex colour masks and articulated object pivots in Blender. No stock penguin
mesh, photographed body texture, or image-warp animation is used.

The walk has a double-contact landing, a planted stance phase, a lifted swing
phase, side-to-side weight transfer, head counterbalance and flipper motion.
Eight rendered camera headings make turns show side and rear anatomy, rather
than mirroring a front-facing picture. Each heading has sixteen poses at 20 fps
(a 0.8-second gait cycle).

Regenerate using Blender 4.3 or newer:

```sh
blender -b -t 4 --python tools/penguin_walk/render_walk.py -- --output /tmp/hasani-penguin-walk
cp /tmp/hasani-penguin-walk/walk_*.png assets/penguins/walk/
```

Use `--preview` for a single large test render. The source `.blend`, individual
render frames and eight 4-by-4 animation atlases are written to the output folder.
The app ships only the eight atlas PNGs, not Blender or a web/Android 3D plugin.

The Flutter canvas displays these rendered poses. It matches projected travel to
stride length and the original render camera's ground foreshortening. Thus a foot
in its stance phase moves backwards relative to the body while the body moves
forwards over the habitat, instead of sliding a rigid still image around.
