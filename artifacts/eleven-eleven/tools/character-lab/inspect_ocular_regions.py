"""Read-only color/texture diagnosis of the generated eye surfaces.

The tiny detached white components are not the complete eye opening. Establish
the surrounding textured surface before authoring any semantic eyelid mask.
"""
from collections import defaultdict
import hashlib
import json
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

APP = Path(__file__).resolve().parents[2]
prod = APP/'art/production/echo-school-rebuild-20261029'
out = prod/'face/intake-20261102'
intake = json.loads((out/'topology.json').read_text())
assert hashlib.sha256((prod/'source/echo-school-rig-metric.glb').read_bytes()).hexdigest() == intake['source_sha256']
bpy.ops.wm.open_mainfile(filepath=str(out/'head-topology-diagnostic.blend'))
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
mesh.modifiers['DiagnosticWireOnly'].show_render = False
components = json.loads((out/'component-vertices.json').read_text())
ids = {index: cid for cid,indices in enumerate(components) for index in indices}
points = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]
images = [node.image for mat in mesh.data.materials if mat and mat.use_nodes
          for node in mat.node_tree.nodes if node.type == 'TEX_IMAGE' and node.image
          and 'base' in node.image.name.lower()]
if not images:
    images = [node.image for mat in mesh.data.materials if mat and mat.use_nodes
              for node in mat.node_tree.nodes if node.type == 'TEX_IMAGE' and node.image]
assert images
texture = images[0]
print('OCULAR_TEXTURE',texture.name,tuple(texture.size))
pixels = np.empty(len(texture.pixels),dtype=np.float32)
texture.pixels.foreach_get(pixels)
pixels = pixels.reshape(texture.size[1],texture.size[0],4)
uv = mesh.data.uv_layers.active.data
eyes = {side:sum((points[i] for cid in cids for i in components[cid]),Vector())/sum(len(components[cid]) for cid in cids)
        for side,cids in [('negative_x',[26,30]),('positive_x',[27,31])]}
attribute = mesh.data.color_attributes.new(name='OcularSurfaceDiagnosis',type='FLOAT_COLOR',domain='CORNER')
rows = []
for polygon in mesh.data.polygons:
    center = sum((points[i] for i in polygon.vertices),Vector())/len(polygon.vertices)
    eye = min(eyes,key=lambda side:(center-eyes[side]).length)
    distance = (center-eyes[eye]).length
    tex_uv = sum((uv[i].uv for i in polygon.loop_indices),Vector((0,0)))/len(polygon.loop_indices)
    rgb = pixels[int(tex_uv.y*(texture.size[1]-1))%texture.size[1],int(tex_uv.x*(texture.size[0]-1))%texture.size[0],:3]
    cid = ids[polygon.vertices[0]]
    near = distance < .026
    candidate = near and cid == 0 and float(rgb[0]-rgb[2]) < .035
    color = (.45,.47,.50)
    if candidate: color = (.05,.95,.85)
    if cid in [26,27]: color = (.15,.4,1)
    if cid in [30,31]: color = (1,.35,.05)
    for loop in polygon.loop_indices: attribute.data[loop].color = (*color,1)
    if near:
        rows.append({'polygon':polygon.index,'component':cid,'eye':eye,'center':list(center),
                     'rgb':list(map(float,rgb)),'blue_gray_candidate':candidate})
mesh.data.color_attributes.active_color = attribute
scene = bpy.context.scene
scene.display.shading.color_type = 'VERTEX'
camera = scene.camera
center = sum(eyes.values(),Vector())/2
camera.data.ortho_scale = .14
for view,offset in [('front',(0,-3,0)),('threequarter',(1.5,-3,0)),('reverse-threequarter',(-1.5,-3,0))]:
    camera.location = center+Vector(offset)
    camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str(out/f'ocular-regions-{view}.png')
    bpy.ops.render.render(write_still=True)
(out/'ocular-regions.json').write_text(json.dumps({'status':'TEXTURE_DIAGNOSIS_NOT_A_DEFORMATION_MASK',
    'texture':texture.name,'source_sha256':intake['source_sha256'],'eyes':{key:list(point) for key,point in eyes.items()},
    'method':'Existing separate iris/sclera centers seed a read-only26mm diagnostic neighborhood;texture blue-gray classification only. No facial edits or approved semantic indices.',
    'nearby_polygons':rows},indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'ocular-surface-diagnostic.blend'))
print('OCULAR_REGIONS',len(rows),sum(row['blue_gray_candidate'] for row in rows))
