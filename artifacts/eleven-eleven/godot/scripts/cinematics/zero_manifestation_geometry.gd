extends RefCounted

## Editable local geometry based on approved publication pages 048–050:
## an elongated broken shadow mass, hollow face, filament mantle and paired
## crimson/violet eyes. No anatomy, costume ornament or new Canon is granted.
static func _instance(parent: Node3D, label: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.name=label
	node.mesh=mesh
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func _vertex(surface: SurfaceTool, point: Vector3, uv: Vector2) -> void:
	surface.set_uv(uv)
	surface.add_vertex(point)

static func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uva:=Vector2.ZERO, uvb:=Vector2.RIGHT, uvc:=Vector2.ONE) -> void:
	_vertex(surface,a,uva)
	_vertex(surface,b,uvb)
	_vertex(surface,c,uvc)

static func _profile(y: float) -> float:
	var profile: Array[Vector2]=[Vector2(0,1.24),Vector2(0.7,1.10),Vector2(1.8,0.77),Vector2(2.8,0.59),Vector2(3.65,0.68),Vector2(4.16,1.15),Vector2(4.49,0.84),Vector2(4.86,0.30)]
	for index in profile.size()-1:
		if y<=profile[index+1].x:
			var weight:=inverse_lerp(profile[index].x,profile[index+1].x,y)
			return lerpf(profile[index].y,profile[index+1].y,clampf(weight,0,1))
	return profile[-1].y

static func _mantle_point(u: float, v: float, inset:=0.0) -> Vector3:
	var angle:=u*TAU
	var y:=v*4.86
	var fold: float=sin(angle*13.0+v*1.9)*0.065+sin(angle*23.0-v*2.3)*0.021
	var radius:=_profile(y)+fold-inset
	# An irregular dissolved hem and deep directional folds avoid a solid bell.
	y+=(0.5+0.5*sin(angle*7.0+0.6))*0.72*pow(1.0-v,5)
	var asymmetry:=sin(angle*2.0+0.7)*0.11*sin(v*PI)
	return Vector3(cos(angle)*(radius+asymmetry),y+sin(angle*3.0)*0.10*pow(v,5),sin(angle)*radius*0.56-0.12)

static func _mantle() -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 40:
		for segment in 96:
			var u: float=(segment+0.5)/96.0
			var v: float=(row+0.5)/40.0
			# The front stays broken and hollow; no spherical torso is inserted.
			if sin(u*TAU)>0.9 and v<0.77: continue
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var uv:=Vector2((segment+corner.x)/96.0,(row+corner.y)/40.0)
				_vertex(surface,_mantle_point(uv.x,uv.y),uv)
	surface.generate_normals()
	return surface.commit()

static func _fold_ribbon(angle: float, index: int) -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flat torn overlapping folds sit outside the broken mantle rather than
	# making a symmetrical necklace of tubes. Each one dissolves at its own
	# height, direction and width; all values are deterministic and editable.
	var end: float=0.035+0.026*(index%6)
	var start: float=0.94-0.017*(index%3)
	for row in 26:
		for column in 4:
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var along: float=(row+corner.y)/26.0
				var across: float=(column+corner.x)/4.0
				var v:=lerpf(end,start,along)
				var width:=0.09+0.018*sin(index*2.7)
				var bent:=angle+sin(v*3.3+index*1.7)*0.055
				var u: float=(bent+(across-0.5)*width)/TAU
				var raised: float=0.025+sin(across*PI)*0.045
				var point:=_mantle_point(u,v,-raised)
				point.y+=sin(across*PI+index*1.4)*0.15*pow(1.0-along,5)
				_vertex(surface,point,Vector2(across,along))
	surface.generate_normals()
	return surface.commit()

static func _tube(points: PackedVector3Array, radii: PackedFloat32Array, sides:=8) -> ArrayMesh:
	var curve:=Curve3D.new()
	for index in points.size():
		var previous: Vector3=points[maxi(0,index-1)]
		var following: Vector3=points[mini(points.size()-1,index+1)]
		var tangent: Vector3=(following-previous)*0.17
		curve.add_point(points[index],-tangent,tangent)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=maxi(16,points.size()*8)
	var length:=curve.get_baked_length()
	var frames: Array[Transform3D]=[]
	var widths: PackedFloat32Array=[]
	for index in count+1:
		var t: float=float(index)/count
		var point:=curve.sample_baked(t*length,true)
		var next:=curve.sample_baked(minf(length,t*length+0.025),true)
		var previous:=curve.sample_baked(maxf(0,t*length-0.025),true)
		var direction: Vector3=(next-previous).normalized()
		var side: Vector3=Vector3.UP.cross(direction).normalized()
		if side.length()<0.1: side=Vector3.RIGHT
		var up: Vector3=direction.cross(side).normalized()
		frames.append(Transform3D(Basis(side,up,direction),point))
		var at: float=t*(radii.size()-1)
		var first:=mini(int(at),radii.size()-1)
		widths.append(lerpf(radii[first],radii[mini(first+1,radii.size()-1)],at-first))
	for row in count:
		for segment in sides:
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var index:=row+int(corner.y)
				var angle: float=(segment+corner.x)/sides*TAU
				var frame:=frames[index]
				var vertex: Vector3=frame.origin+(frame.basis.x*cos(angle)+frame.basis.y*sin(angle))*widths[index]
				_vertex(surface,vertex,Vector2((segment+corner.x)/sides,float(index)/count))
	surface.generate_normals()
	return surface.commit()

static func _hood() -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front: Array[Vector3]=[Vector3(-0.12,6.20,0.08),Vector3(-0.53,5.88,0.30),Vector3(-0.69,5.55,0.38),Vector3(-0.76,5.28,0.39),Vector3(-0.52,4.89,0.47),Vector3(-0.06,4.67,0.52),Vector3(0.48,4.99,0.45),Vector3(0.75,5.29,0.36),Vector3(0.65,5.78,0.29),Vector3(0.34,6.02,0.20)]
	var center:=Vector3(0,5.40,0.61)
	var back:=Vector3(0,5.36,-0.54)
	for index in front.size():
		var next: int=(index+1)%front.size()
		var a: Vector3=front[index]
		var b: Vector3=front[next]
		var ai: Vector3=center+(a-center)*Vector3(0.62,0.72,0.4)
		var bi: Vector3=center+(b-center)*Vector3(0.62,0.72,0.4)
		_tri(surface,a,bi,b)
		_tri(surface,a,ai,bi)
		_tri(surface,a,b,back)
	surface.generate_normals()
	return surface.commit()

static func _face_void() -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center:=Vector3(0,5.4,0.56)
	var outline: Array[Vector3]=[Vector3(0,5.97,0.55),Vector3(-0.33,5.72,0.55),Vector3(-0.48,5.43,0.55),Vector3(-0.35,5.10,0.55),Vector3(0,4.91,0.55),Vector3(0.35,5.10,0.55),Vector3(0.48,5.43,0.55),Vector3(0.33,5.72,0.55)]
	for index in outline.size(): _tri(surface,center,outline[(index+1)%outline.size()],outline[index])
	surface.generate_normals()
	return surface.commit()

static func _eye(side: float) -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center:=Vector3(side*0.22,5.46,0.65)
	var vertices: Array[Vector3]=[Vector3(-0.18,-side*0.027,0),Vector3(-0.07,0.038,0.004),Vector3(0.17,side*0.027,0),Vector3(0.065,-0.025,0.004)]
	_tri(surface,center+vertices[0],center+vertices[2],center+vertices[1])
	_tri(surface,center+vertices[0],center+vertices[3],center+vertices[2])
	surface.generate_normals()
	return surface.commit()

static func _combine(meshes: Array[ArrayMesh]) -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mesh in meshes: surface.append_from(mesh,0,Transform3D.IDENTITY)
	return surface.commit()

static func build_independent_field(parent: Node3D, shadow: Material, vein: Material) -> void:
	# The imported body remains the identity. These two merged draws are an
	# independent broken network field, not replacement anatomy or clothing.
	var dark: Array[ArrayMesh]=[]
	var light: Array[ArrayMesh]=[]
	for index in 14:
		var side: float=-1 if index%2==0 else 1
		var y: float=0.85+(index%7)*0.68
		var points:=PackedVector3Array([Vector3(side*1.33,y,-0.28),Vector3(side*1.91,y+0.19,-0.62),Vector3(side*(2.53+0.12*(index%3)),y-0.09,-0.59),Vector3(side*(3.00+0.13*(index%4)),y+0.26,-0.39)])
		dark.append(_tube(points,PackedFloat32Array([0.047,0.045,0.017,0.001]),6))
		if index%3==0: light.append(_tube(points,PackedFloat32Array([0.004,0.008,0.006,0.001]),5))
	_instance(parent,"IndependentInkRibbons",_combine(dark),shadow)
	_instance(parent,"IndependentSignalRibbons",_combine(light),vein)

static func build(parent: Node3D, shadow: Material, vein: Material) -> void:
	_instance(parent,"BrokenFoldedMantle",_mantle(),shadow)
	_instance(parent,"HollowAngularHood",_hood(),shadow)
	var black:=StandardMaterial3D.new()
	black.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color=Color(0.003,0.002,0.008)
	black.cull_mode=BaseMaterial3D.CULL_DISABLED
	_instance(parent,"FaceVoid",_face_void(),black)
	for side in [-1.0,1.0]:
		var eye:=StandardMaterial3D.new()
		eye.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		eye.cull_mode=BaseMaterial3D.CULL_DISABLED
		eye.albedo_color=Color(0.9,0.07,0.15) if side<0 else Color(0.62,0.20,1.0)
		eye.emission_enabled=true
		eye.emission=eye.albedo_color
		eye.emission_energy_multiplier=1.7
		_instance(parent,"CrimsonDirectedEye" if side<0 else "VioletDirectedEye",_eye(side),eye)
		var broken_offset:=0.16 if side<0 else -0.07
		var arm:=PackedVector3Array([Vector3(side*0.35,4.75,-0.16),Vector3(side*1.31,4.17+broken_offset,-0.25),Vector3(side*1.63,3.50+broken_offset,-0.04),Vector3(side*1.53,2.64,0.22),Vector3(side*1.76,2.24+broken_offset,0.36)])
		_instance(parent,"FrayedArmMantle",_tube(arm,PackedFloat32Array([0.25,0.28,0.16,0.075,0.026])),shadow)
		for finger in 4:
			var tip:=PackedVector3Array([arm[-2],arm[-1]+Vector3(side*0.045*finger,0.08,0.05),arm[-1]+Vector3(side*(0.12+finger*0.11),-0.36-finger*0.035,0.18)])
			_instance(parent,"FilamentClaw",_tube(tip,PackedFloat32Array([0.035,0.029,0.003]),6),shadow)
	# Layered torn streamers and their fine signal seams surround the same
	# immutable silhouette. Geometry supplies folds before any motion is added.
	for index in 18:
		var angle: float=index*TAU/18.0
		_instance(parent,"LayeredInkFold",_fold_ribbon(angle,index),shadow)
		if index%3==0:
			var seam:=PackedVector3Array()
			for v in [0.93,0.71,0.46,0.25,0.12]:
				seam.append(_mantle_point((angle+0.035*sin(v*8+index))/TAU,v,-0.072))
			_instance(parent,"MantleSignalVein",_tube(seam,PackedFloat32Array([0.007,0.012,0.011,0.008,0.002]),5),vein)
	for index in 12:
		var side: float=-1.0 if index%2==0 else 1.0
		var height: float=1.1+(index%6)*0.64
		var points:=PackedVector3Array([Vector3(side*0.42,height,-0.40),Vector3(side*1.70,height+0.26,-0.82),Vector3(side*(2.5+0.16*(index%3)),height+0.12,-0.66),Vector3(side*(2.9+0.20*(index%4)),height+0.50,-0.4)])
		_instance(parent,"LivingShadowFilament",_tube(points,PackedFloat32Array([0.105,0.10,0.035,0.002]),7),shadow)
	# Angular fracture threads refer to the publication's broken network field.
	for index in 22:
		var angle: float=index*TAU/22.0
		var y: float=1.0+(index%7)*0.54
		var point:=_mantle_point(angle/TAU,y/4.86)+Vector3(0,0,0.035)
		var points:=PackedVector3Array([point,point+Vector3(0.10,0.16,0.015),point+Vector3(-0.04,0.27,0.025),point+Vector3(0.10,0.39,0.018)])
		_instance(parent,"FractureThread",_tube(points,PackedFloat32Array([0.006,0.009,0.007,0.002]),5),vein)
	# Sparse tangled fibers belong to the approved broken network identity.
	# Merge them into two draws; individual strands are not decorative armor.
	var fibers: Array[ArrayMesh]=[]
	var signals: Array[ArrayMesh]=[]
	for index in 72:
		var angle: float=index*2.399963
		var start_v: float=0.54+0.39*(0.5+0.5*sin(index*5.71))
		var end_v: float=0.08+0.38*(0.5+0.5*sin(index*3.19+0.8))
		var uv: float=angle/TAU
		var offset:=Vector3(cos(angle)*0.07,0,sin(angle)*0.07)
		var points:=PackedVector3Array([
			_mantle_point(uv,start_v,-0.10),
			_mantle_point(uv+0.037*sin(index),lerpf(start_v,end_v,0.32),-0.14)+offset,
			_mantle_point(uv-0.029*cos(index*1.7),lerpf(start_v,end_v,0.67),-0.12)-offset,
			_mantle_point(uv+0.02*sin(index*2.3),end_v,-0.12)+Vector3(cos(angle)*0.12,-0.18,sin(angle)*0.11)])
		var mesh:=_tube(points,PackedFloat32Array([0.006,0.010,0.007,0.001]),5)
		if index%9==0: signals.append(mesh)
		else: fibers.append(mesh)
	for index in 24:
		var side: float=-1 if index%2==0 else 1
		var y: float=4.75+(index%12)*0.11
		var points:=PackedVector3Array([Vector3(side*0.55,y,0.32),Vector3(side*(0.75+0.015*(index%5)),y+0.07,0.24),Vector3(side*(0.86+0.021*(index%3)),y-0.12,-0.10),Vector3(side*0.65,y-0.35,-0.25)])
		fibers.append(_tube(points,PackedFloat32Array([0.010,0.014,0.008,0.001]),5))
	_instance(parent,"MergedTangledShadowFibers",_combine(fibers),shadow)
	_instance(parent,"MergedFracturedSignalFibers",_combine(signals),vein)
