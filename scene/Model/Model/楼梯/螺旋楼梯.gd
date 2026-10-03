@tool
extends Node3D
class_name 螺旋楼梯

@export var use_ramp_collision: bool = true:
	set(v):
		use_ramp_collision = v
		rebuild()

## 台阶数量
@export var step_count: int = 20:
	set(v):
		step_count = max(1, v)
		rebuild()

## 楼梯总高度
@export var total_height: float = 4.0:
	set(v):
		total_height = max(0.1, v)
		rebuild()

## 总旋转角度（度）
@export var total_angle: float = 360.0:
	set(v):
		total_angle = v
		rebuild()

## 中心柱半径
@export var pillar_radius: float = 0.3:
	set(v):
		pillar_radius = max(0.05, v)
		rebuild()

## 台阶径向宽度
@export var step_width: float = 0.8:
	set(v):
		step_width = max(0.1, v)
		rebuild()

## 台阶厚度
@export var step_thickness: float = 0.1:
	set(v):
		step_thickness = max(0.02, v)
		rebuild()

## 台阶切向深度（沿行走方向）
@export var step_depth: float = 0.4:
	set(v):
		step_depth = max(0.1, v)
		rebuild()

## 是否生成栏杆
@export var enable_railing: bool = true:
	set(v):
		enable_railing = v
		rebuild()

## 栏杆立柱高度
@export var railing_height: float = 0.9:
	set(v):
		railing_height = max(0.1, v)
		rebuild()

## 栏杆立柱半径
@export var railing_radius: float = 0.05:
	set(v):
		railing_radius = max(0.01, v)
		rebuild()

## 是否生成立柱
@export var railing: bool = true:
	set(v):
		railing = v
		rebuild()

## 扶手截面半径
@export var handrail_radius: float = 0.06:
	set(v):
		handrail_radius = max(0.01, v)
		rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	# 仅在场景树中时才执行重建
	if not is_inside_tree():
		return

	# 移除所有现有子节点
	for child in get_children():
		child.queue_free()

	# 等待队列释放后再添加新节点（使用 call_deferred 避免冲突）
	call_deferred("_do_rebuild")


func _do_rebuild() -> void:
	# 清除可能残留的旧节点（因为 queue_free 会延迟执行）
	for child in get_children():
		child.queue_free()

	# 实际生成
	_build_pillar()
	_build_steps()
	if enable_railing:
		_build_railing_posts()
		_build_handrail()

func _add_static_body_with_collision(mesh_instance: MeshInstance3D, shape: Shape3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	collision_shape.name = "CollisionShape"

	body.add_child(mesh_instance)
	body.add_child(collision_shape)
	# 碰撞形状的局部位置保持默认(0,0,0)，与网格重合
	return body

func _build_pillar() -> void:
	if not railing:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "CenterPillarMesh"
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.height = total_height
	cylinder_mesh.top_radius = pillar_radius
	cylinder_mesh.bottom_radius = pillar_radius
	cylinder_mesh.radial_segments = 16
	mesh_instance.mesh = cylinder_mesh
	# 位置相对于父StaticBody
	mesh_instance.position = Vector3.ZERO

	var shape := CylinderShape3D.new()
	shape.height = total_height
	shape.radius = pillar_radius

	var body := _add_static_body_with_collision(mesh_instance, shape)
	body.name = "CenterPillar"
	body.position = Vector3(0, total_height / 2.0, 0)
	_add_child(body)


func _build_steps() -> void:
	var angle_step := total_angle / float(step_count)
	var height_step := total_height / float(step_count)
	var center_radius := pillar_radius + step_width / 2.0

	for i in range(step_count):
		var angle_deg := i * angle_step
		var angle_rad := deg_to_rad(angle_deg)
		var y := i * height_step + height_step / 2.0

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "StepMesh" + str(i)
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(step_depth, step_thickness, step_width)
		mesh_instance.mesh = box_mesh
		mesh_instance.position = Vector3.ZERO

		# 如果使用斜面碰撞，台阶本身不加碰撞体
		if use_ramp_collision:
			_add_child(mesh_instance)   # 只添加网格，无 StaticBody
			mesh_instance.position = Vector3(
				center_radius * cos(angle_rad),
				y,
				center_radius * sin(angle_rad)
			)
			mesh_instance.rotation.y = -angle_rad + PI / 2.0
		else:
			# 保留原有的独立盒碰撞（旧方式）
			var shape := BoxShape3D.new()
			shape.size = box_mesh.size
			var body := _add_static_body_with_collision(mesh_instance, shape)
			body.name = "Step" + str(i)
			body.position = Vector3(
				center_radius * cos(angle_rad),
				y,
				center_radius * sin(angle_rad)
			)
			body.rotation.y = -angle_rad + PI / 2.0
			_add_child(body)

	if use_ramp_collision:
		_build_stair_ramp()

func _build_stair_ramp() -> void:
	var angle_step := total_angle / float(step_count)
	var height_step := total_height / float(step_count)
	var inner_radius := pillar_radius                # 台阶内边缘
	var outer_radius := pillar_radius + step_width   # 台阶外边缘

	# 生成条带网格（两个螺旋边 + 三角形）
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segments := step_count * 2  # 细分使斜面更平滑
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle_deg := lerpf(0.0, total_angle, t)
		var angle_rad := deg_to_rad(angle_deg)
		var y := lerpf(0.0, total_height, t) + step_thickness  # 顶面高度（加上第一级厚度）

		var inner := Vector3(inner_radius * cos(angle_rad), y, inner_radius * sin(angle_rad))
		var outer := Vector3(outer_radius * cos(angle_rad), y, outer_radius * sin(angle_rad))

		# 添加两个顶点（内、外）
		st.add_vertex(inner)
		st.set_normal(Vector3.UP)   # 临时法线，最终会重新计算
		st.add_vertex(outer)
		st.set_normal(Vector3.UP)

	# 生成三角形索引
	for i in range(segments):
		var base := i * 2
		# 三角形1：inner0, inner1, outer0
		st.add_index(base + 1)
		st.add_index(base + 2)
		st.add_index(base + 0)
		# 三角形2：inner1, outer1, outer0
		st.add_index(base + 3)
		st.add_index(base + 2)
		st.add_index(base + 1)

	st.generate_normals()
	var ramp_mesh := st.commit()

	# 创建静态碰撞体（仅碰撞，不可见）
	var body := StaticBody3D.new()
	body.name = "StairRampCollision"
	var col_shape := CollisionShape3D.new()
	col_shape.shape = ramp_mesh.create_trimesh_shape()
	body.add_child(col_shape)
	_add_child(body)

func _build_railing_posts() -> void:
	var outer_radius := pillar_radius + step_width
	var angle_step := total_angle / float(step_count)
	var height_step := total_height / float(step_count)

	for i in range(step_count):
		var angle_deg := i * angle_step
		var angle_rad := deg_to_rad(angle_deg)
		var base_y := i * height_step + step_thickness
		var post_y := base_y + railing_height / 2.0

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "PostMesh" + str(i)
		var cylinder_mesh := CylinderMesh.new()
		cylinder_mesh.height = railing_height
		cylinder_mesh.top_radius = railing_radius
		cylinder_mesh.bottom_radius = railing_radius
		cylinder_mesh.radial_segments = 8
		mesh_instance.mesh = cylinder_mesh
		mesh_instance.position = Vector3.ZERO

		var shape := CylinderShape3D.new()
		shape.height = railing_height
		shape.radius = railing_radius

		var body := _add_static_body_with_collision(mesh_instance, shape)
		body.name = "Post" + str(i)
		body.position = Vector3(
			outer_radius * cos(angle_rad),
			post_y,
			outer_radius * sin(angle_rad)
		)
		_add_child(body)


func _build_handrail() -> void:
	var outer_radius := pillar_radius + step_width
	var angle_step := total_angle / float(step_count)
	var height_step := total_height / float(step_count)

	var start_angle_deg := 0.0
	var end_angle_deg := (step_count - 1) * angle_step
	var start_y := 0.0 + step_thickness + railing_height
	var end_y := (step_count - 1) * height_step + step_thickness + railing_height

	# 生成扶手网格
	var mesh := _generate_spiral_tube(outer_radius, start_angle_deg, end_angle_deg, start_y, end_y, handrail_radius, 8, 64)
	if mesh == null:
		return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "HandrailMesh"
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3.ZERO

	# 使用三角网格生成精确碰撞形状
	var trimesh_shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	var body := _add_static_body_with_collision(mesh_instance, trimesh_shape)
	body.name = "Handrail"
	_add_child(body)

## 生成螺旋管网格
## outer_radius: 螺旋半径
## start_angle: 起始角度（度）
## end_angle: 终止角度（度）
## start_y: 起始高度
## end_y: 终止高度
## tube_radius: 管道截面半径
## radial_segments: 截面分段数（越大越圆滑）
## length_segments: 沿螺旋线的分段数
func _generate_spiral_tube(
	outer_radius: float, 
	start_angle: float, 
	end_angle: float, 
	start_y: float, 
	end_y: float, 
	tube_radius: float, 
	radial_segments: int = 8, 
	length_segments: int = 64
) -> ArrayMesh:
	if tube_radius <= 0.0 or radial_segments < 3 or length_segments < 2:
		return null

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 为了生成封闭的环，我们在径向方向上多绕一圈（即首尾相连）
	for j in range(length_segments + 1):
		var t := float(j) / float(length_segments)
		var angle_deg := lerpf(start_angle, end_angle, t)
		var angle_rad := deg_to_rad(angle_deg)
		var y := lerpf(start_y, end_y, t)

		# 螺旋线上的中心点
		var center := Vector3(
			outer_radius * cos(angle_rad),
			y,
			outer_radius * sin(angle_rad)
		)

		# 计算该点的切线方向（朝向螺旋前进方向）
		var next_t := float(j + 1) / float(length_segments)
		var next_angle_deg := lerpf(start_angle, end_angle, next_t)
		var next_angle_rad := deg_to_rad(next_angle_deg)
		var next_y := lerpf(start_y, end_y, next_t)
		var next_center := Vector3(
			outer_radius * cos(next_angle_rad),
			next_y,
			outer_radius * sin(next_angle_rad)
		)
		var tangent := (next_center - center).normalized()
		if tangent.length() < 0.001:
			tangent = Vector3(0, 1, 0)  # 安全回退

		# 构建局部坐标系：法线、副法线
		var up := Vector3.UP
		var normal := tangent.cross(up).normalized()
		if normal.length() < 0.001:
			normal = Vector3.RIGHT  # 竖直管道时
		var binormal := tangent.cross(normal).normalized()

		# 生成围绕 center 的径向截面圆上的点
		for i in range(radial_segments + 1):
			var ang := 2.0 * PI * float(i) / float(radial_segments)
			var radial_dir := normal * cos(ang) + binormal * sin(ang)
			var vert := center + radial_dir * tube_radius
			st.add_vertex(vert)
			# 法线向外
			st.set_normal(radial_dir)

	# 生成三角形索引（连接相邻的两个截面环）
	for j in range(length_segments):
		for i in range(radial_segments):
			# 当前环的第i点索引 = j * (radial_segments+1) + i
			var a := j * (radial_segments + 1) + i
			var b := a + 1
			var c := (j + 1) * (radial_segments + 1) + i
			var d := c + 1
			# 两个三角形组成一个四边形
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)

	# 生成网格并返回
	st.generate_normals()  # 确保法线正确
	var mesh := st.commit()
	return mesh

## 生成用于 CSGPolygon3D 的近似圆形多边形
func _make_circle_polygon(radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := 2.0 * PI * i / sides
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _add_child(node: Node) -> void:
	add_child(node)
	if Engine.is_editor_hint():
		_set_owner_recursive(node, get_tree().edited_scene_root)

func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_set_owner_recursive(child, owner_node)
