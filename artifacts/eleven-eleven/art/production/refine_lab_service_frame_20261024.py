"""Reassign complete measured frame components; keep all vertices and UVs."""
import bpy,json,hashlib,struct
from pathlib import Path
from mathutils import Vector
APP=Path(__file__).resolve().parents[2]
P=APP/'art/production/lab-modular-refinement-20261024'
SOURCE=P/'clinical-modular-perimeter-v3-before-composition.blend'
TARGET=APP/'godot/assets/environments/lab_clinical_cp45/clinical_service_frame_clean.glb'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
obj=bpy.data.objects['ClinicalCleanFrameAndGallery']
assert obj.type=='MESH'
def geometry_digest():
    return hashlib.sha256(b''.join(struct.pack('<fff',*v.co) for v in obj.data.vertices)).hexdigest()
before=geometry_digest()
links=[[] for _ in obj.data.vertices]
for edge in obj.data.edges:
    a,b=edge.vertices;links[a].append(b);links[b].append(a)
components=[];lookup={};seen=set()
for seed in range(len(links)):
    if seed in seen:continue
    todo=[seed];seen.add(seed);indices=[]
    while todo:
        current=todo.pop();indices.append(current)
        for other in links[current]:
            if other not in seen:seen.add(other);todo.append(other)
    number=len(components)
    for vertex in indices:lookup[vertex]=number
    points=[obj.matrix_world@obj.data.vertices[v].co for v in indices]
    # BlenderXYZ -> native GodotXYZ.
    points=[Vector((v.x,v.z,-v.y)) for v in points]
    lo=Vector(tuple(min(v[i] for v in points) for i in range(3)))
    hi=Vector(tuple(max(v[i] for v in points) for i in range(3)))
    components.append({'centre':(lo+hi)*.5,'size':hi-lo})
def material(name,color):
    result=bpy.data.materials.new(name);result.use_nodes=True
    shader=result.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Metallic'].default_value=.18
    shader.inputs['Roughness'].default_value=.65
    obj.data.materials.append(result)
    return len(obj.data.materials)-1
header=material('ClinicalServiceBlueHeader',(.24,.31,.40))
porcelain=material('ClinicalCentralPorcelain',(.45,.49,.53))
targets=[('SouthDoorHeaderLower',(0,4.88,.01),(2.60,3.36,.06),header),('SouthDoorHeaderUpper',(0,8.26,.01),(2.60,3.32,.06),header),('ClockUnderPanel',(0,3.38,-40.01),(10.80,.68,.06),porcelain),('ClockUpperPanel',(0,6.88,-40.01),(10.80,1.0,.06),porcelain),('NorthUpperInfill',(0,8.62,-40.01),(11.68,2.20,.06),porcelain)]
for side in [-1,1]:
    targets.extend([('NorthBaySidePanel'+str(side),(side*3.4,1.48,-40.01),(4.6,2.96,.06),porcelain),('NorthBayUpperPier'+str(side),(side*5.65,4.95,-39.99),(.44,9.8,.08),porcelain)])
changes={};records=[]
for name,centre,size,index in targets:
    matches=[i for i,c in enumerate(components) if (c['centre']-Vector(centre)).length<.004 and (c['size']-Vector(size)).length<.008]
    assert len(matches)==1,(name,matches)
    changes[matches[0]]=index
    records.append({'part':name,'centre':centre,'size':size,'material':obj.data.materials[index].name})
for polygon in obj.data.polygons:
    component=lookup[polygon.vertices[0]]
    assert all(lookup[v]==component for v in polygon.vertices)
    if component in changes:polygon.material_index=changes[component]
assert geometry_digest()==before,'Geometry moved during material refinement'
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
bpy.ops.wm.save_as_mainfile(filepath=str(P/'clinical-service-frame-composition-v4.blend'))
bpy.ops.export_scene.gltf(filepath=str(TARGET),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
(P/'frame-composition-refinement.json').write_text(json.dumps({'source':str(SOURCE.relative_to(APP)).replace('\\','/'),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'output':str(TARGET.relative_to(APP)).replace('\\','/'),'output_sha256':hashlib.sha256(TARGET.read_bytes()).hexdigest(),'geometry_digest_before':before,'geometry_digest_after':geometry_digest(),'whole_components_reassigned':records,'scope':'Nine whole authored components,material assignment only. No changed vertex,UV,door clearance,collider,clock or native gameplay.'},indent=2)+'\n')
print('FRAME_COMPOSITION_REFINED_WHOLE_COMPONENTS',len(records))
