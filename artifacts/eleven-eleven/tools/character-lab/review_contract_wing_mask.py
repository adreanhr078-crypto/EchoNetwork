"""Preview a topology-bound wing selection before any weight authoring."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Vector
app=Path(__file__).resolve().parents[2]
out=app/'art/production/echo-contract-rebuild-20261101/work/wing-intake'
data=json.loads((out/'topology.json').read_text())
source=out.parent.parent/'source/contract-rig4k.glb'
assert hashlib.sha256(source.read_bytes()).hexdigest()==data['source_sha256']
groups=json.loads((out/'component-vertices.json').read_text())
# Component 1 is the large blue wing actually inspected from the back.
# Isolated feather islands lie behind the body (body max Y=-0.2058).
selected=[c['id'] for c in data['components'] if c['id']==1 or (c['low'][0]>0 and c['low'][2]>.34 and c['high'][1]>-.19)]
vertices=sorted(v for i in selected for v in groups[i])
selected_set=set(vertices)
bpy.ops.wm.open_mainfile(filepath=str(out/'diagnostic-components.blend'))
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
attribute=mesh.data.color_attributes['DiagnosticComponents']
for loop in mesh.data.loops:
    attribute.data[loop.index].color=(1,.08,.04,1) if loop.vertex_index in selected_set else (.35,.4,.45,1)
scene=bpy.context.scene
scene.display.shading.color_type='VERTEX'
low,high=Vector(data['bounds']['low']),Vector(data['bounds']['high'])
center=(low+high)*.5
for name,direction in [('front',(0,-4,0)),('back',(0,4,0)),('side',(4,0,0))]:
    scene.camera.location=center+Vector(direction)
    scene.camera.rotation_euler=(center-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/('wing-mask-'+name+'.png'))
    bpy.ops.render.render(write_still=True)
result={'status':'CAPTURED_PENDING_SEMANTIC_REVIEW','source_sha256':data['source_sha256'],'component_ids':selected,'vertex_indices':vertices,'vertex_count':len(vertices),'scope':'Diagnostic selection only;no geometry/weights/texture changes'}
(out/'wing-mask.json').write_text(json.dumps(result)+'\n')
print('WING_MASK',len(selected),len(vertices))
