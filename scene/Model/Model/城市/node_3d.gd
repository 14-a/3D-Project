@tool
extends Node3D

# ==================== 导入用户模块 ====================
# 请将您的楼梯、栏杆、树模块场景或脚本放在相应路径，并修改下方的 preload
const StairScene = preload("res://Model/楼梯/直楼梯.tscn")       # 您的楼梯场景
const RailingScene = preload("res://Model/栅栏/栅栏.tscn")   # 您的栏杆场景
const ComplexTreeScene = preload("res://Model/植物/tree.tscn")  # 您的复杂树场景

# ==================== 导出参数 ====================
@export var city_size: Vector2i = Vector2i(3, 3)          # 街区数量 (x, z)
@export var block_size: float = 40.0                        # 每街区边长
@export var road_width: float = 12.0                        # 道路宽度
@export var building_density_global: float = 0.65           # 基础密度（会被区域覆盖）
@export var tree_density: float = 0.4                       # 树木密度
@export var random_seed: int = 0                            # 随机种子

@export var lod_distance: float = 60.0                      # 高细节可见距离
@export var low_lod_distance: float = 300.0                 # 低细节可见距离
@export var prop_cull_distance: float = 100.0               # 树木/路灯裁剪距离

@export var generate_collision: bool = true                 # 是否生成碰撞
@export var optimize_props: bool = true                     # 是否优化道具（MultiMesh）
@export var generate_in_editor: bool = true                 # 编辑器中自动生成

# ---------- 新增：模块控制 ----------
@export var enable_stairs: bool = true
@export var stair_count: int = 3                    # 楼梯数量
@export var enable_railings: bool = true
@export var railing_probability: float = 0.2        # 每条道路边出现栏杆的概率
@export var enable_complex_trees: bool = true
@export var complex_tree_count: int = 10            # 复杂树数量（仅在公园区域）

@export var regenerate: bool = false:
	set(value):
		if value:
			regenerate = false
			generate_city()

# ==================== 区域定义 ====================
enum ZoneType {
	ZONE_RESIDENTIAL,
	ZONE_COMMERCIAL,
	ZONE_INDUSTRIAL,
	ZONE_PARK
}

# 区域配置（高度、密度、颜色、屋顶权重）
var zone_configs = {
	ZoneType.ZONE_RESIDENTIAL: {
		"color": Color(0.7, 0.5, 0.3),
		"height_min": 3.0,
		"height_max": 15.0,
		"density": 0.7,
		"roof_weights": [0.5, 0.3, 0.1, 0.1]  # 平顶,尖顶,圆顶,天线
	},
	ZoneType.ZONE_COMMERCIAL: {
		"color": Color(0.2, 0.3, 0.6),
		"height_min": 10.0,
		"height_max": 40.0,
		"density": 0.8,
		"roof_weights": [0.2, 0.1, 0.3, 0.4]
	},
	ZoneType.ZONE_INDUSTRIAL: {
		"color": Color(0.4, 0.4, 0.3),
		"height_min": 5.0,
		"height_max": 20.0,
		"density": 0.5,
		"roof_weights": [0.6, 0.2, 0.1, 0.1]
	},
	ZoneType.ZONE_PARK: {
		"color": Color(0.2, 0.6, 0.2),
		"height_min": 0.0,
		"height_max": 0.0,
		"density": 0.1,
		"roof_weights": [1.0, 0.0, 0.0, 0.0]
	}
}

var rng: RandomNumberGenerator

# ==================== 入口 ====================
func _ready():
	if Engine.is_editor_hint() and not generate_in_editor:
		return
	generate_city()

func generate_city():
	print("=== 生成城市开始 ===")
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	rng = RandomNumberGenerator.new()
	rng.seed = random_seed if random_seed != 0 else randi()

	_generate_ground()
	_generate_roads_and_markings()
	var zone_map = _generate_zone_map()
	var building_count = _generate_buildings_with_lod(zone_map)
	
	# 新增：生成装饰模块
	_generate_stairs(zone_map)
	_generate_railings()
	_generate_complex_trees(zone_map)
	
	_generate_trees_and_lamps()   # 原有简单树木（可关闭）
	print("=== 生成完成，建筑数量: ", building_count, " ===")

# ==================== 新增：楼梯生成 ====================
func _generate_stairs(zone_map: Array):
	if not enable_stairs or stair_count <= 0:
		return
	# 找到商业区或市中心街区作为楼梯放置点
	var candidates = []
	for x in range(city_size.x):
		for z in range(city_size.y):
			if zone_map[x][z] == ZoneType.ZONE_COMMERCIAL or zone_map[x][z] == ZoneType.ZONE_PARK:
				candidates.append(Vector2(x, z))
	if candidates.is_empty():
		candidates = [Vector2(city_size.x/2, city_size.y/2)]
	# 随机选择
	var placed = 0
	while placed < stair_count and candidates.size() > 0:
		var idx = rng.randi() % candidates.size()
		var cell = candidates[idx]
		candidates.remove_at(idx)
		var world_pos = _cell_to_world(cell.x, cell.y)
		# 在街区内部找一个随机位置
		var offset_x = rng.randf() * (block_size - 4) + 2
		var offset_z = rng.randf() * (block_size - 4) + 2
		var pos = world_pos + Vector3(offset_x, 0, offset_z)
		# 实例化楼梯
		var stair = StairScene.instantiate()
		# 设置楼梯参数（假设模块有这些属性）
		# 您可以按需调整，这里使用随机值
		stair.order = rng.randi_range(5, 12)
		stair.stepLength = 0.3 + rng.randf() * 0.4
		stair.stepWidth = 1.0 + rng.randf() * 1.0
		stair.heightDifference = 0.15 + rng.randf() * 0.15
		stair.position = pos
		add_child(stair)
		placed += 1

# ==================== 新增：栏杆生成 ====================
func _generate_railings():
	if not enable_railings:
		return
	# 沿道路生成栏杆，随机选择一些道路段
	var total_w = city_size.x * (block_size + road_width) + road_width
	var total_d = city_size.y * (block_size + road_width) + road_width
	
	# 横向道路（z方向）
	for z in range(city_size.y + 1):
		if rng.randf() > railing_probability:
			continue
		var rz = z * (block_size + road_width)
		# 在道路一侧生成栏杆（例如左侧）
		var start = Vector3(0, 0, rz - road_width/2 - 0.5)  # 稍微偏移
		var end = Vector3(total_w, 0, rz - road_width/2 - 0.5)
		_place_railing(start, end)
	# 纵向道路（x方向）
	for x in range(city_size.x + 1):
		if rng.randf() > railing_probability:
			continue
		var rx = x * (block_size + road_width)
		var start = Vector3(rx - road_width/2 - 0.5, 0, 0)
		var end = Vector3(rx - road_width/2 - 0.5, 0, total_d)
		_place_railing(start, end)

func _place_railing(start: Vector3, end: Vector3):
	var railing = RailingScene.instantiate()
	railing.start_point = start
	railing.end_point = end
	# 设置其他参数（使用默认值或随机）
	railing.pillar_spacing = 2.0 + rng.randf() * 1.0
	railing.pillar_height = 1.0 + rng.randf() * 0.5
	railing.pillar_radius = 0.05 + rng.randf() * 0.05
	railing.rail_thickness = 0.1
	railing.rail_depth = 0.08
	railing.rail_offsets = [0.2, 0.8]  # 上下两根
	# 材质可设置默认，或使用模块内部默认
	add_child(railing)

# ==================== 新增：复杂树生成（仅在公园区域）====================
func _generate_complex_trees(zone_map: Array):
	if not enable_complex_trees or complex_tree_count <= 0:
		return
	# 收集公园区域坐标
	var park_cells = []
	for x in range(city_size.x):
		for z in range(city_size.y):
			if zone_map[x][z] == ZoneType.ZONE_PARK:
				park_cells.append(Vector2(x, z))
	if park_cells.is_empty():
		# 若没有公园，随机放一些在住宅区边缘
		for x in range(city_size.x):
			for z in range(city_size.y):
				if zone_map[x][z] == ZoneType.ZONE_RESIDENTIAL and rng.randf() < 0.1:
					park_cells.append(Vector2(x, z))
	if park_cells.is_empty():
		park_cells = [Vector2(city_size.x/2, city_size.y/2)]
	
	var placed = 0
	while placed < complex_tree_count and park_cells.size() > 0:
		var idx = rng.randi() % park_cells.size()
		var cell = park_cells[idx]
		park_cells.remove_at(idx)
		var world_pos = _cell_to_world(cell.x, cell.y)
		var offset_x = rng.randf() * block_size
		var offset_z = rng.randf() * block_size
		var pos = world_pos + Vector3(offset_x, 0, offset_z)
		# 实例化复杂树
		var tree = ComplexTreeScene.instantiate()
		tree.random_seed = rng.randi()
		tree.trunk_height = 2.0 + rng.randf() * 3.0
		tree.trunk_radius = 0.15 + rng.randf() * 0.1
		tree.max_levels = rng.randi_range(3, 5)
		tree.branch_angle = 30 + rng.randf() * 20
		tree.length_decay = 0.7 + rng.randf() * 0.15
		tree.radius_decay = 0.7 + rng.randf() * 0.15
		tree.branch_segments = 8
		tree.leaf_size = 0.3 + rng.randf() * 0.2
		tree.position = pos
		add_child(tree)
		placed += 1

# ==================== 辅助函数 ====================
# 将街区坐标转为世界坐标（街区左下角）
func _cell_to_world(cx: int, cz: int) -> Vector3:
	var x = cx * (block_size + road_width) + road_width
	var z = cz * (block_size + road_width) + road_width
	return Vector3(x, 0, z)

# ==================== 地面 ====================
func _generate_ground():
	var total_w = city_size.x * (block_size + road_width) + road_width
	var total_d = city_size.y * (block_size + road_width) + road_width
	var ground = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(total_w, 0.3, total_d)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.28, 0.25)
	mat.roughness = 0.9
	mesh.material = mat
	ground.mesh = mesh
	ground.position = Vector3(total_w/2, -0.15, total_d/2)
	add_child(ground)

	# 地面碰撞
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(total_w, 0.3, total_d)
	collision_shape.shape = box_shape
	collision_shape.position = ground.position
	static_body.add_child(collision_shape)
	add_child(static_body)

# ==================== 道路与标线 ====================
func _generate_roads_and_markings():
	var total_w = city_size.x * (block_size + road_width) + road_width
	var total_d = city_size.y * (block_size + road_width) + road_width
	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.15, 0.15, 0.15)
	road_mat.roughness = 0.9

	# 横向道路
	for z in range(city_size.y + 1):
		var rz = z * (block_size + road_width)
		var road = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(total_w, 0.2, road_width)
		mesh.material = road_mat
		road.mesh = mesh
		road.position = Vector3(total_w/2, 0.1, rz)
		add_child(road)
		# 虚线
		if z < city_size.y:
			for x in range(0, int(total_w), 8):
				var dot = MeshInstance3D.new()
				var dmesh = BoxMesh.new()
				dmesh.size = Vector3(2.0, 0.25, 0.4)
				var dmat = StandardMaterial3D.new()
				dmat.albedo_color = Color.WHITE
				dmesh.material = dmat
				dot.mesh = dmesh
				dot.position = Vector3(x + 4, 0.25, rz + road_width/2)
				add_child(dot)

	# 纵向道路
	for x in range(city_size.x + 1):
		var rx = x * (block_size + road_width)
		var road = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(road_width, 0.2, total_d)
		mesh.material = road_mat
		road.mesh = mesh
		road.position = Vector3(rx, 0.1, total_d/2)
		add_child(road)
		if x < city_size.x:
			for z in range(0, int(total_d), 8):
				var dot = MeshInstance3D.new()
				var dmesh = BoxMesh.new()
				dmesh.size = Vector3(0.4, 0.25, 2.0)
				var dmat = StandardMaterial3D.new()
				dmat.albedo_color = Color.WHITE
				dmesh.material = dmat
				dot.mesh = dmesh
				dot.position = Vector3(rx + road_width/2, 0.25, z + 4)
				add_child(dot)

	# 人行道
	var sidewalk_mat = StandardMaterial3D.new()
	sidewalk_mat.albedo_color = Color(0.6, 0.6, 0.6)
	sidewalk_mat.roughness = 0.8
	for z in range(city_size.y + 1):
		var rz = z * (block_size + road_width)
		for side in [-1, 1]:
			var sw = MeshInstance3D.new()
			var smesh = BoxMesh.new()
			smesh.size = Vector3(total_w, 0.25, 1.5)
			smesh.material = sidewalk_mat
			sw.mesh = smesh
			sw.position = Vector3(total_w/2, 0.2, rz + side * (road_width/2 + 0.75))
			add_child(sw)
	for x in range(city_size.x + 1):
		var rx = x * (block_size + road_width)
		for side in [-1, 1]:
			var sw = MeshInstance3D.new()
			var smesh = BoxMesh.new()
			smesh.size = Vector3(1.5, 0.25, total_d)
			smesh.material = sidewalk_mat
			sw.mesh = smesh
			sw.position = Vector3(rx + side * (road_width/2 + 0.75), 0.2, total_d/2)
			add_child(sw)

# ==================== 区域地图 ====================
func _generate_zone_map() -> Array:
	var map = []
	var center_x = city_size.x / 2.0
	var center_z = city_size.y / 2.0
	var max_dist = max(center_x, center_z) * 1.2

	for x in range(city_size.x):
		var row = []
		for z in range(city_size.y):
			var dx = (x + 0.5) - center_x
			var dz = (z + 0.5) - center_z
			var dist = sqrt(dx*dx + dz*dz)
			var norm_dist = dist / max_dist

			var zone = ZoneType.ZONE_RESIDENTIAL
			if norm_dist < 0.25:
				zone = ZoneType.ZONE_COMMERCIAL
			elif norm_dist < 0.6:
				zone = ZoneType.ZONE_RESIDENTIAL
			else:
				zone = ZoneType.ZONE_INDUSTRIAL

			# 随机扰动
			if rng.randf() < 0.1:
				var choices = [ZoneType.ZONE_RESIDENTIAL, ZoneType.ZONE_COMMERCIAL, ZoneType.ZONE_INDUSTRIAL]
				zone = choices[rng.randi() % choices.size()]
			if rng.randf() < 0.05:
				zone = ZoneType.ZONE_PARK

			row.append(zone)
		map.append(row)
	return map

# ==================== 建筑生成（含屋顶、区域颜色、LOD）====================
func _generate_buildings_with_lod(zone_map: Array) -> int:
	var total_w = city_size.x * (block_size + road_width) + road_width
	var total_d = city_size.y * (block_size + road_width) + road_width
	var center = Vector2(total_w/2, total_d/2)
	var sub_grids = 3
	var sub_size = block_size / sub_grids

	# 收集建筑数据
	var building_data: Array[Dictionary] = []

	for x in range(city_size.x):
		for z in range(city_size.y):
			var zone = zone_map[x][z]
			var cfg = zone_configs[zone]
			var density = cfg["density"]
			var h_min = cfg["height_min"]
			var h_max = cfg["height_max"]
			var base_color = cfg["color"]
			var roof_weights = cfg["roof_weights"]

			var block_origin = Vector3(
				x * (block_size + road_width) + road_width,
				0,
				z * (block_size + road_width) + road_width
			)
			var block_center = block_origin + Vector3(block_size/2, 0, block_size/2)
			var dist_ratio = min(1.0, Vector2(block_center.x, block_center.z).distance_to(center) / (total_w * 0.6))
			var height_mult = 1.0 - dist_ratio * 0.7

			for i in range(sub_grids):
				for j in range(sub_grids):
					if rng.randf() > density:
						continue
					var base_h = h_min + rng.randf() * (h_max - h_min)
					var h = clampf(base_h * height_mult, 1.0, h_max * 1.2)
					var w = sub_size * (0.3 + rng.randf() * 0.5)
					var d = sub_size * (0.3 + rng.randf() * 0.5)
					var offset_x = rng.randf() * (sub_size - w)
					var offset_z = rng.randf() * (sub_size - d)
					var pos = block_origin + Vector3(
						i * sub_size + offset_x,
						h / 2.0,
						j * sub_size + offset_z
					)
					building_data.append({
						"position": pos,
						"size": Vector3(w, h, d),
						"color": base_color,
						"roof_weights": roof_weights,
						"height": h
					})

	var count = building_data.size()
	if count == 0:
		print("警告：无建筑")
		return 0

	# ---------- 生成网格 ----------
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	st.set_smooth_group(-1)

	# 单位立方体顶点和UV（每个面独立，共24个顶点）
	var unit_verts = []
	var unit_uvs = []
	# 六个面：前、后、左、右、上、下（每个面4个顶点）
	var face_verts = [
		[Vector3(-0.5,-0.5,-0.5), Vector3(0.5,-0.5,-0.5), Vector3(0.5,0.5,-0.5), Vector3(-0.5,0.5,-0.5)],
		[Vector3(0.5,-0.5,0.5), Vector3(-0.5,-0.5,0.5), Vector3(-0.5,0.5,0.5), Vector3(0.5,0.5,0.5)],
		[Vector3(-0.5,-0.5,0.5), Vector3(-0.5,-0.5,-0.5), Vector3(-0.5,0.5,-0.5), Vector3(-0.5,0.5,0.5)],
		[Vector3(0.5,-0.5,-0.5), Vector3(0.5,-0.5,0.5), Vector3(0.5,0.5,0.5), Vector3(0.5,0.5,-0.5)],
		[Vector3(-0.5,0.5,-0.5), Vector3(0.5,0.5,-0.5), Vector3(0.5,0.5,0.5), Vector3(-0.5,0.5,0.5)],
		[Vector3(-0.5,-0.5,0.5), Vector3(0.5,-0.5,0.5), Vector3(0.5,-0.5,-0.5), Vector3(-0.5,-0.5,-0.5)]
	]
	var face_uv = [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)]
	var tri_idx = [0,1,2, 0,2,3]
	for face in face_verts:
		for idx in tri_idx:
			unit_verts.append(face[idx])
			unit_uvs.append(face_uv[idx])

	# 预处理屋顶几何（缓存）
	var roof_cache = {}

	for data in building_data:
		var pos = data.position
		var size = data.size
		var color = data.color
		var roof_weights = data.roof_weights

		# 主体
		for vi in range(unit_verts.size()):
			var v = unit_verts[vi]
			var world_pos = Vector3(v.x * size.x, v.y * size.y, v.z * size.z) + pos
			st.set_color(color)
			st.set_uv(unit_uvs[vi])
			st.add_vertex(world_pos)

		# 屋顶
		var roof_type = _weighted_random(roof_weights, rng)
		# 使用缓存（可优化）
		var key = str(roof_type) + "_" + str(size)
		if not roof_cache.has(key):
			var roof_data = _get_roof_geometry(roof_type, size, rng)
			roof_cache[key] = roof_data
		var roof_data = roof_cache[key]
		var roof_verts = roof_data[0]
		var roof_uvs = roof_data[1]
		for ri in range(roof_verts.size()):
			st.set_color(color)
			st.set_uv(roof_uvs[ri])
			st.add_vertex(roof_verts[ri] + pos)

	st.generate_normals()
	var mesh = st.commit()

	# ---------- 材质 ----------
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true   # 顶点颜色做主色
	# 窗户纹理叠加（发射）
	var window_tex = _create_window_texture()
	mat.emission_enabled = true
	mat.emission_texture = window_tex
	mat.emission_energy_multiplier = 0.1
	mat.emission = Color(1,1,1)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.visibility_range_end = low_lod_distance
	add_child(mesh_instance)

	# 碰撞体（每个建筑盒体）
	if generate_collision:
		for data in building_data:
			var pos = data.position
			var size = data.size
			var box = BoxShape3D.new()
			box.size = size
			var body = StaticBody3D.new()
			var shape = CollisionShape3D.new()
			shape.shape = box
			shape.position = pos
			body.add_child(shape)
			add_child(body)

	return count

# ==================== 屋顶几何生成 ====================
func _get_roof_geometry(roof_type: int, size: Vector3, rng: RandomNumberGenerator) -> Array:
	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var h = size.y
	var w = size.x
	var d = size.z
	var top_y = h / 2.0

	match roof_type:
		0:  # 平顶 - 不添加额外几何
			pass
		1:  # 尖顶（金字塔）
			var peak_height = w * 0.3 + rng.randf() * 0.5
			var peak = Vector3(0, top_y + peak_height, 0)
			var corners = [
				Vector3(-w/2, top_y, -d/2),
				Vector3( w/2, top_y, -d/2),
				Vector3( w/2, top_y,  d/2),
				Vector3(-w/2, top_y,  d/2)
			]
			for i in range(4):
				var p0 = corners[i]
				var p1 = corners[(i+1)%4]
				verts.append(p0); verts.append(p1); verts.append(peak)
				uvs.append(Vector2(0,0)); uvs.append(Vector2(1,0)); uvs.append(Vector2(0.5,1))
		2:  # 圆顶（半球）
			var radius = min(w, d) * 0.4
			var segments = 8
			var rings = 4
			var center = Vector3(0, top_y, 0)
			for i in range(segments):
				var theta1 = i * 2 * PI / segments
				var theta2 = (i+1) * 2 * PI / segments
				for j in range(rings):
					var phi1 = j * PI / 2 / rings
					var phi2 = (j+1) * PI / 2 / rings
					var p00 = center + Vector3(radius * sin(phi1) * cos(theta1), radius * cos(phi1), radius * sin(phi1) * sin(theta1))
					var p01 = center + Vector3(radius * sin(phi1) * cos(theta2), radius * cos(phi1), radius * sin(phi1) * sin(theta2))
					var p10 = center + Vector3(radius * sin(phi2) * cos(theta1), radius * cos(phi2), radius * sin(phi2) * sin(theta1))
					var p11 = center + Vector3(radius * sin(phi2) * cos(theta2), radius * cos(phi2), radius * sin(phi2) * sin(theta2))
					verts.append(p00); verts.append(p10); verts.append(p01)
					verts.append(p01); verts.append(p10); verts.append(p11)
					for _k in range(6):
						uvs.append(Vector2(float(i)/segments, float(j)/rings))
		3:  # 天线
			var pole_height = rng.randf() * 2.0 + 1.0
			var pole_w = 0.12
			var pole_d = 0.12
			var pole_h = pole_height
			var pole_pos = Vector3(0, top_y + pole_h/2, 0)
			# 柱体（用立方体近似）
			var half = Vector3(pole_w/2, pole_h/2, pole_d/2)
			var corners = [
				Vector3(-half.x, -half.y, -half.z),
				Vector3( half.x, -half.y, -half.z),
				Vector3( half.x,  half.y, -half.z),
				Vector3(-half.x,  half.y, -half.z),
				Vector3(-half.x, -half.y,  half.z),
				Vector3( half.x, -half.y,  half.z),
				Vector3( half.x,  half.y,  half.z),
				Vector3(-half.x,  half.y,  half.z)
			]
			var idx = [0,1,2, 0,2,3,  4,6,5, 4,7,6,  0,3,7, 0,7,4,  1,5,6, 1,6,2,  3,2,6, 3,6,7,  0,4,5, 0,5,1]
			for i in idx:
				verts.append(corners[i] + pole_pos)
				uvs.append(Vector2(0,0))
			# 顶部小球
			var ball_radius = 0.2
			var ball_pos = Vector3(0, top_y + pole_h + ball_radius, 0)
			var seg_ball = 6
			for i in range(seg_ball):
				var theta1 = i * 2 * PI / seg_ball
				var theta2 = (i+1) * 2 * PI / seg_ball
				for j in range(seg_ball/2):
					var phi1 = j * PI / (seg_ball/2)
					var phi2 = (j+1) * PI / (seg_ball/2)
					var p00 = ball_pos + Vector3(ball_radius * sin(phi1) * cos(theta1), ball_radius * cos(phi1), ball_radius * sin(phi1) * sin(theta1))
					var p01 = ball_pos + Vector3(ball_radius * sin(phi1) * cos(theta2), ball_radius * cos(phi1), ball_radius * sin(phi1) * sin(theta2))
					var p10 = ball_pos + Vector3(ball_radius * sin(phi2) * cos(theta1), ball_radius * cos(phi2), ball_radius * sin(phi2) * sin(theta1))
					var p11 = ball_pos + Vector3(ball_radius * sin(phi2) * cos(theta2), ball_radius * cos(phi2), ball_radius * sin(phi2) * sin(theta2))
					verts.append(p00); verts.append(p10); verts.append(p01)
					verts.append(p01); verts.append(p10); verts.append(p11)
					for _k in range(6):
						uvs.append(Vector2(0,0))
	return [verts, uvs]

# ==================== 辅助函数 ====================
func _weighted_random(weights: Array, rng: RandomNumberGenerator) -> int:
	var total = 0.0
	for w in weights:
		total += w
	var r = rng.randf() * total
	var cum = 0.0
	for i in range(weights.size()):
		cum += weights[i]
		if r <= cum:
			return i
	return weights.size() - 1

func _create_window_texture() -> Texture2D:
	var size = 64
	var img = Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.1, 0.15))
	for x in range(2, size - 2, 8):
		for y in range(2, size - 2, 8):
			var bright = 0.4 + rng.randf() * 0.6
			var c = Color(bright * 0.9, bright * 0.85, bright * 0.5)
			for dx in range(4):
				for dy in range(4):
					img.set_pixel(x + dx, y + dy, c)
	return ImageTexture.create_from_image(img)

func lerp(a, b, t): return a + (b - a) * t
func clampf(v, min_v, max_v): return max(min_v, min(max_v, v))

# ==================== 树木与路灯（MultiMesh优化）====================
func _generate_trees_and_lamps():
	if not optimize_props:
		return  # 可保留旧节点版本，此处省略

	var total_w = city_size.x * (block_size + road_width) + road_width
	var total_d = city_size.y * (block_size + road_width) + road_width

	# ---------- 树木 ----------
	var tree_positions: Array[Vector3] = []
	for x in range(city_size.x + 1):
		var rx = x * (block_size + road_width)
		for z in range(0, int(total_d), 8):
			if rng.randf() < tree_density:
				tree_positions.append(Vector3(rx + road_width/2, 0, z + 4))
				tree_positions.append(Vector3(rx - road_width/2, 0, z + 4))
	for z in range(city_size.y + 1):
		var rz = z * (block_size + road_width)
		for x in range(0, int(total_w), 8):
			if rng.randf() < tree_density:
				tree_positions.append(Vector3(x + 4, 0, rz + road_width/2))
				tree_positions.append(Vector3(x + 4, 0, rz - road_width/2))

	if tree_positions.size() > 0:
		# 树干
		var trunk_mesh = CylinderMesh.new()
		trunk_mesh.top_radius = 0.15
		trunk_mesh.bottom_radius = 0.2
		trunk_mesh.height = 1.5
		var trunk_mat = StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.3, 0.15, 0.05)
		trunk_mesh.material = trunk_mat

		var crown_mesh = SphereMesh.new()
		crown_mesh.radius = 0.8
		crown_mesh.height = 1.2
		var crown_mat = StandardMaterial3D.new()
		crown_mat.albedo_color = Color(0.2, 0.6, 0.1)
		crown_mat.roughness = 0.9
		crown_mesh.material = crown_mat

		var trunk_multi = MultiMesh.new()
		trunk_multi.mesh = trunk_mesh
		trunk_multi.instance_count = tree_positions.size()
		trunk_multi.transform_format = MultiMesh.TRANSFORM_3D

		var crown_multi = MultiMesh.new()
		crown_multi.mesh = crown_mesh
		crown_multi.instance_count = tree_positions.size()
		crown_multi.transform_format = MultiMesh.TRANSFORM_3D

		for i in range(tree_positions.size()):
			var pos = tree_positions[i]
			var t_trunk = Transform3D()
			t_trunk.origin = pos + Vector3(0, 0.75, 0)
			trunk_multi.set_instance_transform(i, t_trunk)
			var t_crown = Transform3D()
			t_crown.origin = pos + Vector3(0, 1.8, 0)
			crown_multi.set_instance_transform(i, t_crown)

		var trunk_instance = MultiMeshInstance3D.new()
		trunk_instance.multimesh = trunk_multi
		trunk_instance.visibility_range_end = prop_cull_distance
		add_child(trunk_instance)

		var crown_instance = MultiMeshInstance3D.new()
		crown_instance.multimesh = crown_multi
		crown_instance.visibility_range_end = prop_cull_distance
		add_child(crown_instance)

	# ---------- 路灯 ----------
	var lamp_positions: Array[Vector3] = []
	for x in range(city_size.x + 1):
		var rx = x * (block_size + road_width)
		for z in range(city_size.y + 1):
			var rz = z * (block_size + road_width)
			for dx in [-2, 2]:
				for dz in [-2, 2]:
					lamp_positions.append(Vector3(rx + dx, 0, rz + dz))

	if lamp_positions.size() > 0:
		var pole_mesh = CylinderMesh.new()
		pole_mesh.top_radius = 0.05
		pole_mesh.bottom_radius = 0.08
		pole_mesh.height = 2.5
		var pole_mat = StandardMaterial3D.new()
		pole_mat.albedo_color = Color(0.1, 0.1, 0.1)
		pole_mat.roughness = 0.5
		pole_mesh.material = pole_mat

		var arm_mesh = BoxMesh.new()
		arm_mesh.size = Vector3(0.6, 0.1, 0.1)
		var arm_mat = StandardMaterial3D.new()
		arm_mat.albedo_color = Color(0.1, 0.1, 0.1)
		arm_mat.roughness = 0.5
		arm_mesh.material = arm_mat

		var bulb_mesh = SphereMesh.new()
		bulb_mesh.radius = 0.15
		bulb_mesh.height = 0.15
		var bulb_mat = StandardMaterial3D.new()
		bulb_mat.albedo_color = Color(1.0, 0.9, 0.5)
		bulb_mat.emission_enabled = true
		bulb_mat.emission = Color(1.0, 0.8, 0.4)
		bulb_mat.emission_energy_multiplier = 0.8
		bulb_mesh.material = bulb_mat

		var pole_multi = MultiMesh.new()
		pole_multi.mesh = pole_mesh
		pole_multi.instance_count = lamp_positions.size()
		pole_multi.transform_format = MultiMesh.TRANSFORM_3D

		var arm_multi = MultiMesh.new()
		arm_multi.mesh = arm_mesh
		arm_multi.instance_count = lamp_positions.size()
		arm_multi.transform_format = MultiMesh.TRANSFORM_3D

		var bulb_multi = MultiMesh.new()
		bulb_multi.mesh = bulb_mesh
		bulb_multi.instance_count = lamp_positions.size()
		bulb_multi.transform_format = MultiMesh.TRANSFORM_3D

		for i in range(lamp_positions.size()):
			var pos = lamp_positions[i]
			var t_pole = Transform3D()
			t_pole.origin = pos + Vector3(0, 1.25, 0)
			pole_multi.set_instance_transform(i, t_pole)

			var t_arm = Transform3D()
			t_arm.origin = pos + Vector3(0.3, 2.5, 0)
			arm_multi.set_instance_transform(i, t_arm)

			var t_bulb = Transform3D()
			t_bulb.origin = pos + Vector3(0.6, 2.5, 0)
			bulb_multi.set_instance_transform(i, t_bulb)

		var pole_instance = MultiMeshInstance3D.new()
		pole_instance.multimesh = pole_multi
		pole_instance.visibility_range_end = prop_cull_distance
		add_child(pole_instance)

		var arm_instance = MultiMeshInstance3D.new()
		arm_instance.multimesh = arm_multi
		arm_instance.visibility_range_end = prop_cull_distance
		add_child(arm_instance)

		var bulb_instance = MultiMeshInstance3D.new()
		bulb_instance.multimesh = bulb_multi
		bulb_instance.visibility_range_end = prop_cull_distance
		add_child(bulb_instance)
