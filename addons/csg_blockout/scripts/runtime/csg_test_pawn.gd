class_name CSGBlockoutTestPawn
extends CharacterBody3D
## First-person test character spawned by "Play From Here".
## Reads physical keys directly (no InputMap changes): WASD / arrows move, Space
## jumps, Shift sprints, Ctrl crouches, R respawns, Esc frees the mouse.
## Its numbers come from the player metrics: the jump reaches single_jump_height and
## a sprint jump on flat ground covers sprint_jump_distance, the same values the
## level ruler and checks use. Runtime script: must not reference editor classes.

const MOUSE_SENSITIVITY: float = 0.0025
const EYE_OFFSET: float = 0.12
const ACCELERATION: float = 40.0

var metrics: Dictionary = {}
var spawn: Transform3D = Transform3D.IDENTITY
## False for automated runs, so the real mouse is never grabbed.
var capture_mouse: bool = true
## Localized controls line provided by the editor (runtime has no i18n tables).
var hud_text: String = ""

var _camera: Camera3D
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _hud: Label
var _gravity: float = 9.8
var _walk_speed: float = 5.0
var _sprint_speed: float = 7.0
var _jump_velocity: float = 5.0
var _height: float = 1.8
var _crouch_height: float = 1.0
var _crouched: bool = false
var _pitch: float = 0.0

func setup(p_metrics: Dictionary, p_spawn: Transform3D) -> void:
	metrics = p_metrics
	spawn = p_spawn
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_height = float(metrics.get("character_height", 1.8))
	_crouch_height = minf(float(metrics.get("crouch_height", 1.0)), _height)
	var radius: float = minf(float(metrics.get("capsule_radius", 0.35)), _height * 0.5)
	var jump_height: float = float(metrics.get("single_jump_height", 1.5))
	var jump_distance: float = float(metrics.get("sprint_jump_distance", 4.0))
	_walk_speed = float(metrics.get("walk_speed", 5.0))
	_jump_velocity = sqrt(2.0 * _gravity * jump_height)
	# Time in the air for a jump on flat ground; sprinting covers jump_distance in it.
	var airtime: float = 2.0 * _jump_velocity / _gravity
	_sprint_speed = jump_distance / airtime
	# Walking never outruns sprinting, so no jump exceeds sprint_jump_distance.
	_walk_speed = minf(_walk_speed, _sprint_speed)
	floor_max_angle = deg_to_rad(float(metrics.get("max_slope_angle", 45.0)))
	floor_snap_length = 0.3

	_capsule = CapsuleShape3D.new()
	_capsule.radius = radius
	_capsule.height = _height
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = _height * 0.5
	add_child(_shape)

	_camera = Camera3D.new()
	_camera.position.y = _height - EYE_OFFSET
	_camera.fov = 75.0
	_camera.near = 0.05
	add_child(_camera)

	var layer: CanvasLayer = CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_color_override(&"font_color", Color(1, 1, 1))
	_hud.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(_hud)
	add_child(layer)

func _ready() -> void:
	global_transform = spawn
	_camera.make_current()
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func respawn() -> void:
	global_transform = spawn
	velocity = Vector3.ZERO
	_pitch = 0.0
	_camera.rotation.x = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-mm.screen_relative.x * MOUSE_SENSITIVITY)
		_pitch = clampf(_pitch - mm.screen_relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		_camera.rotation.x = _pitch
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).physical_keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_R:
				respawn()
	elif event is InputEventMouseButton and event.is_pressed() and capture_mouse and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_update_crouch()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_physical_key_pressed(KEY_SPACE) and not _crouched:
		velocity.y = _jump_velocity
	var input: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0
	var dir: Vector3 = (global_transform.basis * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	dir = dir.normalized()
	var speed: float = _walk_speed
	if Input.is_physical_key_pressed(KEY_SHIFT) and not _crouched:
		speed = _sprint_speed
	elif _crouched:
		speed = _walk_speed * 0.5
	var target: Vector3 = dir * speed
	var accel: float = ACCELERATION if is_on_floor() else ACCELERATION * 0.25
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	move_and_slide()
	if global_position.y < spawn.origin.y - 100.0:
		respawn()
	_update_hud()

func _update_crouch() -> void:
	var want: bool = Input.is_physical_key_pressed(KEY_CTRL)
	if want == _crouched:
		return
	if not want and not _can_stand():
		return
	_crouched = want
	var h: float = _crouch_height if _crouched else _height
	_capsule.height = maxf(h, _capsule.radius * 2.0)
	_shape.position.y = _capsule.height * 0.5
	_camera.position.y = h - EYE_OFFSET

## True when nothing blocks standing up from a crouch.
func _can_stand() -> bool:
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var tall: CapsuleShape3D = CapsuleShape3D.new()
	tall.radius = _capsule.radius * 0.9
	tall.height = _height
	params.shape = tall
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, _height * 0.5 + 0.02, 0))
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()

func _update_hud() -> void:
	var flat: Vector2 = Vector2(velocity.x, velocity.z)
	var controls: String = hud_text if not hud_text.is_empty() else "WASD move · Space jump · Shift sprint · Ctrl crouch · R respawn · Esc mouse · F8 stop"
	_hud.text = "CSG Blockout · Play From Here\n%s\n%.1f m/s%s" % [controls, flat.length(), "  (crouched)" if _crouched else ""]
