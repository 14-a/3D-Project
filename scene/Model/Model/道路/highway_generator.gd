@tool
extends Node3D
class_name highway_generator

@export var random_seed: int = 0
@export var point_count: int = 10
@export var segment_length: float = 6.0
@export var turn_randomness: float = 0.5

@export var lane_width: float = 3.5
@export var shoulder_width: float = 1.2
@export var mark_width: float = 0.15
@export var texture_repeat_distance: float = 6.0   # 纹理每6米重复

@export var road_material: Material
@export var shoulder_material: Material
@export var mark_material: Material

func _ready():
	seed(random_seed)
	var curve = generate_smooth_curve()
	
	# 1. 路面主体
	add_surface(curve, -lane_width, lane_width, 0.0, road_material, true)
	
	# 2. 左右路肩
	add_surface(curve, -lane_width - shoulder_width, -lane_width, 0.0, shoulder_material)
	add_surface(curve, lane_width, lane_width + shoulder_width, 0.0, shoulder_material)
	
	# 3. 中心虚线（略抬高防Z-fighting）
	var half_mark = mark_width / 2.0
	add_surface(curve, -half_mark, half_mark, 0.02, mark_material)

func add_surface(curve: Curve3D, left_offset: float, right_offset: float, raise: float, mat: Material, collision: bool = false):
	var mesh = build_strip(curve, left_offset, right_offset, raise)
	if mesh == null: return
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if collision:
		mi.create_trimesh_collision()
	add_child(mi)

func build_strip(curve: Curve3D, left_dist: float, right_dist: float, y_offset: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var pts = curve.get_baked_points()
	if pts.size() < 2:
		return null
	
	var up = Vector3.UP
	var accumulated = 0.0
	
	for i in range(pts.size()):
		var p = pts[i]
		var tangent: Vector3
		if i == 0:
			tangent = (pts[1] - p).normalized()
		elif i == pts.size() - 1:
			tangent = (p - pts[i-1]).normalized()
		else:
			tangent = (pts[i+1] - pts[i-1]).normalized()
		
		var side = tangent.cross(up).normalized()
		
		if i > 0:
			accumulated += pts[i].distance_to(pts[i-1])
		var v_uv = accumulated / texture_repeat_distance
		
		var left_v = p + side * left_dist + up * y_offset
		var right_v = p + side * right_dist + up * y_offset
		
		st.set_normal(up)
		st.set_uv(Vector2(0.0, v_uv))
		st.add_vertex(left_v)
		
		st.set_normal(up)
		st.set_uv(Vector2(1.0, v_uv))
		st.add_vertex(right_v)
	
	for i in range(pts.size() - 1):
		var base = i * 2
		st.add_index(base + 2)
		st.add_index(base + 1)
		st.add_index(base)
		st.add_index(base + 3)
		st.add_index(base + 1)
		st.add_index(base + 2)
	
	st.generate_normals()
	return st.commit()

func generate_smooth_curve() -> Curve3D:
	var curve = Curve3D.new()
	var pos = Vector3.ZERO
	var dir = Vector3.FORWARD
	
	for i in range(point_count):
		curve.add_point(pos)
		var angle = randf_range(-turn_randomness, turn_randomness)
		dir = dir.rotated(Vector3.UP, angle)
		pos += dir * segment_length
	
	for i in range(curve.get_point_count()):
		var p = curve.get_point_position(i)
		var t = Vector3.ZERO
		if i > 0: t += p - curve.get_point_position(i-1)
		if i < curve.get_point_count()-1: t += curve.get_point_position(i+1) - p
		t = t.normalized() * segment_length * 0.4
		curve.set_point_in(i, -t)
		curve.set_point_out(i, t)
	
	curve.bake_interval = 0.2
	return curve
