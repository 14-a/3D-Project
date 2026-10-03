@tool
class_name GMSAnimationCurveEditor
extends Control

signal curve_committed(channel: int, control_1: Vector2, control_2: Vector2)

enum Channel {
	POSITION,
	ROTATION,
	SCALE,
}

const MARGIN: float = 22.0
const HANDLE_RADIUS: float = 6.0
const BACKGROUND: Color = Color(0.052, 0.057, 0.068, 1.0)
const GRID: Color = Color(0.42, 0.45, 0.52, 0.22)
const CURVE: Color = Color(0.95, 0.66, 0.18, 1.0)
const HANDLE_LINE: Color = Color(0.57, 0.72, 1.0, 0.75)
const HANDLE_FILL: Color = Color(0.76, 0.86, 1.0, 1.0)
const TEXT: Color = Color(0.78, 0.81, 0.87, 0.9)

var channel: int = Channel.POSITION
var control_1: Vector2 = Vector2(0.33, 0.0)
var control_2: Vector2 = Vector2(0.67, 1.0)
var editable: bool = false
var segment_label: String = "Select a key with a following key."
var _drag_handle: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(240.0, 170.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true


func set_curve_data(
	new_channel: int,
	new_control_1: Vector2,
	new_control_2: Vector2,
	can_edit: bool,
	new_segment_label: String
) -> void:
	channel = clampi(new_channel, Channel.POSITION, Channel.SCALE)
	control_1 = Vector2(clampf(new_control_1.x, 0.0, 0.99), clampf(new_control_1.y, -0.5, 1.5))
	control_2 = Vector2(clampf(new_control_2.x, 0.01, 1.0), clampf(new_control_2.y, -0.5, 1.5))
	if control_1.x >= control_2.x:
		var midpoint: float = clampf((control_1.x + control_2.x) * 0.5, 0.01, 0.99)
		control_1.x = midpoint - 0.005
		control_2.x = midpoint + 0.005
	editable = can_edit
	segment_label = new_segment_label
	_drag_handle = -1
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			grab_focus()
			var point_1: Vector2 = _curve_to_screen(control_1)
			var point_2: Vector2 = _curve_to_screen(control_2)
			if mouse.position.distance_squared_to(point_1) <= 12.0 * 12.0:
				_drag_handle = 1
			elif mouse.position.distance_squared_to(point_2) <= 12.0 * 12.0:
				_drag_handle = 2
			else:
				_drag_handle = 1 if mouse.position.x < size.x * 0.5 else 2
				_set_dragged_handle(mouse.position)
			accept_event()
		else:
			if _drag_handle >= 0:
				_set_dragged_handle(mouse.position)
				curve_committed.emit(channel, control_1, control_2)
			_drag_handle = -1
			accept_event()
	elif event is InputEventMouseMotion and _drag_handle >= 0:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if bool(motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_set_dragged_handle(motion.position)
			accept_event()


func _set_dragged_handle(screen_position: Vector2) -> void:
	var curve_point: Vector2 = _screen_to_curve(screen_position)
	if _drag_handle == 1:
		control_1 = _sanitize_control(curve_point, true)
	elif _drag_handle == 2:
		control_2 = _sanitize_control(curve_point, false)
	queue_redraw()


func _sanitize_control(value: Vector2, first: bool) -> Vector2:
	var result: Vector2 = value
	result.x = clampf(result.x, 0.0, 1.0)
	result.y = clampf(result.y, -0.5, 1.5)
	if first:
		result.x = minf(result.x, control_2.x - 0.01) if control_2.x > 0.01 else result.x
	else:
		result.x = maxf(result.x, control_1.x + 0.01) if control_1.x < 0.99 else result.x
	return result


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var rect: Rect2 = Rect2(
		Vector2(MARGIN, MARGIN + 18.0),
		Vector2(maxf(size.x - MARGIN * 2.0, 1.0), maxf(size.y - MARGIN * 2.0 - 18.0, 1.0))
	)
	for grid_index: int in 5:
		var amount: float = float(grid_index) / 4.0
		var x: float = lerpf(rect.position.x, rect.end.x, amount)
		var y: float = lerpf(rect.position.y, rect.end.y, amount)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), GRID, 1.0)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), GRID, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(MARGIN, 16.0),
		segment_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - MARGIN * 2.0,
		11,
		TEXT
	)
	if not editable:
		return
	var start: Vector2 = _curve_to_screen(Vector2.ZERO)
	var end: Vector2 = _curve_to_screen(Vector2.ONE)
	var point_1: Vector2 = _curve_to_screen(control_1)
	var point_2: Vector2 = _curve_to_screen(control_2)
	draw_line(start, point_1, HANDLE_LINE, 1.0, true)
	draw_line(end, point_2, HANDLE_LINE, 1.0, true)
	var samples: PackedVector2Array = PackedVector2Array()
	for sample_index: int in 65:
		var t: float = float(sample_index) / 64.0
		var curve_point: Vector2 = _cubic_point(t, Vector2.ZERO, control_1, control_2, Vector2.ONE)
		samples.append(_curve_to_screen(curve_point))
	draw_polyline(samples, CURVE, 2.0, true)
	for point: Vector2 in [start, end]:
		draw_circle(point, 4.0, CURVE)
	for point: Vector2 in [point_1, point_2]:
		draw_circle(point, HANDLE_RADIUS + 1.5, Color(0.03, 0.035, 0.045, 1.0))
		draw_circle(point, HANDLE_RADIUS, HANDLE_FILL)


func _curve_to_screen(point: Vector2) -> Vector2:
	var width: float = maxf(size.x - MARGIN * 2.0, 1.0)
	var height: float = maxf(size.y - MARGIN * 2.0 - 18.0, 1.0)
	return Vector2(
		MARGIN + point.x * width,
		MARGIN + 18.0 + (1.5 - point.y) / 2.0 * height
	)


func _screen_to_curve(point: Vector2) -> Vector2:
	var width: float = maxf(size.x - MARGIN * 2.0, 1.0)
	var height: float = maxf(size.y - MARGIN * 2.0 - 18.0, 1.0)
	return Vector2(
		clampf((point.x - MARGIN) / width, 0.0, 1.0),
		1.5 - ((point.y - MARGIN - 18.0) / height) * 2.0
	)


static func _cubic_point(t: float, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> Vector2:
	var one_minus: float = 1.0 - t
	return (
		p0 * one_minus * one_minus * one_minus
		+ p1 * 3.0 * one_minus * one_minus * t
		+ p2 * 3.0 * one_minus * t * t
		+ p3 * t * t * t
	)
