@tool
extends Node3D
class_name 路

@export var random_seed: int = 0:
	set(v):
		random_seed = v
		_Make()

@export var point_count: int = 8:
	set(v):
		point_count = v
		_Make()

@export var segment_length: float = 4.0:
	set(v):
		segment_length = v
		_Make()

@export var turn_randomness: float = 0.4:
	set(v):
		turn_randomness = v
		_Make()

@export var road_width: float = 3.0:
	set(v):
		road_width = v
		_Make()

@export var baked_subdivs: int = 200:
	set(v):
		baked_subdivs = v
		_Make()

@export var material: Material

func _ready():
	_Make()

func _Make() -> void:
	seed(random_seed)
	var curve = generate_random_curve()
	var mesh = build_road_mesh(curve)
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	if material:
		mi.material_override = material
	add_child(mi)

	# 自动生成碰撞
	mi.create_trimesh_collision()

# 生成带平滑切线的随机路径
func generate_random_curve() -> Curve3D:
	var curve = Curve3D.new()
	var pos = Vector3.ZERO
	var forward = Vector3.FORWARD

	# 添加控制点
	for i in range(point_count):
		curve.add_point(pos)
		var angle = randf_range(-turn_randomness, turn_randomness)
		forward = forward.rotated(Vector3.UP, angle)
		pos += forward * segment_length

	# 计算 Catmull-Rom 风格的切线，保证曲线光滑
	for i in range(curve.get_point_count()):
		var p = curve.get_point_position(i)
		var tangent = Vector3.ZERO
		if i > 0:
			tangent += p - curve.get_point_position(i - 1)
		if i < curve.get_point_count() - 1:
			tangent += curve.get_point_position(i + 1) - p
		tangent = tangent.normalized() * segment_length * 0.4
		curve.set_point_in(i, -tangent)
		curve.set_point_out(i, tangent)

	# 烘焙为均匀采样点
	curve.bake_interval = 0.2
	return curve

# 使用 SurfaceTool 构建道路网格
func build_road_mesh(curve: Curve3D) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var points = curve.get_baked_points()
	if points.size() < 2:
		return null

	var up = Vector3.UP
	var total_length = curve.get_baked_length()

	for i in range(points.size()):
		var p = points[i]
		# 计算切线方向
		var tangent: Vector3
		if i == 0:
			tangent = (points[1] - p).normalized()
		elif i == points.size() - 1:
			tangent = (p - points[i - 1]).normalized()
		else:
			tangent = (points[i + 1] - points[i - 1]).normalized()

		var side = tangent.cross(up).normalized()
		var left = p - side * road_width * 0.5
		var right = p + side * road_width * 0.5

		var v = i / float(points.size() - 1)  # 纵向 UV

		st.set_normal(up)
		st.set_uv(Vector2(0.0, v))
		st.add_vertex(left)

		st.set_normal(up)
		st.set_uv(Vector2(1.0, v))
		st.add_vertex(right)

	# 三角形索引（每隔两个顶点组成一个四边形）
	for i in range(points.size() - 1):
		var base = i * 2
		st.add_index(base + 2)
		st.add_index(base + 1)
		st.add_index(base)

		st.add_index(base + 3)
		st.add_index(base + 1)
		st.add_index(base + 2)

	st.generate_normals()
	return st.commit()
