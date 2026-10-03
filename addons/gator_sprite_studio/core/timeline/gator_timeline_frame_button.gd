@tool
class_name GatorTimelineFrameButton
extends Button

signal selection_requested(frame_index: int, additive_selection: bool, range_selection: bool)
signal frames_dropped(source_frame_indices: PackedInt32Array, insertion_index: int)

var frame_index: int = 0
var selected_frame_indices: Array[int] = []

func _gui_input(input_event: InputEvent) -> void:
	if not input_event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = input_event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	selection_requested.emit(frame_index, mouse_event.is_command_or_control_pressed(), mouse_event.shift_pressed)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var dragged_frame_indices: Array[int] = []
	for selected_frame_index: int in selected_frame_indices:
		dragged_frame_indices.append(selected_frame_index)
	if dragged_frame_indices.is_empty() or not dragged_frame_indices.has(frame_index):
		dragged_frame_indices.clear()
		dragged_frame_indices.append(frame_index)
	dragged_frame_indices.sort()

	var drag_preview: Label = Label.new()
	drag_preview.text = "Move frame %d" % (dragged_frame_indices[0] + 1) if dragged_frame_indices.size() == 1 else "Move %d frames" % dragged_frame_indices.size()
	drag_preview.add_theme_color_override("font_color", Color.WHITE)
	drag_preview.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	drag_preview.add_theme_constant_override("shadow_offset_x", 1)
	drag_preview.add_theme_constant_override("shadow_offset_y", 1)
	set_drag_preview(drag_preview)

	return {
		"gss_timeline_frames": true,
		"frame_indices": dragged_frame_indices,
	}

func _can_drop_data(_at_position: Vector2, drag_data: Variant) -> bool:
	if not drag_data is Dictionary:
		return false
	var drag_dictionary: Dictionary = drag_data
	var raw_frame_indices: Variant = drag_dictionary.get("frame_indices", [])
	return bool(drag_dictionary.get("gss_timeline_frames", false)) and raw_frame_indices is Array

func _drop_data(at_position: Vector2, drag_data: Variant) -> void:
	if not _can_drop_data(at_position, drag_data):
		return
	var drag_dictionary: Dictionary = drag_data
	var raw_frame_indices_variant: Variant = drag_dictionary.get("frame_indices", [])
	if not raw_frame_indices_variant is Array:
		return
	var raw_frame_indices: Array = raw_frame_indices_variant
	var dropped_frame_indices: PackedInt32Array = PackedInt32Array()
	for raw_frame_index: Variant in raw_frame_indices:
		dropped_frame_indices.append(int(raw_frame_index))
	var insertion_index: int = frame_index + (1 if at_position.x >= size.x * 0.5 else 0)
	frames_dropped.emit(dropped_frame_indices, insertion_index)
