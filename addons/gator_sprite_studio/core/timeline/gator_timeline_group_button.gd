@tool
class_name GatorTimelineGroupButton
extends Button

signal group_selection_requested(group_title: String)
signal layers_dropped(source_layer_indices: PackedInt32Array, insertion_index: int, target_group_title: String, preserve_groups: bool, join_target_group: bool, drop_after_target: bool)

var group_title: String = ""
var member_layer_indices: Array[int] = []

func _gui_input(input_event: InputEvent) -> void:
	if not input_event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = input_event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	group_selection_requested.emit(group_title)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if member_layer_indices.is_empty():
		return null
	var drag_preview: Label = Label.new()
	drag_preview.text = "Move %s (%d layers)" % [group_title, member_layer_indices.size()]
	drag_preview.add_theme_color_override("font_color", Color.WHITE)
	drag_preview.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	drag_preview.add_theme_constant_override("shadow_offset_x", 1)
	drag_preview.add_theme_constant_override("shadow_offset_y", 1)
	set_drag_preview(drag_preview)
	return {
		"gss_timeline_group": true,
		"group_title": group_title,
		"layer_indices": member_layer_indices.duplicate(),
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
	var is_group_drag: bool = bool(drag_dictionary.get("gss_timeline_group", false))
	var normalized_drop_y: float = at_position.y / maxf(1.0, size.y)
	var drop_after_target: bool = normalized_drop_y >= 0.5
	var insertion_index: int
	var target_group: String = group_title
	var join_target_group: bool = false
	if is_group_drag:
		insertion_index = member_layer_indices[0] if not drop_after_target else member_layer_indices[member_layer_indices.size() - 1] + 1
		target_group = ""
	elif normalized_drop_y < 0.25:
		# The top edge is a reorder target before the whole group.
		insertion_index = member_layer_indices[0]
		drop_after_target = false
	elif normalized_drop_y > 0.75:
		# The bottom edge is a reorder target after the whole group.
		insertion_index = member_layer_indices[member_layer_indices.size() - 1] + 1
		drop_after_target = true
	else:
		# Only the center of a group header adds layers to the group.
		insertion_index = member_layer_indices[member_layer_indices.size() - 1] + 1
		join_target_group = true
	layers_dropped.emit(dropped_layer_indices, insertion_index, target_group, is_group_drag, join_target_group, drop_after_target)
