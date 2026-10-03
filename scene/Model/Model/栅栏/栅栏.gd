@tool
extends Node3D
class_name 栅栏

## 栏杆起点（局部坐标）
@export var start_point := Vector3(0.0, 0.0, 0.0):
	set(v):
		start_point = v
		rebuild()
## 栏杆终点（局部坐标）
@export var end_point := Vector3(5.0, 0.0, 0.0):
	set(v):
		end_point = v
		rebuild()

## 立柱间距
@export var pillar_spacing := 1.0:
	set(v):
		pillar_spacing = max(0.1, v)
		rebuild()

## 立柱高度
@export var pillar_height := 2.0:
	set(v):
		pillar_height = max(0.01, v)
		rebuild()

## 立柱半径（圆柱）
@export var pillar_radius := 0.05:
	set(v):
		pillar_radius = max(0.001, v)
		rebuild()

## 横杆垂直厚度（Y方向）
@export var rail_thickness := 0.05:
	set(v):
		rail_thickness = max(0.001, v)
		rebuild()

## 横杆横向深度（Z方向，栏杆侧面）
@export var rail_depth := 0.05:
	set(v):
		rail_depth = max(0.001, v)
		rebuild()

## 横杆距立柱底部的高度偏移数组（例如上下两根：[0.2, 1.8]）
## 修改此数组后需勾选 Force Rebuild 刷新
@export var rail_offsets: Array[float] = [0.2, 1.8]

## 立柱材质
@export var pillar_material: Material:
	set(v):
		pillar_material = v
		rebuild()

## 横杆材质
@export var rail_material: Material:
	set(v):
		rail_material = v
		rebuild()

## 勾选以强制重建（用于数组更新等情况）
@export var force_rebuild: bool:
	set(v):
		if v:
			rebuild()
		force_rebuild = false


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	if not is_inside_tree():
		return

	# 清除旧网格
	for child in get_children():
		child.queue_free()

	var dir := end_point - start_point
	var length := dir.length()
	if length < 0.001:
		return

	var step_dir := dir.normalized()

	# 计算立柱位置
	var pillar_count := int(floor(length / pillar_spacing)) + 1
	var positions: Array[Vector3] = []
	for i in range(pillar_count):
		positions.append(start_point + step_dir * pillar_spacing * i)

	# 若终点未被覆盖，添加上终点柱
	if positions[-1].distance_to(end_point) > 0.001:
		positions.append(end_point)

	# ---------- 立柱 (自动附带碰撞箱) ----------
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = pillar_radius
	pillar_mesh.bottom_radius = pillar_radius
	pillar_mesh.height = pillar_height
	pillar_mesh.radial_segments = 8

	for pos in positions:
		var pillar := MeshInstance3D.new()
		pillar.mesh = pillar_mesh
		pillar.position = pos + Vector3.UP * pillar_height / 2.0
		if pillar_material:
			pillar.material_override = pillar_material
		add_child(pillar)

		# 自动生成碰撞体
		var body := StaticBody3D.new()
		pillar.add_child(body)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = pillar_radius
		cyl.height = pillar_height
		shape.shape = cyl
		body.add_child(shape)

	# ---------- 横杆 (自动附带碰撞箱) ----------
	for i in range(positions.size() - 1):
		var p1 := positions[i]
		var p2 := positions[i + 1]
		var seg_dir := p2 - p1
		var seg_length := seg_dir.length()
		if seg_length < 0.001:
			continue

		var x_axis := seg_dir.normalized()
		var y_axis := Vector3.UP
		var z_axis := x_axis.cross(y_axis)
		if z_axis.length() < 0.001:
			z_axis = Vector3.RIGHT
			y_axis = z_axis.cross(x_axis).normalized()
		var basis := Basis(x_axis, y_axis, z_axis.normalized())

		for offset in rail_offsets:
			if offset < 0.0 or offset > pillar_height:
				continue

			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(seg_length, rail_thickness, rail_depth)

			var mid := (p1 + p2) / 2.0
			var rail := MeshInstance3D.new()
			rail.mesh = rail_mesh
			rail.position = mid + Vector3.UP * offset
			rail.basis = basis
			if rail_material:
				rail.material_override = rail_material
			add_child(rail)

			# 自动生成碰撞体
			var body := StaticBody3D.new()
			rail.add_child(body)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(seg_length, rail_thickness, rail_depth)
			shape.shape = box
			body.add_child(shape)
