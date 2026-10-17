"""Original bevelled archival frame; keeps the existing non-Canon emulsion."""
import bpy, bmesh, json, math
from pathlib import Path
from mathutils import Vector
dest=Path(r'C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\art\production\room01-hero-clock-20261014')
scene=bpy.data.scenes.new('Room01PersonalTraceCraft')
bpy.context.window.scene=scene
collection=bpy.data.collections.new('Room01TraceAsset')
scene.collection.children.link(collection)
scene.unit_settings.system='METRIC'

def material(name,color,metal,rough):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    mat.diffuse_color=(*color,1)
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Metallic'].default_value=metal
    shader.inputs['Roughness'].default_value=rough
    return mat

slate=material('Trace_ArchiveSlate',(.035,.051,.068),.35,.58)
brass=material('Trace_AgedInnerBrass',(.42,.30,.12),.65,.48)

def rectangle(x,y,chamfer):
    return [(-x+chamfer,-y),(x-chamfer,-y),(x,-y+chamfer),(x,y-chamfer),
            (x-chamfer,y),(-x+chamfer,y),(-x,y-chamfer),(-x,-y+chamfer)]

def loft(name,profiles,mat):
    vertices=[(x,y,z) for rx,ry,c,z in profiles for x,y in rectangle(rx,ry,c)]
    faces=[(layer*8+k,layer*8+(k+1)%8,((layer+1)%len(profiles))*8+(k+1)%8,((layer+1)%len(profiles))*8+k)
           for layer in range(len(profiles)) for k in range(8)]
    mesh=bpy.data.meshes.new(name+'Mesh');mesh.from_pydata(vertices,[],faces);mesh.update()
    item=bpy.data.objects.new(name,mesh);collection.objects.link(item);mesh.materials.append(mat)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    return item

frame=loft('PhotoFrameHero',[(.43,.31,.016,-.0275),(.43,.31,.016,.019),
    (.419,.299,.012,.0275),(.333,.233,.007,.0275),(.325,.225,.006,.020),
    (.325,.225,.006,-.0275)],slate)
inner=loft('TraceInnerInlay',[(.337,.237,.007,.0277),(.339,.239,.007,.0277),
    (.339,.239,.007,.0284),(.337,.237,.007,.0284)],brass)

camera_data=bpy.data.cameras.new('TraceReviewCamera')
camera=bpy.data.objects.new('TraceReviewCamera',camera_data);scene.collection.objects.link(camera)
camera.location=(.25,-.75,1.35);camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO';camera_data.ortho_scale=1.10;scene.camera=camera
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('TraceReviewWorld');scene.world.color=(.035,.035,.035)
light_data=bpy.data.lights.new('TraceKey','AREA');light_data.energy=40;light_data.size=1.2
light=bpy.data.objects.new('TraceKey',light_data);scene.collection.objects.link(light)
light.location=(-.4,-.5,1.2);light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
scene.view_settings.view_transform='AgX'
result={'stage':'silhouette/proportion/contact/camera-read; frame ring replaces solid plate',
        'dimensions_m':[.86,.62,.055], 'opening_m':[.65,.45],
        'kept_runtime_trace_m':[.64,.44],'trace_plane_height_m':.031,
        'canon':'No replacement memory image or invented person; runtime emulsion remains unchanged'}
(dest/'frame-blockout-report.json').write_text(json.dumps(result,indent=2))
