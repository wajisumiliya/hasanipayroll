"""Original 3D silver herring for the branch feed interaction.
blender -b -t 4 --python tools/penguin_family/render_herring.py -- --output assets/penguins/family/herring.png
"""
import bpy, math, os, sys, argparse
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=96;s.cycles.use_denoising=False
s.render.resolution_x=256;s.render.resolution_y=256;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=True
s.world.color=(.22,.27,.34);s.view_settings.view_transform='AgX'
def material(name,c,metal=0,rough=.4):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;b=n.get('Principled BSDF');b.inputs['Base Color'].default_value=(*c,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=rough
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=180
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.2;bump.inputs['Distance'].default_value=.007;m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],b.inputs['Normal']);return m
silver=material('silver herring scales',(.47,.61,.67),.65,.25);blue=material('blue dorsal scales',(.07,.18,.24),.5,.3);black=material('herring cornea',(.004,.008,.012),0,.1)
def uv(loc,scale,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=32);o=bpy.context.object;o.location=loc;o.scale=scale;o.data.materials.append(m)
 for q in o.data.polygons:q.use_smooth=True
uv((0,0,0),(.43,.075,.105),silver);uv((0,.018,.05),(.40,.06,.05),blue);uv((.32,-.074,.03),(.014,.009,.014),black)
mesh=bpy.data.meshes.new('forked herring tail');mesh.from_pydata([(-.37,0,0),(-.62,0,.14),(-.57,0,0),(-.62,0,-.13)],[],[(0,1,2),(0,2,3)]);mesh.materials.append(silver);o=bpy.data.objects.new('forked tail fin',mesh);bpy.context.collection.objects.link(o)
bpy.ops.object.camera_add(location=(0,-6.7,.1));cam=bpy.context.object;cam.rotation_euler=(Vector((-.08,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.3;s.camera=cam
for loc,energy in [((-3,-4,6),500),((4,-1,3),150),((2,4,5),400)]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=energy;l.data.size=4;l.rotation_euler=(-l.location).to_track_quat('-Z','Y').to_euler()
os.makedirs(os.path.dirname(a.output),exist_ok=True);s.render.filepath=a.output;bpy.ops.render.render(write_still=True)
