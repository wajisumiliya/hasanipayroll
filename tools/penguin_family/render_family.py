"""Render original articulated family actions. Run after render_walk.py.
blender -b -t 4 --python tools/penguin_family/render_family.py -- \
  --model /tmp/penguin-walk/penguin-walk.blend --output assets/penguins/family
"""
import bpy, math, os, sys, argparse
from array import array
p=argparse.ArgumentParser();p.add_argument('--model',required=True);p.add_argument('--output',required=True);p.add_argument('--actions',nargs='+',default=['walk','swim','eat'])
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);os.makedirs(a.output,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=a.model)
s=bpy.context.scene;s.cycles.samples=32;s.render.resolution_x=192;s.render.resolution_y=192
rig=bpy.data.objects['Penguin direction'];body=bpy.data.objects['Body weight shift'];head=bpy.data.objects['Head counterbalance']
wings=[bpy.data.objects[n] for n in ['Left flipper','Right flipper']]
feet=[bpy.data.objects[n] for n in ['Left foot','Right foot']]
for o in [rig,body,head]+wings+feet:o.animation_data_clear()
# Adults have a longer torso, smaller head, and sleeker feather silhouette.
body.scale=(.88,.9,1.03);head.scale=(.78,.8,.82);head.location.z=2.02
for o in bpy.data.objects:
    if 'fine down' in o.name:o.hide_render=True
# Lateral eye placement follows the curved cheek so profiles retain visible eyes.
for o in bpy.data.objects:
    if o.name.startswith('Eye'):
        side=-1 if o.location.x < 0 else 1
        o.location.x=side*.35;o.location.y=-.215
        o.rotation_euler.z=side*.9
s.camera.data.ortho_scale=3.15

def pose(action,phase):
    t=phase*math.tau
    body.location=(0,0,0);body.rotation_euler=(0,0,0)
    head.rotation_euler=(0,0,0)
    for i,(wing,foot) in enumerate(zip(wings,feet)):
        side=-1 if i==0 else 1
        wing.rotation_euler=(0,side*.1,0);foot.location=(side*.19,0,.06);foot.rotation_euler=(0,0,0)
        if action=='walk':
            q=(phase+i*.5)%1
            if q<.5:y=-.145+.29*q*2;z=.06;tilt=0
            else:
                u=(q-.5)*2;y=.145-.29*(.5-.5*math.cos(math.pi*u));z=.06+.15*math.sin(math.pi*u);tilt=.22*math.sin(math.pi*u)
            foot.location=(side*.19,y,z);foot.rotation_euler.x=tilt
            wing.rotation_euler.y=side*(.1+.09*math.cos(t+side*.8))
        elif action=='swim':
            wing.rotation_euler.y=side*(.65+.55*math.sin(t))
            wing.rotation_euler.x=.25*math.cos(t)
            foot.rotation_euler.x=-.55+.15*math.sin(t+i*math.pi)
        elif action=='eat':
            head.rotation_euler.x=.30+.36*(.5-.5*math.cos(t))
            head.location.z=1.96-.04*(.5-.5*math.cos(t))
            body.location.z=.08
            wing.rotation_euler.y=side*(.1+.025*math.sin(t))
    if action=='walk':
        body.location.x=-.045*math.sin(t);body.location.z=.026*(1-math.cos(2*t));body.rotation_euler.y=-.075*math.sin(t)
        head.rotation_euler.y=.035*math.sin(t)
    elif action=='swim':
        # Actual forward lean with flipper propulsion; not a rotated still.
        body.rotation_euler.x=1.10;body.location=(0,.58,.40)
        head.rotation_euler.x=-.45;head.location.z=2.02
        for foot in feet:foot.location.y=.70;foot.location.z=.32
    else:body.rotation_euler.x=.80+.10*math.sin(t)

for action in a.actions:
    s.camera.data.ortho_scale=4.1 if action=='eat' else 3.8 if action=='swim' else 3.15
    for direction in [2,6]:
        rig.rotation_euler.z=direction*math.pi/4
        pixels=array('f',[0.0])*(768*768*4)
        for frame in range(16):
            pose(action,frame/16)
            s.render.filepath=os.path.join(a.output,'frame.png');bpy.ops.render.render(write_still=True)
            im=bpy.data.images.load(s.render.filepath,check_existing=False);buf=array('f',[0.0])*(192*192*4);im.pixels.foreach_get(buf)
            for y in range(192):
                dest=(((3-frame//4)*192+y)*768+(frame%4)*192)*4
                pixels[dest:dest+768]=buf[y*768:(y+1)*768]
            bpy.data.images.remove(im)
        atlas=bpy.data.images.new('family atlas',width=768,height=768,alpha=True);atlas.pixels.foreach_set(pixels)
        atlas.filepath_raw=os.path.join(a.output,f'{action}_{direction}.png');atlas.file_format='PNG';atlas.save();bpy.data.images.remove(atlas)
        print('FAMILY_ATLAS',action,direction,flush=True)
os.remove(os.path.join(a.output,'frame.png'))
print('FAMILY_COMPLETE',flush=True)
