"""Revision 3: measured service hardware and readable contact surfaces.
Run in the existing Jutsu project; preserve its collider names and route.
"""
import bpy, math
from mathutils import Vector
scene=bpy.context.scene
steel=bpy.data.materials['Graphite structural steel']
grip=bpy.data.materials['Ivory grip ceramic']
dark=bpy.data.materials['Deep service void']
signal=bpy.data.materials['Route cyan']
warning=bpy.data.materials['Warning amber']
for mat,color in [(steel,(.18,.22,.26)),(grip,(.32,.36,.38)),(dark,(.055,.07,.085))]:
    mat.diffuse_color=(*color,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)

def box(name,position,size,material,radius=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=position)
    o=bpy.context.object; o.name=name; o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    if radius:
        bevel=o.modifiers.new('Machined edge','BEVEL'); bevel.width=radius; bevel.segments=2
    return o

def cylinder(name,position,radius,depth,material,axis='Y',vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=position)
    o=bpy.context.object; o.name=name
    if axis=='Y': o.rotation_euler.x=math.pi/2
    if axis=='X': o.rotation_euler.y=math.pi/2
    o.data.materials.append(material)
    return o

# Recessed tile seams, captive fasteners, grip end stops and ledge capping.
# Everything stays within 5cm of its collider surface; contact remains legible.
for center,width,front,bottom,height in [(0,5,5.75,0,3.4),(4,2,9.15,3.4,2)]:
    for x in [center-width/2+.08,center+width/2-.08]:
        box('ClimbPlate_SideRail',(x,front-.018,bottom+height/2),(.06,.025,height),steel)
    for z in [bottom+.12,bottom+height-.12]:
        box('ClimbPlate_CaptiveSeam',(center,front-.02,z),(width-.16,.025,.025),dark,0)
    box('MantleLip',(center,front-.01,bottom+height-.035),(width,.04,.07),warning,.008)
    for x in [center-width/2+.13,center+width/2-.13]:
        for z in [bottom+.18,bottom+height-.18]:
            cylinder('ClimbPlate_HexBolt',(x,front-.025,z),.026,.027,steel,vertices=6)
for o in list(scene.objects):
    if o.name.startswith('ClimbGrip') or o.name.startswith('UpperGrip'):
        x,y,z=o.location; width=o.dimensions.x
        for offset in [-width/2+.055,width/2-.055]:
            cylinder('Grip_Anchor',(x+offset,y-.071,z),.026,.025,warning,vertices=6)
        box('Grip_ContactStripe',(x,y-.073,z+.018),(width-.13,.012,.018),signal,.003)

# Left service wall: panel bays and a purposeful pipe manifold outside the route.
root=bpy.data.objects['Maintenance_BreakerPanel_Catalog']
root.location=(-3.91,3.5,1.6)
root.rotation_euler.z=math.pi/2
root['role']='Decorative power distribution; not a task or climb surface'
for y in [1,4,7,10,13]:
    box('ServiceBay_Inset',(-4.16,y,3.8),(.03,2.64,6.5),steel)
    for z in [.7,6.8]:
        box('ServiceBay_CrossSeam',(-4.13,y,z),(.04,2.6,.035),dark,0)
for y in [1.45,1.85,2.25]:
    cylinder('SupplyPipe',(-3.97,y,2.7),.072,4.5,steel,axis='Z',vertices=16)
    for z in [.8,2.3,4.4]:
        cylinder('SupplyPipe_Collar',(-3.97,y,z),.092,.085,warning,axis='Z',vertices=16)
        box('SupplyPipe_Bracket',(-4.10,y,z),(.20,.09,.075),dark)
box('Vent_DarkRecess',(-4.08,7.9,5.2),(.10,1.7,1.0),dark)
for z in [4.82,4.96,5.1,5.24,5.38,5.52]:
    box('Vent_ServiceLouver',(-3.99,7.9,z),(.05,1.55,.045),steel,.005)

# Upper destination frame, with quiet amber status and a sealed inner panel.
# It has no animation or story-authoritative interaction in this proof.
box('ServiceAccess_InnerPanel',(0,12.94,6.36),(1.75,.12,1.9),grip,.03)
for x in [-1,1]: box('ServiceAccess_Frame',(x,12.8,6.4),(.18,.32,2.25),steel)
box('ServiceAccess_Lintel',(0,12.8,7.48),(2.18,.32,.15),steel)
box('ServiceAccess_Status',(0,12.60,7.34),(.36,.05,.05),warning,.005)
for z in [5.85,6.35,6.85]:
    box('ServiceAccess_PanelSeam',(0,12.866,z),(1.5,.018,.025),dark,0)
for x in [-.18,.18]:
    box('ServiceAccess_CenterSeam',(x,12.86,6.4),(.012,.02,1.5),steel,0)

# Floor tiles/edge markings read from the walking camera without extra collision.
for x in [-3,-1,1,3]:
    for y in [0,2,4]:
        box('Floor_ServiceSeam',(x,y,.004),(1.96,.025,.008),dark,0)
for y in [-1.0,.5,2,3.5]:
    for x in [-2.8,2.8]:
        box('Floor_SafetyEdge',(x,y,.012),(.035,.6,.012),warning,0)
scene.camera.location=(3.7,-2.7,7.4)
scene.camera.rotation_euler=(Vector((1,9,3))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.lens=22
result={'objects':len(scene.objects),'catalogAsset':'721d0886-a431-414c-8f1c-40207d941113','routeColliderChanges':False,'detail':'service manifold, removable panels, contact stripes, machined ledges, sealed destination'}
