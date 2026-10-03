@tool
class_name GASAutomationCurveEditor
extends Control

signal automation_changed

const AutomationEngine := preload("res://addons/gator_audio_studio/audio/automation_engine.gd")

var model: GASEditorModel
var parameter: String = "volume_db"
var minimum_value: float = -60.0
var maximum_value: float = 24.0
var default_curve: String = "linear"
var _drag_index: int = -1
var _dragging: bool = false

const POINT_RADIUS: float = 5.0
const PAD_X: float = 10.0
const PAD_Y: float = 10.0


func _ready() -> void:
	custom_minimum_size = Vector2(420.0, 160.0)
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	set_process_unhandled_input(false)


func set_context(editor_model: GASEditorModel, lane_parameter: String, min_value: float, max_value: float, curve: String) -> void:
	model = editor_model
	parameter = lane_parameter
	minimum_value = min_value
	maximum_value = maxf(min_value + 0.000001, max_value)
	default_curve = curve
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if model == null or model.selected_track < 0 or model.selected_track >= model.tracks.size() or not model.is_track_editable(model.selected_track):
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_begin_point_edit(button.position)
			else:
				_finish_point_edit()
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			_delete_point_at(button.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_drag_point_to(motion.position)
		accept_event()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.055, 0.06, 0.07, 1.0), true)
	draw_rect(rect, Color(0.20, 0.23, 0.27, 1.0), false, 1.0)
	if model == null or model.selected_track < 0 or model.selected_track >= model.tracks.size():
		draw_string(get_theme_default_font(), Vector2(12.0, 24.0), "Select a track to edit automation.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.7, 0.72, 0.75))
		return
	var points: Array[Dictionary] = _points()
	var end_frame: int = _display_end_frame()
	for grid_index: int in range(1, 4):
		var gy: float = lerpf(PAD_Y, size.y - PAD_Y, float(grid_index) / 4.0)
		draw_line(Vector2(PAD_X, gy), Vector2(size.x - PAD_X, gy), Color(0.15, 0.17, 0.20, 1.0), 1.0)
	if points.is_empty():
		draw_string(get_theme_default_font(), Vector2(12.0, 24.0), "Left-click to add automation points. Right-click a point to delete.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.62, 0.66, 0.70))
		return
	var previous: Vector2 = Vector2.ZERO
	var has_previous: bool = false
	var sample_count: int = maxi(64, int(size.x / 5.0))
	for sample_index: int in range(sample_count + 1):
		var frame: int = int(round(float(end_frame) * float(sample_index) / float(sample_count)))
		var value: float = AutomationEngine.value_at(points, frame, float(points[0].get("value", 0.0)))
		var point: Vector2 = Vector2(_x_from_frame(frame, end_frame), _y_from_value(value))
		if has_previous:
			draw_line(previous, point, Color(0.35, 0.80, 0.95, 1.0), 2.0)
		previous = point
		has_previous = true
	for index: int in range(points.size()):
		var lane_point: Dictionary = points[index]
		var point_pos: Vector2 = Vector2(_x_from_frame(int(lane_point.get("frame", 0)), end_frame), _y_from_value(float(lane_point.get("value", 0.0))))
		draw_circle(point_pos, POINT_RADIUS + (2.0 if index == _drag_index else 0.0), Color(0.98, 0.72, 0.25, 1.0))
	var label: String = "%s   %.3g → %.3g" % [parameter, minimum_value, maximum_value]
	draw_string(get_theme_default_font(), Vector2(12.0, size.y - 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.68, 0.72, 0.76))


func _begin_point_edit(position: Vector2) -> void:
	var points: Array[Dictionary] = _points()
	var hit: int = _nearest_point(position, points)
	model.push_undo("Edit Automation")
	if hit < 0:
		var end_frame: int = _display_end_frame()
		points.append({
			"frame": _frame_from_x(position.x, end_frame),
			"value": _value_from_y(position.y),
			"curve": default_curve,
		})
		points = AutomationEngine.sorted_points(points)
		_set_points(points)
		hit = _nearest_point(position, points)
	_drag_index = hit
	_dragging = _drag_index >= 0
	if _dragging:
		_drag_point_to(position)


func _drag_point_to(position: Vector2) -> void:
	var points: Array[Dictionary] = _points()
	if _drag_index < 0 or _drag_index >= points.size():
		return
	var end_frame: int = _display_end_frame()
	points[_drag_index]["frame"] = _frame_from_x(position.x, end_frame)
	points[_drag_index]["value"] = _value_from_y(position.y)
	points[_drag_index]["curve"] = default_curve
	points = AutomationEngine.sorted_points(points)
	_set_points(points)
	_drag_index = _nearest_point(position, points)
	queue_redraw()
	automation_changed.emit()


func _finish_point_edit() -> void:
	if _dragging:
		model.dirty = true
		automation_changed.emit()
	_dragging = false
	_drag_index = -1
	queue_redraw()


func _delete_point_at(position: Vector2) -> void:
	var points: Array[Dictionary] = _points()
	var hit: int = _nearest_point(position, points)
	if hit < 0:
		return
	model.push_undo("Delete Automation Point")
	points.remove_at(hit)
	_set_points(points)
	model.dirty = true
	queue_redraw()
	automation_changed.emit()


func _points() -> Array[Dictionary]:
	if model == null or model.selected_track < 0 or model.selected_track >= model.tracks.size():
		var empty_points: Array[Dictionary] = []
		return empty_points
	return AutomationEngine.lane_points(model.tracks[model.selected_track].automation_lanes, parameter)


func _set_points(points: Array[Dictionary]) -> void:
	if model == null or model.selected_track < 0 or model.selected_track >= model.tracks.size():
		return
	model.tracks[model.selected_track].automation_lanes[parameter] = AutomationEngine.sorted_points(points)
	model.dirty = true


func _display_end_frame() -> int:
	if model == null:
		return 1
	return maxi(1, maxi(model.project_end_frame(), model.sample_rate * 5))


func _nearest_point(position: Vector2, points: Array[Dictionary]) -> int:
	var end_frame: int = _display_end_frame()
	var best_index: int = -1
	var best_distance: float = POINT_RADIUS * 2.4
	for index: int in range(points.size()):
		var lane_point: Dictionary = points[index]
		var point_pos: Vector2 = Vector2(_x_from_frame(int(lane_point.get("frame", 0)), end_frame), _y_from_value(float(lane_point.get("value", 0.0))))
		var distance: float = point_pos.distance_to(position)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


func _x_from_frame(frame: int, end_frame: int) -> float:
	var usable: float = maxf(1.0, size.x - PAD_X * 2.0)
	return PAD_X + clampf(float(frame) / float(maxi(1, end_frame)), 0.0, 1.0) * usable


func _frame_from_x(x: float, end_frame: int) -> int:
	var usable: float = maxf(1.0, size.x - PAD_X * 2.0)
	var t: float = clampf((x - PAD_X) / usable, 0.0, 1.0)
	return int(round(t * float(end_frame)))


func _y_from_value(value: float) -> float:
	var usable: float = maxf(1.0, size.y - PAD_Y * 2.0)
	var t: float = inverse_lerp(minimum_value, maximum_value, clampf(value, minimum_value, maximum_value))
	return size.y - PAD_Y - t * usable


func _value_from_y(y: float) -> float:
	var usable: float = maxf(1.0, size.y - PAD_Y * 2.0)
	var t: float = clampf((size.y - PAD_Y - y) / usable, 0.0, 1.0)
	return lerpf(minimum_value, maximum_value, t)
