@tool
class_name GMSAnimationTimeline
extends Control

signal frame_requested(frame: int)
signal bone_requested(bone_index: int)
signal key_requested(bone_index: int, frame: int, additive: bool)
signal key_move_requested(bone_index: int, old_frame: int, new_frame: int)

const HEADER_HEIGHT: float = 28.0
const ROW_HEIGHT: float = 23.0
const LABEL_WIDTH: float = 132.0
const KEY_RADIUS: float = 5.0
const BACKGROUND: Color = Color(0.055, 0.06, 0.072, 1.0)
const HEADER_COLOR: Color = Color(0.075, 0.082, 0.098, 1.0)
const ROW_ALT: Color = Color(0.075, 0.08, 0.092, 0.55)
const GRID_COLOR: Color = Color(0.36, 0.39, 0.46, 0.22)
const TEXT_COLOR: Color = Color(0.88, 0.9, 0.94, 0.95)
const MUTED_TEXT: Color = Color(0.62, 0.65, 0.72, 0.9)
const KEY_COLOR: Color = Color(0.96, 0.65, 0.16, 1.0)
const SELECTED_KEY_COLOR: Color = Color(1.0, 0.92, 0.42, 1.0)
const CURRENT_FRAME_COLOR: Color = Color(0.95, 0.24, 0.22, 0.95)
const SELECTED_ROW_COLOR: Color = Color(0.24, 0.42, 0.72, 0.22)

var rig: GMSRigData
var clip: GMSAnimationClip
var current_frame: int = 0
var selected_bone_index: int = -1
var selected_keys: PackedStringArray = PackedStringArray()
var _drag_bone_index: int = -1
var _drag_old_frame: int = -1
var _drag_preview_frame: int = -1
var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(420.0, 210.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true


func set_timeline_data(
	new_rig: GMSRigData,
	new_clip: GMSAnimationClip,
	new_frame: int,
	new_selected_bone: int,
	new_selected_keys: PackedStringArray
) -> void:
	rig = new_rig
	clip = new_clip
	current_frame = maxi(new_frame, 0)
	selected_bone_index = new_selected_bone
	selected_keys = new_selected_keys.duplicate()
	var rows: int = rig.bones.size() if rig != null else 1
	custom_minimum_size.y = maxf(150.0, HEADER_HEIGHT + ROW_HEIGHT * float(rows) + 2.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if clip == null or rig == null:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			grab_focus()
			var key_hit: Dictionary = _find_key(mouse.position)
			if not key_hit.is_empty():
				_drag_bone_index = int(key_hit["bone_index"])
				_drag_old_frame = int(key_hit["frame"])
				_drag_preview_frame = _drag_old_frame
				_drag_start = mouse.position
				_dragging = false
				key_requested.emit(
					_drag_bone_index,
					_drag_old_frame,
					mouse.shift_pressed or mouse.ctrl_pressed
				)
				accept_event()
				return
			var frame: int = _frame_from_x(mouse.position.x)
			frame_requested.emit(frame)
			var bone_index: int = _bone_from_y(mouse.position.y)
			if bone_index >= 0:
				bone_requested.emit(bone_index)
			accept_event()
		else:
			if _drag_bone_index >= 0 and _dragging and _drag_preview_frame != _drag_old_frame:
				key_move_requested.emit(_drag_bone_index, _drag_old_frame, _drag_preview_frame)
			_drag_bone_index = -1
			_drag_old_frame = -1
			_drag_preview_frame = -1
			_dragging = false
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _drag_bone_index >= 0 and bool(motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
			if motion.position.distance_to(_drag_start) >= 3.0:
				_dragging = true
			_drag_preview_frame = _frame_from_x(motion.position.x)
			queue_redraw()
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, HEADER_HEIGHT)), HEADER_COLOR)
	draw_line(Vector2(LABEL_WIDTH, 0.0), Vector2(LABEL_WIDTH, size.y), GRID_COLOR, 1.0)
	if clip == null or rig == null:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(12.0, 24.0),
			"Create or select an animation clip.",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			13,
			MUTED_TEXT
		)
		return

	var frame_count: int = maxi(clip.frame_count, 1)
	var major_step: int = _major_frame_step(frame_count)
	for frame: int in range(0, frame_count + 1):
		if frame % major_step != 0 and frame != frame_count:
			continue
		var x: float = _x_from_frame(frame)
		draw_line(Vector2(x, HEADER_HEIGHT), Vector2(x, size.y), GRID_COLOR, 1.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + 3.0, 19.0),
			str(frame),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			10,
			MUTED_TEXT
		)

	for bone_index: int in rig.bones.size():
		var top: float = HEADER_HEIGHT + float(bone_index) * ROW_HEIGHT
		if bone_index % 2 == 1:
			draw_rect(Rect2(Vector2(0.0, top), Vector2(size.x, ROW_HEIGHT)), ROW_ALT)
		if bone_index == selected_bone_index:
			draw_rect(Rect2(Vector2(0.0, top), Vector2(size.x, ROW_HEIGHT)), SELECTED_ROW_COLOR)
		draw_line(Vector2(0.0, top + ROW_HEIGHT), Vector2(size.x, top + ROW_HEIGHT), GRID_COLOR, 1.0)
		var bone: GMSBoneData = rig.bones[bone_index]
		draw_string(
			ThemeDB.fallback_font,
			Vector2(8.0, top + 16.0),
			bone.display_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			LABEL_WIDTH - 14.0,
			11,
			TEXT_COLOR if bone_index == selected_bone_index else MUTED_TEXT
		)
		var track: GMSBoneAnimationTrack = clip.find_track(bone.bone_id, bone.display_name)
		if track == null:
			continue
		for key: GMSAnimationKey in track.keys:
			if key == null:
				continue
			var key_frame: int = key.frame
			if _drag_bone_index == bone_index and _drag_old_frame == key.frame and _dragging:
				key_frame = _drag_preview_frame
			var point: Vector2 = Vector2(_x_from_frame(key_frame), top + ROW_HEIGHT * 0.5)
			var is_selected: bool = selected_keys.has(_key_id(bone.bone_id, key.frame))
			_draw_key(point, SELECTED_KEY_COLOR if is_selected else KEY_COLOR)

	var current_x: float = _x_from_frame(clampi(current_frame, 0, frame_count))
	draw_line(Vector2(current_x, 0.0), Vector2(current_x, size.y), CURRENT_FRAME_COLOR, 2.0, true)
	draw_circle(Vector2(current_x, 6.0), 4.0, CURRENT_FRAME_COLOR)


func _draw_key(point: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		point + Vector2(0.0, -KEY_RADIUS),
		point + Vector2(KEY_RADIUS, 0.0),
		point + Vector2(0.0, KEY_RADIUS),
		point + Vector2(-KEY_RADIUS, 0.0),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.05, 0.055, 0.065, 1.0), 1.0, true)


func _find_key(position: Vector2) -> Dictionary:
	var bone_index: int = _bone_from_y(position.y)
	if bone_index < 0 or bone_index >= rig.bones.size():
		return {}
	var bone: GMSBoneData = rig.bones[bone_index]
	var track: GMSBoneAnimationTrack = clip.find_track(bone.bone_id, bone.display_name)
	if track == null:
		return {}
	for key: GMSAnimationKey in track.keys:
		if key == null:
			continue
		var point: Vector2 = Vector2(
			_x_from_frame(key.frame),
			HEADER_HEIGHT + float(bone_index) * ROW_HEIGHT + ROW_HEIGHT * 0.5
		)
		if position.distance_squared_to(point) <= 9.0 * 9.0:
			return {"bone_index": bone_index, "frame": key.frame}
	return {}


func _bone_from_y(y: float) -> int:
	if y < HEADER_HEIGHT or rig == null:
		return -1
	var bone_index: int = int(floor((y - HEADER_HEIGHT) / ROW_HEIGHT))
	return bone_index if bone_index >= 0 and bone_index < rig.bones.size() else -1


func _frame_from_x(x: float) -> int:
	if clip == null:
		return 0
	var width: float = maxf(size.x - LABEL_WIDTH - 10.0, 1.0)
	var amount: float = clampf((x - LABEL_WIDTH) / width, 0.0, 1.0)
	return int(round(amount * float(clip.frame_count)))


func _x_from_frame(frame: int) -> float:
	if clip == null:
		return LABEL_WIDTH
	var width: float = maxf(size.x - LABEL_WIDTH - 10.0, 1.0)
	return LABEL_WIDTH + width * (float(frame) / float(maxi(clip.frame_count, 1)))


func _major_frame_step(frame_count: int) -> int:
	if frame_count <= 24:
		return 2
	if frame_count <= 60:
		return 5
	if frame_count <= 180:
		return 10
	if frame_count <= 600:
		return 30
	return maxi(60, int(ceil(float(frame_count) / 20.0)))


static func _key_id(bone_id: String, frame: int) -> String:
	return "%s|%d" % [bone_id, frame]
