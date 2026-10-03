@tool
class_name GMSViewOrientationGizmo
extends Control

signal axis_view_requested(direction: Vector3, up: Vector3)

const GIZMO_SIZE: Vector2 = Vector2(92.0, 92.0)
const CENTER: Vector2 = Vector2(46.0, 46.0)
const AXIS_RADIUS: float = 29.0
const KNOB_DIAMETER: float = 12.0
const KNOB_BORDER_WIDTH: float = 1.0
const LABEL_PADDING: float = 2.0

const AXIS_X_COLOR: Color = Color(0.95, 0.22, 0.28)
const AXIS_Y_COLOR: Color = Color(0.42, 0.86, 0.12)
const AXIS_Z_COLOR: Color = Color(0.12, 0.48, 0.96)

var _camera_basis: Basis = Basis.IDENTITY
var _axis_buttons: Array[Button] = []
var _axis_directions: Array[Vector3] = [
	Vector3.RIGHT,
	Vector3.LEFT,
	Vector3.UP,
	Vector3.DOWN,
	Vector3.BACK,
	Vector3.FORWARD,
]
var _axis_up_vectors: Array[Vector3] = [
	Vector3.UP,
	Vector3.UP,
	Vector3.BACK,
	Vector3.BACK,
	Vector3.UP,
	Vector3.UP,
]
var _axis_colors: Array[Color] = [
	AXIS_X_COLOR,
	AXIS_X_COLOR,
	AXIS_Y_COLOR,
	AXIS_Y_COLOR,
	AXIS_Z_COLOR,
	AXIS_Z_COLOR,
]
var _axis_labels: PackedStringArray = PackedStringArray(["+X", "-X", "+Y", "-Y", "+Z", "-Z"])
var _axis_tooltips: PackedStringArray = PackedStringArray([
	"Right view (+X)",
	"Left view (-X)",
	"Top view (+Y)",
	"Bottom view (-Y)",
	"Front view (+Z)",
	"Back view (-Z)",
])
var _projected_positions: PackedVector2Array = PackedVector2Array()
var _projected_depths: PackedFloat32Array = PackedFloat32Array()
var _knob_centers: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	custom_minimum_size = GIZMO_SIZE
	size = GIZMO_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_build_axis_buttons()
	_update_layout()


func set_camera_basis(camera_basis: Basis) -> void:
	_camera_basis = camera_basis.orthonormalized()
	_update_layout()


func _build_axis_buttons() -> void:
	if not _axis_buttons.is_empty():
		return
	for axis_index: int in range(_axis_directions.size()):
		var button: Button = Button.new()
		button.name = "Axis%d" % axis_index
		button.text = _axis_labels[axis_index]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = _axis_tooltips[axis_index]
		button.add_theme_font_size_override("font_size", 9)
		button.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
		button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.92, 0.94, 0.97))
		button.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.09, 0.95))
		button.add_theme_constant_override("outline_size", 1)
		_apply_button_style(button, _axis_colors[axis_index])
		button.pressed.connect(_on_axis_pressed.bind(axis_index))
		add_child(button)
		_axis_buttons.append(button)


func _apply_button_style(button: Button, color: Color) -> void:
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)


func _update_layout() -> void:
	if _axis_buttons.is_empty():
		return

	_projected_positions.resize(_axis_directions.size())
	_projected_depths.resize(_axis_directions.size())
	_knob_centers.resize(_axis_directions.size())

	for axis_index: int in range(_axis_directions.size()):
		var direction: Vector3 = _axis_directions[axis_index]
		var projected: Vector2 = Vector2(
			direction.dot(_camera_basis.x),
			-direction.dot(_camera_basis.y)
		)
		var depth: float = direction.dot(_camera_basis.z)
		var tip_position: Vector2 = CENTER + projected * AXIS_RADIUS
		_projected_positions[axis_index] = tip_position
		_projected_depths[axis_index] = depth

		var depth_scale: float = lerpf(0.88, 1.12, (depth + 1.0) * 0.5)
		var knob_radius: float = KNOB_DIAMETER * depth_scale * 0.5
		var knob_center: Vector2 = tip_position
		if projected.length_squared() > 0.0001:
			knob_center += projected.normalized() * knob_radius
		_knob_centers[axis_index] = knob_center

		var button: Button = _axis_buttons[axis_index]
		var font: Font = button.get_theme_font("font")
		var font_size: int = button.get_theme_font_size("font_size")
		var text_size: Vector2 = Vector2.ZERO
		if font != null:
			text_size = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var hit_size: Vector2 = Vector2(
			maxf(text_size.x + LABEL_PADDING * 2.0, KNOB_DIAMETER),
			maxf(text_size.y + LABEL_PADDING * 2.0, KNOB_DIAMETER)
		)
		button.size = hit_size
		button.position = knob_center - hit_size * 0.5
		var is_positive: bool = axis_index % 2 == 0
		button.z_index = int(round((depth + 1.0) * 50.0)) + (1 if is_positive else 0)

	_sort_buttons_by_depth()
	queue_redraw()


func _sort_buttons_by_depth() -> void:
	var order: Array[int] = []
	for axis_index: int in range(_axis_buttons.size()):
		order.append(axis_index)

	for left_index: int in range(order.size()):
		for right_index: int in range(left_index + 1, order.size()):
			var left_axis: int = order[left_index]
			var right_axis: int = order[right_index]
			var left_depth: float = _projected_depths[left_axis]
			var right_depth: float = _projected_depths[right_axis]
			if left_axis % 2 == 0:
				left_depth += 0.001
			if right_axis % 2 == 0:
				right_depth += 0.001
			if right_depth < left_depth:
				var temporary: int = order[left_index]
				order[left_index] = order[right_index]
				order[right_index] = temporary

	for child_index: int in range(order.size()):
		move_child(_axis_buttons[order[child_index]], child_index)


func _draw() -> void:
	draw_circle(CENTER, 39.0, Color(0.055, 0.062, 0.075, 0.72))
	draw_arc(CENTER, 39.0, 0.0, TAU, 48, Color(0.52, 0.57, 0.66, 0.55), 1.0, true)

	for axis_pair_start: int in range(0, _axis_directions.size(), 2):
		var positive_position: Vector2 = _projected_positions[axis_pair_start]
		var negative_position: Vector2 = _projected_positions[axis_pair_start + 1]
		var color: Color = _axis_colors[axis_pair_start]
		draw_line(negative_position, positive_position, color.darkened(0.18), 2.0, true)

	for axis_index: int in range(_axis_directions.size()):
		var depth_scale: float = lerpf(0.88, 1.12, (_projected_depths[axis_index] + 1.0) * 0.5)
		var knob_radius: float = KNOB_DIAMETER * depth_scale * 0.5
		var knob_color: Color = _axis_colors[axis_index]
		draw_circle(_knob_centers[axis_index], knob_radius, knob_color)
		draw_arc(
			_knob_centers[axis_index],
			knob_radius,
			0.0,
			TAU,
			16,
			knob_color.lightened(0.3),
			KNOB_BORDER_WIDTH,
			true
		)

	draw_circle(CENTER, 4.0, Color(0.72, 0.76, 0.84, 0.9))


func _on_axis_pressed(axis_index: int) -> void:
	if axis_index < 0 or axis_index >= _axis_directions.size():
		return
	axis_view_requested.emit(
		_axis_directions[axis_index],
		_axis_up_vectors[axis_index]
	)
