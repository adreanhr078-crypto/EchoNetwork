"""Blender-only installation/secondary-chain smoke test; never opens Echo assets."""
import bpy
import hashlib
import importlib
import json
import math
from pathlib import Path
from mathutils import Vector

app=Path(__file__).resolve().parents[2]
out=app/'.tmp/echo-character-lab/physics-tools'
out.mkdir(exist_ok=True)
module='bl_ext.user_default.wiggle_bones'
assert module in bpy.context.preferences.addons, 'Extension did not persist into a fresh lab process'
assert str(app/'.tmp/echo-character-lab/blender-profile') in bpy.utils.user_resource('CONFIG')
core=importlib.import_module(module+'.wiggle_core')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.object.armature_add()
rig=bpy.context.object
rig.name='DisposablePhysicsProbe'
bpy.ops.object.mode_set(mode='EDIT')
body=rig.data.edit_bones[0]
body.name='ProtectedBody'
body.head=(0,0,1)
body.tail=(0,0,1.2)
parent=body
for i in range(3):
    bone=rig.data.edit_bones.new('Accessory%d'%i)
    bone.head=(i*.4,0,1)
    bone.tail=((i+1)*.4,0,1)
    bone.parent=parent
    bone.use_connect=i>0
    parent=bone
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,-.25))
floor=bpy.context.object
floor.name='DisposableCollider'
floor.scale=(4,4,1.0)
bpy.context.view_layer.objects.active=rig
scene=bpy.context.scene
scene.render.fps=60
scene.wiggle.iterations=8
scene.wiggle.full_bone_collision.enable_fullbone_collision=True
scene.wiggle.full_bone_collision.steps=12
for bone in rig.pose.bones:
    if not bone.name.startswith('Accessory'): continue
    bone.wiggle.tail=True
    bone.wiggle.stiff=0.0
    bone.wiggle.stretch=0.0
    bone.wiggle.damp=.15
    bone.wiggle.gravity=1.0
    bone.wiggle.collider_type='Object'
    bone.wiggle.collider=floor
    bone.wiggle.radius=.03
scene.wiggle.enable=True
core.build_list()
bpy.context.view_layer.update()
protected=rig.pose.bones['ProtectedBody'].matrix.copy()
initial=(rig.matrix_world @ rig.pose.bones['Accessory2'].tail).copy()
minimum_clearance=math.inf
maximum_length_error=0.0
maximum_protected_error=0.0
maximum_displacement=0.0
finite=True
for frame in range(1,181):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    for bone in rig.pose.bones:
        finite=finite and all(math.isfinite(x) for row in bone.matrix for x in row)
        if bone.name.startswith('Accessory'):
            tail=rig.matrix_world @ bone.tail
            minimum_clearance=min(minimum_clearance,tail.z-.25)
            maximum_length_error=max(maximum_length_error,abs((bone.tail-bone.head).length-.4))
    current=rig.pose.bones['ProtectedBody'].matrix
    maximum_protected_error=max(maximum_protected_error,max(abs(current[r][c]-protected[r][c]) for r in range(4) for c in range(4)))
    maximum_displacement=max(maximum_displacement,(rig.matrix_world @ rig.pose.bones['Accessory2'].tail-initial).length)
passed=finite and maximum_protected_error<1e-7 and maximum_length_error<1e-4 and maximum_displacement>.01 and minimum_clearance>=-.005
report={'status':'PASS_INSTALL_AND_DISPOSABLE_CHAIN' if passed else 'FAIL_CHAIN_QUALIFICATION',
        'blender':bpy.app.version_string,'addon':module,'version':'1.1.2',
        'license':'GPL-3.0-or-later','package_sha256':hashlib.sha256((app/'.tmp/echo-character-lab/cache/packages/wiggle-bones-1.1.2.zip').read_bytes()).hexdigest(),
        'config':bpy.utils.user_resource('CONFIG'),'extension_root':bpy.utils.user_resource('EXTENSIONS'),
        'frames':180,'fps':60,'finite':finite,'protected_body_matrix_max_error':maximum_protected_error,
        'maximum_bone_length_error_m':maximum_length_error,'minimum_tip_floor_clearance_m':minimum_clearance,
        'maximum_tip_displacement_m':maximum_displacement,
        'built_in':{'cloth':hasattr(bpy.types,'ClothModifier'),'rigid_body':hasattr(bpy.types,'RigidBodyObject'),'soft_body':hasattr(bpy.types,'SoftBodyModifier')},
        'scope':'Fresh isolated-profile load and disposable three-bone collision chain only;Echo wing/cloth/export/runtime are NOT qualified'}
(out/'blender-tools-review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'disposable-chain.blend'))
print('PHYSICS_TOOLS',json.dumps(report))
if not passed: raise RuntimeError('Disposable chain gate failed;not enabled on Echo')
