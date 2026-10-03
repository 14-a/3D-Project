@tool
class_name GMSTransformGizmo
extends Node3D




enum Mode {
	NONE,
	MOVE,
	ROTATE,
	SCALE,
}

enum Orientation {
	GLOBAL,
	LOCAL,
}

const AXIS_X: int = 0
const AXIS_Y: int = 1
const AXIS_Z: int = 2
const HANDLE_PIXEL_LENGTH: float = 92.0
const HANDLE_PICK_RADIUS: float = 11.0
const RING_PICK_RADIUS: float = 10.0
const RING_SEGMENTS: int = 64
const RING_RADIUS: float = 0.82
const RING_HALF_WIDTH: float = 0.024

var mode: int = Mode.MOVE
var orientation: int = Orientation.GLOBAL

var _axis_colours: Array[Color] = [
	Color(0.92, 0.20, 0.20),
	Color(0.25, 0.85, 0.32),
	Color(0.22, 0.48, 1.0),
]
var _normal_materials: Array[StandardMaterial3D] = []
var _highlight_material: StandardMaterial3D
var _axis_parts: Array = [[], [], []]
var _move_roots: Array[Node3D] = []
var _scale_roots: Array[Node3D] = []
var _rotate_roots: Array[MeshInstance3D] = []
var _pivot_world: Vector3 = Vector3.ZERO
var _orientation_basis: Basis = Basis.IDENTITY
var _world_size: float = 1.0
var _hovered_axis: int = -1


func _ready() -> void:
	name = "TransformGizmo"
	_build_materials()
	_build_handles()
	visible = false


func set_mode(new_mode: int) -> void:
	mode = new_mode
	_refresh_mode_visibility()
	set_hovered_axis(-1)


func set_orientation(new_orientation: int) -> void:
	orientation = new_orientation


func update_state(
	camera: Camera3D,
	viewport_height: float,
	pivot_world: Vector3,
	orientation_basis: Basis,
	is_visible: bool
) -> void:
	visible = is_visible
	if not is_visible or camera == null:
		return

	_pivot_world = pivot_world
	_orientation_basis = orientation_basis.orthonormalized()
	_world_size = _calculate_world_size(camera, viewport_height)
	global_transform = Transform3D(
		_orientation_basis.scaled(Vector3.ONE * _world_size),
		_pivot_world
	)
	_refresh_mode_visibility()


func update_preview_pivot(
	camera: Camera3D,
	viewport_height: float,
	pivot_world: Vector3
) -> void:
	if not visible or camera == null:
		return
	_pivot_world = pivot_world
	_world_size = _calculate_world_size(camera, viewport_height)
	global_transform = Transform3D(
		_orientation_basis.scaled(Vector3.ONE * _world_size),
		_pivot_world
	)


func pick_axis(camera: Camera3D, screen_position: Vector2) -> int:
	if not visible or camera == null:
		return -1

	if mode == Mode.ROTATE:
		return _pick_rotation_axis(camera, screen_position)
	return _pick_linear_axis(camera, screen_position)


func set_hovered_axis(axis_index: int) -> void:
	if _hovered_axis == axis_index:
		return
	_hovered_axis = axis_index
	for current_axis: int in 3:
		_apply_axis_material(current_axis, current_axis == _hovered_axis)


func get_axis_world(axis_index: int) -> Vector3:
	match axis_index:
		AXIS_X:
			return (_orientation_basis * Vector3.RIGHT).normalized()
		AXIS_Y:
			return (_orientation_basis * Vector3.UP).normalized()
		AXIS_Z:
			return (_orientation_basis * Vector3.BACK).normalized()
		_:
			return Vector3.ZERO


func _build_materials() -> void:
	for colour: Color in _axis_colours:
		_normal_materials.append(_make_material(colour))
	_highlight_material = _make_material(Color(1.0, 0.78, 0.16))


func _make_material(colour: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material


func _build_handles() -> void:
	for axis_index: int in 3:
		var move_root: Node3D = Node3D.new()
		move_root.name = "Move%s" % _axis_name(axis_index)
		add_child(move_root)
		_move_roots.append(move_root)
		_build_linear_shaft(move_root, axis_index)
		_build_move_tip(move_root, axis_index)

		var scale_root: Node3D = Node3D.new()
		scale_root.name = "Scale%s" % _axis_name(axis_index)
		add_child(scale_root)
		_scale_roots.append(scale_root)
		_build_linear_shaft(scale_root, axis_index)
		_build_scale_tip(scale_root, axis_index)

		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.name = "Rotate%s" % _axis_name(axis_index)
		ring.mesh = _build_ring_mesh(axis_index, _normal_materials[axis_index])
		ring.material_override = _normal_materials[axis_index]
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rotate_roots.append(ring)
		_axis_parts[axis_index].append(ring)

	_refresh_mode_visibility()


func _build_linear_shaft(parent: Node3D, axis_index: int) -> void:
	var axis: Vector3 = _local_axis(axis_index)
	var shaft_mesh: CylinderMesh = CylinderMesh.new()
	shaft_mesh.top_radius = 0.016
	shaft_mesh.bottom_radius = 0.016
	shaft_mesh.height = 0.68
	shaft_mesh.radial_segments = 10

	var shaft: MeshInstance3D = MeshInstance3D.new()
	shaft.name = "Shaft"
	shaft.mesh = shaft_mesh
	shaft.material_override = _normal_materials[axis_index]
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.transform = Transform3D(_basis_from_y(axis), axis * 0.47)
	parent.add_child(shaft)
	_axis_parts[axis_index].append(shaft)


func _build_move_tip(parent: Node3D, axis_index: int) -> void:
	var axis: Vector3 = _local_axis(axis_index)
	var cone_mesh: CylinderMesh = CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.065
	cone_mesh.height = 0.22
	cone_mesh.radial_segments = 12

	var cone: MeshInstance3D = MeshInstance3D.new()
	cone.name = "Arrow"
	cone.mesh = cone_mesh
	cone.material_override = _normal_materials[axis_index]
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.transform = Transform3D(_basis_from_y(axis), axis * 0.92)
	parent.add_child(cone)
	_axis_parts[axis_index].append(cone)


func _build_scale_tip(parent: Node3D, axis_index: int) -> void:
	var axis: Vector3 = _local_axis(axis_index)
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE * 0.115

	var box: MeshInstance3D = MeshInstance3D.new()
	box.name = "Cube"
	box.mesh = box_mesh
	box.material_override = _normal_materials[axis_index]
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box.position = axis * 0.92
	parent.add_child(box)
	_axis_parts[axis_index].append(box)


func _build_ring_mesh(axis_index: int, material: Material) -> ImmediateMesh:
	var immediate: ImmediateMesh = ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for segment: int in RING_SEGMENTS:
		var angle_a: float = TAU * float(segment) / float(RING_SEGMENTS)
		var angle_b: float = TAU * float(segment + 1) / float(RING_SEGMENTS)
		var inner_a: Vector3 = _ring_point(axis_index, angle_a, RING_RADIUS - RING_HALF_WIDTH)
		var outer_a: Vector3 = _ring_point(axis_index, angle_a, RING_RADIUS + RING_HALF_WIDTH)
		var inner_b: Vector3 = _ring_point(axis_index, angle_b, RING_RADIUS - RING_HALF_WIDTH)
		var outer_b: Vector3 = _ring_point(axis_index, angle_b, RING_RADIUS + RING_HALF_WIDTH)

		immediate.surface_add_vertex(inner_a)
		immediate.surface_add_vertex(outer_a)
		immediate.surface_add_vertex(outer_b)
		immediate.surface_add_vertex(inner_a)
		immediate.surface_add_vertex(outer_b)
		immediate.surface_add_vertex(inner_b)
	immediate.surface_end()
	return immediate


func _refresh_mode_visibility() -> void:
	if _move_roots.size() < 3 or _scale_roots.size() < 3 or _rotate_roots.size() < 3:
		return
	for axis_index: int in 3:
		_move_roots[axis_index].visible = mode == Mode.MOVE
		_scale_roots[axis_index].visible = mode == Mode.SCALE
		_rotate_roots[axis_index].visible = mode == Mode.ROTATE


func _apply_axis_material(axis_index: int, highlighted: bool) -> void:
	var material: StandardMaterial3D = _highlight_material if highlighted else _normal_materials[axis_index]
	for part_value: Variant in _axis_parts[axis_index]:
		var part: MeshInstance3D = part_value as MeshInstance3D
		if part != null:
			part.material_override = material


func _calculate_world_size(camera: Camera3D, viewport_height: float) -> float:
	var safe_height: float = maxf(viewport_height, 1.0)
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return maxf(0.0001, camera.size * HANDLE_PIXEL_LENGTH / safe_height)

	var distance: float = maxf(camera.global_position.distance_to(_pivot_world), 0.01)
	var visible_height: float = 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5)
	return maxf(0.0001, visible_height * HANDLE_PIXEL_LENGTH / safe_height)


func _pick_linear_axis(camera: Camera3D, screen_position: Vector2) -> int:
	var pivot_screen: Vector2 = camera.unproject_position(_pivot_world)
	var best_axis: int = -1
	var best_distance: float = HANDLE_PICK_RADIUS

	for axis_index: int in 3:
		var endpoint_world: Vector3 = _pivot_world + get_axis_world(axis_index) * _world_size
		if camera.is_position_behind(endpoint_world):
			continue
		var endpoint_screen: Vector2 = camera.unproject_position(endpoint_world)
		var distance: float = _distance_to_segment(
			screen_position,
			pivot_screen.lerp(endpoint_screen, 0.12),
			endpoint_screen
		)
		if distance < best_distance:
			best_distance = distance
			best_axis = axis_index
	return best_axis


func _pick_rotation_axis(camera: Camera3D, screen_position: Vector2) -> int:
	var best_axis: int = -1
	var best_distance: float = RING_PICK_RADIUS

	for axis_index: int in 3:
		var tangent: Vector3 = get_axis_world((axis_index + 1) % 3)
		var bitangent: Vector3 = get_axis_world((axis_index + 2) % 3)
		var previous_world: Vector3 = _pivot_world + tangent * (_world_size * RING_RADIUS)
		for segment: int in RING_SEGMENTS:
			var angle: float = TAU * float(segment + 1) / float(RING_SEGMENTS)
			var current_world: Vector3 = _pivot_world + (
				tangent * cos(angle) + bitangent * sin(angle)
			) * (_world_size * RING_RADIUS)
			if not camera.is_position_behind(previous_world) and not camera.is_position_behind(current_world):
				var distance: float = _distance_to_segment(
					screen_position,
					camera.unproject_position(previous_world),
					camera.unproject_position(current_world)
				)
				if distance < best_distance:
					best_distance = distance
					best_axis = axis_index
			previous_world = current_world
	return best_axis


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment: Vector2 = b - a
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_to(a)
	var amount: float = clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(a + segment * amount)


func _local_axis(axis_index: int) -> Vector3:
	match axis_index:
		AXIS_X:
			return Vector3.RIGHT
		AXIS_Y:
			return Vector3.UP
		_:
			return Vector3.BACK


func _axis_name(axis_index: int) -> String:
	match axis_index:
		AXIS_X:
			return "X"
		AXIS_Y:
			return "Y"
		_:
			return "Z"


func _basis_from_y(direction: Vector3) -> Basis:
	var y_axis: Vector3 = direction.normalized()
	var reference: Vector3 = Vector3.FORWARD
	if absf(y_axis.dot(reference)) > 0.98:
		reference = Vector3.RIGHT
	var x_axis: Vector3 = reference.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _ring_point(axis_index: int, angle: float, radius: float = RING_RADIUS) -> Vector3:
	var cosine: float = cos(angle) * radius
	var sine: float = sin(angle) * radius
	match axis_index:
		AXIS_X:
			return Vector3(0.0, cosine, sine)
		AXIS_Y:
			return Vector3(cosine, 0.0, sine)
		_:
			return Vector3(cosine, sine, 0.0)
