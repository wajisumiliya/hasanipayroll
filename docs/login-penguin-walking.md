# Login penguin walking

After the server confirms a login egg has hatched, `LoginPenguinWalker` replaces
its fixed hatched image with an original articulated 3D-rendered animation. The
orange crown, ivory belly, slate-grey body and lime-green bill/feet are preserved.
The personal employee pet and branch crew are separate widgets.

The wide login follows the winding route marked in the supplied Friday evening
screenshot. Coordinates are normalised to the viewport and corners are rounded;
the yellow annotation itself is not displayed. The route is authored geometry,
not automatic detection of ice or water in a photograph. Background changes do
not perform new terrain recognition.

The character starts at the former egg location and turns through eight views.
It stays left of the sign-in card. Its size decreases into the distance and still
uses the existing day-by-day growth scale: 30% size at hatching, reaching full size
42 days later. A contact shadow anchors its feet to the scene. The compact mobile
login uses a smaller trail below the form so the character never covers inputs.

The sixteen changing poses per direction come from a jointed Blender character,
with a stance foot, lifted swing foot, body weight transfer, head counterbalance
and flipper movement. This is rendered animation, not real-time 3D and not a
translated still photograph. See `tools/penguin_walk/README.md` for regeneration.

The 0.4-second gait cycle (twice the original speed) advances in proportion to projected stride, viewport
size, depth and the current growth size. Towards/away movement is foreshortened
using the render camera, preventing the feet from sliding along the ground.
Pause/resume clamps elapsed time to avoid a sudden jump across the habitat.
Reduced-motion preferences stop travel and show a resting rendered pose.

Only the moving canvas repaints each frame. The eight atlas textures are decoded
once for the active walker and disposed when it closes. Assets can preload during
the final five egg minutes; an unavailable animation never blocks sign-in. This
feature requires the new web/client build; already-installed Android code cannot
load new bundled frames or movement logic through a server-only change.

Tests check route continuity and bounds, eight packaged 16-pose atlases, distinct
poses, changing rendered pixels during walking, and a frozen reduced-motion pose.
