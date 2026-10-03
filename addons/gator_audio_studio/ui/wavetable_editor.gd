@tool
class_name GASWavetableEditor
extends Control

signal values_changed(values: PackedFloat32Array)

var values: PackedFloat32Array = PackedFloat32Array()
var tool: String = "Pencil"
var _dragging: bool = false
var _last_index: int = -1
var _last_value: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(280, 140)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if values.is_empty():
		set_size_steps(32)


func set_size_steps(step_count: int) -> void:
	var count: int = maxi(2, step_count)
	values.resize(count)
	for i: int in range(count):
		values[i] = 0.0
	queue_redraw()
	emit_signal("values_changed", values)


func set_values(new_values: PackedFloat32Array) -> void:
	if new_values.is_empty():
		return
	values = new_values
	queue_redraw()


func get_values() -> PackedFloat32Array:
	return values


func set_tool(new_tool: String) -> void:
	tool = new_tool


func _gui_input(event: InputEvent) -> void:
	if values.is_empty():
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		_dragging = mouse_button.pressed
		if _dragging:
			_apply_point(mouse_button.position)
		else:
			_last_index = -1
	elif event is InputEventMouseMotion and _dragging:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_apply_point(mouse_motion.position)


func _apply_point(pos: Vector2) -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var index: int = clampi(int(floor((pos.x / rect.size.x) * values.size())), 0, values.size() - 1)
	var v: float = clampf(1.0 - (pos.y / rect.size.y) * 2.0, -1.0, 1.0)
	if tool == "Line" and _last_index >= 0 and _last_index != index:
		var start_idx: int = _last_index
		var end_idx: int = index
		var start_v: float = _last_value
		var end_v: float = v
		if start_idx > end_idx:
			start_idx = index
			end_idx = _last_index
			start_v = v
			end_v = _last_value
		for i: int in range(start_idx, end_idx + 1):
			var u: float = 0.0 if end_idx == start_idx else float(i - start_idx) / float(end_idx - start_idx)
			values[i] = lerpf(start_v, end_v, u)
	else:
		values[index] = v
	_last_index = index
	_last_value = v
	queue_redraw()
	emit_signal("values_changed", values)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.11, 0.13), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.28, 0.32, 0.38), false, 1.0)
	if values.is_empty():
		return
	var mid_y: float = size.y * 0.5
	draw_line(Vector2(0, mid_y), Vector2(size.x, mid_y), Color(0.3, 0.33, 0.38), 1.0)
	var step_x: float = size.x / float(values.size() - 1)
	for i: int in range(values.size()):
		var x: float = float(i) * step_x
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.14, 0.16, 0.19), 1.0)
	var points: PackedVector2Array = []
	for i: int in range(values.size()):
		var x: float = float(i) * step_x
		var y: float = size.y * (1.0 - ((values[i] + 1.0) * 0.5))
		points.append(Vector2(x, y))
	for i: int in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color(0.35, 0.8, 0.95), 2.0)
	for point: Vector2 in points:
		draw_circle(point, 2.5, Color(0.88, 0.95, 1.0))
