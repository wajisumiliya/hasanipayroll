"""Author an original articulated 3D penguin; render its walk, not a photo warp.
Run: blender -b -t 4 --python tools/penguin_walk/render_walk.py -- --preview
No third-party character meshes or photographic textures are used.
"""
import bpy, math, os, sys, random, argparse
from mathutils import Vector

args = argparse.ArgumentParser()
args.add_argument('--preview', action='store_true')
args.add_argument('--output', default='/workspace/scratch/penguin-walk')
args = args.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
os.makedirs(args.output, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
random.seed(2310)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'; scene.cycles.device = 'CPU'; scene.cycles.samples = 64
scene.cycles.use_denoising = False
scene.render.resolution_x = 256; scene.render.resolution_y = 256
scene.render.resolution_percentage = 100; scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'; scene.render.image_settings.color_mode = 'RGBA'
scene.render.fps = 20
scene.world.color = (.16,.18,.22)
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'


def material(name, color, rough=.72, fluff=False):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    nodes=m.node_tree.nodes; shader=nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=rough
    if fluff:
        noise=nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=135
        noise.inputs['Roughness'].default_value=.78
        bump=nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.34; bump.inputs['Distance'].default_value=.035
        m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs['Normal'],shader.inputs['Normal'])
    return m
slate=material('soft slate down',(.075,.095,.115),fluff=True)
white=material('warm ivory down',(.78,.775,.72),fluff=True)
orange=material('orange crown down',(.95,.135,.003),fluff=True)
green=material('lime green bill and feet',(.40,.62,.045),.45)
darkgreen=material('bill seam',(.13,.22,.016),.52)
eye=material('black brown glossy eyes',(.012,.009,.007),.13)
rim=material('natural eye rim',(.13,.125,.11),.5)
claw=material('grey claws',(.12,.15,.15),.42)

# Smooth per-vertex colour masks avoid polygon-shaped belly/crown boundaries.
down_surface=slate.copy();down_surface.name='Continuous feather surface'
vc=down_surface.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='DownColor'
down_surface.node_tree.links.new(vc.outputs['Color'],down_surface.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
palette=[(.075,.095,.115),(.78,.775,.72),(.95,.135,.003)]


def empty(name, loc=(0,0,0), parent=None):
    obj=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(obj)
    obj.location=loc; obj.parent=parent; return obj
rig=empty('Penguin direction')
body=empty('Body weight shift',parent=rig)
head=empty('Head counterbalance',(0,-.005,1.96),body)

def sphere(name,loc,scale,mat,parent=None,segments=48):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=24,location=(0,0,0))
    o=bpy.context.object; o.name=name; o.parent=parent; o.location=loc; o.scale=scale
    o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def body_color(n):
    return 1 if n.y < -.30 and abs(n.x)<.78 and n.z>-.88 else 0

def head_color(n):
    crown=n.z>.25 and not(n.y<-.48 and abs(n.x)>.23 and n.z<.72)
    return 2 if crown else (1 if n.y<-.22 else 0)

def feathered(name,loc,scale,parent,color_fn,count):
    o=sphere(name,loc,scale,slate,parent)
    o.data.materials.clear();o.data.materials.append(down_surface)
    attribute=o.data.color_attributes.new(name='DownColor',type='FLOAT_COLOR',domain='CORNER')
    for index,loop in enumerate(o.data.loops):
        n=o.data.vertices[loop.vertex_index].co.normalized()
        attribute.data[index].color=(*palette[color_fn(n)],1)
    verts=[]; faces=[]; colors=[]
    for _ in range(count):
        z=random.uniform(-1,1);theta=random.uniform(0,math.tau);rr=math.sqrt(1-z*z)
        n=Vector((rr*math.cos(theta),rr*math.sin(theta),z))
        p=Vector((n.x*scale[0],n.y*scale[1],n.z*scale[2]))+Vector(loc)
        normal=Vector((n.x/scale[0],n.y/scale[1],n.z/scale[2])).normalized()
        down=Vector((0,0,-1)); tangent=(down-normal*down.dot(normal)).normalized()
        if tangent.length<.1:tangent=Vector((1,0,0))
        side=normal.cross(tangent).normalized()
        length=random.uniform(.026,.055); width=random.uniform(.0017,.0035)
        root=p+normal*.001
        tip=root+normal*length*.7+tangent*length*.6
        index=len(verts); verts.extend([root-side*width,root+side*width,tip])
        faces.append((index,index+1,index+2)); colors.append(color_fn(n))
    mesh=bpy.data.meshes.new(name+' individual down');mesh.from_pydata(verts,[],faces);mesh.update()
    down=bpy.data.objects.new(name+' fine down',mesh);bpy.context.collection.objects.link(down);down.parent=parent
    for m in [slate,white,orange]:mesh.materials.append(m)
    for i,p in enumerate(mesh.polygons):p.material_index=colors[i];p.use_smooth=True
    return o

feathered('Pear shaped torso',(0,0,.99),(.59,.425,.80),body,body_color,3200)
feathered('Rounded chick head',(0,0,0),(.43,.365,.43),head,head_color,2200)
sphere('Small tail',(0,.34,.39),(.15,.22,.12),slate,body)
for side in [-1,1]:
    sphere('Eye rim',(side*.18,-.330,.085),(.059,.012,.067),rim,head)
    sphere('Eye',(side*.18,-.341,.085),(.051,.011,.058),eye,head)

# Rounded tapered bill, with a visible lower seam and nostrils.
verts=[];faces=[];rings=[(-.32,.105,.052),(-.41,.13,.071),(-.54,.078,.045),(-.61,.014,.014)]
for y,w,h in rings:
    for i in range(12):
        a=i*math.tau/12;verts.append((math.sin(a)*w,y,-.07+math.cos(a)*h))
for j in range(len(rings)-1):
    for i in range(12):faces.append((j*12+i,j*12+(i+1)%12,(j+1)*12+(i+1)%12,(j+1)*12+i))
faces.extend([tuple(reversed(range(12))),tuple(range(36,48))])
mesh=bpy.data.meshes.new('tapered bill');mesh.from_pydata(verts,[],faces);mesh.materials.append(green)
bill=bpy.data.objects.new('Organic green bill',mesh);bpy.context.collection.objects.link(bill);bill.parent=head
for p in mesh.polygons:p.use_smooth=True
sub=bill.modifiers.new('rounded bill','SUBSURF');sub.levels=2
for side in [-1,1]:
    sphere('Nostril',(side*.051,-.454,-.011),(.011,.016,.006),darkgreen,head,24)
sphere('Lower bill seam',(0,-.485,-.094),(.086,.104,.006),darkgreen,head)

wings=[]; feet=[]
for side in [-1,1]:
    wing=empty('Left flipper' if side<0 else 'Right flipper',(side*.46,0,1.43),body)
    feathered('Tapered flipper',(side*.055,.006,-.30),(.112,.132,.48),wing,lambda n:1 if n.y<-.58 and n.x*side<-.1 else 0,700)
    wings.append((side,wing))
    foot=empty('Left foot' if side<0 else 'Right foot',(side*.19,0,.06),rig);feet.append((side,foot))
    sphere('Short ankle',(0,.015,.09),(.067,.062,.085),green,foot)
    sphere('Webbed foot',(0,-.095,.012),(.14,.20,.042),green,foot)
    for toe in [-1,0,1]:
        sphere('Toe',(toe*.087,-.22,.01),(.044,.12,.033),green,foot,32)
        sphere('Small claw',(toe*.087,-.326,.014),(.023,.047,.022),claw,foot,24)

# An articulated planted-foot gait: stance foot moves back as the body advances;
# swing foot lifts clear, moves forward, then lands before taking the weight.
def pose(phase):
    angle=phase*math.tau
    body.location.x=-.045*math.sin(angle)
    body.location.z=.026*(1-math.cos(2*angle))
    body.rotation_euler[1]=-.075*math.sin(angle)
    body.rotation_euler[0]=.025*math.sin(angle)
    head.rotation_euler[1]=.035*math.sin(angle)
    head.rotation_euler[0]=.018*math.sin(2*angle)
    for side,wing in wings:
        wing.rotation_euler[1]=side*(.10+.09*math.cos(angle+side*.8))
        wing.rotation_euler[0]=.10*math.sin(angle+side*math.pi/2)
    for side,foot in feet:
        p=(phase+(0 if side<0 else .5))%1
        if p<.5:
            t=p/.5;y=-.145+.29*t;z=.06;tilt=-.08*math.sin(math.pi*t)
        else:
            t=(p-.5)/.5;y=.145-.29*(.5-.5*math.cos(math.pi*t));z=.06+.15*math.sin(math.pi*t);tilt=.22*math.sin(math.pi*t)
        foot.location=(side*.19,y,z);foot.rotation_euler[0]=tilt

for frame in range(17):
    pose((frame%16)/16)
    for obj in [body,head]+[x[1] for x in wings+feet]:
        obj.keyframe_insert('location',frame=frame+1);obj.keyframe_insert('rotation_euler',frame=frame+1)
scene.frame_start=1;scene.frame_end=16
for obj in [body,head]+[x[1] for x in wings+feet]:
    if obj.animation_data:
        for curve in obj.animation_data.action.fcurves:
            for k in curve.keyframe_points:k.interpolation='LINEAR'

bpy.ops.object.camera_add(location=(0,-6.7,2.85));cam=bpy.context.object
cam.rotation_euler=(Vector((0,0,1.24))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=2.95;scene.camera=cam

def light(name,loc,energy,size):
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name
    o.data.energy=energy;o.data.shape='DISK';o.data.size=size
    o.rotation_euler=(Vector((0,0,1.2))-o.location).to_track_quat('-Z','Y').to_euler()
light('Soft daylight key',(-3,-4,5),380,4)
light('Soft sky fill',(3,-3,3),80,3)
light('Feather rim',(2,3,4),400,3)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.output,'penguin-walk.blend'))
if args.preview:
    scene.frame_set(5);rig.rotation_euler.z=math.pi/4
    scene.render.resolution_x=512;scene.render.resolution_y=512;scene.cycles.samples=96
    scene.render.filepath=os.path.join(args.output,'model-preview.png');bpy.ops.render.render(write_still=True)
else:
    # Each atlas is a 4x4 grid of independently rendered 3D poses, 256px per cell.
    # Assemble render buffers inside Blender; no photographic assets are edited.
    from array import array
    for direction in range(8):
        rig.rotation_euler.z=direction*math.pi/4
        pixels=array('f',[0.0])*(1024*1024*4)
        for frame in range(16):
            scene.frame_set(frame+1)
            os.makedirs(os.path.join(args.output,'frames'),exist_ok=True)
            scene.render.filepath=os.path.join(args.output,'frames',f'd{direction}_f{frame:02d}.png')
            bpy.ops.render.render(write_still=True)
            image=bpy.data.images.load(scene.render.filepath,check_existing=False)
            buf=array('f',[0.0])*(256*256*4);image.pixels.foreach_get(buf)
            col=frame%4;row=3-frame//4
            for y in range(256):
                dest=((row*256+y)*1024+col*256)*4
                pixels[dest:dest+256*4]=buf[y*256*4:(y+1)*256*4]
            bpy.data.images.remove(image)
            print('WALK_FRAME',direction,frame,flush=True)
        atlas=bpy.data.images.new('walk atlas',width=1024,height=1024,alpha=True)
        atlas.pixels.foreach_set(pixels);atlas.filepath_raw=os.path.join(args.output,f'walk_{direction}.png')
        atlas.file_format='PNG';atlas.save();bpy.data.images.remove(atlas)
    print('WALK_ATLASES_COMPLETE',flush=True)
