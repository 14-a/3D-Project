@tool
class_name GatorTimelineLayerButton
extends Button

signal selection_requested(layer_index: int, additive_selection: bool, range_selection: bool)
signal layers_dropped(source_layer_indices: PackedInt32Array, insertion_index: int, target_group_title: String, preserve_groups: bool, join_target_group: bool, drop_after_target: bool)

var layer_index: int = 0
var selected_layer_indices: Array[int] = []
var target_group_title: String = ""

func _gui_input(input_event: InputEvent) -> void:
	if not input_event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = input_event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	selection_requested.emit(layer_index, mouse_event.is_command_or_control_pressed(), mouse_event.shift_pressed)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var dragged_layer_indices: Array[int] = []
	for selected_layer_index: int in selected_layer_indices:
		dragged_layer_indices.append(selected_layer_index)
	if dragged_layer_indices.is_empty() or not dragged_layer_indices.has(layer_index):
		dragged_layer_indices.clear()
		dragged_layer_indices.append(layer_index)
	dragged_layer_indices.sort()

	var drag_preview: Label = Label.new()
	drag_preview.text = "Move layer %d" % (dragged_layer_indices[0] + 1) if dragged_layer_indices.size() == 1 else "Move %d layers" % dragged_layer_indices.size()
	drag_preview.add_theme_color_override("font_color", Color.WHITE)
	drag_preview.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	drag_preview.add_theme_constant_override("shadow_offset_x", 1)
	drag_preview.add_theme_constant_override("shadow_offset_y", 1)
	set_drag_preview(drag_preview)

	return {
		"gss_timeline_layers": true,
		"layer_indices": dragged_layer_indices,
	}

func _can_drop_data(_at_position: Vector2, drag_data: Variant) -> bool:
	if not drag_data is Dictionary:
		return false
	var drag_dictionary: Dictionary = drag_data
	var raw_layer_indices: Variant = drag_dictionary.get("layer_indices", [])
	return raw_layer_indices is Array and (bool(drag_dictionary.get("gss_timeline_layers", false)) or bool(drag_dictionary.get("gss_timeline_group", false)))

func _drop_data(at_position: Vector2, drag_data: Variant) -> void:
	if not _can_drop_data(at_position, drag_data):
		return
	var drag_dictionary: Dictionary = drag_data
	var raw_layer_indices_variant: Variant = drag_dictionary.get("layer_indices", [])
	if not raw_layer_indices_variant is Array:
		return
	var raw_layer_indices: Array = raw_layer_indices_variant
	var dropped_layer_indices: PackedInt32Array = PackedInt32Array()
	for raw_layer_index: Variant in raw_layer_indices:
		dropped_layer_indices.append(int(raw_layer_index))
	var drop_after_target: bool = at_position.y >= size.y * 0.5
	var insertion_index: int = layer_index + (1 if drop_after_target else 0)
	var preserve_groups: bool = bool(drag_dictionary.get("gss_timeline_group", false))
	# Layer rows are reorder targets only. Joining a group requires dropping on its header.
	layers_dropped.emit(dropped_layer_indices, insertion_index, target_group_title, preserve_groups, false, drop_after_target)
