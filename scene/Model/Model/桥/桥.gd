@tool
extends Node3D
class_name 桥

# ========== 可调参数 ==========
@export var bridge_length : float = 10.0:
	set(v):
		bridge_length = v
		generate_bridge()
@export var bridge_width  : float = 3.0:
	set(v):
		bridge_width = v
		generate_bridge()
@export var deck_thickness: float = 0.3:
	set(v):
		deck_thickness = v
		generate_bridge()
@export var deck_height   : float = 2.0:
	set(v):
		deck_height = v
		generate_bridge()          # 桥面离地高度

@export var pillar_radius : float = 0.2:
	set(v):
		pillar_radius = v
		generate_bridge()
@export var pillar_count  : int   = 4:
	set(v):
		pillar_count = v
		generate_bridge()            # 桥墩数量（至少2）
@export var pillar_offset : float = 1.0:
	set(v):
		pillar_offset = v
		generate_bridge()          # 首尾桥墩离桥端距离

@export var rail_height   : float = 0.8:
	set(v):
		rail_height = v
		generate_bridge()
@export var rail_radius   : float = 0.05:
	set(v):
		rail_radius = v
		generate_bridge()
@export var rail_pillar_spacing : float = 1.0:
	set(v):
		rail_pillar_spacing = v
		generate_bridge()    # 栏杆立柱间距

@export var material_floor : Material = null     # 可指定材质，否则使用默认
@export var material_pillar: Material = null
@export var material_rail  : Material = null

# ========== 生成入口 ==========
func _ready() -> void:
	generate_bridge()

func generate_bridge() -> void:
	# 清除旧的子节点
	for child in get_children():
		child.queue_free()
	#await get_tree().process_frame

	create_deck()
	create_pillars()
	create_rails()

# ========== 核心工具：生成带碰撞体的静态物体 ==========
func _add_physics_piece(mesh: Mesh, pos: Vector3, shape: Shape3D) -> void:
	var body = StaticBody3D.new()
	body.position = pos

	# 视觉网格
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)

	# 碰撞体
	var cs = CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

	add_child(body)

# ========== 1. 桥面 ==========
func create_deck() -> void:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(bridge_length, deck_thickness, bridge_width)
	
	# 材质处理
	if material_floor:
		mesh.material = material_floor
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.SADDLE_BROWN
		mesh.material = mat

	var shape = BoxShape3D.new()
	shape.size = mesh.size

	# 桥面中心在 (0, deck_height, 0)
	_add_physics_piece(mesh, Vector3(0, deck_height, 0), shape)

# ========== 2. 桥墩 ==========
func create_pillars() -> void:
	if pillar_count < 2:
		pillar_count = 2

	var mesh = CylinderMesh.new()
	mesh.top_radius = pillar_radius
	mesh.bottom_radius = pillar_radius
	mesh.height = deck_height   # 从地面到桥面底部

	if material_pillar:
		mesh.material = material_pillar
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.GRAY
		mesh.material = mat

	var shape = CylinderShape3D.new()
	shape.radius = pillar_radius
	shape.height = deck_height

	var step = (bridge_length - 2 * pillar_offset) / (pillar_count - 1)
	for i in range(pillar_count):
		var x = -bridge_length/2 + pillar_offset + i * step
		# 圆柱中心在几何中点，底部在地面 y=0，所以中心在 y = deck_height/2
		_add_physics_piece(mesh, Vector3(x, deck_height/2, 0), shape)

# ========== 3. 栏杆 ==========
func create_rails() -> void:
	for side in [-1, 1]:
		var z_offset = side * (bridge_width/2 + 0.1)

		# ---------- 立柱 ----------
		var pillar_mesh = CylinderMesh.new()
		pillar_mesh.top_radius = rail_radius
		pillar_mesh.bottom_radius = rail_radius
		pillar_mesh.height = rail_height

		if material_rail:
			pillar_mesh.material = material_rail
		else:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color.WHITE
			pillar_mesh.material = mat

		var pillar_shape = CylinderShape3D.new()
		pillar_shape.radius = rail_radius
		pillar_shape.height = rail_height

		var num_pillars = max(2, int(bridge_length / rail_pillar_spacing) + 1)
		var step = bridge_length / (num_pillars - 1)
		for i in range(num_pillars):
			var x = -bridge_length/2 + i * step
			var y_pos = deck_height + rail_height/2  # 立柱底部在桥面，中心向上偏移
			_add_physics_piece(pillar_mesh, Vector3(x, y_pos, z_offset), pillar_shape)

		# ---------- 横梁（上下两根） ----------
		for y_frac in [0.2, 0.8]:
			var beam_mesh = BoxMesh.new()
			beam_mesh.size = Vector3(bridge_length, 0.06, 0.06)

			if material_rail:
				beam_mesh.material = material_rail
			else:
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color.WHITE_SMOKE
				beam_mesh.material = mat

			var beam_shape = BoxShape3D.new()
			beam_shape.size = beam_mesh.size

			var y_pos = deck_height + y_frac * rail_height
			_add_physics_piece(beam_mesh, Vector3(0, y_pos, z_offset), beam_shape)
