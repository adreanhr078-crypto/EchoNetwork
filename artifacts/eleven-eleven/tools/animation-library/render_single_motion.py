import bpy,json,math,sys,argparse
from pathlib import Path
from mathutils import Vector,Quaternion

app=Path('C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven')
parser=argparse.ArgumentParser()
parser.add_argument('--case',type=Path,required=True)
parser.add_argument('--phase',choices=['source','comparison'],required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
out=args.case.resolve();mode=args.phase
sys.path.insert(0,str(app/'tools/animation-library'))
from golden_reference import verify,guard_output
verify();guard_output(out)
bpy.ops.wm.open_mainfile(filepath=str(out/('source-inspection.blend' if mode=='source' else 'single-motion.blend')))
d=json.loads((out/'diagnosis.json').read_text())
source=bpy.data.objects[d['source_rig']]
mapping=d['mapping_and_local_axes']
align=Quaternion((0,0,1),math.radians(d['alignment_yaw_degrees']))
ratio=d['leg_length_ratio']
sr=(source.matrix_world @ source.data.bones[mapping['hips']['source']].matrix_local).translation
target=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE' and o!=source)
tr=(target.matrix_world @ target.data.bones[mapping['hips']['target']].matrix_local).translation
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        belongs=any(m.type=='ARMATURE' and m.object==target for m in o.modifiers)
        o.hide_render=not belongs or mode=='source'
if mode!='source':
    top=target
    while top.parent:top=top.parent
    top_location=top.location.copy()
material=bpy.data.materials.new('source-rig')
material.diffuse_color=(.15,.65,.95,1)
rods={}
for k in mapping:
    parent=source.data.bones[mapping[k]['source']].parent
    if k != 'hips' and parent and parent.name in {v['source'] for v in mapping.values()}:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=.012,depth=1)
        o=bpy.context.object;o.data.materials.append(material)
        rods[k]=(o,parent.name)
bpy.ops.object.camera_add()
camera=bpy.context.object
bpy.context.scene.camera=camera
camera.data.type='ORTHO';camera.data.ortho_scale=4.5
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.display.shading.background_type='WORLD'
if scene.world is None:scene.world=bpy.data.worlds.new('Review World')
scene.world.color=(.06,.07,.09)
scene.render.resolution_x=1200;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
dest=out/(mode+'-frames');dest.mkdir(exist_ok=True)
for view,offset in [('back',Vector((0,-5,0))),('side',Vector((5,0,0)))]:
    separation=Vector((1.1,0,0)) if view=='back' else Vector((0,1.1,0))
    if mode!='source':top.location=top_location+separation
    count=d['source_metrics']['samples']
    indices=range(count) if mode!='source' else sorted(set(round(j*(count-1)/8) for j in range(9)))
    for i in indices:
        scene.frame_set(i+1 if mode=='source' else i)
        # Source original action is sampled at its own frame range, independent
        # of target bake frame numbers. No source curve is edited.
        if mode!='source':
            # Evaluate source through cached inspection using its original keys:
            scene.frame_set(i+1)
            source_points={k:(source.matrix_world @ source.pose.bones[v['source']].matrix).translation.copy() for k,v in mapping.items()}
            scene.frame_set(i)
        else:
            source_points={k:(source.matrix_world @ source.pose.bones[v['source']].matrix).translation.copy() for k,v in mapping.items()}
        points={mapping[k]['source']:tr+(align @ (p-sr))*ratio-(separation if mode!='source' else Vector()) for k,p in source_points.items()}
        for k,(o,parent) in rods.items():
            a,b=points[parent],points[mapping[k]['source']]
            o.location=(a+b)/2;o.scale.z=(b-a).length
            o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
        hip=tr+(align @ (source_points['hips']-sr))*ratio
        center=Vector((hip.x,hip.y,1.0))
        camera.location=center+offset
        camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(dest/f'{view}-{i:04}.png')
        bpy.ops.render.render(write_still=True)
verify()
print('RENDER_SINGLE_MOTION '+mode)
