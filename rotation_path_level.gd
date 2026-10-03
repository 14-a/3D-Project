extends Node3D

const TILE_SIZE := 4.2
const WALKWAY_WIDTH := 1.25
const WALKWAY_HEIGHT := 0.45
const ROTATION_STEP := PI / 2.0

var player: CharacterBody3D
var modules: Array[Node3D] = []
var rotation_count := 0
var status_label: Label
var result_label: Label
var start_position := Vector3(-TILE_SIZE, 1.8, TILE_SIZE)

var route_masks := {
	Vector2i(-1, 1): 2,
	Vector2i(0, 1): 10,
	Vector2i(1, 1): 9,
	Vector2i(1, 0): 5,
	Vector2i(1, -1): 1,
}

func _ready() -> void:
	_build_environment()
	_build_modules()
	_build_player()
	_build_ui()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("旋转"):
		_rotate_modules()
	if player.position.y < -3.0:
		_reset_player("路径断开，已回到起点")
	if player.position.distance_to(Vector3(TILE_SIZE, 0.9, -TILE_SIZE)) < 1.1:
		result_label.text = "路线完成\n按 R 可以继续观察模块状态"
		result_label.modulate = Color("#8af0b6")

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0b1320")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#94a9c8")
	environment.ambient_light_energy = 0.55
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	key_light.light_energy = 1.5
	key_light.shadow_enabled = true
	add_child(key_light)

	var pit := MeshInstance3D.new()
	var pit_mesh := PlaneMesh.new()
	pit_mesh.size = Vector2(22.0, 22.0)
	pit.mesh = pit_mesh
	pit.position.y = -2.2
	pit.material_override = _material(Color("#111b2b"), 0.9, 0.0)
	add_child(pit)

func _build_modules() -> void:
	for z in range(-1, 2):
		for x in range(-1, 2):
			var coordinate := Vector2i(x, z)
			var desired_mask: int = route_masks.get(coordinate, _decoy_mask(coordinate))
			var local_mask := _rotate_mask(desired_mask, 2)
			var module := _create_module(coordinate, local_mask)
			modules.append(module)
			add_child(module)

func _create_module(coordinate: Vector2i, mask: int) -> Node3D:
	var module := Node3D.new()
	module.name = "旋转模块_%d_%d" % [coordinate.x, coordinate.y]
	module.position = Vector3(coordinate.x * TILE_SIZE, 0.0, coordinate.y * TILE_SIZE)
	module.set_meta("rotation_index", 0)

	var body := StaticBody3D.new()
	body.name = "PathCollision"
	module.add_child(body)
	_add_box(module, body, Vector3(0.0, WALKWAY_HEIGHT / 2.0, 0.0), Vector3(WALKWAY_WIDTH, WALKWAY_HEIGHT, WALKWAY_WIDTH), Color("#e8b45f"))
	var directions := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	for index in directions.size():
		if mask & (1 << index):
			var direction: Vector3 = directions[index]
			var segment_position := direction * 1.25
			var segment_size := Vector3(WALKWAY_WIDTH, WALKWAY_HEIGHT, 2.5)
			if abs(direction.x) > 0.5:
				segment_size = Vector3(2.5, WALKWAY_HEIGHT, WALKWAY_WIDTH)
			_add_box(module, body, Vector3(segment_position.x, WALKWAY_HEIGHT / 2.0, segment_position.z), segment_size, Color("#f2ca72"))

	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(3.75, 0.08, 3.75)
	marker.mesh = marker_mesh
	marker.position.y = -0.08
	marker.material_override = _material(Color("#22334a"), 0.96, 0.0)
	module.add_child(marker)
	return module

func _add_box(module: Node3D, body: StaticBody3D, box_position: Vector3, box_size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh_instance.mesh = mesh
	mesh_instance.position = box_position
	mesh_instance.material_override = _material(color, 0.7, 0.05)
	module.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	collision.position = box_position
	body.add_child(collision)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = start_position
	player.set_script(load("res://player.gd"))
	add_child(player)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 1.45
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(Color("#58c7ff"), 0.38, 0.15)
	mesh_instance.position.y = 0.7
	player.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.45
	collision.shape = shape
	collision.position.y = 0.7
	player.add_child(collision)

	var camera := Camera3D.new()
	camera.position = Vector3(11.5, 14.0, 15.5)
	camera.look_at_from_position(camera.position, Vector3.ZERO)
	add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(24.0, 24.0)
	panel.size = Vector2(390.0, 142.0)
	panel.color = Color(0.03, 0.07, 0.13, 0.86)
	layer.add_child(panel)

	var title := Label.new()
	title.position = Vector2(20.0, 14.0)
	title.text = "ROTATION PATH / 01"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#f5cc79"))
	panel.add_child(title)

	status_label = Label.new()
	status_label.position = Vector2(20.0, 53.0)
	status_label.text = "WASD 移动    R 旋转全部模块\n沿金色路径走到右上角的绿色终点"
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#d6e2f3"))
	panel.add_child(status_label)

	result_label = Label.new()
	result_label.position = Vector2(24.0, 184.0)
	result_label.text = "模块旋转次数：0"
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.add_theme_color_override("font_color", Color("#ffffff"))
	layer.add_child(result_label)

	var goal := Label.new()
	goal.text = "EXIT"
	goal.add_theme_font_size_override("font_size", 18)
	goal.add_theme_color_override("font_color", Color("#8af0b6"))
	goal.position = Vector2(930.0, 690.0)
	layer.add_child(goal)

func _rotate_modules() -> void:
	rotation_count += 1
	for module in modules:
		module.rotation.y += ROTATION_STEP
	result_label.text = "模块旋转次数：%d" % rotation_count
	result_label.modulate = Color("#ffffff")

func _reset_player(message: String) -> void:
	player.position = start_position
	player.velocity = Vector3.ZERO
	result_label.text = message
	result_label.modulate = Color("#ffb4a8")

func _decoy_mask(coordinate: Vector2i) -> int:
	return [3, 6, 12, 5][abs(coordinate.x * 3 + coordinate.y) % 4]

func _rotate_mask(mask: int, turns: int) -> int:
	var rotated := mask
	for _index in turns:
		rotated = ((rotated << 1) & 15) | ((rotated >> 3) & 1)
	return rotated

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
