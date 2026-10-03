@tool
extends Node3D
class_name TreeGenerator

## 勾选后自动重新生成（仅编辑器）
@export var regenerate: bool = false:
	set(value):
		regenerate = value
		if value and is_inside_tree():
			generate_tree()
			regenerate = false

## 随机种子
@export var random_seed: int = 0:
	set(v):
		random_seed = v
		generate_tree()

## 树干高度
@export var trunk_height: float = 3.0:
	set(v):
		trunk_height = v
		generate_tree()

## 树干根部半径
@export var trunk_radius: float = 0.2:
	set(v):
		trunk_radius = v
		generate_tree()

## 最大递归深度（树枝层级，0 = 只有主干）
@export var max_levels: int = 4:
	set(v):
		max_levels = v
		generate_tree()

## 树枝偏离父枝的角度（度）
@export var branch_angle: float = 30.0:
	set(v):
		branch_angle = v
		generate_tree()

## 子枝长度递减系数
@export var length_decay: float = 0.7:
	set(v):
		length_decay = v
		generate_tree()

## 子枝半径递减系数
@export var radius_decay: float = 0.6:
	set(v):
		radius_decay = v
		generate_tree()

## 树枝圆柱截面分段数
@export var branch_segments: int = 8:
	set(v):
		branch_angle = v
		generate_tree()

## 叶子大小
@export var leaf_size: float = 0.3:
	set(v):
		leaf_size = v
		generate_tree()


var rng: RandomNumberGenerator

var has_leaves: bool = false

func _ready() -> void:
	# 在编辑器下不自动生成，仅通过 regenerate 触发；运行时则自动生成
	if not Engine.is_editor_hint():
		generate_tree()


func generate_tree() -> void:
	# 确保随机数生成器可用
	rng = RandomNumberGenerator.new()
	rng.seed = random_seed
	has_leaves = false
	
	# 树枝表面工具
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark_mat := _create_bark_material()
	bark_st.set_material(bark_mat)

	# 叶子表面工具
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_mat := _create_leaf_material()
	leaf_st.set_material(leaf_mat)

	# 递归生成树干和树枝
	generate_branch(bark_st, leaf_st, Vector3.ZERO, Vector3.UP, trunk_height, trunk_radius, 0)

	# 构建并应用树枝网格
	bark_st.generate_tangents()
	var bark_mesh: ArrayMesh = bark_st.commit()
	_apply_mesh_to_child("BarkMesh", bark_mesh, bark_mat)

	# 构建并应用叶子网格（独立子节点）
	if has_leaves:
		leaf_st.generate_tangents()
		var leaf_mesh: ArrayMesh = leaf_st.commit()
		_apply_mesh_to_child("LeafMesh", leaf_mesh, leaf_mat)
	else:
		_remove_child("LeafMesh")


func generate_branch(
	bark_st: SurfaceTool,
	leaf_st: SurfaceTool,
	from: Vector3,
	direction: Vector3,
	length: float,
	start_radius: float,
	level: int
) -> void:
	var end := from + direction * length
	var end_radius := start_radius * radius_decay

	# 绘制当前树枝段圆柱
	draw_cylinder(bark_st, from, end, start_radius, end_radius, branch_segments)

	# 到达最大层级时添加叶子
	if level >= max_levels:
		add_leaves(leaf_st, end, direction, leaf_size)
		return

	# 生成子枝
	var child_length := length * length_decay
	var child_radius := start_radius * radius_decay
	var num_branches := rng.randi_range(2, 4)

	# 计算与生长方向正交的两个轴
	var axis_a: Vector3
	var axis_b: Vector3
	if abs(direction.dot(Vector3.UP)) < 0.99:
		axis_a = direction.cross(Vector3.UP).normalized()
	else:
		axis_a = Vector3.RIGHT
	axis_b = direction.cross(axis_a).normalized()

	for _i in range(num_branches):
		var angle_rad := deg_to_rad(branch_angle + rng.randf_range(-10.0, 20.0))
		var azimuth := rng.randf_range(0.0, TAU)

		var tilted = direction.rotated(axis_a, angle_rad)
		var child_dir = tilted.rotated(direction, azimuth)

		var branch_start := end - direction * length * 0.2
		generate_branch(bark_st, leaf_st, branch_start, child_dir, child_length, child_radius, level + 1)


func draw_cylinder(
	st: SurfaceTool,
	p1: Vector3,
	p2: Vector3,
	radius_start: float,
	radius_end: float,
	sides: int
) -> void:
	var height := p1.distance_to(p2)
	if height < 0.001:
		return

	var dir := (p2 - p1).normalized()
	var right: Vector3
	if abs(dir.dot(Vector3.RIGHT)) < 0.9:
		right = dir.cross(Vector3.RIGHT).normalized()
	else:
		right = dir.cross(Vector3.UP).normalized()
	var forward := dir.cross(right).normalized()

	var top_verts := PackedVector3Array()
	var bottom_verts := PackedVector3Array()
	for i in range(sides):
		var angle := TAU * i / sides
		var x := cos(angle)
		var z := sin(angle)
		top_verts.append(p2 + right * x * radius_end + forward * z * radius_end)
		bottom_verts.append(p1 + right * x * radius_start + forward * z * radius_start)

	for i in range(sides):
		var j := (i + 1) % sides
		st.add_vertex(top_verts[j])
		st.add_vertex(bottom_verts[j])
		st.add_vertex(bottom_verts[i])

		st.add_vertex(top_verts[i])
		st.add_vertex(top_verts[j])
		st.add_vertex(bottom_verts[i])


func add_leaves(leaf_st: SurfaceTool, position: Vector3, direction: Vector3, size: float) -> void:
	has_leaves = true
	var right: Vector3
	if abs(direction.dot(Vector3.UP)) < 0.99:
		right = direction.cross(Vector3.UP).normalized()
	else:
		right = Vector3.RIGHT
	var up := direction.cross(right).normalized()
	var forward := up.cross(right).normalized()
	var half := size * 0.5

	for _i in range(rng.randi_range(3, 5)):
		var offset := Vector3(
			rng.randf_range(-0.2, 0.2),
			rng.randf_range(-0.1, 0.1),
			rng.randf_range(-0.2, 0.2)
		)
		var pos := position + offset

		# 十字交叉的四边形叶子
		var p1 = pos - right * half - up * half
		var p2 = pos + right * half - up * half
		var p3 = pos + right * half + up * half
		var p4 = pos - right * half + up * half
		_add_quad(leaf_st, p1, p2, p3, p4)

		p1 = pos - right * half - forward * half
		p2 = pos + right * half - forward * half
		p3 = pos + right * half + forward * half
		p4 = pos - right * half + forward * half
		_add_quad(leaf_st, p1, p2, p3, p4)


func _add_quad(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3) -> void:
	st.add_vertex(v3)
	st.add_vertex(v2)
	st.add_vertex(v1)
	st.add_vertex(v4)
	st.add_vertex(v3)
	st.add_vertex(v1)


func _apply_mesh_to_child(child_name: String, mesh: ArrayMesh, material: Material) -> void:
	var child = get_node_or_null(child_name)
	if not child:
		child = MeshInstance3D.new()
		child.name = child_name
		add_child(child)
		if Engine.is_editor_hint():
			child.owner = get_tree().edited_scene_root
	child.mesh = mesh
	# 材质已包含在网格表面中，但也可单独设置
	if child.get_surface_override_material_count() == 0:
		child.material_override = material


func _remove_child(child_name: String) -> void:
	var child = get_node_or_null(child_name)
	if child:
		child.queue_free()


func _create_bark_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.25, 0.16)
	mat.roughness = 0.9
	return mat


func _create_leaf_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.65, 0.15)
	mat.roughness = 0.8
	mat.cull_mode = StandardMaterial3D.CULL_DISABLED
	return mat
