"""Original metre-scale room01 watch. Run in the dedicated Blender session.
No avatar, skeletal action, or protected Golden file is touched.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

DEST = Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\room01-hero-clock-20261014')
scene = bpy.data.scenes.new('Room01ClockCraft')
bpy.context.window.scene = scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1.0
collection=bpy.data.collections.new('Room01ClockAsset')
scene.collection.children.link(collection)

def material(name, color, metal, roughness):
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=(*color,1)
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(*color,1)
    bsdf.inputs['Metallic'].default_value=metal
    bsdf.inputs['Roughness'].default_value=roughness
    return mat

brass=material('Clock_AgedBrass',(0.57,0.36,0.105),0.72,0.38)
enamel=material('Clock_MidnightEnamel',(0.017,0.031,0.046),0.16,0.56)
ivory=material('Clock_SignalInlay',(0.10,0.45,0.50),0.15,0.42)
signal_shader=ivory.node_tree.nodes.get('Principled BSDF')
signal_shader.inputs['Emission Color'].default_value=(0.0,0.36,0.40,1)
signal_shader.inputs['Emission Strength'].default_value=.1
scene['ivory_material']=ivory.name

def mesh_object(name, vertices, faces, mat):
    mesh=bpy.data.meshes.new(name+'Mesh')
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    collection.objects.link(obj)
    mesh.materials.append(mat)
    return obj

def lathe(name, profile, mat, segments=64):
    # Explicit radii/heights produce bevels and recesses in one continuous skin.
    vertices=[(r*math.sin(a*2*math.pi/segments),r*math.cos(a*2*math.pi/segments),z)
              for r,z in profile for a in range(segments)]
    faces=[]
    for level in range(len(profile)):
        nxt=(level+1)%len(profile)
        for a in range(segments):
            b=(a+1)%segments
            faces.append((level*segments+a,level*segments+b,nxt*segments+b,nxt*segments+a))
    return mesh_object(name,vertices,faces,mat)

body=lathe('WatchCase',[(.164,-.012),(.183,-.012),(.194,-.003),(.195,.008),
    (.189,.017),(.178,.020),(.173,.016),(.164,.016)],brass)
dial=lathe('ClockDial',[(.001,.013),(.170,.013),(.170,.017),(.001,.017)],enamel)
lid=lathe('PocketWatchLid',[(0,0),(.176,0),(.188,.0014),(.19,.00315),
    (.185,.0049),(.17,.00455),(.153,.00245),(0,.00245)],brass)
# Near-vertical lid leaves the dial clear from the actual top-facing camera.
hinge=Vector((0,.190,.021))
from mathutils import Matrix
rotation=Matrix.Rotation(math.radians(-85),4,'X')
for vertex in lid.data.vertices:
    vertex.co=hinge+rotation.to_3x3()@(vertex.co-Vector((0,.190,0)))

camera_data=bpy.data.cameras.new('ClockReviewCamera')
camera=bpy.data.objects.new('ClockReviewCamera',camera_data)
scene.collection.objects.link(camera)
camera.location=(0,-.69,.68)
target=Vector((0,.05,.08))
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'
camera_data.ortho_scale=.84
scene.camera=camera
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=960
scene.render.resolution_y=960
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('ClockReviewWorld')
scene.world.color=(.055,.055,.055)
for name,location,energy,size in [('ClockKey',(-.4,-.2,.65),45,.5),('ClockFill',(.4,.25,.5),16,.4)]:
    data=bpy.data.lights.new(name,'AREA')
    data.energy=energy
    data.shape='DISK'
    data.size=size
    light=bpy.data.objects.new(name,data)
    scene.collection.objects.link(light)
    light.location=location
    light.rotation_euler=(Vector((0,0,.03))-light.location).to_track_quat('-Z','Y').to_euler()
scene.view_settings.view_transform='AgX'
result={'scene':scene.name,'objects':[o.name for o in collection.objects],
        'dimensions_m':{o.name:list(o.dimensions) for o in collection.objects},
        'stage':'silhouette/proportion/depth/contact/camera-read; no final detail yet',
        'protected_previous_scene':'Scene; untouched'}
(DEST/'blockout-report.json').write_text(json.dumps(result,indent=2))
